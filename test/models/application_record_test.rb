# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "database_now reads the writer database clock" do
    database_now = Client.database_now
    writer_now = Client.connection.select_value("SELECT clock_timestamp()")

    assert_instance_of Time, database_now
    assert_instance_of Time, writer_now
    assert_in_delta writer_now.to_f, database_now.to_f, 1.0
  end

  test "clear_fixed_id_seed_cache! clears the cache" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    ApplicationRecord.insert_missing_fixed_ids!([99_999])
    assert_nothing_raised do
      ApplicationRecord.clear_fixed_id_seed_cache!
    end
  end

  test "insert_missing_fixed_ids! creates records for missing IDs" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_000

    assert_not_predicate ClientStatus.where(id: missing_id), :exists?

    assert_nothing_raised do
      ClientStatus.insert_missing_fixed_ids!([missing_id])
    end

    assert_predicate ClientStatus.where(id: missing_id), :exists?
  end

  test "insert_missing_fixed_ids! is idempotent" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_001

    ClientStatus.insert_missing_fixed_ids!([missing_id])
    count = ClientStatus.where(id: missing_id).count

    ClientStatus.insert_missing_fixed_ids!([missing_id])

    assert_equal count, ClientStatus.where(id: missing_id).count
  end

  test "insert_missing_fixed_ids! handles blank ids" do
    assert_nothing_raised do
      ApplicationRecord.insert_missing_fixed_ids!([])
    end
  end

  test "insert_missing_fixed_ids! handles nil ids" do
    assert_nothing_raised do
      ApplicationRecord.insert_missing_fixed_ids!(nil)
    end
  end

  test "insert_missing_fixed_ids! skips when table does not exist" do
    ApplicationRecord.clear_fixed_id_seed_cache!

    nonexistent_class =
      Class.new(ApplicationRecord) do
        self.table_name = "nonexistent_table_for_test"
      end

    assert_nothing_raised do
      nonexistent_class.insert_missing_fixed_ids!([1])
    end
  end

  test "insert_missing_fixed_ids! skips when all ids already present" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    existing = ClientStatus.first!

    assert_nothing_raised do
      ClientStatus.insert_missing_fixed_ids!([existing.id])
    end
  end

  test "insert_missing_fixed_ids! uses cache to skip redundant work" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_002

    ClientStatus.insert_missing_fixed_ids!([missing_id])

    # Second call should hit cache and skip
    assert_nothing_raised do
      ClientStatus.insert_missing_fixed_ids!([missing_id])
    end
  end

  test "insert_missing_fixed_ids! does not hide a bulk insert database failure" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_003
    prosopite = defined?(Prosopite) ? Prosopite : nil

    Object.send(:remove_const, :Prosopite) if prosopite

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientStatus.stub(:insert_all, ->(*) { raise ActiveRecord::StatementInvalid, "unsupported" }) do
        ClientStatus.insert_missing_fixed_ids!([missing_id])
      end
    end

    assert_not_predicate ClientStatus.where(id: missing_id), :exists?
  ensure
    Object.const_set(:Prosopite, prosopite) if prosopite && !defined?(Prosopite)
  end

  test "insert_missing_fixed_ids! fallback tolerates concurrent creation collisions" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_004
    prosopite = defined?(Prosopite) ? Prosopite : nil

    Object.send(:remove_const, :Prosopite) if prosopite

    relation = ClientStatus.where(id: missing_id)

    ClientStatus.stub(:insert_all, ->(*) { raise ActiveRecord::RecordNotUnique, "duplicate" }) do
      relation.stub(:first_or_create!, -> { raise ActiveRecord::RecordNotUnique, "duplicate" }) do
        ClientStatus.stub(
          :where, ->(conditions) {
                    if conditions["id"] == missing_id || conditions[:id] == missing_id
                      relation
                    else
                      ClientStatus.unscoped.where(conditions)
                    end
                  },
        ) do
          assert_nothing_raised do
            ClientStatus.insert_missing_fixed_ids!([missing_id])
          end
        end
      end
    end
  ensure
    Object.const_set(:Prosopite, prosopite) if prosopite && !defined?(Prosopite)
  end
end
