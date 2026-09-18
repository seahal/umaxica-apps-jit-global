# typed: false
# frozen_string_literal: true

require "test_helper"

class SurfaceWriterConnectionTest < ActiveSupport::TestCase
  test "app principal and rp models share one writer pool" do
    assert_same AppRpRecord.connection_pool, AppPrincipalRecord.connection_pool
  end

  test "com principal and rp models share one writer pool" do
    assert_same ComRpRecord.connection_pool, ComPrincipalRecord.connection_pool
  end

  test "org principal and rp models share one writer pool" do
    assert_same OrgRpRecord.connection_pool, OrgPrincipalRecord.connection_pool
  end

  test "nested surface models resolve the canonical connection owner" do
    assert_same AppZenithRecord, Client.connection_class_for_self
    assert_same ComZenithRecord, Visitor.connection_class_for_self
    assert_same OrgZenithRecord, Operator.connection_class_for_self
  end
end
