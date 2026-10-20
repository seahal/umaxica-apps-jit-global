# typed: false
# frozen_string_literal: true

require "test_helper"

class IndividualAssignmentTest < ActiveSupport::TestCase
  setup do
    VisitorIdentityState.ensure_defaults!
  end

  test "creates active assignment with public id and assigned at" do
    individual, identity = build_individual_and_identity

    assignment = IndividualAssignment.create!(individual: individual, visitor_identity: identity)

    assert_predicate assignment.public_id, :present?
    assert_predicate assignment.assigned_at, :present?
    assert_predicate assignment, :active?
    assert_not_predicate assignment, :revoked?
  end

  test "revoke marks assignment as revoked" do
    individual, identity = build_individual_and_identity
    assignment = IndividualAssignment.create!(individual: individual, visitor_identity: identity)

    assignment.revoke!(at: Time.utc(2026, 6, 27, 12, 0, 0))

    assert_predicate assignment, :revoked?
    assert_not_predicate assignment, :active?
    assert_equal Time.utc(2026, 6, 27, 12, 0, 0), assignment.revoked_at
  end

  test "rejects duplicate active assignment for the same pair" do
    individual, identity = build_individual_and_identity

    IndividualAssignment.create!(individual: individual, visitor_identity: identity)

    duplicate = IndividualAssignment.new(individual: individual, visitor_identity: identity)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "allows a new active assignment after revoking the old one" do
    individual, identity = build_individual_and_identity

    first = IndividualAssignment.create!(individual: individual, visitor_identity: identity)
    first.revoke!

    second = IndividualAssignment.create!(individual: individual, visitor_identity: identity)

    assert_predicate second, :active?
    assert_equal 2, IndividualAssignment.where(individual: individual, visitor_identity: identity).count
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::IndividualAssignment)
  end

  private

  def build_individual_and_identity
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "individual-assignment-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 3000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    individual = Individual.create!(visitor_identity: identity, moniker: "Default Individual", title: "Indiv01")
    [individual, identity]
  end
end
