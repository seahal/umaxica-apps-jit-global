# typed: false
# frozen_string_literal: true

class ConvertClientAuthAdmissionBindingTimestamps < ActiveRecord::Migration[8.2]
  COLUMNS = %w(base_confirmed_at redeemed_at retired_at expires_at created_at updated_at).freeze

  def up
    convert_to_timestamptz
  end

  def down
    convert_to_timestamp
  end

  private

  def convert_to_timestamptz
    COLUMNS.each do |column|
      safety_assured do
        execute <<~SQL
          ALTER TABLE client_auth_admission_bindings
          ALTER COLUMN #{column} TYPE timestamptz
          USING #{column} AT TIME ZONE 'UTC'
        SQL
      end
    end
  end

  def convert_to_timestamp
    COLUMNS.each do |column|
      safety_assured do
        execute <<~SQL
          ALTER TABLE client_auth_admission_bindings
          ALTER COLUMN #{column} TYPE timestamp
          USING #{column} AT TIME ZONE 'UTC'
        SQL
      end
    end
  end
end
