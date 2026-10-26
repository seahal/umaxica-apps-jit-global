# frozen_string_literal: true

# WU-34 / D-128 (owner approval D-168): COM gets the APP registration states. Existing COM data is
# development-only and volatile under D-168, so no Visitor row is moved.
class AddVisitorRegistrationStatuses < ActiveRecord::Migration[8.2]
  def up
    safety_assured { execute("INSERT INTO visitor_statuses (id) VALUES (4), (5) ON CONFLICT (id) DO NOTHING") }
  end

  def down
    safety_assured { execute("DELETE FROM visitor_statuses WHERE id IN (4, 5)") }
  end
end
