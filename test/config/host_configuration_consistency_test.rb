# typed: false
# frozen_string_literal: true

require "test_helper"

# Rails.configuration.x.boot_config is built once, in the config/application.rb class body,
# from the environment as it stands at boot. Anything that changes a host variable after
# that point (a test_helper assignment, a stub left installed, a fixture that writes ENV)
# moves ENV without moving boot_config.
#
# The application reads both: routes and the CSP form-action allowlist come from
# boot_config, while controllers call ENV.fetch for the same hosts. When the two disagree
# the application still serves requests, so nothing fails here -- instead redirects land on
# one host while assertions expect the other, and unrelated tests fail far away from the
# cause. Worse, whether they disagree depends on who booted the application first, so the
# suite passes when a file is run alone and fails when the runner boots first.
#
# These assertions turn that silent divergence into an immediate, named failure.
class HostConfigurationConsistencyTest < ActiveSupport::TestCase
  HOST_SOURCES = {
    sign_service: "PUBLIC_AUTH_SERVICE_URL",
    sign_corporate: "PUBLIC_AUTH_CORPORATE_URL",
    sign_staff: "PUBLIC_AUTH_STAFF_URL",
    base_service: "PUBLIC_BASE_SERVICE_URL",
    base_corporate: "PUBLIC_BASE_CORPORATE_URL",
    base_staff: "PUBLIC_BASE_STAFF_URL",
    edit_staff: "PUBLIC_EDIT_STAFF_URL",
    core_service: "PUBLIC_CORE_SERVICE_URL",
    core_corporate: "PUBLIC_CORE_CORPORATE_URL",
    core_staff: "PUBLIC_CORE_STAFF_URL",
  }.freeze

  test "boot_config resolves every public host to the value the environment still holds" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    HOST_SOURCES.each do |surface, env_key|
      environment_host = URI::DEFAULT_PARSER.parse(
        ENV.fetch(env_key).match?(%r{\Ahttps?://}) ? ENV.fetch(env_key) : "https://#{ENV.fetch(env_key)}",
      ).host

      assert_equal(
        environment_host,
        hosts.public_send(surface).host,
        "#{surface} was frozen into boot_config as #{hosts.public_send(surface).host} but #{env_key} now " \
        "says #{environment_host}. Something changed the host after boot; set it in the process " \
        "environment instead, so both sources agree however the suite is invoked.",
      )
    end
  end

  test "the auth surface a browser reaches is the one the CSP form-action allowlist names" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    get_response_policy = Rails.application.config.content_security_policy
    form_action = get_response_policy.directives.fetch("form-action")

    assert_includes form_action, "https://#{hosts.sign_service.host}"
    assert_includes form_action, "https://#{hosts.base_service.host}"
  end
end
