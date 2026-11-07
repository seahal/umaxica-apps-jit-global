# frozen_string_literal: true

require "active_record/middleware/database_selector"

# Rails' DatabaseSelector routes a read to the replica once the session's last write is older
# than its delay, measured against `Time.now`. Two things break that here: a test that travels
# the clock makes an immediate read look stale, and a read with no prior write in the session
# (the timestamp defaults to the epoch) always looks stale. The test environment's replica
# databases are static copies that never receive the rows a test commits, so either read cannot
# see them. Tests that travel, or that read before their first write, call
# `keep_reads_on_primary!` in setup and `restore_database_selector_delay!` in teardown; while
# that is in effect every read resolves to the primary.
module DatabaseSelectorPrimary
  # Reports a last write of "just now", which keeps `time_since_last_write_ok?` false and the
  # read on the primary for as long as the surrounding test keeps `forced` set.
  module FreshLastWrite
    def last_write_timestamp
      return Time.current if DatabaseSelectorPrimary.forced

      super
    end
  end

  class << self
    def forced
      @forced
    end

    def forced=(value)
      @forced = value
    end
  end

  def keep_reads_on_primary!
    DatabaseSelectorPrimary.forced = true
  end

  def restore_database_selector_delay!
    DatabaseSelectorPrimary.forced = false
  end
end

ActiveRecord::Middleware::DatabaseSelector::Resolver::Session.prepend(DatabaseSelectorPrimary::FreshLastWrite)
