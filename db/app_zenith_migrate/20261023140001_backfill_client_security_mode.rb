# frozen_string_literal: true

# WU-30 data step (D-92, owner approval D-168): APP actors all start in NORMAL.
class BackfillClientSecurityMode < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("INSERT INTO client_security_modes (id) VALUES (3), (7) ON CONFLICT (id) DO NOTHING")
      execute("UPDATE clients SET security_mode_id = 3 WHERE security_mode_id IS NULL")
    end
  end

  def down
    safety_assured { execute("UPDATE clients SET security_mode_id = NULL") }
  end
end
