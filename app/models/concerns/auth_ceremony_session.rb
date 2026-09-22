# typed: false
# frozen_string_literal: true

require "digest"
require "base64"

# Short-lived Auth ceremony continuity only. Holds no Base login, identity, AAL,
# policy, or RP Session authority. Cookie __Host-auth_sid carries only the raw
# random id; this row stores SHA-256(sid) plus lifecycle timestamps. Authentication
# evidence recorded after a successful local ceremony is a one-time handoff input
# for Base; it is not authority held by Auth or this row.
module AuthCeremonySession
  extend ActiveSupport::Concern

  class InvalidTransition < StandardError; end

  SID_BYTES = 32
  DEFAULT_TTL = 30.minutes
  AUTHENTICATION_METHODS = %w(email telephone secret passkey totp google apple entra).freeze

  module ClassMethods
    public

    def issue!(ttl: DEFAULT_TTL, now: nil)
      raw_sid = SecureRandom.random_bytes(SID_BYTES)
      digest = digest_for(raw_sid)
      record =
        writing_connection do
          decision_time = now || database_now
          create!(
            sid_digest: digest,
            expires_at: decision_time + ttl,
            created_at: decision_time,
            updated_at: decision_time,
          )
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
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= ComTicketRecord
        ComTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      else
        ActiveRecord::Base
      end
    end
  end

  public

  def active?(now: nil)
    now ||= self.class.database_now
    !terminal? && expires_at > now
  end

  def admitted?
    admitted_at.present?
  end

  def authentication_evidence_recorded?
    authentication_method.present? && authentication_event_at.present?
  end

  def record_authentication_evidence!(method:, now: nil)
    normalized_method = method.to_s
    unless AUTHENTICATION_METHODS.include?(normalized_method)
      raise InvalidTransition, "unsupported authentication method"
    end

    self.class.writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        raise InvalidTransition, "auth ceremony session was never admitted" unless admitted?
        raise InvalidTransition, "authentication evidence is already recorded" if authentication_evidence_recorded?
        raise InvalidTransition, "authentication evidence is incomplete" if authentication_method.present? ||
          authentication_event_at.present?

        update!(
          authentication_method: normalized_method,
          authentication_event_at: decision_time,
          updated_at: decision_time,
        )
      end
    end
  end

  def completed?
    completed_at.present?
  end

  def cancelled?
    cancelled_at.present?
  end

  def terminal?
    revoked_at.present? || completed? || cancelled?
  end

  def admit!(authorization_transaction_ref: nil, now: nil)
    self.class.writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        raise InvalidTransition, "auth ceremony session is already admitted" if admitted?

        update!(
          authorization_transaction_ref: authorization_transaction_ref.to_s.presence,
          admitted_at: decision_time,
          updated_at: decision_time,
        )
      end
    end
  end

  def revoke!(now: nil)
    transition_to_terminal!(:revoked_at, now: now, require_admitted: false)
  end

  def complete!(now: nil)
    transition_to_terminal!(:completed_at, now: now, require_admitted: true)
  end

  def cancel!(now: nil)
    transition_to_terminal!(:cancelled_at, now: now, require_admitted: true)
  end

  def rotate!(ttl: DEFAULT_TTL, now: nil)
    self.class.writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
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
      identity_id user_id visitor_id staff_id aal amr role permission
      base_browser_session_id rp_session_id oidc_client_id
      state nonce pkce_verifier code authorization_code access_token refresh_token
      sign_in sign_up sign_in_intent sign_up_intent
    ).each do |name|
      raise ArgumentError, "authority attribute leaked: #{name}" if respond_to?(name) || has_attribute?(name.to_s)
    end
    true
  end

  private

  def transition_to_terminal!(timestamp_attribute, now:, require_admitted:)
    self.class.writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        raise InvalidTransition, "auth ceremony session is not active" unless active?(now: decision_time)
        if require_admitted && !admitted?
          raise InvalidTransition, "auth ceremony session was never admitted"
        end

        update!(timestamp_attribute => decision_time, :updated_at => decision_time)
      end
    end
  end
end
