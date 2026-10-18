# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch17CompletionsAndEmailsTest < ActiveSupport::TestCase
  test "authentication audit writer skipped class include" do
    assert defined?(AuthenticationAuditWriter)
  end
end
