# frozen_string_literal: true

# WU-17 data step: a root or grant without a recorded authentication epoch is set to 0, the epoch
# of an actor that was never stopped. Owner approval: D-168. Separate from the schema change.
class BackfillAuthenticationEpochOpBaseCom < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      %w(visitor_tokens op_com_grants).each do |table|
        execute("UPDATE #{table} SET authentication_epoch = 0 WHERE authentication_epoch IS NULL")
      end
    end
  end

  def down
    # Nothing to restore: the rows that were NULL are not recorded.
  end
end
