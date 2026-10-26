# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02BaseOpSessionIsolationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "A02-12: Base controllers and views never read Rails session keys written by Auth controllers" do
    auth_files = Dir.glob("app/controllers/auth/**/*.rb")
    base_files = Dir.glob("app/controllers/base/**/*.rb") + Dir.glob("app/views/base/**/*")
    auth_session_keys = auth_files.flat_map do |path|
      File.read(path).scan(/\bsession\s*(?:\[|\.dig\s*\()\s*:(\w+)/).flatten
    end.uniq
    offenders = base_files.flat_map do |path|
      next unless File.file?(path)

      File.read(path).lines.each_with_index.filter_map do |line, index|
        key = auth_session_keys.find do |session_key|
          line.match?(/\bsession\s*(?:\[\s*:(?:#{Regexp.escape(session_key)})\b|\.dig\s*\(\s*:(?:#{Regexp.escape(session_key)})\b)/)
        end
        "#{path}:#{index + 1}: Rails session key :#{key}" if key
      end
    end.compact

    assert_empty offenders, "Base must not consume Rails session keys written by Auth:\n#{offenders.join("\n")}"
  end
end
