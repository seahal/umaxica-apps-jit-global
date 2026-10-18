# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    clients client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_secret_credentials client_secret_issuances
  )

  test "anonymous cannot list create view rename or delete Secret credentials" do
    policy = ClientSecretCredentialPolicy.new(client_secret_credentials(:one), user: nil)

    %i(index? new? create? show? edit? update? destroy?).each do |rule|
      assert_not policy.apply(rule)
    end
  end

  test "persisted owner may access metadata and ownership layer of management" do
    policy = ClientSecretCredentialPolicy.new(client_secret_credentials(:one), user: clients(:one))

    %i(index? new? create? show? edit? update? destroy?).each do |rule|
      assert policy.apply(rule)
    end
  end

  test "another Client cannot view rename or delete the credential" do
    policy = ClientSecretCredentialPolicy.new(client_secret_credentials(:one), user: clients(:two))

    %i(show? edit? update? destroy?).each do |rule|
      assert_not policy.apply(rule)
    end
  end

  test "foreign surface and unsaved actors cannot manage app Secrets even with matching numeric IDs" do
    owner_id = clients(:one).id
    [Operator.new(id: owner_id), Visitor.new(id: owner_id), Client.new(id: owner_id), Client.new].each do |actor|
      policy = ClientSecretCredentialPolicy.new(client_secret_credentials(:one), user: actor)

      %i(index? new? create? show? update? destroy?).each do |rule|
        assert_not policy.apply(rule)
      end
    end
  end

  test "scope returns only the persisted Client's credentials using the new owner key" do
    policy = ClientSecretCredentialPolicy.new(ClientSecretCredential, user: clients(:one))
    scoped = policy.apply_scope(ClientSecretCredential.all, type: :active_record_relation)

    assert_equal [client_secret_credentials(:one).id], scoped.pluck(:id)
    policy = ClientSecretCredentialPolicy.new(ClientSecretCredential, user: nil)

    assert_empty policy.apply_scope(ClientSecretCredential.all, type: :active_record_relation)
  end

  test "new record has no object management permission before persistence" do
    policy = ClientSecretCredentialPolicy.new(ClientSecretCredential.new(client: clients(:one)), user: clients(:one))

    assert policy.apply(:create?)
    assert_not policy.apply(:show?)
    assert_not policy.apply(:update?)
    assert_not policy.apply(:destroy?)
  end
end
