# typed: false
# frozen_string_literal: true

require "test_helper"

class StandardCsrfInvariantTest < ActiveSupport::TestCase
  test "application and library code leave Rails request acceptance and CSRF exception handling unchanged" do
    offenders =
      Rails.root.glob("{app,lib}/**/*.rb").filter_map do |path|
        relative = path.relative_path_from(Rails.root).to_s
        line_number =
          File.foreach(path).with_index(1).filter_map do |line, number|
            number if line.match?(/^\s*def\s+(?:valid_request_origin\?|verified_request\?|handle_unverified_request\b)/)
          end.first
        line_number && "#{relative}:#{line_number}"
      end

    assert_empty offenders,
                 "Rails forgery protection must own request acceptance; remove custom overrides from:\n" \
                 "#{offenders.join("\n")}"
  end
end
