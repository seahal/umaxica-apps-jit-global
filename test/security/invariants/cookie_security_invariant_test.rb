# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceSecurityInvariantController < ApplicationController
  include PreferenceBase

  def test_preference_auth_cookie_options(expires_at:)
    preference_auth_cookie_options(expires_at: expires_at)
  end

  def test_preference_cookie_options(expires_at:, httponly:, domain: false)
    preference_cookie_options(expires_at: expires_at, httponly: httponly, domain: domain)
  end

  def test_write_preference_cookie(key, value)
    write_preference_cookie(key, value)
  end
end

module Security
  module Invariants
    class CookieSecurityInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      RecordingCookies =
        Struct.new(:writes) do
          delegate :[]=, to: :writes
        end

      Request =
        Struct.new(:host) do
          def ssl? = false
        end

      test "production auth cookie names use host prefix" do
        assert_equal "__Host-auth_access", AuthenticationCookieName.access(production: true)
        assert_equal "__Host-auth_refresh", AuthenticationCookieName.refresh(production: true)
        assert_equal "__Host-auth_dbsc", AuthenticationCookieName.dbsc(production: true)
      end

      test "production preference cookie names use host prefix" do
        assert_equal "__Host-preference_access", PreferenceCookieName.access(production: true)
        assert_equal "__Host-preference_refresh", PreferenceCookieName.refresh(production: true)
        assert_equal "__Host-preference_dbsc", PreferenceCookieName.dbsc(production: true)
      end

      test "insecure context cookie names stay role based without host prefix" do
        assert_equal "auth_access", AuthenticationCookieName.access(production: false)
        assert_equal "auth_refresh", AuthenticationCookieName.refresh(production: false)
        assert_equal "auth_dbsc", AuthenticationCookieName.dbsc(production: false)
        assert_equal "preference_access", PreferenceCookieName.access(production: false)
        assert_equal "preference_refresh", PreferenceCookieName.refresh(production: false)
        assert_equal "preference_dbsc", PreferenceCookieName.dbsc(production: false)
      end

      test "new credential cookie names do not encode authority surface or component names" do
        names = [
          AuthenticationCookieName.access(production: true),
          AuthenticationCookieName.refresh(production: true),
          AuthenticationCookieName.dbsc(production: true),
          PreferenceCookieName.access(production: true),
          PreferenceCookieName.refresh(production: true),
          PreferenceCookieName.dbsc(production: true),
          AuthenticationCookieName.access(production: false),
          AuthenticationCookieName.refresh(production: false),
          AuthenticationCookieName.dbsc(production: false),
          PreferenceCookieName.access(production: false),
          PreferenceCookieName.refresh(production: false),
          PreferenceCookieName.dbsc(production: false),
        ]

        names.each do |name|
          assert_no_match(/(?:^|_)(?:global|regional|app|com|org|core|palm)(?:_|$)/, name)
        end
      end

      test "auth cookies use secure host-prefix compatible attributes" do
        cookies = RecordingCookies.new({})
        request = Request.new("id.app.example")

        with_force_secure_cookies do
          AuthenticationCookieService.new(cookies, request).set_auth_cookies(
            access_token: "access-token",
            refresh_token: "refresh-token",
            access_ttl: 15.minutes,
            refresh_ttl: 30.days,
          )
        end

        assert_auth_cookie_options(cookies.writes.fetch(AuthenticationCookieName.access))
        assert_auth_cookie_options(cookies.writes.fetch(AuthenticationCookieName.refresh))
      end

      test "preference credential cookies use secure host-prefix compatible attributes" do
        controller = PreferenceSecurityInvariantController.new
        controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.example")
        controller.response = ActionDispatch::TestResponse.new

        production = ActiveSupport::EnvironmentInquirer.new("production")

        Rails.stub(:env, production) do
          access_options = controller.test_preference_auth_cookie_options(expires_at: 10.minutes.from_now)
          refresh_options = controller.test_preference_auth_cookie_options(expires_at: 30.days.from_now)
          dbsc_options = controller.test_preference_cookie_options(expires_at: 10.minutes.from_now, httponly: true)

          assert_auth_cookie_options(access_options)
          assert_auth_cookie_options(refresh_options)
          assert_auth_cookie_options(dbsc_options)
        end
      end

      test "JS-readable mirror cookies are apex-scoped and credential cookies are host-only" do
        [
          ["www.umaxica.app", ".umaxica.app"],
          ["www.umaxica.com", ".umaxica.com"],
          ["www.umaxica.org", ".umaxica.org"],
        ].each do |host, expected_domain|
          controller = PreferenceSecurityInvariantController.new
          controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
          controller.response = ActionDispatch::TestResponse.new

          mirror_options = controller.test_preference_cookie_options(
            expires_at: 400.days.from_now,
            httponly: false,
            domain: true,
          )

          assert_equal expected_domain, mirror_options[:domain],
                       "mirror cookie at #{host} must be apex-scoped (#{expected_domain})"
          assert_not mirror_options[:httponly], "mirror cookies must not be httponly"

          cred_options = controller.test_preference_auth_cookie_options(expires_at: 15.minutes.from_now)

          assert_not cred_options.key?(:domain),
                     "credential cookies at #{host} must be host-only (no Domain attribute)"
        end
      end

      test "production session cookie is secure httponly lax and host-prefixed" do
        assert JitSessionCookieConfig.force_secure?(
          id_service_host: "id.app.example",
          rails_env: ActiveSupport::StringInquirer.new("production"),
        )
        assert_equal "__Host-session", JitSessionCookieConfig.cookie_key(force_secure: true)

        session_options = JitSessionCookieConfig.session_options(force_secure: true)

        assert session_options[:httponly]
        assert session_options[:secure]
        assert_equal :lax, session_options[:same_site]
        assert_not session_options.key?(:partitioned), "a top-level first-party session is not Partitioned"
        assert_not session_options.key?(:domain), "__Host-session must not carry a Domain attribute"
        assert JitSessionCookieConfig.force_secure?(
          id_service_host: "id.app.example",
          rails_env: ActiveSupport::StringInquirer.new("production"),
        )
      end

      test "insecure session cookie is host-only and never shared across sibling subdomains" do
        session_options = JitSessionCookieConfig.session_options(force_secure: false)

        assert_not session_options.key?(:domain), "each FQDN owns its own Rails session in every environment"
        assert_not session_options.key?(:partitioned)
      end

      private

      def assert_auth_cookie_options(options)
        assert options[:secure]
        assert options[:httponly]
        assert_equal :strict, options[:same_site]
        assert_equal "/", options[:path]
        assert_not options.key?(:domain), "__Host- cookies must not carry a Domain attribute"
      end

      def with_force_secure_cookies
        previous = ENV["FORCE_SECURE_COOKIES"]
        ENV["FORCE_SECURE_COOKIES"] = "1"
        yield
      ensure
        ENV["FORCE_SECURE_COOKIES"] = previous
      end
    end
  end
end
