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
            "a #{issued} challenge was accepted by the identifier-first #{consumed} verifier",
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
