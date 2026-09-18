# typed: false
# frozen_string_literal: true

require "test_helper"

class IndividualCompanyModelLayerTest < ActiveSupport::TestCase
  setup do
    VisitorIdentityState.ensure_defaults!
    IndividualMembershipKind.ensure_defaults!
    IndividualMembershipState.ensure_defaults!
    IndividualMembershipRevokeReason.ensure_defaults!
  end

  test "persona and organization concerns are included" do
    assert_includes Individual.included_modules, Persona
    assert_includes Company.included_modules, Organization
  end

  test "root and child unit closure rows are maintained" do
    company = Company.create!(name: "Example Co", title: "ExampleCo")
    root = CompanyUnit.create!(company:, name: "Root")
    child = CompanyUnit.create!(company:, parent: root, name: "Child")

    assert_equal 0, CompanyUnitClosure.find_by!(ancestor: root, descendant: root).depth
    assert_equal 0, CompanyUnitClosure.find_by!(ancestor: child, descendant: child).depth
    assert_equal 1, CompanyUnitClosure.find_by!(ancestor: root, descendant: child).depth
    assert_equal [child], root.descendants.to_a
    assert_equal [root], child.ancestors.to_a
  end

  test "unit parent must belong to same company and cannot be changed" do
    first = Company.create!(name: "First", title: "First")
    second = Company.create!(name: "Second", title: "Second")
    parent = CompanyUnit.create!(company: first, name: "Root")
    invalid = CompanyUnit.new(company: second, parent:, name: "Invalid")

    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:parent, :invalid)

    sibling = CompanyUnit.create!(company: first, name: "Sibling")
    sibling.parent = parent

    assert_not sibling.valid?
    assert sibling.errors.of_kind?(:parent_id, :invalid)
  end

  test "membership validates company and active primary uniqueness" do
    individual = Individual.create!(visitor_identity: visitor_identity("individual-primary"), title: "Indiv1")
    company = Company.create!(name: "Example Co", title: "ExampleCo")
    unit = CompanyUnit.create!(company:, name: "Root")
    IndividualMembership.create!(
      individual:,
      company:,
      company_unit: unit,
      membership_kind_id: IndividualMembershipKind::OWNER,
      membership_state_id: IndividualMembershipState::ACTIVE,
      primary: true,
    )

    duplicate = IndividualMembership.new(
      individual:,
      company:,
      company_unit: unit,
      membership_kind_id: IndividualMembershipKind::MEMBER,
      membership_state_id: IndividualMembershipState::ACTIVE,
      primary: true,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:primary, :taken)

    other_company = Company.create!(name: "Other", title: "Other")
    mismatch = IndividualMembership.new(
      individual:,
      company: other_company,
      company_unit: unit,
      membership_kind_id: IndividualMembershipKind::MEMBER,
      membership_state_id: IndividualMembershipState::ACTIVE,
    )

    assert_not mismatch.valid?
    assert mismatch.errors.of_kind?(:company_unit, :invalid)
  end

  test "persona exposes current membership and organization protocol" do
    individual = Individual.create!(visitor_identity: visitor_identity("individual-interface"), title: "Indiv2")
    company = Company.create!(name: "Example Co", title: "ExampleCo")
    unit = CompanyUnit.create!(company:, name: "Root")
    membership = IndividualMembership.create!(
      individual:,
      company:,
      company_unit: unit,
      membership_kind_id: IndividualMembershipKind::OWNER,
      membership_state_id: IndividualMembershipState::ACTIVE,
      primary: true,
    )

    assert_equal :individual_memberships, Individual.membership_association_name
    assert_equal membership, individual.primary_membership
    assert_equal membership, individual.current_membership
    assert_equal [membership], individual.current_memberships.to_a
    assert_equal company, individual.current_collective
    assert_equal unit, individual.current_collective_unit
    assert_equal individual, membership.account
    assert_equal company, membership.collective
    assert_equal unit, membership.collective_unit
    assert_predicate membership, :active?
    assert_predicate membership, :primary_active?
  end

  test "database rejects identity and company hierarchy integrity violations" do
    identity = visitor_identity("individual-identity-unique")
    Individual.create!(visitor_identity: identity, title: "Indiv3")
    first = Company.create!(name: "First", title: "First")
    second = Company.create!(name: "Second", title: "Second")
    unit = CompanyUnit.create!(company: first, name: "Root")
    individual = Individual.create!(visitor_identity: visitor_identity("individual-db-mismatch"), title: "Indiv4")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Individual.transaction(requires_new: true) do
        Individual.insert_all!(
          [
            {
              visitor_identity_id: identity.id,
              public_id: "dup-#{SecureRandom.hex(8)}",
              title: "Indiv3",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      IndividualMembership.transaction(requires_new: true) do
        IndividualMembership.insert_all!(
          [
            {
              individual_id: individual.id,
              company_id: second.id,
              company_unit_id: unit.id,
              membership_kind_id: IndividualMembershipKind::OWNER,
              membership_state_id: IndividualMembershipState::ACTIVE,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  private

  def visitor_identity(label)
    VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_com",
      source_record_id: Zlib.crc32(label),
      status_id: VisitorIdentityState::ACTIVE,
    )
  end
end
