# typed: false
# frozen_string_literal: true

module SingleUseToken
  extend ActiveSupport::Concern
  include RefreshTokenShared

  PREFERENCE_REFRESH_TTL = 400.days

  # Concurrency grace window for refresh-token rotation. A single page load can
  # fire several requests that all carry the pre-rotation refresh cookie; the
  # first rotates it and the rest then present an already-consumed token. Within
  # this short window such a presentation is treated as a benign sibling request
  # rather than a stolen-token replay. Kept intentionally tight: it widens the
  # "consumed token still honored" window, so only just-rotated tokens that still
  # have a usable replacement qualify (see PreferenceBase grace handling).
  PREFERENCE_REFRESH_GRACE_WINDOW = 30.seconds

  PREFERENCE_CHILD_SUFFIXES = %w(
    cookie region timezone language theme currency date_format time_format
    motion density page_size adult_content_gate
  ).freeze

  included do
    scope :active, -> { where(arel_table[:discard_at].gt(Time.current)) }
    scope :unconsumed, -> { where(used_at: nil) }
  end

  class_methods do
    def consume_once_by_digest!(digest:, now: Time.current)
      return nil if digest.blank?

      consumed_at = now
      consumed = nil
      with_writing_role do
        transaction do
          record = lock_consumable_by_digest(digest, now: consumed_at)
          next unless record

          consumed = consume_record!(record, now: consumed_at)
        end
      end
      consumed
    end

    def rotate!(presented_digest:, now: Time.current)
      replacement = nil
      raw_refresh_token = nil

      with_writing_role do
        transaction do
          consumed = lock_consumable_by_digest(presented_digest, now: now)
          next unless consumed

          consume_record!(consumed, now: now)
          replacement = create_rotated_record!(consumed, now: now)
          link_consumed_record_to_replacement!(consumed, replacement, now: now)
          raw_refresh_token = replacement.issued_refresh_token
        end
      end

      return nil unless replacement

      replacement.issued_refresh_token = raw_refresh_token
      replacement
    end

    private

    def lock_consumable_by_digest(digest, now:)
      lock_refresh_token_record_by_digest(
        digest,
        digest_column: :token_digest,
        unused_column: :used_at,
        expires_at_column: :discard_at,
        now: now,
      )
    end

    def consume_record!(record, now:)
      record.update!(used_at: now, updated_at: now)
      record
    end

    def create_rotated_record!(consumed, now:)
      # dbsc_session_id is unique: the DBSC binding moves to the replacement, so the consumed
      # record releases it first.
      bound_session_id = consumed.dbsc_session_id
      consumed.update!(dbsc_session_id: nil, updated_at: now) if bound_session_id.present?

      attrs = {
        status_id: consumed.status_id,
        discard_at: now + PREFERENCE_REFRESH_TTL,
        jti: JitSecurityJwtJtiGenerator.generate,
        binding_method_id: consumed.binding_method_id,
        dbsc_status_id: consumed.dbsc_status_id,
        dbsc_session_id: bound_session_id,
        dbsc_public_key: consumed.dbsc_public_key,
        dbsc_challenge: consumed.dbsc_challenge,
        dbsc_challenge_issued_at: consumed.dbsc_challenge_issued_at,
      }

      replacement = create!(attrs)
      raw_refresh_token, verifier = generate_refresh_token(public_id: replacement.public_id)
      replacement.update!(token_digest: digest_refresh_token(verifier))
      migrate_preference_children!(from: consumed, to: replacement)
      replacement.issued_refresh_token = raw_refresh_token
      replacement
    end

    def link_consumed_record_to_replacement!(consumed, replacement, now:)
      consumed.update!(replaced_by_id: replacement.id, updated_at: now)
    end

    def migrate_preference_children!(from:, to:)
      operation =
        lambda do
          prefix = from.class.model_name.singular
          PREFERENCE_CHILD_SUFFIXES.each do |suffix|
            association_name = "#{prefix}_#{suffix}"
            unless from.class.respond_to?(:reflect_on_association)
              child = from.public_send(association_name) if from.respond_to?(association_name)
              child&.update!(preference_id: to.id) if child&.respond_to?(:preference_id)
              next
            end

            reflection = from.class.reflect_on_association(association_name.to_sym)
            next unless reflection

            reflection.klass.where(reflection.foreign_key => from.id).update(
              reflection.foreign_key => to.id,
              :updated_at => Time.current,
            )
          end
        end

      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end

    def with_writing_role(&)
      if connection_class_for_self.current_role == ActiveRecord.writing_role
        yield
      else
        connection_class_for_self.connected_to(role: :writing, &)
      end
    end
  end

  def replay?
    used_at.present?
  end

  # True when this token was consumed very recently AND has a linked
  # replacement, i.e. it looks like a concurrent sibling request from the same
  # page load rather than a genuine replay. The caller must still confirm the
  # replacement itself is currently usable before honoring the presentation.
  #
  # NOTE: `replaced_by_id` defaults to self on create (self-replacement marker),
  # so a real rotation is only present when it points at a *different* record.
  def rotated_within_grace?(window: PREFERENCE_REFRESH_GRACE_WINDOW, now: Time.current)
    return false if used_at.blank?
    return false if replaced_by_id.blank? || replaced_by_id == id

    used_at >= now - window
  end

  def revoked?
    lapsed?
  end

  attr_accessor :issued_refresh_token
end
