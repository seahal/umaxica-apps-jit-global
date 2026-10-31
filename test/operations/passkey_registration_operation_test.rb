# frozen_string_literal: true

require "test_helper"

class PasskeyRegistrationOperationTest < ActiveSupport::TestCase
  test "registration refuses unavailable owners without creating a credential or audit" do
    [
      [Client, ClientPasskey, ClientPasskeyAuditOutbox, ClientStatus::RESERVED, "app", SecurityModeConfigurable::NORMAL],
      [Operator, OperatorPasskey, OperatorPasskeyAuditOutbox, OperatorStatus::RESERVED, "org", SecurityModeConfigurable::ADVANCED],
    ].each do |actor_class, passkey_class, outbox_class, reserved_status, surface, security_mode|
      [
        { status_id: reserved_status },
        { withdrawn_at: 1.minute.ago },
      ].each do |unavailable|
        actor = actor_class.create!(security_mode_id: security_mode, **unavailable)
        credential_id = SecureRandom.uuid

        assert_no_difference([-> { passkey_class.count }, -> { outbox_class.count }]) do
          assert_raises(ArgumentError) do
            PasskeyRegistrationOperation.call!(
              actor: actor, passkey_class: passkey_class,
              attributes: { webauthn_id: credential_id, public_key: "unavailable-owner-key" },
              audit: { event_type: "passkey.registered.settings", surface: surface },
            )
          end
        end
      end
    end
  end

  self.fixture_table_names = []

  SURFACES = [
    [Client, ClientPasskey, :user_id, "app"],
    [Operator, OperatorPasskey, :staff_id, "org"],
  ].freeze

  test "the ninth and tenth registrations succeed and the eleventh is refused on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      registered = 10.times.map { |index| register(actor, passkey_class, index, surface:) }

      assert_equal 10, passkey_class.where(owner_key => actor.id).count, surface
      assert_equal 10, PasskeyAuditOutbox.source_for(registered.first).where(
        external_id: registered.map(&:external_id),
      ).count, surface

      refused = passkey_class.new(passkey_attributes(11))
      error =
        assert_raises(ActiveRecord::RecordInvalid, surface) do
          PasskeyRegistrationOperation.call!(actor:, passkey: refused, audit: audit(surface))
        end

      assert_match(/exceeds maximum passkeys/, error.record.errors[:base].join, surface)
      assert_equal 10, passkey_class.where(owner_key => actor.id).count, surface
      assert_not PasskeyAuditOutbox.source_for(registered.first).exists?(external_id: refused.external_id), surface
    end
  end

  test "removing a Passkey at the limit frees capacity for the same owner" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    registered = 10.times.map { |index| register(actor, ClientPasskey, index) }

    registered.first.destroy!
    replacement = register(actor, ClientPasskey, 11)

    assert_predicate replacement, :persisted?
    assert_equal 10, ClientPasskey.where(user_id: actor.id).count
  end

  test "one owner at the limit does not limit another owner" do
    full = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    10.times { |index| register(full, ClientPasskey, index) }

    assert_predicate register(other, ClientPasskey, 0), :persisted?
  end

  test "an unsupported record class is refused" do
    assert_raises(ArgumentError) do
      PasskeyRegistrationOperation.call!(
        actor: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL),
        passkey_class: Client, attributes: {}, audit: { event_type: "passkey.registered.settings", surface: "app" },
      )
    end
  end

  test "only the credential ID constraint is classified as a duplicate credential on each surface" do
    SURFACES.each do |actor_class, passkey_class, _owner_key, surface|
      owner = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      credential = PasskeyRegistrationOperation.call!(
        actor: owner, passkey_class: passkey_class,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "constraint-key" },
        audit: { event_type: "passkey.registered.settings", surface: surface },
      )
      duplicate_id = credential.attributes.except("id").merge("external_id" => SecureRandom.uuid)
      duplicate_id["public_id"] = PublicId.generate if duplicate_id.key?("public_id")
      credential_error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          passkey_class.transaction(requires_new: true) { passkey_class.insert_all!([duplicate_id]) }
        end

      assert PasskeyRegistrationOperation.credential_id_conflict?(credential_error)

      duplicate_reference = credential.attributes.except("id").merge("webauthn_id" => SecureRandom.uuid)
      duplicate_reference["public_id"] = PublicId.generate if duplicate_reference.key?("public_id")
      reference_error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          passkey_class.transaction(requires_new: true) { passkey_class.insert_all!([duplicate_reference]) }
        end

      assert_not PasskeyRegistrationOperation.credential_id_conflict?(reference_error)
    end
    assert_not PasskeyRegistrationOperation.credential_id_conflict?(ActiveRecord::RecordNotUnique.new)
  end

  test "invalid audit references roll back registration on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      credential_id = SecureRandom.uuid
      assert_raises(ArgumentError) do
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: credential_id, public_key: "rollback-key" },
          audit: {
            event_type: "passkey.registered.settings",
            surface: surface,
            metadata: { "actor_ref" => "another-owner" },
          },
        )
      end
      assert_not passkey_class.exists?(owner_key => actor.id, :webauthn_id => credential_id)
    end
  end

  test "registration without an audit event is refused without creating a credential on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, _surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      omitted_id = SecureRandom.uuid
      assert_raises(ArgumentError) do
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: omitted_id, public_key: "missing-audit-key" },
        )
      end
      assert_not passkey_class.exists?(owner_key => actor.id, :webauthn_id => omitted_id)
      [nil, {}].each do |audit|
        credential_id = SecureRandom.uuid
        assert_raises(ArgumentError, KeyError) do
          PasskeyRegistrationOperation.call!(
            actor: actor, passkey_class: passkey_class,
            attributes: { webauthn_id: credential_id, public_key: "missing-audit-key" }, audit: audit,
          )
        end
        assert_not passkey_class.exists?(owner_key => actor.id, :webauthn_id => credential_id)
      end
    end
  end

  test "registration rejects an audit event for a different operation on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      credential_id = SecureRandom.uuid
      assert_raises(ArgumentError) do
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: credential_id, public_key: "wrong-event-key" },
          audit: { event_type: "passkey.removed", surface: surface },
        )
      end
      assert_not passkey_class.exists?(owner_key => actor.id, :webauthn_id => credential_id)
    end
  end

  test "registration rejects another actor in its audit event on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      other = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      credential_id = SecureRandom.uuid
      assert_raises(ArgumentError) do
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: credential_id, public_key: "wrong-actor-key" },
          audit: { event_type: "passkey.registered.settings", surface: surface, actor_ref: other.public_id },
        )
      end
      assert_not passkey_class.exists?(owner_key => actor.id, :webauthn_id => credential_id)
    end
  end

  test "signup registration writes the owner's signup audit event" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    credential = PasskeyRegistrationOperation.call!(
      actor: actor, passkey_class: ClientPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "signup-key" },
      audit: { event_type: "passkey.registered.signup", surface: "app" },
    )
    event = ClientPasskeyAuditOutbox.find_by!(external_id: credential.external_id)

    assert_equal "passkey.registered.signup", event.event_type
    assert_equal actor.public_id, event.actor_ref
    assert_equal actor.id, credential.user_id
  end

  test "outer principal rollback removes both credential and audit event on every surface" do
    SURFACES.each do |actor_class, passkey_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      external_id = nil
      actor_class.transaction do
        record = PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "outer-rollback-key" },
          audit: { event_type: "passkey.registered.settings", surface: surface },
        )
        external_id = record.external_id
        raise ActiveRecord::Rollback
      end

      assert_not passkey_class.exists?(owner_key => actor.id, :external_id => external_id)
      assert_not PasskeyAuditOutbox.source_for(passkey_class.new).exists?(external_id: external_id)
    end
  end

  test "a passkey cannot cross its identity surface" do
    assert_raises(ArgumentError) do
      PasskeyRegistrationOperation.call!(
        actor: Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED),
        passkey_class: ClientPasskey,
        attributes: passkey_attributes(0),
        audit: audit("app"),
      )
    end
  end

  test "an explicit class cannot disguise a credential from another surface" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    foreign_record = OperatorPasskey.new(webauthn_id: SecureRandom.uuid, public_key: "foreign-key")

    assert_raises(ArgumentError) do
      PasskeyRegistrationOperation.call!(
        actor: actor, passkey: foreign_record, passkey_class: ClientPasskey,
        audit: { event_type: "passkey.registered.settings", surface: "app" },
      )
    end
    assert_predicate foreign_record, :new_record?
  end

  test "registration cannot reassign an existing credential to another owner" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = PasskeyRegistrationOperation.call!(
      actor: owner, passkey_class: ClientPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "existing-owner-key" },
      audit: { event_type: "passkey.registered.settings", surface: "app" },
    )

    assert_raises(ArgumentError) do
      PasskeyRegistrationOperation.call!(
        actor: other, passkey: record, audit: { event_type: "passkey.registered.settings", surface: "app" },
      )
    end
    assert_equal owner.id, record.reload.user_id
  end

  test "registration refuses a new credential already assigned to another owner" do
    [
      [Client, ClientPasskey, ClientPasskeyAuditOutbox, :user_id, "app", SecurityModeConfigurable::NORMAL],
      [Operator, OperatorPasskey, OperatorPasskeyAuditOutbox, :staff_id, "org", SecurityModeConfigurable::ADVANCED],
    ].each do |actor_class, passkey_class, outbox_class, owner_key, surface, security_mode|
      owner = actor_class.create!(security_mode_id: security_mode)
      other = actor_class.create!(security_mode_id: security_mode)
      record = passkey_class.new(
        owner_key => other.id, :webauthn_id => SecureRandom.uuid, :public_key => "different-owner-key",
      )

      assert_no_difference([-> { passkey_class.count }, -> { outbox_class.count }]) do
        assert_raises(ArgumentError) do
          PasskeyRegistrationOperation.call!(
            actor: owner, passkey: record, audit: { event_type: "passkey.registered.settings", surface: surface },
          )
        end
      end
      assert_equal other.id, record[owner_key]
      assert_predicate record, :new_record?
    end
  end

  test "registration accepts a new credential already assigned to its owner" do
    [
      [Client, ClientPasskey, :user_id, "app", SecurityModeConfigurable::NORMAL],
      [Operator, OperatorPasskey, :staff_id, "org", SecurityModeConfigurable::ADVANCED],
    ].each do |actor_class, passkey_class, owner_key, surface, security_mode|
      actor = actor_class.create!(security_mode_id: security_mode)
      record = passkey_class.new(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "matching-owner-key",
      )

      created = PasskeyRegistrationOperation.call!(
        actor: actor, passkey: record, audit: { event_type: "passkey.registered.settings", surface: surface },
      )

      assert_predicate created, :persisted?
      assert_equal actor.id, created.reload[owner_key]
      assert PasskeyAuditOutbox.source_for(created).exists?(
        external_id: created.external_id, actor_ref: actor.public_id,
      )
    end
  end

  private

  def register(actor, passkey_class, index, surface: "app")
    PasskeyRegistrationOperation.call!(
      actor:, passkey_class:, attributes: passkey_attributes(index), audit: audit(surface),
    )
  end

  def audit(surface)
    { event_type: "passkey.registered.settings", surface:, operation_ref: SecureRandom.uuid }
  end

  def passkey_attributes(index)
    {
      webauthn_id: "registration-webauthn-#{SecureRandom.uuid}-#{index}",
      public_key: "registration-public-key-#{index}",
      description: "Registration key #{index}",
    }
  end
end
