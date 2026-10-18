# frozen_string_literal: true

class FixVisitorVerificationsVisitorTokenIdDefault < ActiveRecord::Migration[8.2]
  def up
    change_column_default :visitor_verifications, :visitor_token_id, nil
  end

  def down
    # Not reversible safely since we don't want the old sequence back
  end
end
