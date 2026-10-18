# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    # Authorization codes, token usages, and OIDC connection records live on the
    # per-surface ticket databases (OpBaseAppRecord / OpBaseComRecord /
    # OpBaseOrgRecord), which are separate connections from ActiveRecord::Base.
    #
    # `ActiveRecord::Base.transaction` therefore opens a transaction on the
    # primary connection and wraps none of those writes. A `lock!` taken inside
    # such a block runs in autocommit: the SELECT ... FOR UPDATE commits and
    # releases immediately, so a `consumed?` check followed by `consume!` is a
    # TOCTOU window in which one authorization code can be redeemed twice.
    class TicketTransactionConnectionInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      TICKET_CONNECTION_CLASSES = %w(OpBaseAppRecord OpBaseComRecord OpBaseOrgRecord).freeze

      # Services that lock or consume ticket-owned rows. None may open its
      # transaction on ActiveRecord::Base.
      TICKET_TRANSACTION_SERVICES = %w(
        app/services/oidc_token_exchange_coordinator.rb
        app/operations/oidc_refresh_token_issuer.rb
      ).freeze

      test "ticket connections are distinct from the primary connection" do
        primary_database = ActiveRecord::Base.connection_db_config.database

        TICKET_CONNECTION_CLASSES.each do |class_name|
          ticket_database = class_name.constantize.connection_db_config.database

          assert_not_equal primary_database, ticket_database,
                           "#{class_name} shares a database with ActiveRecord::Base. If that ever becomes " \
                           "true, revisit this invariant - but until then ActiveRecord::Base.transaction " \
                           "cannot protect #{class_name} rows."
        end
      end

      test "services that lock ticket rows do not open transactions on ActiveRecord::Base" do
        offenders =
          TICKET_TRANSACTION_SERVICES.filter_map do |relative_path|
            path = Rails.root.join(relative_path)
            next unless path.exist?

            matching_lines =
              path.read.lines.each_with_index.filter_map do |line, index|
                stripped = line.strip
                next if stripped.start_with?("#") # comments may name the pattern to explain why it is wrong
                next unless stripped.include?("ActiveRecord::Base.transaction")

                "#{relative_path}:#{index + 1}: #{stripped}"
              end

            matching_lines.presence
          end.flatten

        assert_empty offenders,
                     "These services write ticket-owned rows but open their transaction on the primary " \
                     "connection, so the transaction wraps nothing and `lock!` runs in autocommit:\n  " \
                     "#{offenders.join("\n  ")}\n" \
                     "Use the owning connection class instead, e.g. `OpBaseAppRecord.transaction`."
      end

      test "the token exchange coordinator opens its transaction on the code's own connection" do
        source = Rails.root.join("app/services/oidc_token_exchange_coordinator.rb").read

        assert_includes source, "connection_class.transaction",
                        "The authorization-code consume path must hold its row lock and its consume in one " \
                        "transaction on the ticket connection, otherwise a code can be redeemed twice."
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
