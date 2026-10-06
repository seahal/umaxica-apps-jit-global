# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ExternalAuthenticationUnlinkUseCaseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ExternalIdentityTestHelper

  test "unlinks an identity and records a typed audited result" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "unlink_uc_#{SecureRandom.hex(4)}")
    identity = create_active_external_identity(client: client, provider: "google", subject: "unlink-use-case-subject")

    AuthMethodGuard.stub(:can_remove_external_identity?, true) do
      assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
        result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

        assert_instance_of ExternalAuthentication::UnlinkResult, result
        assert_equal :unlinked, result.status
        assert_equal "google", result.provider
        assert_not ClientExternalIdentity.effective_binding.exists?(id: identity.id)
        assert_not_nil identity.reload.released_at
      end
    end
  end

  test "does not remove the last active authentication method" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "last_uc_#{SecureRandom.hex(4)}")
    identity = create_active_external_identity(client: client, provider: "google", subject: "unlink-last-subject")

    AuthMethodGuard.stub(:can_remove_external_identity?, false) do
      assert_raises(SocialAuth::LastIdentityError) do
        ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)
      end
    end

    assert ClientExternalIdentity.exists?(identity.id)
  end

  test "Apple unlink removes the binding without retaining a provider token" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "apple_unlink_#{SecureRandom.hex(4)}")
    identity = create_active_external_identity(
      client: client, provider: "apple", subject: "apple-unlink-subject",
    )

    AuthMethodGuard.stub(:can_remove_external_identity?, true) do
      ExternalAuthenticationUnlinkUseCase.call(provider: "apple", user: client)
    end

    assert_not ClientExternalIdentity.effective_binding.exists?(id: identity.id)
    assert_not_nil identity.reload.released_at
  end

  test "returns already unlinked when no provider identity exists" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "none_uc_#{SecureRandom.hex(4)}")

    result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

    assert_instance_of ExternalAuthentication::UnlinkResult, result
    assert_equal :already_unlinked, result.status
    assert_equal "google", result.provider
  end
end
