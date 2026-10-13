# frozen_string_literal: true

require "test_helper"

class SettingPreferencePublicIdImmutabilityTest < ActiveSupport::TestCase
  [AppPreference, ComPreference, OrgPreference].each do |model|
    %i(update_columns update_all upsert_all sql).each do |writer|
      test "#{model.name} rejects permanent identity replacement through #{writer}" do
        preference = model.create!
        original = preference.public_id
        replacement = (original == "a" * 21) ? "b" * 21 : "a" * 21

        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) do
              case writer
              when :update_columns
                preference.update_columns(public_id: replacement)
              when :update_all
                model.where(id: preference.id).update_all(public_id: replacement)
              when :upsert_all
                model.upsert_all([preference.attributes.merge("public_id" => replacement)])
              when :sql
                connection = model.lease_connection
                connection.execute(
                  "UPDATE #{connection.quote_table_name(model.table_name)} " \
                  "SET public_id = #{connection.quote(replacement)} WHERE id = #{connection.quote(preference.id)}",
                )
              else
                raise ArgumentError, "unsupported identity writer"
              end
            end
          end

        assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
        assert_equal "#{model.table_name}_public_id_immutable",
                     error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
        assert_equal original, preference.reload.public_id
      end
    end

    test "#{model.name} rejects null and blank replacement without losing issued identity" do
      preference = model.create!
      original = preference.public_id

      [nil, "", " "].each do |replacement|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { preference.update_columns(public_id: replacement) }
          end

        assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
        assert_equal original, preference.reload.public_id
      end
    end

    test "#{model.name} permits same identity and unrelated mutable state updates" do
      preference = model.create!
      original = preference.public_id
      used_at = Time.current.change(usec: 0)

      preference.update_columns(public_id: original)
      model.where(id: preference.id).update_all(public_id: original)
      model.upsert_all([preference.attributes.merge("public_id" => original)])
      preference.update!(used_at: used_at)

      assert_equal original, preference.reload.public_id
      assert_equal used_at, preference.used_at
    end

    test "#{model.name} retains immutable identity after logical deletion" do
      preference = model.create!
      original = preference.public_id
      preference.update!(discard_at: Time.current)
      replacement = (original == "a" * 21) ? "b" * 21 : "a" * 21

      assert_raises(ActiveRecord::StatementInvalid) do
        model.transaction(requires_new: true) { preference.update_columns(public_id: replacement) }
      end

      assert_equal original, preference.reload.public_id
    end
  end
end
