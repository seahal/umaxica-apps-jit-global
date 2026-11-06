# frozen_string_literal: true

class PreserveEmptyRpBaseAppSessionSelectionMigration < ActiveRecord::Migration[8.2]
  # This empty version was recorded in the development DB before the staged constraints were
  # finalized. Actual validation is performed by 20261105065916.
  def change
  end
end
