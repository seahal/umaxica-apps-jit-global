# typed: false
# frozen_string_literal: true

require "test_helper"

class PersonaAssignmentTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
  end

  test "creates active assignment with public id and assigned at" do
    persona, identity = build_persona_and_identity

    assignment = PersonaAssignment.create!(persona: persona, client_identity: identity)

    assert_predicate assignment.public_id, :present?
    assert_predicate assignment.assigned_at, :present?
    assert_predicate assignment, :active?
    assert_not_predicate assignment, :revoked?
  end

  test "revoke marks assignment as revoked" do
    persona, identity = build_persona_and_identity
    assignment = PersonaAssignment.create!(persona: persona, client_identity: identity)

    assignment.revoke!(at: Time.utc(2026, 6, 27, 12, 0, 0))

    assert_predicate assignment, :revoked?
    assert_not_predicate assignment, :active?
    assert_equal Time.utc(2026, 6, 27, 12, 0, 0), assignment.revoked_at
  end

  test "rejects duplicate active assignment for the same pair" do
    persona, identity = build_persona_and_identity

    PersonaAssignment.create!(persona: persona, client_identity: identity)

    duplicate = PersonaAssignment.new(persona: persona, client_identity: identity)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "allows a new active assignment after revoking the old one" do
    persona, identity = build_persona_and_identity

    first = PersonaAssignment.create!(persona: persona, client_identity: identity)
    first.revoke!

    second = PersonaAssignment.create!(persona: persona, client_identity: identity)

    assert_predicate second, :active?
    assert_equal 2, PersonaAssignment.where(persona: persona, client_identity: identity).count
  end

  private

  def build_persona_and_identity
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "persona-assignment-#{SecureRandom.hex(4)}",
      audience: "acme_app",
      source_record_id: SecureRandom.random_number(1_000_000) + 1000,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = ClientPersona.create!(client_identity: identity, moniker: "Default ClientPersona", title: "Persona01")
    [persona, identity]
  end
end
