# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ProsopiteSmokeTest < ActionDispatch::IntegrationTest
  test "prosopite raises for n+1 queries in integration tests" do
    created_user_ids =
      Prosopite.pause do
        3.times.map do |i|
          user = Client.create!
          ClientEmail.create!(user: user, address: "prosopite-smoke-#{i}-#{SecureRandom.hex(4)}@example.com")
          user.id
        end
      end

    error =
      Prosopite.pause do
        assert_raises(Prosopite::NPlusOneQueriesError) do
          Prosopite.scan do
            # Query the same child table once per parent without lazy-loading an association, so
            # Prosopite remains observable while global strict loading stays enabled.
            Client.where(id: created_user_ids).order(:id).each do |user|
              ClientEmail.where(user_id: user.id).load
            end
          end
        end
      end

    # The global test hook also wraps this test, so clear its counters after
    # the focused local assertion to avoid a duplicate raise in teardown.
    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |h, k| h[k] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end

    assert_match(/N\+1/i, error.message)
  end
end
