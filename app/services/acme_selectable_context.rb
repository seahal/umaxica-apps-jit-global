# typed: false
# frozen_string_literal: true

# Shared selectable-context resolution for the Acme surfaces.
#
# Both the login-time selector (BaseSelectorAuthority) and the post-login switcher
# (BaseSwitcherAuthority) need the same notion of "which account / organization / avatar
# combinations is this principal actually allowed to act as", and the same atomic
# persistence of a chosen combination onto the session token. This module is the single
# source of truth for that candidate resolution and persistence so the two authorities can
# never drift apart on what counts as a valid context.
#
# Includers must expose private readers `config` (an AcmeSelectorSurfaceConfig), `principal`
# (the authenticated subject), and `session` (the session token, may be nil for read-only
# use).
module AcmeSelectableContext
  # Raised when a chosen context cannot be persisted (e.g. no session token to write to).
  InvalidSelection = Class.new(StandardError)

  # Every (account, collective, unit, avatar) combination the principal may act as. For
  # optional and unsupported Avatar modes the nil slot is explicit. Avatar candidates require
  # current ownership by the membership's collective and surface-specific avatar.view permission.
  def selectable_candidates
    accounts.flat_map do |account|
      account.current_memberships.flat_map do |membership|
        next [] unless membership.active?

        collective = membership.collective
        unit = membership.collective_unit
        avatars_for(account: account, collective: collective).map do |avatar|
          candidate(account: account, collective: collective, unit: unit, avatar: avatar)
        end
      end
    end
  end

  # The single candidate matching the supplied public ids, or nil when the combination is not
  # a real candidate for this principal (cross-user, inconsistent, or avatar mismatch).
  def candidate_for_public_ids(params)
    normalized = {
      account_public_id: params[:account_public_id].presence,
      organization_public_id: params[:organization_public_id].presence || params[:collective_public_id].presence,
      organization_unit_public_id: params[:organization_unit_public_id].presence ||
        params[:collective_unit_public_id].presence,
      avatar_public_id: params[:avatar_public_id].presence,
    }

    selectable_candidates.find do |candidate|
      public_ids = candidate.fetch(:public)
      public_ids[:account_public_id] == normalized[:account_public_id] &&
        public_ids[:organization_public_id] == normalized[:organization_public_id] &&
        public_ids[:organization_unit_public_id] == normalized[:organization_unit_public_id] &&
        public_ids[:avatar_public_id].to_s == normalized[:avatar_public_id].to_s
    end
  end

  # Atomically write the chosen candidate's public ids onto the session token. Validation is
  # the caller's responsibility (candidate must already be confirmed); this only persists.
  def persist_selection!(candidate)
    raise InvalidSelection, "session_required" if session.blank?

    public_ids = candidate.fetch(:public)
    connection_owner(session.class).connected_to(role: :writing) do
      session.with_lock do
        raise InvalidSelection, "invalid_selection" unless candidate_still_authorized?(public_ids)

        attributes = {
          selected_account_public_id: public_ids[:account_public_id],
          selected_collective_public_id: public_ids[:organization_public_id],
          selected_collective_unit_public_id: public_ids[:organization_unit_public_id],
          selected_at: Time.current,
        }
        if session.respond_to?(:selected_avatar_public_id=)
          attributes[:selected_avatar_public_id] = public_ids[:avatar_public_id]
        elsif config.avatar_mode != :none
          raise InvalidSelection, "avatar_selection_storage_required"
        end

        session.update!(attributes)
      end
    end
  end

  # Flattened, view-friendly serialization of candidates for JSON responses.
  def serialize_candidates(candidates)
    candidates.flatten!
    candidates.map do |candidate|
      public_ids = candidate.fetch(:public)
      {
        public_id: public_ids[:account_public_id],
        organization: {
          public_id: public_ids[:organization_public_id],
          unit_public_id: public_ids[:organization_unit_public_id],
        },
        avatar: public_ids[:avatar_public_id].present? ? { public_id: public_ids[:avatar_public_id] } : nil,
      }
    end
  end

  private

  def accounts
    config.account_class
      .joins(config.account_identity_association)
      .where(config.identity_class.table_name => { source_record_id: principal.id })
      .order(:created_at, :id)
  end

  def avatars_for(account:, collective:)
    return [nil] if config.avatar_mode == :none
    unless %i(required optional).include?(config.avatar_mode)
      raise ArgumentError, "unsupported Avatar mode: #{config.avatar_mode.inspect}"
    end

    authorized = AvatarPermissionResolver.call(
      actor: principal,
      surface: config.surface,
      subject_public_id: account.public_id,
      owner_collective_public_id: collective.public_id,
      permission: "avatar.view",
    )
    avatars =
      if authorized
        Avatar
          .joins(:current_ownership_period, :lifecycle_state)
          .where(
            avatar_ownership_periods: {
              owner_surface: config.surface.to_s,
              owner_collective_public_id: collective.public_id,
            },
            avatar_lifecycle_states: { key: "active" },
          )
          .where("avatars.discard_at > ?", Time.current)
          .distinct
          .order(:created_at, :id)
      else
        Avatar.none
      end

    case config.avatar_mode
    when :required then avatars.to_a
    when :optional then [nil, *avatars.to_a]
    end
  end

  def candidate(account:, collective:, unit:, avatar:)
    {
      account: account,
      collective: collective,
      unit: unit,
      avatar: avatar,
      public: {
        account_public_id: account.public_id,
        organization_public_id: collective.public_id,
        organization_unit_public_id: unit.public_id,
        avatar_public_id: avatar&.public_id,
      },
    }
  end

  def candidate_still_authorized?(public_ids)
    account = nil
    connection_owner(config.account_class).connected_to(role: :writing) do
      account = config.account_class.lock.find_by(public_id: public_ids[:account_public_id])
    end
    return false unless account

    membership = nil
    connection_owner(config.membership_class).connected_to(role: :writing) do
      membership =
        account.current_memberships.lock.find do |candidate_membership|
          candidate_membership.active? &&
            candidate_membership.collective.public_id == public_ids[:organization_public_id] &&
            candidate_membership.collective_unit.public_id == public_ids[:organization_unit_public_id]
        end
    end
    return false unless membership
    return true if config.avatar_mode == :none
    return true if config.avatar_mode == :optional && public_ids[:avatar_public_id].blank?
    return false if config.avatar_mode == :required && public_ids[:avatar_public_id].blank?

    authorized = AvatarPermissionResolver.call(
      actor: principal,
      surface: config.surface,
      subject_public_id: public_ids[:account_public_id],
      owner_collective_public_id: public_ids[:organization_public_id],
      permission: "avatar.view",
    )
    return false unless authorized

    connection_owner(Avatar).connected_to(role: :writing) do
      Avatar
        .joins(:current_ownership_period, :lifecycle_state)
        .lock
        .where(public_id: public_ids[:avatar_public_id])
        .where(
          avatar_ownership_periods: {
            owner_surface: config.surface.to_s,
            owner_collective_public_id: public_ids[:organization_public_id],
          },
          avatar_lifecycle_states: { key: "active" },
        )
        .exists?(["avatars.discard_at > ?", Time.current])
    end
  end

  def connection_owner(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end
end
