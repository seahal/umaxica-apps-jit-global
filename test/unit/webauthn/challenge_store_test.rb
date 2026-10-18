# typed: false
# frozen_string_literal: true

require "test_helper"

module Webauthn
  class ChallengeStoreTest < ActiveSupport::TestCase
    APP_BINDING = {
      surface: :app,
      rp_id: "auth.umaxica.app",
      origin: "https://auth.umaxica.app",
      actor_global_key: "client:1",
    }.freeze

    setup do
      @session = {}
      @store = Webauthn::ChallengeStore.new(@session)
    end

    test "issue and consume round-trips the challenge with full binding" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      assert_equal "raw-challenge", @store.consume!(id, purpose: :authentication, **APP_BINDING)
    end

    test "a challenge is one-time use" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)
      @store.consume!(id, purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING)
      end
    end

    test "an expired challenge is rejected" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      travel Webauthn::ChallengeStore::TTL + 1.second do
        assert_raises(Webauthn::ChallengeStore::ChallengeExpiredError) do
          @store.consume!(id, purpose: :authentication, **APP_BINDING)
        end
      end
    end

    # The stored deadline is an integer Unix second; one second is its nearest representable neighbor.
    test "bound consumption accepts before expiry and rejects at and after expiry without replay" do
      issued_at = Time.utc(2026, 10, 4, 4, 0, 0)
      [-1, 0, 1].each do |offset|
        store = Webauthn::ChallengeStore.new({})
        id = nil
        travel_to issued_at do
          id = store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)
        end
        travel_to issued_at + Webauthn::ChallengeStore::TTL + offset.seconds do
          if offset.negative?
            assert_equal "raw-challenge", store.consume!(id, purpose: :authentication, **APP_BINDING)
          else
            assert_raises(Webauthn::ChallengeStore::ChallengeExpiredError) do
              store.consume!(id, purpose: :authentication, **APP_BINDING)
            end
          end
          assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) do
            store.consume!(id, purpose: :authentication, **APP_BINDING)
          end
        end
      end
    end

    test "actor-returning consumption rejects exactly at its integer deadline and afterward" do
      issued_at = Time.utc(2026, 10, 4, 4, 0, 0)
      [-1, 0, 1].each do |offset|
        store = Webauthn::ChallengeStore.new({})
        id = nil
        travel_to issued_at do
          id = store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)
        end
        travel_to issued_at + Webauthn::ChallengeStore::TTL + offset.seconds do
          if offset.negative?
            consumed = store.consume_with_actor!(id, purpose: :authentication, **APP_BINDING.except(:actor_global_key))

            assert_equal "raw-challenge", consumed.challenge
            assert_equal "client:1", consumed.actor_global_key
          else
            assert_raises(Webauthn::ChallengeStore::ChallengeExpiredError) do
              store.consume_with_actor!(id, purpose: :authentication, **APP_BINDING.except(:actor_global_key))
            end
          end
          assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) do
            store.consume_with_actor!(id, purpose: :authentication, **APP_BINDING.except(:actor_global_key))
          end
        end
      end
    end

    # Purposes are separate namespaces, not labels. Every ordered pair is checked
    # rather than a sample, so adding a purpose without deciding what it may be
    # confused with fails here.
    test "no challenge issued for one purpose is usable under any other" do
      Webauthn::ChallengeStore::PURPOSES.each do |issued|
        Webauthn::ChallengeStore::PURPOSES.each do |consumed|
          next if issued == consumed

          id = @store.issue!(challenge: "raw-challenge", purpose: issued, **APP_BINDING)

          assert_raises(
            Webauthn::ChallengeStore::ChallengePurposeMismatchError,
            "a #{issued} challenge was accepted by the #{consumed} verifier",
          ) do
            @store.consume!(id, purpose: consumed, **APP_BINDING)
          end

          id = @store.issue!(challenge: "raw-challenge", purpose: issued, **APP_BINDING)

          assert_raises(
            Webauthn::ChallengeStore::ChallengePurposeMismatchError,
            "a #{issued} challenge was accepted by the actor-returning #{consumed} verifier",
          ) do
            @store.consume_with_actor!(id, purpose: consumed, **APP_BINDING.except(:actor_global_key))
          end
        end
      end
    end

    test "purpose mismatch is rejected and consumes the challenge" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :registration, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengePurposeMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING)
      end
      assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) do
        @store.consume!(id, purpose: :registration, **APP_BINDING)
      end
    end

    test "surface mismatch is rejected" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING.merge(surface: :com))
      end
    end

    test "rp_id mismatch is rejected" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING.merge(rp_id: "auth.umaxica.com"))
      end
    end

    test "origin mismatch including port is rejected" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING.merge(origin: "https://auth.umaxica.app:8443"))
      end
    end

    test "actor mismatch is rejected" do
      id = @store.issue!(challenge: "raw-challenge", purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING.merge(actor_global_key: "client:2"))
      end
    end

    test "anonymous challenges bind to a nil actor and reject actor spoofing" do
      id = @store.issue!(
        challenge: "raw-challenge", purpose: :authentication,
        **APP_BINDING.merge(actor_global_key: nil),
      )

      assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
        @store.consume!(id, purpose: :authentication, **APP_BINDING)
      end
    end

    test "session keeps at most the challenge limit and evicts the oldest" do
      first = @store.issue!(challenge: "c0", purpose: :authentication, **APP_BINDING)
      (Webauthn::ChallengeStore::MAX_CHALLENGES_PER_SESSION - 1).times do |i|
        @store.issue!(challenge: "c#{i + 1}", purpose: :authentication, **APP_BINDING)
      end
      @store.issue!(challenge: "overflow", purpose: :authentication, **APP_BINDING)

      assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) do
        @store.consume!(first, purpose: :authentication, **APP_BINDING)
      end
    end
  end
end
