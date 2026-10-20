# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class AppleOnlyCredentialStatusTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  fixtures :client_statuses

  test "identifies an active Apple identity as the only AAL1 credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    create_active_external_identity(client: client, provider: "apple")

    assert AppleOnlyCredentialStatus.call(client)
  end

  test "Google replaces a released Apple binding and two effective social bindings are rejected" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    apple = create_active_external_identity(client: client, provider: "apple")
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientExternalIdentity.transaction(requires_new: true) do
        create_active_external_identity(client: client, provider: "google")
      end
    end
    assert_predicate apple.reload, :active?
    assert AppleOnlyCredentialStatus.call(client)
    apple.release!
    create_active_external_identity(client: client, provider: "google")

    assert_equal 1, client.client_external_identities.effective_binding.count
    assert_not_predicate apple.reload, :active?

    assert_not AppleOnlyCredentialStatus.call(client)
  end

  test "does not warn when there is no client" do
    assert_not AppleOnlyCredentialStatus.call(nil)
  end
end
