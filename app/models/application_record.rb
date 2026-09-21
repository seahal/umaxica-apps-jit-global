# typed: false
# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Every domain gets its own dedicated abstract class with its own `connects_to`
  # (PublishingRecord, AppTicketRecord, ...); nothing does business logic through
  # ApplicationRecord directly. Without a connection of its own, though,
  # `ActiveRecord::Base.connection` (what any gem or Rails-provided model that skips those
  # dedicated classes ends up calling -- rails_db's dashboard, ActiveStorage, ActionMailbox)
  # raised ActiveRecord::ConnectionNotEstablished, and DatabaseSelector
  # (config/initializers/multi_db.rb) wraps every GET in `connected_to(role: :reading)`, which
  # needs a reading pool to exist at all or raises ActiveRecord::ConnectionNotDefined. `primary`
  # is this repository's conventional default database for exactly this kind of
  # application-wide, non-domain-specific state (Flipper's own model connects to it the same
  # way; see config/initializers/flipper.rb and adr/global-regional-database-ownership.md).
  connects_to database: { writing: :primary, reading: :primary }

  # Return one instant from this model's writer database. `clock_timestamp()`
  # is deliberately read outside the query cache so a state transition does
  # not reuse a previously cached wall-clock value. Callers should obtain it
  # after acquiring any lock required for their decision and pass the value
  # through the rest of that decision unit.
  def self.database_now
    value = uncached { lease_connection.select_value("SELECT clock_timestamp()", "DatabaseClock") }
    value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
  end
  public_class_method :database_now

  FIXED_ID_SEED_CACHE = Concurrent::Map.new
  private_constant :FIXED_ID_SEED_CACHE

  def self.clear_fixed_id_seed_cache!
    FIXED_ID_SEED_CACHE.clear
  end

  # Guarantees the fixed-id rows a reference table depends on (its DEFAULTS /
  # enum constants) exist, without duplicating any that are already present.
  # Called from db/seeds.rb and config/initializers/preference_reference_defaults.rb
  # (and, as a fallback, from the request path when a reference table is found
  # empty after db:reset). Re-running it inserts nothing new.
  #
  # Only a duplicate fixed id is an expected race: another writer may have
  # inserted the same reference row after the initial presence check. Other
  # database failures must escape so a partial reference set cannot be reported
  # as successfully seeded.
  def self.insert_missing_fixed_ids!(ids)
    return if ids.blank?

    # The boot initializer can run before migrations on a fresh database, so a
    # missing table is an expected state here, not an error. lease_connection is
    # the Rails 8 accessor for a connection outside a checked-out block.
    return unless lease_connection.data_source_exists?(table_name)

    fixed_ids = ids.uniq
    seed_key = "#{name}:#{connection_db_config&.name || "default"}:#{fixed_ids.sort.join(",")}"

    present_ids = pluck_fixed_ids(fixed_ids)
    missing_ids = fixed_ids - present_ids
    return if FIXED_ID_SEED_CACHE[seed_key] && missing_ids.blank?
    return if missing_ids.blank?

    operation =
      lambda do
        now = Time.current
        rows =
          missing_ids.map do |id|
            row = { primary_key => id }
            if record_timestamps
              row["created_at"] = now if column_names.include?("created_at")
              row["updated_at"] = now if column_names.include?("updated_at")
            end
            row
          end

        insert_all(rows)
      rescue ActiveRecord::RecordNotUnique
        # Fallback for concurrent inserts or models without insert_all support
        missing_ids.each do |id|
          where(primary_key => id).first_or_create!
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end

    if defined?(Prosopite)
      Prosopite.pause(&operation)
    else
      operation.call
    end

    FIXED_ID_SEED_CACHE[seed_key] = true
  end

  def self.pluck_fixed_ids(fixed_ids)
    if defined?(Prosopite)
      Prosopite.pause { where(primary_key => fixed_ids).pluck(primary_key) }
    else
      where(primary_key => fixed_ids).pluck(primary_key)
    end
  end
  private_class_method :pluck_fixed_ids
end
