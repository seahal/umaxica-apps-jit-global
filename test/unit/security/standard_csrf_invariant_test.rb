# typed: false
# frozen_string_literal: true

require "test_helper"

class StandardCsrfInvariantTest < ActiveSupport::TestCase
  test "application code does not define a custom valid_request_origin override" do
    offenders =
      Rails.root.glob("app/**/*.rb").filter_map do |path|
        relative = path.relative_path_from(Rails.root).to_s
        line_number =
          File.foreach(path).with_index(1).filter_map do |line, number|
            number if line.match?(/\bdef\s+valid_request_origin\?/)
          end.first
        line_number && "#{relative}:#{line_number}"
      end

    assert_empty offenders,
                 "Rails forgery protection must own Origin validation; remove custom overrides from:\n" \
                 "#{offenders.join("\n")}"
  end
end
