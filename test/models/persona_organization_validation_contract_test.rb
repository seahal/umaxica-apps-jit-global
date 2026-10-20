# frozen_string_literal: true

require "test_helper"

class PersonaOrganizationValidationContractTest < ActiveSupport::TestCase
  ORGANIZATIONS = [Enterprise, Company, Bureau].freeze
  PERSONAS = [
    [ClientPersona, ClientIdentity, ClientIdentityState, :client_identity, "acme_app"],
    [Individual, VisitorIdentity, VisitorIdentityState, :visitor_identity, "acme_com"],
    [Agent, OperatorIdentity, OperatorIdentityState, :operator_identity, "acme_org"],
  ].freeze

  ORGANIZATIONS.each do |model|
    test "#{model.name} saves title boundaries and string sentinels without changing name requirements" do
      [["A", "A"], ["A2", "A2"], ["A" * 9, "A" * 9], ["A" * 10, "A" * 10],
       [false, "f"], [true, "t"], [0, "0"],].each do |input, expected|
        record = model.create!(name: "Organization", title: input)

        assert_equal expected, record.reload.title
        assert_equal "Organization", record.name
      end

      [nil, "", " "].each do |name|
        record = model.new(name: name, title: "Valid")

        assert_not record.valid?
        assert record.errors.of_kind?(:name, :blank)
      end
    end

    test "#{model.name} retains saves of existing records projected without title" do
      record = model.create!(name: "Organization", title: "Valid")
      projected = model.select(model.column_names - ["title"]).find(record.id)

      projected.update!(name: "Updated")

      assert_equal "Updated", record.reload.name
      assert_equal "Valid", record.title
    end

    test "#{model.name} retains saves of existing records projected without name" do
      record = model.create!(name: "Organization", title: "Valid")
      projected = model.select(model.column_names - ["name"]).find(record.id)

      projected.update!(title: "Updated")

      assert_equal "Organization", record.reload.name
      assert_equal "Updated", record.title
    end

    test "#{model.name} rejects missing malformed and eleven character titles" do
      # Unicode is an intentional invalid-input partition for the ASCII title contract.
      [nil, "", " ", "bad title", "_", "名", "A" * 11].each do |title|
        record = model.new(name: "Organization", title: title)

        assert_not record.save
        assert_includes record.errors.attribute_names, :title
        assert_not_predicate record, :persisted?
      end
    end

    test "#{model.name} retains direct database null refusal for both required columns" do
      record = model.create!(name: "Organization", title: "Valid")
      connection = model.lease_connection

      %w(name title).each do |column|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            connection.transaction(requires_new: true) do
              # SQL is an internal persistence command, not localized copy.
              connection.execute(
                model.sanitize_sql_array(
                  ["UPDATE #{connection.quote_table_name(model.table_name)} " \
                   "SET #{connection.quote_column_name(column)} = NULL WHERE id = ?", record.id,],
                ),
              )
            end
          end
        assert_instance_of PG::NotNullViolation, error.cause
        assert_equal "Organization", record.reload.name
        assert_equal "Valid", record.title
      end
    end
  end

  PERSONAS.each do |model, identity_model, state_model, identity_key, audience|
    test "#{model.name} saves title boundaries and normalized boolean numeric sentinels" do
      state_model.ensure_defaults!
      [["A", "A"], ["A2", "A2"], ["A" * 9, "A" * 9], ["A" * 10, "A" * 10],
       [false, "f"], [true, "t"], [0, "0"],].each_with_index do |(input, expected), index|
        identity = identity_model.create!(
          issuer: "https://id.example.test", subject: "title-boundary-#{index}", audience: audience,
          source_record_id: 930_000 + index, status_id: state_model::ACTIVE,
        )
        record = model.create!(identity_key => identity, :title => input)

        assert_equal expected, record.reload.title
        assert_equal identity.id, record.attributes.fetch("#{identity_key}_id")
      end
    end

    test "#{model.name} retains saves of existing records projected without title" do
      state_model.ensure_defaults!
      identity = identity_model.create!(
        issuer: "https://id.example.test", subject: "projected-title", audience: audience,
        source_record_id: 960_000, status_id: state_model::ACTIVE,
      )
      record = model.create!(identity_key => identity, :title => "Valid")
      projected = model.select(model.column_names - ["title"]).find(record.id)

      projected.save!

      assert_equal "Valid", record.reload.title
      assert_equal identity.id, record.attributes.fetch("#{identity_key}_id")
    end

    test "#{model.name} rejects missing malformed and eleven character titles" do
      state_model.ensure_defaults!
      identity = identity_model.create!(
        issuer: "https://id.example.test", subject: "invalid-title", audience: audience,
        source_record_id: 940_000, status_id: state_model::ACTIVE,
      )
      # Unicode is an intentional invalid-input partition for the ASCII title contract.
      [nil, "", " ", "bad title", "_", "名", "A" * 11].each do |title|
        record = model.new(identity_key => identity, :title => title)

        assert_not record.save
        assert_includes record.errors.attribute_names, :title
        assert_not_predicate record, :persisted?
      end
    end

    test "#{model.name} retains direct database title null refusal" do
      state_model.ensure_defaults!
      identity = identity_model.create!(
        issuer: "https://id.example.test", subject: "null-title", audience: audience,
        source_record_id: 950_000, status_id: state_model::ACTIVE,
      )
      record = model.create!(identity_key => identity, :title => "Valid")
      connection = model.lease_connection

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          connection.transaction(requires_new: true) do
            # SQL is an internal persistence command, not localized copy.
            # rubocop:disable I18n/RailsI18n/DecorateString
            connection.execute(
              model.sanitize_sql_array(
                [
                  "UPDATE #{connection.quote_table_name(model.table_name)} SET title = NULL WHERE id = ?", record.id,
                ],
              ),
            )
            # rubocop:enable I18n/RailsI18n/DecorateString
          end
        end
      assert_instance_of PG::NotNullViolation, error.cause
      assert_equal "Valid", record.reload.title
    end
  end

  [Enterprise, Company, Bureau, ClientPersona, Individual, Agent].each do |model|
    test "#{model.name} renders title rejection messages in both languages" do
      [[:en, "Title"], [:ja, "タイトル"]].each do |locale, label|
        I18n.with_locale(locale) do
          [[nil, :blank], ["", :blank], ["bad title", :invalid], ["A" * 11, :too_long]].each do |title, kind|
            record = model.new(title: title)

            assert_not record.valid?
            assert record.errors.of_kind?(:title, kind)
            messages = record.errors.full_messages_for(:title)

            assert_not_empty messages
            messages.each { |message| assert_includes message, label }
          end
        end
      end
    end
  end

  test "legacy organization remains persistable without a title column" do
    OrganizationStatus.find_or_create_by!(id: OrganizationStatus::NOTHING)
    record = OperatorOrganization.create!(
      name: "Legacy", domain: "legacy-title-contract.example", workspace_status_id: OrganizationStatus::NOTHING,
    )

    assert_equal "Legacy", record.reload.name
    assert_not record.has_attribute?(:title)
  end

  test "legacy organization retains its name validation error" do
    OrganizationStatus.find_or_create_by!(id: OrganizationStatus::NOTHING)
    record = OperatorOrganization.new(domain: "legacy-name-contract.example")

    assert_not record.valid?
    assert_equal 1, record.errors.where(:name, :blank).size
    assert_not record.has_attribute?(:title)
  end
end
