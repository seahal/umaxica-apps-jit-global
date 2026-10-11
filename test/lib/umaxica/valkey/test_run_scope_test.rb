# typed: false
# frozen_string_literal: true

require "test_helper"

class UmaxicaValkeyTestRunScopeTest < ActiveSupport::TestCase
  test "claims, protects, and releases a run scope" do
    run_id = "scope-test-#{SecureRandom.hex(8)}"

    assert_not Umaxica::Valkey::TestRunScope.claimed?(run_id)
    marker_path = Umaxica::Valkey::TestRunScope.claim!(run_id)

    assert_path_exists marker_path
    assert Umaxica::Valkey::TestRunScope.claimed?(run_id)
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::TestRunScope.ensure_cleanup_allowed!(run_id)
    end
    assert_nothing_raised do
      Umaxica::Valkey::TestRunScope.ensure_cleanup_allowed!(run_id, allow_claimed: true)
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::TestRunScope.claim!(run_id)
    end

    Umaxica::Valkey::TestRunScope.release!(run_id)

    assert_not Umaxica::Valkey::TestRunScope.claimed?(run_id)
    assert_nil Umaxica::Valkey::TestRunScope.release!(run_id)
  end

  test "rejects invalid run scope identifiers before touching the marker directory" do
    ["", "../unsafe", "a/b", "a" * 129].each do |run_id|
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::TestRunScope.claim!(run_id)
      end
    end
  end
end
