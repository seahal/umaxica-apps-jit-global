# typed: false
# frozen_string_literal: true

module Webauthn
  # Session-backed one-time store for in-process WebAuthn challenges.
  #
  # Every challenge is bound at issue time to its surface, RP ID, origin,
  # purpose, and actor; consumption re-verifies all bindings and deletes the
  # entry before any of them are checked, so a mismatching or failing attempt
  # still burns the challenge (replay defense). Cross-request ceremonies that
  # span the sign/id boundary use the durable *PasskeyCeremonyTransaction
  # tables instead -- this store is only for same-session XHR ceremonies.
  class ChallengeStore
    SESSION_KEY = :passkey_challenges
    TTL = 10.minutes
    MAX_CHALLENGES_PER_SESSION = 5

    class ChallengeError < StandardError; end

    class ChallengeNotFoundError < ChallengeError; end

    class ChallengeExpiredError < ChallengeError; end

    class ChallengePurposeMismatchError < ChallengeError; end

    class ChallengeBindingMismatchError < ChallengeError; end

    # Ceremony purposes are separate namespaces, not labels: a challenge issued
    # for one is rejected by every other verifier (see #consume! /
    # #consume_with_actor!). `emergency_sign_in` is the org Emergency Access
    # ceremony and must never be interchangeable with normal `authentication`
    # or with `step_up`.
    PURPOSES = %w(registration authentication emergency_sign_in step_up).freeze

    Consumed = Data.define(:challenge, :actor_global_key)

    def initialize(session)
      @session = session
    end

    def issue!(challenge:, purpose:, surface:, rp_id:, origin:, actor_global_key:)
      purpose = normalize_purpose(purpose)
      entries = current_entries
      cleanup_expired!(entries)
      evict_oldest!(entries)

      id = SecureRandom.urlsafe_base64(16)
      entries[id] = {
        "challenge" => challenge,
        "purpose" => purpose,
        "surface" => Surface.for(surface).key.to_s,
        "rp_id" => rp_id.to_s,
        "origin" => origin.to_s,
        "actor_global_key" => actor_global_key&.to_s,
        "expires_at" => TTL.from_now.to_i,
      }
      write!(entries)
      id
    end

    # Deletes the entry first, then validates every binding; any mismatch
    # raises after the challenge is already gone, so it can never be retried.
    def consume!(id, purpose:, surface:, rp_id:, origin:, actor_global_key:)
      entries = current_entries
      data = entries.delete(id)
      write!(entries)

      raise ChallengeNotFoundError, "Challenge not found" unless data

      if Time.current.to_i > data["expires_at"].to_i
        raise ChallengeExpiredError, "Challenge has expired"
      end
      if data["purpose"] != normalize_purpose(purpose)
        raise ChallengePurposeMismatchError,
              "Challenge purpose mismatch: expected #{purpose}, got #{data["purpose"]}"
      end

      verify_binding!(data, "surface", Surface.for(surface).key.to_s)
      verify_binding!(data, "rp_id", rp_id.to_s)
      verify_binding!(data, "origin", origin.to_s)
      verify_binding!(data, "actor_global_key", actor_global_key&.to_s)

      data["challenge"]
    end

    # Consumption variant for identifier-first sign-in, where the server
    # learns the acting account from the challenge itself: validates surface,
    # RP ID, origin, purpose, TTL, and one-time use, and returns the actor
    # binding for the caller to enforce credential ownership against.
    def consume_with_actor!(id, purpose:, surface:, rp_id:, origin:)
      entries = current_entries
      data = entries.delete(id)
      write!(entries)

      raise ChallengeNotFoundError, "Challenge not found" unless data

      if Time.current.to_i > data["expires_at"].to_i
        raise ChallengeExpiredError, "Challenge has expired"
      end
      if data["purpose"] != normalize_purpose(purpose)
        raise ChallengePurposeMismatchError,
              "Challenge purpose mismatch: expected #{purpose}, got #{data["purpose"]}"
      end

      verify_binding!(data, "surface", Surface.for(surface).key.to_s)
      verify_binding!(data, "rp_id", rp_id.to_s)
      verify_binding!(data, "origin", origin.to_s)

      Consumed.new(challenge: data["challenge"], actor_global_key: data["actor_global_key"])
    end

    # Idempotent removal for ensure blocks: guarantees a challenge does not
    # survive any code path once its ceremony has started.
    def discard(id)
      return if id.blank?

      entries = current_entries
      return unless entries.key?(id)

      entries.delete(id)
      write!(entries)
    end

    private

    attr_reader :session

    def normalize_purpose(purpose)
      value = purpose.to_s
      raise ArgumentError, "Unknown challenge purpose: #{purpose.inspect}" unless PURPOSES.include?(value)

      value
    end

    def verify_binding!(data, field, expected)
      return if data[field] == expected

      raise ChallengeBindingMismatchError,
            "Challenge #{field} mismatch: challenge is bound to a different #{field.tr("_", " ")}"
    end

    def current_entries
      value = session[SESSION_KEY]
      value.is_a?(Hash) ? value : {}
    end

    def write!(entries)
      session[SESSION_KEY] = entries
    end

    def cleanup_expired!(entries)
      now = Time.current.to_i
      entries.delete_if { |_, data| data["expires_at"].to_i < now }
    end

    def evict_oldest!(entries)
      return if entries.size < MAX_CHALLENGES_PER_SESSION

      oldest_id, = entries.min_by { |_, data| data["expires_at"].to_i }
      entries.delete(oldest_id)
    end
  end
end
