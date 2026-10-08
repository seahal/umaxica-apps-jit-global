# frozen_string_literal: true

require "test_helper"

# Fact comparisons must not disclose readable identifiers or lookup digests.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
# rubocop:disable Minitest/RefuteEqual
class RealmIdentifierHmacRotationTest < ActiveSupport::TestCase
  %w(app com).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} emergency rotation retains finalized ownership while replacing its lookup digest" do
        model, owner_attributes, identifier_attributes, digest_column, key_name =
          case [realm, channel]
          when ["app", "email"]
            [ClientEmail, { user: Client.create!(status_id: ClientStatus::ACTIVE) },
             { raw_address: "active-rotation-#{SecureRandom.hex(8)}@example.test" },
             :address_digest, "APP_EMAIL_ADDRESS_HMAC_KEY",]
          when ["com", "email"]
            [VisitorEmail, { visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE) },
             { raw_address: "active-rotation-#{SecureRandom.hex(8)}@example.test" },
             :address_digest, "COM_EMAIL_ADDRESS_HMAC_KEY",]
          when ["app", "telephone"]
            [ClientTelephone, { user: Client.create!(status_id: ClientStatus::ACTIVE) },
             { raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}", confirm_using_mfa: true },
             :number_digest, "APP_TELEPHONE_NUMBER_HMAC_KEY",]
          when ["com", "telephone"]
            [VisitorTelephone, { visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE) },
             { raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}", confirm_using_mfa: true },
             :number_digest, "COM_TELEPHONE_NUMBER_HMAC_KEY",]
          end
        record = model.create!(owner_attributes.merge(identifier_attributes).merge(confirm_policy: true))
        record.finalize_binding!
        facts = record.attributes
        original_key = ENV.fetch(key_name)
        ENV[key_name] = SecureRandom.hex(32)
        result =
          Rails.app.creds.stub(:option, nil) do
            IdentifierHmacEmergencyRotation.new(
              realm: realm, channel: channel, maintenance_connection: model.lease_connection.raw_connection,
            ).call
          end

        assert_equal 0, result.records_failed
        record.reload

        assert facts.fetch(digest_column.to_s) != record[digest_column], "The finalized lookup digest must rotate"
        assert facts.except(digest_column.to_s, "updated_at") ==
          record.attributes.except(digest_column.to_s, "updated_at"),
               "Rotation must preserve finalized ownership and all other lifecycle facts"
        audit_model = (realm == "app") ? ClientIdentifierRotationAudit : VisitorIdentifierRotationAudit
        audit = audit_model.find_by!(channel: channel, record_id: record.id)

        assert_equal model.lease_connection.raw_connection.user, audit.actor_role
        assert_match(/\A[0-9a-f-]{36}\z/, audit.operation_ref)
        assert audit.attributes.keys.sort == %w(id operation_ref channel record_id actor_role occurred_at).sort
      ensure
        ENV[key_name] = original_key if original_key
      end
    end
  end

  %w(app com org).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} emergency rotation changes only its explicitly selected identifier model" do
        client = Client.create!(status_id: ClientStatus::ACTIVE)
        visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
        operator = Operator.create!
        records = [
          ["app", "email", ClientEmail.create!(
            user: client, raw_address: "rotation-app-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          ), :address_digest, :user_emails_updated,],
          ["app", "telephone", ClientTelephone.create!(
            user: client, raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            confirm_policy: true, confirm_using_mfa: true,
          ), :number_digest, :user_telephones_updated,],
          ["com", "email", VisitorEmail.create!(
            visitor:, raw_address: "rotation-com-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          ), :address_digest, :visitor_emails_updated,],
          ["com", "telephone", VisitorTelephone.create!(
            visitor:, raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            confirm_policy: true, confirm_using_mfa: true,
          ), :number_digest, :visitor_telephones_updated,],
          ["org", "email", OperatorEmail.create!(
            staff: operator, raw_address: "rotation-org-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          ), :address_digest, :staff_emails_updated,],
          ["org", "telephone", OperatorTelephone.create!(
            staff: operator, raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            confirm_policy: true, confirm_using_mfa: true,
          ), :number_digest, :staff_telephones_updated,],
        ]
        records.each do |_, _, record, digest_column, _|
          # A stale digest models the authorized maintenance-window backfill input, not a lifecycle transition.
          record.update_columns(digest_column => SecureRandom.hex(32))
          record.reload
        end
        facts = records.map { |_, _, record, _, _| record.attributes }
        database =
          case realm
          when "app" then AppZenithRecord
          when "com" then ComZenithRecord
          when "org" then OrgZenithRecord
          end
        result = IdentifierHmacEmergencyRotation.new(
          realm: realm, channel: channel, maintenance_connection: database.lease_connection.raw_connection,
        ).call
        counts = result.to_h

        assert_equal 0, result.records_failed
        records.each_with_index do |(record_realm, record_channel, record, digest_column, result_key), index|
          record.reload
          if record_realm == realm && record_channel == channel
            expected =
              case channel
              when "email" then IdentifierBlindIndex.bidx_for_email(record.address, realm:)
              when "telephone" then IdentifierBlindIndex.bidx_for_telephone(record.number, realm:)
              end

            assert expected == record[digest_column], "Selected model must use only its realm/channel HMAC key"
            assert facts.fetch(index).fetch(digest_column.to_s) != record[digest_column],
                   "Selected stale digest must actually be replaced"
            assert facts.fetch(index).except(digest_column.to_s, "updated_at") ==
              record.attributes.except(digest_column.to_s, "updated_at"),
                   "Rotation must retain identifier ownership, readable PII, OTP and lifecycle facts"
            assert_operator counts.fetch(result_key), :>=, 1
          else
            assert facts.fetch(index) == record.attributes,
                   "Other realm/channel records must remain entirely unchanged, including stale digests"
            assert_equal 0, counts.fetch(result_key), "Unselected model must not be visited"
          end
        end
      end
    end
  end

  test "missing realm or channel refuses construction instead of selecting all six models" do
    assert_raises(ArgumentError) { IdentifierHmacEmergencyRotation.new }
    assert_raises(ArgumentError) { IdentifierHmacEmergencyRotation.new(realm: "com") }
    assert_raises(ArgumentError) { IdentifierHmacEmergencyRotation.new(channel: "telephone") }
    assert_raises(ArgumentError) { IdentifierHmacEmergencyRotation.new(targets: []) }
  end

  test "nil empty unknown NUL and non scalar realms refuse construction" do
    [nil, "", " ", "unknown", "com\0", 0, false, [], {}].each do |realm|
      assert_raises(ArgumentError) do
        IdentifierHmacEmergencyRotation.new(
          realm: realm, channel: "telephone", maintenance_connection: AppZenithRecord.lease_connection.raw_connection,
        )
      end
    end
  end

  test "nil empty unknown NUL and non scalar channels refuse construction" do
    [nil, "", " ", "unknown", "telephone\0", 0, false, [], {}].each do |channel|
      assert_raises(ArgumentError) do
        IdentifierHmacEmergencyRotation.new(
          realm: "com", channel: channel, maintenance_connection: ComZenithRecord.lease_connection.raw_connection,
        )
      end
    end
  end

  test "missing nil malformed and non PostgreSQL maintenance connections fail closed" do
    assert_raises(ArgumentError) { IdentifierHmacEmergencyRotation.new(realm: "app", channel: "email") }
    [nil, "", "postgres\0", 0, false, [], {}].each do |connection|
      assert_raises(ArgumentError) do
        IdentifierHmacEmergencyRotation.new(realm: "app", channel: "email", maintenance_connection: connection)
      end
    end
  end

  test "a COM maintenance connection cannot select APP identifiers" do
    assert_raises(ArgumentError) do
      IdentifierHmacEmergencyRotation.new(
        realm: "app", channel: "email", maintenance_connection: ComZenithRecord.lease_connection.raw_connection,
      )
    end
  end
end
# rubocop:enable Minitest/RefuteEqual
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
