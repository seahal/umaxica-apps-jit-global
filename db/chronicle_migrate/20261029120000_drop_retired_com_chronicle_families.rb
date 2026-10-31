# frozen_string_literal: true

# WU-5: the com realm visitor account family was retired (two.md WU-3/WU-4), so the chronicle-side
# com document and com timeline audit/behavior families have no writer or reader. The
# com_preference chronicle family stays: the anonymous com Preference surface survives until WU-7.
class DropRetiredComChronicleFamilies < ActiveRecord::Migration[8.2]
  RETIRED_TABLES = %w(
    com_document_audits
    com_document_audit_events
    com_document_audit_levels
    com_document_behaviors
    com_document_behavior_events
    com_document_behavior_levels
    com_timeline_audits
    com_timeline_audit_events
    com_timeline_audit_levels
    com_timeline_behaviors
    com_timeline_behavior_events
    com_timeline_behavior_levels
  ).freeze

  def up
    # The retired com realm owns no rows that another retained table references. Drop without
    # touching the shared app/org chronicle families or the retained com_preference family.
    RETIRED_TABLES.each do |table|
      safety_assured { drop_table table }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "retired com chronicle data was intentionally removed"
  end
end
