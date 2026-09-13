# typed: false
# frozen_string_literal: true

# Post-login context switcher authority.
#
# Unlike the selector (which commits the first context during the login ceremony), the switcher
# changes the already-selected account / organization / avatar for a full-access actor. It shares
# the same candidate resolution and atomic persistence as the selector via AcmeSelectableContext,
# so a switch can only ever land on a context the principal is genuinely allowed to act as.
#
# It also exposes read helpers used by the surface-local accounts/organizations/avatars CRUD
# controllers to scope entity lookups to the principal's available set (the authoritative
# ownership/membership gate).
class BaseSwitcherAuthority
  include AcmeSelectableContext

  # Raised when the requested account/organization/avatar combination is not a real candidate
  # for the principal (cross-user, inconsistent, or avatar mismatch on an avatar-required surface).
  InvalidSwitch = Class.new(StandardError)

  def self.current(surface:, principal:, session:)
    new(surface: surface, principal: principal, session: session).current
  end

  def self.switch(surface:, principal:, session:, params:)
    new(surface: surface, principal: principal, session: session).switch(params)
  end

  def initialize(surface:, principal:, session: nil)
    @config = AcmeSelector.config_for(surface)
    @principal = principal
    @session = session
  end

  # Current selection plus the candidates the actor may switch to.
  def current
    {
      status: "ok",
      current: current_selection,
      candidates: serialize_candidates(selectable_candidates),
    }
  end

  # Validate the requested combination against real candidates and, only on success, atomically
  # persist it. On failure nothing is written, so the current context is left unchanged.
  def switch(params)
    candidate = candidate_for_public_ids(params)
    raise InvalidSwitch, "invalid_switch" if candidate.blank?

    persist_selection!(candidate)
    { status: "switched", next: "/dashboard" }
  end

  # --- Read helpers for entity CRUD controllers (scoped to the principal's available set) ---

  def available_accounts
    result = selectable_candidates.map { |candidate| candidate.fetch(:account) }
    result.uniq!
    result
  end

  def available_organizations
    result = selectable_candidates.map { |candidate| candidate.fetch(:collective) }
    result.uniq!
    result
  end

  def available_avatars
    result = selectable_candidates.filter_map { |candidate| candidate.fetch(:avatar) }
    result.uniq!(&:id)
    result
  end

  def find_account(public_id)
    return if public_id.blank?

    available_accounts.find { |account| account.public_id == public_id }
  end

  def find_organization(public_id)
    return if public_id.blank?

    available_organizations.find { |organization| organization.public_id == public_id }
  end

  def find_avatar(public_id)
    return if public_id.blank?

    available_avatars.find { |avatar| avatar.public_id == public_id }
  end

  private

  attr_reader :config, :principal, :session

  def current_selection
    return nil if session.blank?

    {
      account_public_id: session.try(:selected_account_public_id),
      organization_public_id: session.try(:selected_collective_public_id),
      organization_unit_public_id: session.try(:selected_collective_unit_public_id),
      avatar_public_id: session.try(:selected_avatar_public_id),
    }
  end
end
