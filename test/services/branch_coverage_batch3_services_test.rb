# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch3ServicesTest < ActiveSupport::TestCase
  test "AcmeSelectableContext persist_selection! requires session" do
    klass =
      Class.new do
        include AcmeSelectableContext

        def session = nil

        def config = nil

        def principal = nil

        def accounts = []
      end
    error =
      assert_raises(AcmeSelectableContext::InvalidSelection) do
        klass.new.persist_selection!({ public: { account_public_id: "a" } })
      end
    assert_equal "session_required", error.message
  end

  private
end
