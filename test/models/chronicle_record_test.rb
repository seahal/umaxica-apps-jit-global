# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleRecordTest < ActiveSupport::TestCase
  test "connects to chronicle database" do
    config = ChronicleRecord.connection_db_config

    assert_equal "chronicle", config.name
    assert_equal ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "chronicle").database,
                 config.database
    assert_equal config.database, ChronicleRecord.connection.select_value("SELECT current_database()")
  end

  test "can perform basic write and read via chronicle model" do
    temp_id = 99_991
    ClientChronicleLevel.where(id: temp_id).delete_all

    record = ClientChronicleLevel.create!(id: temp_id)

    assert_equal temp_id, record.id
    assert_equal record, ClientChronicleLevel.find(temp_id)
  ensure
    ClientChronicleLevel.where(id: temp_id).delete_all
  end
end
