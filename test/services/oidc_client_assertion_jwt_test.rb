# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class OidcClientAssertionJwtTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "issue returns nil when the client is not registered" do
    assert_nil OidcClientAssertionJwt.issue(client_id: "missing_client", token_url: "https://id.example/token")
  end

  test "issue returns nil when local key refresh still cannot resolve the configured key" do
    previous_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(
      "OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID" => nil,
      "OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY" => nil,
      "OIDC_CLIENT_CORE_APP_JP_PUBLIC_KEYSET" => nil,
    ) do
      JitSecurityJwtRegistry.reload!

      OidcClientAssertionJwt.stub(:refresh_local_key_material!, true) do
        OidcClientAssertionJwt.stub(
          :issue_with_configured_key, ->(**) {
                                        raise JitSecurityJwtRegistry::ConfigurationError
                                      },
        ) do
          assert_nil OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: "https://id.example/token")
        end
      end
    end
  ensure
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous_issuers)
  end

  test "issue refreshes local key material once when the registry is missing a client assertion key" do
    token_url = "https://log.umaxica.app/oauth/token"
    key = OpenSSL::PKey::EC.generate("secp384r1")
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    installed = false

    with_env(
      "OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID" => nil,
      "OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY" => nil,
      "OIDC_CLIENT_CORE_APP_JP_PUBLIC_KEYSET" => nil,
    ) do
      JitSecurityJwtRegistry.reload!

      assert_nil JitSecurityJwtRegistry.private_key_for("oidc_client:CORE_APP_JP")

      installer =
        lambda do |**|
          installed = true
          ENV["OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID"] = "core-app-oidc-recovered"
          ENV["OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
          true
        end

      JitSecurityJwtLocalKeysetInstaller.stub(:install!, installer) do
        assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

        assert installed
        assert_predicate assertion, :present?
      end
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  test "valid? rejects an assertion with the wrong audience" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: "https://log.umaxica.app/oauth/token-alt",
      )
    end
  end

  test "valid? rejects an assertion for another client id" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-com-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? accepts a matching assertion" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "the result-returning verifier exposes an authenticated client and the signed expectation" do
    token_url = "https://log.umaxica.app/oauth/token"
    expectation = OidcClientAssertionStepUpExpectationValue.new(grant: "grant-public-id", subject: "subject-ref")

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(
        client_id: "core-app-jp", token_url:, step_up_expectation: expectation,
      )
      result = OidcClientRegistry.verify_client_assertion("core-app-jp", assertion, token_url:)

      assert_predicate result, :authenticated?
      assert_equal "core-app-jp", result.client.client_id
      assert_equal :valid, result.step_up_claims_state
      assert_equal ["grant-public-id", "subject-ref"],
                   [result.step_up_expectation.grant, result.step_up_expectation.subject]
    end
  end

  test "the result-returning verifier marks ordinary assertions as having no step-up expectation" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url:)
      result = OidcClientRegistry.verify_client_assertion("core-app-jp", assertion, token_url:)

      assert_predicate result, :authenticated?
      assert_equal :none, result.step_up_claims_state
      assert_nil result.step_up_expectation
    end
  end

  test "signed partial and wrongly typed step-up claims remain authenticated but invalid" do
    token_url = "https://log.umaxica.app/oauth/token"
    now = Time.current

    with_oidc_client_key("CORE_APP_JP") do
      issuer_id = "oidc_client:#{OidcClientRegistry.jwt_namespace_for("core-app-jp")}"
      [
        { "step_up_grant" => "grant-public-id" },
        { "step_up_grant" => ["grant-public-id"], "step_up_sub" => "subject-ref" },
      ].each do |expectation_claims|
        payload = {
          "iss" => "core-app-jp",
          "sub" => "core-app-jp",
          "aud" => token_url,
          "jti" => SecureRandom.uuid,
          "iat" => now.to_i,
          "exp" => (now + OidcClientAssertionJwt::TTL).to_i,
          "typ" => OidcClientAssertionJwt::TOKEN_TYPE,
        }.merge(expectation_claims)
        assertion = JitSecurityJwtKeyring.encode(
          payload, typ: OidcClientAssertionJwt::TOKEN_TYPE, issuer_id:,
        )
        result = OidcClientRegistry.verify_client_assertion("core-app-jp", assertion, token_url:)

        assert_predicate result, :authenticated?
        assert_equal :invalid, result.step_up_claims_state
        assert_nil result.step_up_expectation
      end
    end
  end

  test "step-up expectation values require two non-empty strings" do
    assert_raises(ArgumentError) do
      OidcClientAssertionStepUpExpectationValue.new(grant: "", subject: "subject-ref")
    end
    assert_raises(ArgumentError) do
      OidcClientAssertionStepUpExpectationValue.new(grant: "grant-public-id", subject: nil)
    end
  end

  test "valid? rejects a replayed assertion jti" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "runtime replay protection persists the consumed jti in PostgreSQL" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
      assert SecurityConsumedJti.exists?(
        purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_client_assertion),
        issuer: "core-app-jp",
      )
    end
  end

  test "valid? rejects an expired assertion" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url, now: 1.hour.ago)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? rejects an assertion issued in the future" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url, now: 1.hour.from_now)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? rejects an assertion signed by a key that is not registered for the client" do
    token_url = "https://log.umaxica.app/oauth/token"
    assertion = nil

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)
    end

    # Registering a fresh key under the same kid means the original signature no
    # longer matches any key registered for the client.
    with_oidc_client_key("CORE_APP_JP") do
      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-app-jp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? fails closed when the replay record cannot be written" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)
      raising = ->(**) { raise ActiveRecord::StatementInvalid, "replay table unavailable" }

      SecurityConsumedJti.stub(:consume!, raising) do
        assert_not OidcClientAssertionJwt.valid?(
          client_id: "core-app-jp",
          assertion: assertion,
          token_url: token_url,
        )
      end
    end
  end

  test "valid? records the consumed jti in PostgreSQL rather than in Rails.cache" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP_JP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-app-jp", token_url: token_url)

      assert_difference -> { SecurityConsumedJti.count }, 1 do
        assert OidcClientAssertionJwt.valid?(
          client_id: "core-app-jp",
          assertion: assertion,
          token_url: token_url,
        )
      end

      record = SecurityConsumedJti.order(:created_at).last

      assert_equal "oidc_client_assertion", record.purpose
      assert_equal "core-app-jp", record.issuer
    end
  end

  private

  def with_oidc_client_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
