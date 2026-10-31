# typed: false
# frozen_string_literal: true

# Tracks which preference fields the user set explicitly. Child rows hold values; this list records
# which values came from a deliberate actor choice rather than a default.
module PreferenceExplicitFields
  extend ActiveSupport::Concern

  public

  def explicit_field?(field)
    explicit_field_names.include?(field.to_s)
  end

  def explicit_field_names
    explicit_fields.map(&:to_s)
  end

  def mark_field_explicit!(field)
    normalized = field.to_s
    names = explicit_field_names
    return if names.include?(normalized)

    update!(explicit_fields: (names + [normalized]).uniq)
  end

  def clear_explicit_fields!
    return if explicit_field_names.empty?

    update!(explicit_fields: [])
  end
end
