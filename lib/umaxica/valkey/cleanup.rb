# typed: false
# frozen_string_literal: true

require "set"

module Umaxica
  module Valkey
    # Prefix-scoped cleanup for tests. Never issues FLUSHALL/FLUSHDB.
    module Cleanup
      SCAN_COUNT = 100

      module_function

      def delete_by_prefix(connection, prefix:)
        raise ConfigurationError, "cleanup prefix is blank" if prefix.to_s.blank?
        raise ConfigurationError, "cleanup prefix must end with :" unless prefix.to_s.end_with?(":")

        cursor = "0"
        deleted = 0
        seen = Set.new
        loop do
          cursor, keys = connection.call("SCAN", cursor, "MATCH", "#{prefix}*", "COUNT", SCAN_COUNT)
          Array(keys).each do |key|
            next unless seen.add?(key)

            connection.call("DEL", key)
            deleted += 1
          end
          break if cursor.to_s == "0"
        end
        deleted
      end

      def ensure_empty!(connection, prefix:)
        remaining = 0
        cursor = "0"
        loop do
          cursor, keys = connection.call("SCAN", cursor, "MATCH", "#{prefix}*", "COUNT", SCAN_COUNT)
          remaining += Array(keys).size
          break if cursor.to_s == "0"
        end
        raise OperationError, "Valkey prefix #{prefix.inspect} still has #{remaining} keys" if remaining.positive?

        true
      end
    end
  end
end
