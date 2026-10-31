# frozen_string_literal: true

require "test_helper"

class OidcRealmNormalizationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normalization accepts each registered realm and its aliases" do
    { "client" => "client", "operator" => "operator", "staff" => "operator" }.each do |input, expected|
      assert_equal expected, OidcSubject.normalize_resource_type(input)
    end
  end

  test "normalization rejects missing empty and unknown realms" do
    [nil, "", false, 0, "unknown", "visitor", "customer"].each do |input|
      assert_raises(ArgumentError) { OidcSubject.normalize_resource_type(input) }
    end
  end

  test "subject inference rejects an unsupported resource" do
    assert_raises(ArgumentError) { OidcSubject.for(Object.new) }
  end

  test "audience lookup rejects missing empty and unknown realms" do
    [nil, "", false, 0, "unknown", "visitor", "customer"].each do |input|
      assert_raises(ArgumentError) { OidcClientRegistry.audiences_for_resource_type(input) }
    end
  end

  test "an explicitly invalid realm is not replaced by resource inference" do
    assert_raises(ArgumentError) { OidcSubject.for(Client.new, resource_type: false) }
  end
end
