# typed: false
# frozen_string_literal: true

require "test_helper"

class PersonaEnterpriseModelLayerTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
    PersonaMembershipKind.ensure_defaults!
    PersonaMembershipState.ensure_defaults!
    PersonaMembershipRevokeReason.ensure_defaults!
  end

  test "persona and organization concerns are included" do
    assert_includes ClientPersona.included_modules, Persona
    assert_includes Enterprise.included_modules, Organization
  end

  test "persona title validation rejects blank invalid and long values" do
    persona = ClientPersona.new(client_identity: client_identity("persona-title-validation"), title: "bad title!")

    assert_not persona.valid?
    assert persona.errors.of_kind?(:title, :invalid)

    persona.title = ""

    assert_not persona.valid?
    assert persona.errors.of_kind?(:title, :blank)

    persona.title = "TooLongTitleHere"

    assert_not persona.valid?
    assert persona.errors.of_kind?(:title, :too_long)
  end

  test "organization title validation rejects blank invalid and long values" do
    enterprise = Enterprise.new(name: "Acme", title: "bad title!")

    assert_not enterprise.valid?
    assert enterprise.errors.of_kind?(:title, :invalid)

    enterprise.title = ""

    assert_not enterprise.valid?
    assert enterprise.errors.of_kind?(:title, :blank)

    enterprise.title = "TooLongTitleHere"

    assert_not enterprise.valid?
    assert enterprise.errors.of_kind?(:title, :too_long)
  end

  test "root unit creates self closure row" do
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")

    closure = EnterpriseUnitClosure.find_by!(ancestor: root, descendant: root)

    assert_equal 0, closure.depth
    assert_predicate root, :root?
    assert_predicate root, :leaf?
    assert_equal [root], root.subtree.to_a
  end

  test "child unit creates ancestor closure rows" do
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")
    child = EnterpriseUnit.create!(enterprise:, parent: root, name: "Child")

    assert_equal 0, EnterpriseUnitClosure.find_by!(ancestor: child, descendant: child).depth
    assert_equal 1, EnterpriseUnitClosure.find_by!(ancestor: root, descendant: child).depth
    assert_equal [root], child.ancestors.to_a
    assert_equal [child], root.descendants.to_a
    assert_not root.leaf?
  end

  test "unit parent must belong to the same enterprise" do
    first = Enterprise.create!(name: "First", title: "First")
    second = Enterprise.create!(name: "Second", title: "Second")
    parent = EnterpriseUnit.create!(enterprise: first, name: "Root")
    child = EnterpriseUnit.new(enterprise: second, parent:, name: "Invalid")

    assert_not child.valid?
    assert child.errors.of_kind?(:parent, :invalid)
  end

  test "unit parent cannot be changed after create" do
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    first = EnterpriseUnit.create!(enterprise:, name: "First")
    second = EnterpriseUnit.create!(enterprise:, name: "Second")

    second.parent = first

    assert_not second.valid?
    assert second.errors.of_kind?(:parent_id, :invalid)
  end

  test "membership validates unit enterprise" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-membership-mismatch"), title: "P1")
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    other = Enterprise.create!(name: "Other", title: "Other")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")
    membership = PersonaMembership.new(
      persona:,
      enterprise:,
      enterprise_unit: other_unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
    )

    assert_not membership.valid?
    assert membership.errors.of_kind?(:enterprise_unit, :invalid)
  end

  test "allows only one active primary membership per persona" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-primary"), title: "P2")
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    attrs = {
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    }
    PersonaMembership.create!(attrs)

    duplicate = PersonaMembership.new(attrs)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:primary, :taken)
  end

  test "persona exposes current membership and organization protocol" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-interface"), title: "P3")
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )

    assert_equal :persona_memberships, ClientPersona.membership_association_name
    assert_equal membership, persona.primary_membership
    assert_equal membership, persona.current_membership
    assert_equal [membership], persona.current_memberships.to_a
    assert_equal enterprise, persona.current_collective
    assert_equal unit, persona.current_collective_unit
    assert_equal persona, membership.account
    assert_equal enterprise, membership.collective
    assert_equal unit, membership.collective_unit
    assert_predicate membership, :active?
    assert_predicate membership, :primary_active?
  end

  test "database rejects a second persona for the same client identity" do
    identity = client_identity("persona-identity-unique")
    ClientPersona.create!(client_identity: identity, title: "P4")

    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientPersona.transaction(requires_new: true) do
        ClientPersona.insert_all!(
          [
            {
              client_identity_id: identity.id,
              public_id: "dup-#{SecureRandom.hex(8)}",
              title: "P4",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects unit parent from a different enterprise" do
    first = Enterprise.create!(name: "First", title: "First")
    second = Enterprise.create!(name: "Second", title: "Second")
    parent = EnterpriseUnit.create!(enterprise: first, name: "Root")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      EnterpriseUnit.transaction(requires_new: true) do
        EnterpriseUnit.insert_all!(
          [
            {
              enterprise_id: second.id,
              parent_id: parent.id,
              public_id: "unit-#{SecureRandom.hex(8)}",
              name: "Invalid",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects membership whose unit belongs to another enterprise" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-db-membership-mismatch"), title: "P5")
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    other = Enterprise.create!(name: "Other", title: "Other")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      PersonaMembership.transaction(requires_new: true) do
        PersonaMembership.insert_all!(
          [
            {
              persona_id: persona.id,
              enterprise_id: enterprise.id,
              enterprise_unit_id: other_unit.id,
              membership_kind_id: PersonaMembershipKind::OWNER,
              membership_state_id: PersonaMembershipState::ACTIVE,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects non-self closure rows with depth zero" do
    enterprise = Enterprise.create!(name: "Acme", title: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")
    child = EnterpriseUnit.create!(enterprise:, parent: root, name: "Child")

    assert_raises(ActiveRecord::StatementInvalid) do
      EnterpriseUnitClosure.transaction(requires_new: true) do
        EnterpriseUnitClosure.insert_all!(
          [
            {
              ancestor_id: root.id,
              descendant_id: child.id,
              depth: 0,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "accepts a pending membership and records its approver" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-accept"), title: "Accept")
    enterprise = Enterprise.create!(name: "Accept Enterprise", title: "Accept")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::PENDING,
    )

    result = CollectiveMembership::Accept.call(membership:, approved_by: persona)

    assert_same membership, result
    assert_equal PersonaMembershipState::ACTIVE, membership.reload.membership_state_id
    assert_equal persona.id, membership.approved_by_persona_id
    assert_predicate membership.starts_at, :present?
  end

  test "suspends an active membership and clears primary status" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-suspend"), title: "Suspend")
    enterprise = Enterprise.create!(name: "Suspend Enterprise", title: "Suspend")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )

    result = CollectiveMembership::Suspend.call(membership:)

    assert_same membership, result
    assert_equal PersonaMembershipState::SUSPENDED, membership.reload.membership_state_id
    assert_not membership.primary?
  end

  test "revokes an active membership and is idempotent after revocation" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-revoke"), title: "Revoke")
    enterprise = Enterprise.create!(name: "Revoke Enterprise", title: "Revoke")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )

    result = CollectiveMembership::Revoke.call(membership:, revoked_by: persona)
    second_result = CollectiveMembership::Revoke.call(membership: membership.reload, revoked_by: persona)

    assert_same membership, result
    assert_same membership, second_result
    assert_equal PersonaMembershipState::REVOKED, membership.reload.membership_state_id
    assert_equal PersonaMembershipRevokeReason::MANUAL, membership.revoke_reason_id
    assert_equal persona.id, membership.revoked_by_persona_id
    assert_not membership.primary?
  end

  test "transfers an active membership to another unit in the same enterprise" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-transfer"), title: "Transfer")
    enterprise = Enterprise.create!(name: "Transfer Enterprise", title: "Transfer")
    first_unit = EnterpriseUnit.create!(enterprise:, name: "First")
    second_unit = EnterpriseUnit.create!(enterprise:, name: "Second")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: first_unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
    )

    result = CollectiveMembership::TransferUnit.call(membership:, unit: second_unit)

    assert_same membership, result
    assert_equal second_unit.id, membership.reload.enterprise_unit_id
  end

  test "rejects transferring an active membership to another enterprise" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-transfer-invalid"), title: "Transfer")
    enterprise = Enterprise.create!(name: "Transfer Enterprise", title: "Transfer")
    other = Enterprise.create!(name: "Other Enterprise", title: "Other")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")
    membership = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
    )

    error =
      assert_raises(CollectiveMembership::InvalidUnitTransfer) do
        CollectiveMembership::TransferUnit.call(membership:, unit: other_unit)
      end

    assert_equal "unit does not belong to same collective", error.message
    assert_equal unit.id, membership.reload.enterprise_unit_id
  end

  test "makes an active membership primary and demotes the previous primary" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-primary-service"), title: "Primary")
    enterprise = Enterprise.create!(name: "Primary Enterprise", title: "Primary")
    first_unit = EnterpriseUnit.create!(enterprise:, name: "First")
    second_unit = EnterpriseUnit.create!(enterprise:, name: "Second")
    first = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: first_unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )
    second = PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: second_unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: false,
    )

    result = CollectiveMembership::MakePrimary.call(membership: second)

    assert_same second, result
    assert_not first.reload.primary?
    assert_predicate second.reload, :primary?
  end

  test "grants a new active membership" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-grant"), title: "Grant")
    enterprise = Enterprise.create!(name: "Grant Enterprise", title: "Grant")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")

    membership = CollectiveMembership::Grant.call(
      account: persona,
      collective: enterprise,
      unit: unit,
      kind_id: PersonaMembershipKind::MEMBER,
      primary: true,
      granted_by: persona,
    )

    assert_predicate membership, :persisted?
    assert_equal persona.id, membership.persona_id
    assert_equal enterprise.id, membership.enterprise_id
    assert_equal unit.id, membership.enterprise_unit_id
    assert_equal PersonaMembershipState::ACTIVE, membership.membership_state_id
    assert_predicate membership, :primary?
    assert_equal persona.id, membership.granted_by_persona_id
  end

  test "rejects granting a duplicate active membership" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-grant-duplicate"), title: "Grant")
    enterprise = Enterprise.create!(name: "Grant Enterprise", title: "Grant")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    PersonaMembership.create!(
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
    )

    error =
      assert_raises(CollectiveMembership::DuplicateActiveMembership) do
        CollectiveMembership::Grant.call(
          account: persona,
          collective: enterprise,
          unit: unit,
          kind_id: PersonaMembershipKind::MEMBER,
        )
      end

    assert_equal "duplicate active membership", error.message
  end

  test "rejects granting a duplicate active primary membership" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-grant-primary"), title: "Grant")
    first = Enterprise.create!(name: "First Grant Enterprise", title: "First")
    second = Enterprise.create!(name: "Second Grant Enterprise", title: "Second")
    first_unit = EnterpriseUnit.create!(enterprise: first, name: "First Root")
    second_unit = EnterpriseUnit.create!(enterprise: second, name: "Second Root")
    PersonaMembership.create!(
      persona:,
      enterprise: first,
      enterprise_unit: first_unit,
      membership_kind_id: PersonaMembershipKind::MEMBER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )

    error =
      assert_raises(CollectiveMembership::DuplicateActivePrimary) do
        CollectiveMembership::Grant.call(
          account: persona,
          collective: second,
          unit: second_unit,
          kind_id: PersonaMembershipKind::MEMBER,
          primary: true,
        )
      end

    assert_equal "duplicate active primary membership", error.message
  end

  test "rejects granting a membership to a unit in another enterprise" do
    persona = ClientPersona.create!(client_identity: client_identity("persona-grant-unit"), title: "Grant")
    enterprise = Enterprise.create!(name: "Grant Enterprise", title: "Grant")
    other = Enterprise.create!(name: "Other Enterprise", title: "Other")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")

    error =
      assert_raises(CollectiveMembership::InvalidUnitTransfer) do
        CollectiveMembership::Grant.call(
          account: persona,
          collective: enterprise,
          unit: other_unit,
          kind_id: PersonaMembershipKind::MEMBER,
        )
      end

    assert_equal "unit does not belong to collective", error.message
  end

  private

  def client_identity(label)
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_app",
      source_record_id: Zlib.crc32(label),
      status_id: ClientIdentityState::ACTIVE,
    )
  end
end
