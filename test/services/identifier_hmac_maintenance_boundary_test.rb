# frozen_string_literal: true

require "test_helper"

# Fact comparisons must not disclose decrypted identifiers or credential material on failure.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
class IdentifierHmacMaintenanceBoundaryTest < ActiveSupport::TestCase
  %w(app com).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} scoped maintenance preserves binding and refuses direct writes and peer execution" do
        model, owner, owner_key, identifier, digest_column, audit_model =
          case [realm, channel]
          when ["app", "email"]
            [ClientEmail, Client.create!(status_id: ClientStatus::ACTIVE), :user_id,
             { raw_address: "maintenance-#{SecureRandom.hex(8)}@example.test" }, :address_digest,
             ClientIdentifierRotationAudit,]
          when ["com", "email"]
            [VisitorEmail, Visitor.create!(status_id: VisitorStatus::ACTIVE), :visitor_id,
             { raw_address: "maintenance-#{SecureRandom.hex(8)}@example.test" }, :address_digest,
             VisitorIdentifierRotationAudit,]
          when ["app", "telephone"]
            [ClientTelephone, Client.create!(status_id: ClientStatus::ACTIVE), :user_id,
             { raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}", confirm_using_mfa: true },
             :number_digest, ClientIdentifierRotationAudit,]
          when ["com", "telephone"]
            [VisitorTelephone, Visitor.create!(status_id: VisitorStatus::ACTIVE), :visitor_id,
             { raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}", confirm_using_mfa: true },
             :number_digest, VisitorIdentifierRotationAudit,]
          end
        record = model.create!(identifier.merge(owner_key => owner.id, :confirm_policy => true))
        desired_digest = SecureRandom.hex(32)
        record.reload.finalize_binding!
        facts = record.attributes
        connection = model.lease_connection
        raw = connection.raw_connection
        function = "public.rotate_#{model.table_name}_hmac"
        peer_table =
          (channel == "email") ? model.table_name.sub(/emails\z/, "telephones") :
                   model.table_name.sub(/telephones\z/, "emails")
        definer = raw.exec_params(
          "SELECT r.rolname FROM pg_catalog.pg_proc p " \
          "JOIN pg_catalog.pg_roles r ON r.oid = p.proowner WHERE p.oid = $1::regprocedure",
          ["#{function}(bigint,text,text,uuid)"],
        ).getvalue(0, 0)
        prefix = "umaxica_#{realm}_#{channel}_hmac_definer_"

        assert_match(/\A#{Regexp.escape(prefix)}[0-9a-f]{12}\z/, definer)
        caller_role = "umaxica_#{realm}_#{channel}_hmac_caller_#{definer.delete_prefix(prefix)}"
        operation_ref = SecureRandom.uuid

        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { record.update_columns(digest_column => desired_digest) }
        end

        model.transaction(requires_new: true) do
          connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
          response = raw.exec_params(
            "SELECT #{function}($1, $2, $3, $4)::text",
            [record.id, desired_digest, facts.fetch(digest_column.to_s), operation_ref],
          ).getvalue(0, 0)

          assert_equal "true", response
          connection.execute("RESET ROLE")
        end
        after = record.reload.attributes

        assert facts.except(digest_column.to_s) == after.except(digest_column.to_s),
               "Maintenance must not change owner, PII, binding state, proof or timestamps"
        assert desired_digest == record[digest_column], "The selected lookup digest must be replaced"
        audit = audit_model.find_by!(operation_ref: operation_ref, record_id: record.id, channel: channel)

        assert_equal raw.user, audit.actor_role

        invalid_arguments = [
          [nil, desired_digest, SecureRandom.uuid],
          [-1, desired_digest, SecureRandom.uuid],
          [0, desired_digest, SecureRandom.uuid],
          [record.id, nil, SecureRandom.uuid],
          [record.id, "", SecureRandom.uuid],
          [record.id, "a" * 63, SecureRandom.uuid],
          [record.id, "a" * 65, SecureRandom.uuid],
          [record.id, "A" * 64, SecureRandom.uuid],
          [record.id, "g" * 64, SecureRandom.uuid],
          [record.id, desired_digest, nil],
        ]

        invalid_arguments.each do |record_id, new_digest, reference|
          assert_raises(PG::RaiseException) do
            model.transaction(requires_new: true) do
              connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
              raw.exec_params(
                "SELECT #{function}($1, $2, $3, $4)",
                [record_id, new_digest, desired_digest, reference],
              )
            end
          end
        end
        assert_raises(PG::TRSerializationFailure) do
          model.transaction(requires_new: true) do
            connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
            raw.exec_params(
              "SELECT #{function}($1, $2, $3, $4)",
              [record.id, SecureRandom.hex(32), nil, SecureRandom.uuid],
            )
          end
        end
        model.transaction(requires_new: true) do
          connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
          response = raw.exec_params(
            "SELECT #{function}($1, $2, $3, $4)::text",
            [record.id, desired_digest, desired_digest, SecureRandom.uuid],
          ).getvalue(0, 0)

          assert_equal "false", response
          connection.execute("RESET ROLE")
        end

        assert after == record.reload.attributes, "Rejected arguments and stale snapshots must preserve Source facts"
        assert_equal 1, audit_model.where(record_id: record.id, channel: channel).count
        assert_raises(PG::InsufficientPrivilege) do
          model.transaction(requires_new: true) do
            connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
            raw.exec_params(
              # SQL is not customer copy and must not be localized.
              "UPDATE public.#{model.table_name} SET #{digest_column} = $1 WHERE id = $2", # rubocop:disable I18n/RailsI18n/DecorateString
              [SecureRandom.hex(32), record.id],
            )
          end
        end
        assert_raises(PG::InsufficientPrivilege) do
          model.transaction(requires_new: true) do
            connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
            raw.exec_params(
              "SELECT public.rotate_#{peer_table}_hmac($1, $2, $3, $4)",
              [record.id, desired_digest, desired_digest, SecureRandom.uuid],
            )
          end
        end
        assert_raises(PG::UniqueViolation) do
          model.transaction(requires_new: true) do
            connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
            raw.exec_params(
              "SELECT #{function}($1, $2, $3, $4)",
              [record.id, SecureRandom.hex(32), desired_digest, operation_ref],
            )
          end
        end

        assert after == record.reload.attributes, "Audit insert failure must roll back the digest mutation"
        assert_equal 1, audit_model.where(operation_ref: operation_ref).count

        assert_raises(PG::RaiseException) do
          model.transaction(requires_new: true) do
            connection.execute("ALTER FUNCTION #{function}(bigint, text, text, uuid) OWNER TO CURRENT_USER")
            raw.exec_params(
              "SELECT #{function}($1, $2, $3, $4)",
              [record.id, desired_digest, desired_digest, SecureRandom.uuid],
            )
          end
        end
      ensure
        connection&.execute("RESET ROLE")
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
