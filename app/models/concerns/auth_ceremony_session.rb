# typed: false
# frozen_string_literal: true

require "digest"
require "base64"

# Short-lived Auth ceremony continuity only. Holds no Base login, identity, AAL,
# policy, or RP Session authority. Cookie __Host-auth_sid carries only the raw
# random id; this row stores SHA-256(sid), an explicit lifecycle status, and
# immutable admission, authentication, and terminal event facts. Authentication
# evidence recorded after a successful local ceremony is a one-time handoff input
# for Base; it is not authority held by Auth or this row.
module AuthCeremonySession
  extend ActiveSupport::Concern

  class InvalidTransition < StandardError; end

  SID_BYTES = 32
  DEFAULT_TTL = 30.minutes
  STATUS_ISSUED = 10
  STATUS_ADMITTED = 20
  STATUS_EVIDENCE_RECORDED = 30
  STATUS_REPLACED = 40
  STATUS_REVOKED = 90
  STATUS_COMPLETED = 91
  STATUS_CANCELLED_BEFORE_PROGRESS = 92
  STATUS_CANCELLED_AFTER_PROGRESS = 93
  STATUS_IDS = [
    STATUS_ISSUED, STATUS_ADMITTED, STATUS_EVIDENCE_RECORDED, STATUS_REPLACED,
    STATUS_REVOKED, STATUS_COMPLETED, STATUS_CANCELLED_BEFORE_PROGRESS, STATUS_CANCELLED_AFTER_PROGRESS,
  ].freeze
  ACTIVE_STATUS_IDS = [STATUS_ISSUED, STATUS_ADMITTED, STATUS_EVIDENCE_RECORDED].freeze
  ADMITTED_STATUS_IDS = [
    STATUS_ADMITTED, STATUS_EVIDENCE_RECORDED, STATUS_COMPLETED,
    STATUS_CANCELLED_BEFORE_PROGRESS, STATUS_CANCELLED_AFTER_PROGRESS,
  ].freeze
  TERMINAL_STATUS_IDS = [
    STATUS_REPLACED, STATUS_REVOKED, STATUS_COMPLETED,
    STATUS_CANCELLED_BEFORE_PROGRESS, STATUS_CANCELLED_AFTER_PROGRESS,
  ].freeze
  AUTHENTICATION_METHODS = %w(email telephone secret passkey totp google apple entra).freeze
  ADMISSION_PURPOSES = %w(authentication_handoff invitation_handoff
                          step_up_handoff reauthentication_handoff bootstrap_handoff
                          credential_registration_handoff credential_change_handoff).freeze

  module ClassMethods
    public

    def issue!(ttl: DEFAULT_TTL, expires_at: nil, now: nil)
      raw_sid = SecureRandom.random_bytes(SID_BYTES)
      digest = digest_for(raw_sid)
      record =
        writing_connection do
          decision_time = now || database_now
          if expires_at && expires_at <= decision_time
            raise InvalidTransition, "auth ceremony expiry must follow issuance"
          end

          create!(
            sid_digest: digest,
            expires_at: expires_at || (decision_time + ttl),
            status_id: STATUS_ISSUED,
            created_at: decision_time,
            updated_at: decision_time,
          )
        end
      [record, encode_sid(raw_sid)]
    end

    # Replace the previous browser ceremony and admit the replacement in one
    # database transaction. The old row is never revoked unless the new row
    # can also be created successfully.
    def rotate_and_admit!(admission_purpose:, previous_raw_sid: nil, authorization_transaction_ref: nil,
                          step_up_ceremony_transaction_ref: nil, ttl: DEFAULT_TTL, expires_at: nil)
      unless ADMISSION_PURPOSES.include?(admission_purpose)
        raise InvalidTransition, "unsupported admission purpose"
      end

      raw_sid = SecureRandom.random_bytes(SID_BYTES)
      digest = digest_for(raw_sid)
      previous_digest = digest_for(decode_sid(previous_raw_sid)) if previous_raw_sid.present?

      record =
        writing_connection do
          transaction do
            previous = lock.find_by(sid_digest: previous_digest) if previous_digest
            decision_time = database_now
            if expires_at && expires_at <= decision_time
              raise InvalidTransition, "auth ceremony expiry must follow issuance"
            end

            if previous_digest && (previous.nil? || !previous.active?(now: decision_time))
              replacement = find_by(previous_sid_digest: previous_digest)
              raise InvalidTransition, "auth ceremony session was already replaced" if replacement
            end
            if previous && !previous.terminal?
              previous.update!(
                status_id: STATUS_REPLACED,
                revoked_at: decision_time,
                updated_at: decision_time,
              )
            end

            create!(
              sid_digest: digest,
              previous_sid_digest: previous_digest,
              authorization_transaction_ref: authorization_transaction_ref.to_s.presence,
              step_up_ceremony_transaction_ref: step_up_ceremony_transaction_ref,
              admission_purpose: admission_purpose,
              admitted_at: decision_time,
              status_id: STATUS_ADMITTED,
              expires_at: expires_at || (decision_time + ttl),
              created_at: decision_time,
              updated_at: decision_time,
            )
          end
        end

      [record, encode_sid(raw_sid)]
    end

    def find_active_by_raw_sid(raw_sid, now: nil)
      digest = digest_for(decode_sid(raw_sid))
      record, decision_time =
        writing_connection do
          decision_time = now || database_now
          [find_by(sid_digest: digest), decision_time]
        end
      return nil if record.nil?
      return nil unless record.active?(now: decision_time)

      record
    end

    # Resolve a terminal OIDC ceremony only for retrying its existing Cancel handoff. The result
    # has no active authentication authority and is accepted only when the durable parent still
    # carries the matching cancellation handoff.
    def find_cancelled_parent_cancel_replay_by_raw_sid(raw_sid)
      digest = digest_for(decode_sid(raw_sid))
      record = writing_connection { find_by(sid_digest: digest) }
      terminal_cancel_ids = [STATUS_CANCELLED_BEFORE_PROGRESS, STATUS_CANCELLED_AFTER_PROGRESS]
      return unless record && terminal_cancel_ids.include?(record.status_id)
      return unless record.admission_purpose == "authentication_handoff" &&
        record.authorization_transaction_ref.present?

      record
    end

    def digest_for(raw_bytes)
      Digest::SHA256.hexdigest(raw_bytes)
    end

    def encode_sid(raw_bytes)
      Base64.urlsafe_encode64(raw_bytes, padding: false)
    end

    def decode_sid(encoded)
      Base64.urlsafe_decode64(encoded.to_s)
    end

    def writing_connection(&)
      connection_owner.connected_to(role: :writing, &)
    end

    def connection_owner
      if self <= OpBaseAppRecord
        OpBaseAppRecord
      elsif self <= OpBaseOrgRecord
        OpBaseOrgRecord
      else
        ActiveRecord::Base
      end
    end
  end

  public

  def active?(now: nil)
    now ||= self.class.database_now
    ACTIVE_STATUS_IDS.include?(status_id) && expires_at > now
  end

  def admitted?
    ADMITTED_STATUS_IDS.include?(status_id)
  end

  # Authentication timestamps remain durable evidence facts, including after a terminal state.
  def authentication_evidence_recorded?
    authentication_method.present? && authentication_event_at.present?
  end

  def record_authentication_evidence!(method:)
    normalized_method = method.to_s
    unless AUTHENTICATION_METHODS.include?(normalized_method)
      raise InvalidTransition, "unsupported authentication method"
    end

    self.class.writing_connection do
      with_lock do
        decision_time = self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        unless [STATUS_ADMITTED, STATUS_EVIDENCE_RECORDED].include?(status_id)
          raise InvalidTransition, "auth ceremony session was never admitted"
        end
        raise InvalidTransition, "authentication evidence is already recorded" if
          status_id == STATUS_EVIDENCE_RECORDED

        update!(
          status_id: STATUS_EVIDENCE_RECORDED,
          authentication_method: normalized_method,
          authentication_event_at: decision_time,
          updated_at: decision_time,
        )
      end
    end
  end

  def completed?
    status_id == STATUS_COMPLETED
  end

  def cancelled?
    [STATUS_CANCELLED_BEFORE_PROGRESS, STATUS_CANCELLED_AFTER_PROGRESS].include?(status_id)
  end

  def revoked?
    status_id == STATUS_REVOKED
  end

  def replaced?
    status_id == STATUS_REPLACED
  end

  def cancelled_before_authentication_progress?
    status_id == STATUS_CANCELLED_BEFORE_PROGRESS && admission_purpose == "authentication_handoff"
  end

  def terminal?
    TERMINAL_STATUS_IDS.include?(status_id)
  end

  def admit!(admission_purpose:, authorization_transaction_ref: nil)
    raise InvalidTransition, "unsupported admission purpose" unless ADMISSION_PURPOSES.include?(admission_purpose)

    self.class.writing_connection do
      with_lock do
        decision_time = self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        raise InvalidTransition, "auth ceremony session is already admitted" unless status_id == STATUS_ISSUED

        update!(
          status_id: STATUS_ADMITTED,
          authorization_transaction_ref: authorization_transaction_ref.to_s.presence,
          admission_purpose: admission_purpose,
          admitted_at: decision_time,
          updated_at: decision_time,
        )
      end
    end
  end

  def revoke!
    self.class.writing_connection do
      with_lock do
        raise InvalidTransition, "auth ceremony session is terminal" if terminal?

        # Expired continuity has no authority, but must still close when its Base token is
        # revoked. Requiring active continuity here would roll back logout after its TTL.
        decision_time = self.class.database_now
        update!(status_id: STATUS_REVOKED, revoked_at: decision_time, updated_at: decision_time)
      end
    end
  end

  def complete!
    transition_to_terminal!(STATUS_COMPLETED, :completed_at, require_admitted: true)
  end

  def cancel!
    self.class.writing_connection do
      with_lock do
        decision_time = self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        raise InvalidTransition, "auth ceremony session was never admitted" unless admitted?

        target_status_id =
          case status_id
          when STATUS_ADMITTED then STATUS_CANCELLED_BEFORE_PROGRESS
          when STATUS_EVIDENCE_RECORDED then STATUS_CANCELLED_AFTER_PROGRESS
          else raise InvalidTransition, "auth ceremony session cannot be cancelled from its current status"
          end

        update!(status_id: target_status_id, cancelled_at: decision_time, updated_at: decision_time)
      end
    end
  end

  def rotate!(ttl: DEFAULT_TTL)
    self.class.writing_connection do
      with_lock do
        decision_time = self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)

        raw_sid = SecureRandom.random_bytes(SID_BYTES)
        update!(
          previous_sid_digest: sid_digest,
          sid_digest: self.class.digest_for(raw_sid),
          expires_at: decision_time + ttl,
          rotated_at: decision_time,
          updated_at: decision_time,
        )
        self.class.encode_sid(raw_sid)
      end
    end
  end

  # Explicit non-authority surface: these attributes must remain absent.
  def asserts_no_authority_api!
    %i(
      identity_id user_id staff_id aal amr role permission
      base_browser_session_id rp_session_id oidc_client_id
      state nonce pkce_verifier code authorization_code access_token refresh_token
      sign_in sign_up sign_in_intent sign_up_intent
    ).each do |name|
      raise ArgumentError, "authority attribute leaked: #{name}" if respond_to?(name) || has_attribute?(name.to_s)
    end
    true
  end

  private

  def transition_to_terminal!(target_status_id, timestamp_attribute, require_admitted:)
    self.class.writing_connection do
      with_lock do
        decision_time = self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        if require_admitted && !admitted?
          raise InvalidTransition, "auth ceremony session was never admitted"
        end

        update!({ :status_id => target_status_id, timestamp_attribute => decision_time, :updated_at => decision_time })
      end
    end
  end
end
