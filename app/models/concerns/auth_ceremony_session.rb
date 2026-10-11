# typed: false
# frozen_string_literal: true

require "digest"
require "base64"

# Short-lived Auth ceremony continuity only. Holds no Base login, identity, AAL,
# policy, or RP Session authority. Cookie __Host-auth_sid carries only the raw
# random id; this row stores SHA-256(sid) plus lifecycle timestamps.
module AuthCeremonySession
  extend ActiveSupport::Concern

  SID_BYTES = 32
  DEFAULT_TTL = 30.minutes

  module ClassMethods
    public

    def issue!(ttl: DEFAULT_TTL, now: Time.current)
      raw_sid = SecureRandom.random_bytes(SID_BYTES)
      digest = digest_for(raw_sid)
      record = writing_connection { create!(sid_digest: digest, expires_at: now + ttl) }
      [record, encode_sid(raw_sid)]
    end

    def find_active_by_raw_sid(raw_sid, now: Time.current)
      digest = digest_for(decode_sid(raw_sid))
      record = find_by(sid_digest: digest)
      return nil if record.nil?
      return nil unless record.active?(now: now)

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

  def active?(now: Time.current)
    revoked_at.blank? && expires_at > now
  end

  def revoke!(now: Time.current)
    self.class.writing_connection { update!(revoked_at: now) }
  end

  def rotate!(ttl: DEFAULT_TTL, now: Time.current)
    self.class.writing_connection do
      with_lock do
        raise ActiveRecord::RecordInvalid.new(self) unless active?(now: now)

        raw_sid = SecureRandom.random_bytes(SID_BYTES)
        update!(
          previous_sid_digest: sid_digest,
          sid_digest: self.class.digest_for(raw_sid),
          expires_at: now + ttl,
          rotated_at: now,
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
    ).each do |name|
      raise ArgumentError, "authority attribute leaked: #{name}" if respond_to?(name) || has_attribute?(name.to_s)
    end
    true
  end
end
