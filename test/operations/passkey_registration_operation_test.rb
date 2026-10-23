# frozen_string_literal: true

require "test_helper"

class PasskeyRegistrationOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACES = [
    [Client, ClientPasskey, :user_id, "app"],
    [Visitor, VisitorPasskey, :visitor_id, "com"],
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
        passkey_class: Client, attributes: {},
      )
    end
  end

  test "only the credential ID constraint is classified as a duplicate credential on each surface" do
    SURFACES.each do |actor_class, passkey_class, _owner_key, _surface|
      owner = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      credential = PasskeyRegistrationOperation.call!(
        actor: owner, passkey_class: passkey_class,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "constraint-key" },
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
        actor: Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL),
        passkey_class: ClientPasskey,
        attributes: passkey_attributes(0),
        audit: audit("app"),
      )
    end
  end

  test "an explicit class cannot disguise a credential from another surface" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    foreign_record = VisitorPasskey.new(webauthn_id: SecureRandom.uuid, public_key: "foreign-key")

    assert_raises(ArgumentError) do
      PasskeyRegistrationOperation.call!(actor: actor, passkey: foreign_record, passkey_class: ClientPasskey)
    end
    assert_predicate foreign_record, :new_record?
  end

  test "registration cannot reassign an existing credential to another owner" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = PasskeyRegistrationOperation.call!(
      actor: owner, passkey_class: ClientPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "existing-owner-key" },
    )

    assert_raises(ArgumentError) { PasskeyRegistrationOperation.call!(actor: other, passkey: record) }
    assert_equal owner.id, record.reload.user_id
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
