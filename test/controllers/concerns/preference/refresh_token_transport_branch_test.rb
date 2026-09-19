# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "core_test"

class PreferenceRefreshTokenTransportBranchTest < ActiveSupport::TestCase
  class TransportHarness < PreferenceCoreHarness
    include PreferenceRefreshTokenTransport

    attr_accessor :cookies_hash

    def initialize
      super
      @cookies_hash = {}
    end

    def cookies = cookies_hash

    def set_refresh_token_cookie(*) = nil

    def set_preference_dbsc_cookie!(*) = nil

    def issue_preference_dbsc_registration_header_for(*) = nil

    def preference_dbsc_cookie_expires_at(*) = 1.hour.from_now

    def preference_refresh_binding_allowed?(*) = true

    def handle_preference_refresh_replay!(*) = :fail

    def handle_preference_refresh_failed(*) = nil

    def handle_invalid_refresh_digest(*) = nil

    def handle_denied_refresh_binding(*) = nil

    def create_new_preference_record! = nil

    def adopt_rotated_preference!(*) = nil

    def preference_current_resource = nil
  end

  test "create_if_missing false returns nil without creating" do
    h = TransportHarness.new
    h.define_singleton_method(:find_preference_by_refresh_token) { |*| nil }
    result = h.send(:load_preference_record_from_refresh_token!, create_if_missing: false)

    assert_equal [nil, false], result
  end

  test "issue_new_preference_transport! raises when generated token missing" do
    h = TransportHarness.new
    pref = Struct.new(:issued_refresh_token, :expires_at, :dbsc_session_id, :binding_method_dbsc?).new(
      nil,
      1.hour.from_now, nil, false,
    )
    assert_raises(PreferenceBase::ResolutionError) { h.send(:issue_new_preference_transport!, pref) }
  end

  test "issue_new_preference_transport! sets dbsc cookie when binding method is dbsc" do
    h = TransportHarness.new
    called = []
    h.define_singleton_method(:set_preference_dbsc_cookie!) { |*args, **kwargs| called << [args, kwargs] }
    pref = Struct.new(:issued_refresh_token, :expires_at, :dbsc_session_id, :binding_method_dbsc?).new(
      "rt-plain", 1.hour.from_now, "dbsc-1", true,
    )
    h.send(:issue_new_preference_transport!, pref)

    assert_equal "rt-plain", h.instance_variable_get(:@refresh_token_value)
    assert_predicate called, :present?
  end

  test "refresh_refresh_token_lifetime skips grace window" do
    h = TransportHarness.new
    h.instance_variable_set(:@refresh_token_value, "x")
    h.instance_variable_set(:@refresh_presented_digest, "d")
    h.instance_variable_set(:@preference_refresh_grace, true)

    assert_nil h.send(:refresh_refresh_token_lifetime, Object.new)
  end

  test "refresh_refresh_token_lifetime adopts only when resource present" do
    h = TransportHarness.new
    h.instance_variable_set(:@refresh_token_value, "x")
    h.instance_variable_set(:@refresh_presented_digest, "d")
    h.instance_variable_set(:@preference_refresh_grace, false)
    rotated = Struct.new(:dbsc_session_id, :binding_method_dbsc?, :issued_refresh_token, :expires_at).new(
      nil, false, "new", 1.hour.from_now,
    )
    pref_class = Object.new
    pref_class.define_singleton_method(:rotate!) { |**| rotated }
    preference = Struct.new(:class, :binding_method_dbsc?).new(pref_class, false)
    h.define_singleton_method(:with_preference_connection) { |*| preference.class.rotate!(presented_digest: "d") }
    h.define_singleton_method(:create_audit_log) { |**| nil }
    h.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(adopt_rotated_preference! current_resource).include?(name.to_sym)

      super(name, include_all)
    end
    h.define_singleton_method(:preference_current_resource) { nil }
    adopted = []
    h.define_singleton_method(:adopt_rotated_preference!) { |*args| adopted << args }
    h.send(:refresh_refresh_token_lifetime, preference)

    assert_empty adopted
  end
end
