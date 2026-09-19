# typed: false
# frozen_string_literal: true

require "test_helper"

# Pins the provider x surface allow matrix enforced by the /social/* middleware.
#
# The matrix is deny-by-default: a host that owns no auth surface classifies as
# :unknown and gets no provider at all. Rails Host Authorization admits many more
# hosts than the three auth origins (side, base, core, help, info, palm, guid...),
# and none of them may start or complete an external sign-in ceremony.
class OmniauthSocialProviderHostMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PROVIDERS = %w(google apple entra).freeze

  setup do
    @downstream_called = false
    @matrix = OmniAuthSocialProviderHostMatrix.new(
      ->(_env) {
        @downstream_called = true
        [200, {}, ["ok"]]
      },
    )
    @hosts = Rails.configuration.x.boot_config.fetch(:hosts)
  end

  test "the app auth host allows Google and Apple and denies Entra" do
    assert_allowed host: app_auth_host, provider: "google"
    assert_allowed host: app_auth_host, provider: "apple"
    assert_denied host: app_auth_host, provider: "entra"
  end

  # config/routes/base.rb mounts the app-surface provider callbacks and the
  # /social/authentication continuation/completion pair on the base service
  # host, so it is part of the app surface too -- and must still refuse Entra.
  test "the app base host allows Google and Apple and denies Entra" do
    assert_allowed host: app_base_host, provider: "google"
    assert_allowed host: app_base_host, provider: "apple"
    assert_denied host: app_base_host, provider: "entra"
  end

  test "the org auth host allows Entra and denies Google and Apple" do
    assert_allowed host: org_auth_host, provider: "entra"
    assert_denied host: org_auth_host, provider: "google"
    assert_denied host: org_auth_host, provider: "apple"
  end

  test "the org auth host allows the Entra paths and denies other providers' paths" do
    %w(/social/entra /social/entra/callback /social/entra/failure).each do |path|
      assert_allowed host: org_auth_host, path: path
    end

    assert_denied host: org_auth_host, path: "/social/google"
    assert_denied host: org_auth_host, path: "/social/apple/callback"
  end

  test "com hosts allow no external provider" do
    com_hosts.each do |host|
      PROVIDERS.each { |provider| assert_denied host: host, provider: provider }
    end
  end

  test "hosts that own no auth surface allow no external provider" do
    non_auth_hosts.each do |host|
      PROVIDERS.each do |provider|
        assert_denied host: host, provider: provider
      end
    end
  end

  test "hosts that own no auth surface are not classified as the app surface" do
    non_auth_hosts.each do |host|
      assert_equal :unknown, surface_for(host), "#{host} must not classify as a surface that allows providers"
    end
  end

  test "non-provider social paths remain app-surface only" do
    assert_allowed host: app_auth_host, path: "/social/authentication/completion"
    assert_allowed host: app_base_host, path: "/social/authentication/completion"
    assert_denied host: org_auth_host, path: "/social/authentication/completion"
    assert_denied host: non_auth_hosts.first, path: "/social/authentication/completion"
  end

  test "paths outside /social are not touched by the matrix" do
    assert_allowed host: non_auth_hosts.first, path: "/settings"
  end

  private

  def surface_for(host)
    @matrix.send(:surface_for_host, host)
  end

  def app_auth_host = @hosts.auth_service.host

  def app_base_host = @hosts.base_service.host

  def org_auth_host = @hosts.auth_staff.host

  def com_hosts
    [@hosts.auth_corporate.host, @hosts.base_corporate.host].uniq
  end

  # Representative hosts that Rails Host Authorization admits but that own no
  # auth surface, drawn from the same boot host families the app really has.
  def non_auth_hosts
    [
      @hosts.side_service, @hosts.side_staff,
      @hosts.base_staff,
      @hosts.core_service, @hosts.core_staff,
      @hosts.help_service, @hosts.info_service,
      @hosts.palm_service, @hosts.guid_service,
    ].map(&:host).uniq - app_hosts - [org_auth_host, *com_hosts]
  end

  # Every host that legitimately serves an app-surface /social/* path: the auth
  # origin plus the base origin, in both their public and private forms.
  def app_hosts
    (
      [app_auth_host, app_base_host] +
        OmniAuthSocialProviderHostMatrix::APP_HOST_ENV_KEYS.filter_map { |key|
          value = ENV.fetch(key, nil)
          next if value.blank?

          ConfigValues.build(value, allow_localhost: true).uri&.host
        }
    ).uniq
  end

  def call(host:, path:)
    @downstream_called = false
    env = Rack::MockRequest.env_for("https://#{host}#{path}", method: "GET")
    @matrix.call(env)
  end

  def assert_allowed(host:, provider: nil, path: nil)
    path ||= "/social/#{provider}/callback"
    status, = call(host: host, path: path)

    assert_equal 200, status, "expected #{host}#{path} to be allowed"
    assert @downstream_called, "expected #{host}#{path} to reach the application"
  end

  def assert_denied(host:, provider: nil, path: nil)
    path ||= "/social/#{provider}/callback"
    status, = call(host: host, path: path)

    assert_equal 404, status, "expected #{host}#{path} to be denied"
    assert_not @downstream_called, "expected #{host}#{path} never to reach the application"
  end
end
