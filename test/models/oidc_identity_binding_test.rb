# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientOidcIdentityBindingTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
  end

  test "one canonical identity can own bindings for several RP audiences" do
    identity = ClientIdentity.create!(
      issuer: "https://www.umaxica.app",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_001,
      status_id: ClientIdentityState::ACTIVE,
    )

    first = ClientOidcIdentityBinding.create!(
      client_identity: identity,
      issuer: "https://www.umaxica.app",
      subject: "cli-#{SecureRandom.hex(6)}",
      audience: "warp-app",
    )
    second = ClientOidcIdentityBinding.create!(
      client_identity: identity,
      issuer: "https://www.umaxica.app",
      subject: "cli-#{SecureRandom.hex(6)}",
      audience: "core-app",
    )

    assert_equal identity.id, first.client_identity_id
    assert_equal identity.id, second.client_identity_id
    assert_equal 2, identity.reload.oidc_identity_bindings.count
    assert_equal "base-selector-bootstrap", identity.audience
  end

  test "binding uniqueness is exact for subject tuple and canonical identity audience" do
    identity = ClientIdentity.create!(
      issuer: "https://www.umaxica.app",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_002,
      status_id: ClientIdentityState::ACTIVE,
    )
    other_identity = ClientIdentity.create!(
      issuer: "https://www.umaxica.app",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_003,
      status_id: ClientIdentityState::ACTIVE,
    )
    claims = {
      issuer: "https://www.umaxica.app",
      subject: "cli-#{SecureRandom.hex(6)}",
      audience: "warp-app",
    }
    ClientOidcIdentityBinding.create!(client_identity: identity, **claims)

    duplicate_subject = ClientOidcIdentityBinding.new(client_identity: other_identity, **claims)

    assert_not duplicate_subject.valid?
    assert duplicate_subject.errors.of_kind?(:subject, :taken)

    duplicate_identity = ClientOidcIdentityBinding.new(
      client_identity: identity,
      issuer: claims.fetch(:issuer),
      subject: "cli-#{SecureRandom.hex(6)}",
      audience: claims.fetch(:audience),
    )

    assert_not duplicate_identity.valid?
    assert duplicate_identity.errors.of_kind?(:client_identity_id, :taken)
  end

  test "canonical selector identity and its persona remain unchanged by a binding" do
    identity = ClientIdentity.create!(
      issuer: "https://www.umaxica.app",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_004,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = ClientPersona.create!(client_identity: identity, moniker: "Binding Persona", title: "Persona")

    ClientOidcIdentityBinding.create!(
      client_identity: identity,
      issuer: "https://www.umaxica.app",
      subject: "cli-#{SecureRandom.hex(6)}",
      audience: "warp-app",
    )

    assert_equal identity.id, persona.reload.client_identity_id
    assert_equal persona.id, identity.reload.client_persona.id
    assert_empty ClientOidcIdentityBinding.where(audience: "base-selector-bootstrap")
  end
end

class VisitorOidcIdentityBindingTest < ActiveSupport::TestCase
  setup do
    VisitorIdentityState.ensure_defaults!
  end

  test "visitor binding points to the canonical visitor identity" do
    identity = VisitorIdentity.create!(
      issuer: "https://www.umaxica.com",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_101,
      status_id: VisitorIdentityState::ACTIVE,
    )
    binding = VisitorOidcIdentityBinding.create!(
      visitor_identity: identity,
      issuer: "https://www.umaxica.com",
      subject: "vis-#{SecureRandom.hex(6)}",
      audience: "warp-com",
    )

    assert_equal identity, binding.visitor_identity
    assert_equal [binding], identity.reload.oidc_identity_bindings.to_a
  end
end

class OperatorOidcIdentityBindingTest < ActiveSupport::TestCase
  setup do
    OperatorIdentityState.ensure_defaults!
  end

  test "operator binding points to the canonical operator identity" do
    identity = OperatorIdentity.create!(
      issuer: "https://www.umaxica.org",
      subject: "canonical-#{SecureRandom.hex(6)}",
      audience: "base-selector-bootstrap",
      source_record_id: 9_201,
      status_id: OperatorIdentityState::ACTIVE,
    )
    binding = OperatorOidcIdentityBinding.create!(
      operator_identity: identity,
      issuer: "https://www.umaxica.org",
      subject: "opr-#{SecureRandom.hex(6)}",
      audience: "warp-org",
    )

    assert_equal identity, binding.operator_identity
    assert_equal [binding], identity.reload.oidc_identity_bindings.to_a
  end
end
