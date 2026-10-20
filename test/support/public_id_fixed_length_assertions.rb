# frozen_string_literal: true

# Contract for NanoID public_id columns (adr/identifier-contract.md): storage and validation are
# fixed at the 21-character generation length. Each PublicId model's own test calls
# assert_public_id_fixed_length, so the contract is visible next to the model it describes.
module PublicIdFixedLengthAssertions
  PUBLIC_ID_LENGTH = 21
  # One below, at and one above the fixed length; only the exact length is accepted.
  PUBLIC_ID_LENGTH_BOUNDARIES = { 20 => false, 21 => true, 22 => false }.freeze

  def assert_public_id_fixed_length(model)
    assert_equal "character varying(#{PUBLIC_ID_LENGTH})", model.columns_hash.fetch("public_id").sql_type

    PUBLIC_ID_LENGTH_BOUNDARIES.each do |length, accepted|
      value = "a" * length
      errors = public_id_validation_errors(model, value)

      if accepted
        assert_empty errors, "#{model.name} must accept a #{length}-character public_id"
      else
        assert_includes errors, :wrong_length, "#{model.name} must reject a #{length}-character public_id"
      end

      assert_equal accepted, public_id_database_accepts?(model, value),
                   "#{model.table_name} must #{accepted ? "accept" : "refuse"} #{length} characters in the database"
    end

    # Missing and empty values are their own partitions: the model reports them as blank.
    [nil, ""].each do |value|
      assert_includes public_id_validation_errors(model, value), :blank,
                      "#{model.name} must reject a #{value.inspect} public_id"
    end
  end

  private

  # Runs only the presence and length validations on public_id, so the check needs no other
  # attributes, no callbacks and no uniqueness query.
  def public_id_validation_errors(model, value)
    record = model.new
    record.public_id = value
    model.validators_on(:public_id)
      .select { |validator| %i(presence length).include?(validator.kind) }
      .each { |validator| validator.validate(record) }
    record.errors.details[:public_id].pluck(:error)
  end

  # Evaluates the table's public_id CHECK constraints against a literal value.
  def public_id_database_accepts?(model, value)
    model.with_connection do |connection|
      expressions = connection.check_constraints(model.table_name).map(&:expression)
        .grep(/char_length\(\(?public_id\)?(::text)?\)/)
      return true if expressions.empty?

      table = connection.quote_table_name(model.table_name)
      connection.select_value(
        "SELECT #{expressions.map { |expression| "(#{expression})" }.join(" AND ")} " \
        "FROM (SELECT #{connection.quote(value)}::varchar AS public_id) AS #{table}",
      )
    end
  end
end
