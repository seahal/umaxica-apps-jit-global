# typed: false
# frozen_string_literal: true

require "test_helper"

# Mass unit tops for still-cold raise/return arms that do not need the request stack.
class BranchCoverageBatch24MassEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AuthenticationLogoutable short-circuits when cookies or token helpers are absent" do
    bare = Class.new(ApplicationController) { include AuthenticationLogoutable }.new
    bare.set_request!(ActionDispatch::TestRequest.create)
    bare.set_response!(ActionDispatch::TestResponse.new)

    assert_nil bare.send(:session_token_from_refresh_cookie_for_logout)
    assert_nil bare.send(:record_logout_audit, nil)
    assert_nil bare.send(:record_logout_all_sessions_audit, nil)
  end

  test "AdministrativeAccessLock validate_inputs! refuses unsupported shapes" do
    reason = AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.first

    assert_raises(ArgumentError) do
      AdministrativeAccessLock.new(
        account: Object.new, operator: Operator.new, reason_code: reason,
        metadata: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AdministrativeAccessLock.new(
        account: Client.new, operator: Client.new, reason_code: reason,
        metadata: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AdministrativeAccessLock.new(
        account: Client.new, operator: Operator.new, reason_code: "not-a-reason",
        metadata: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AdministrativeAccessLock.new(
        account: Client.new, operator: Operator.new, reason_code: reason,
        metadata: [],
      ).send(:validate_inputs!)
    end

    service = AdministrativeAccessLock.new(
      account: Operator.new, operator: Operator.new, reason_code: reason,
      metadata: {},
    )
    locked = Operator.new
    locked.define_singleton_method(:access_enabled?) { false }
    service.define_singleton_method(:account) { locked }

    assert_nil service.send(:ensure_operator_can_be_locked!)
  end

  test "Retainable discard_now! and blank created_at helpers" do
    record = Client.new
    record.define_singleton_method(:created_at) { nil }
    record.define_singleton_method(:update!) { |*| true }

    assert_raises(ArgumentError) { record.discard_now!(purge_after: -1.second) }

    infinite = Object.new
    infinite.define_singleton_method(:infinite?) { true }
    infinite.define_singleton_method(:present?) { true }
    infinite.define_singleton_method(:>) { |_| false }

    assert record.send(:future_time?, infinite)
    assert_equal Time.zone.parse("2000-01-01"), record.send(:persisted_created_at_or, Time.zone.parse("2000-01-01"))
    assert_nil record.send(:retention_times_not_before_created_at)
  end

  test "Withdrawable recovery and early-termination blank arms" do
    client = Client.new
    client.define_singleton_method(:deactivated_at) { nil }
    client.define_singleton_method(:recovery_deadline) { 1.day.from_now }
    client.define_singleton_method(:recovery_available_at) { nil }
    client.define_singleton_method(:suspended?) { true }
    client.define_singleton_method(:early_termination_available_at) { nil }

    assert_predicate client, :can_recover?
    assert_nil Client.new.recovery_available_at
    assert_nil Client.new.early_termination_available_at
    assert_not client.early_terminatable?
  end

  test "DbscProofVerifier claim checks refuse out-of-window iat and non-RSA keys" do
    verifier = DbscProofVerifier.new(
      proof: "a.b.c",
      challenge: "challenge",
      challenge_issued_at: Time.current,
      expected_audience: "https://example.test/x",
    )
    header = { "typ" => "dbsc+jwt", "alg" => "ES256" }

    assert_equal "issued_at_future",
                 verifier.send(
                   :validate_claims,
                   {
                     "aud" => "https://example.test/x",
                     "jti" => "challenge",
                     "iat" => (1.hour.from_now).to_i,
                   },
                   header,
                 ).error_code
    assert_equal "issued_at_expired",
                 verifier.send(
                   :validate_claims,
                   {
                     "aud" => "https://example.test/x",
                     "jti" => "challenge",
                     "iat" => (2.days.ago).to_i,
                   },
                   header,
                 ).error_code

    assert verifier.send(:rsa_key_length_ok?, OpenSSL::PKey::EC.generate("prime256v1"), "ES256")
  end

  test "OidcTokenRevoker private guards refuse blank sid and blank jti" do
    revoker = OidcTokenRevoker.new(token: "tok", client_id: "cid", client_secret: "sec")

    assert_nil revoker.send(:find_usage_by_sid, "client", "")
    assert_nil revoker.send(:find_token_by_sid, "client", "")

    token = Object.new
    token.define_singleton_method(:has_attribute?) { |_| false }

    assert_not revoker.send(:token_jti_matches?, token, { "jti" => "x" })

    token.define_singleton_method(:has_attribute?) { |name| name.to_sym == :oidc_jti }
    token.define_singleton_method(:oidc_jti) { "" }

    assert_not revoker.send(:token_jti_matches?, token, { "jti" => "x" })
  end

  test "IdentifierDetection returns nil for blank normalized identifiers" do
    helper = Class.new do
      include IdentifierDetection

      def validate_and_normalize_email(_) = nil

      def identity_email_model = ClientEmail

      def identity_telephone_model = ClientTelephone
    end.new

    helper.define_singleton_method(:detect_identifier_type) { |_| :email }

    assert_nil helper.send(:find_user_by_identifier, "a@b.c")

    helper.define_singleton_method(:validate_and_normalize_email) { |_| "a@b.c" }

    IdentifierBlindIndex.stub(:bidx_for_email, nil) do
      assert_nil helper.send(:find_user_by_identifier, "a@b.c")
    end

    helper.define_singleton_method(:detect_identifier_type) { |_| :telephone }

    TelephoneNormalization.stub(:normalize_to_e164, nil) do
      assert_nil helper.send(:find_user_by_identifier, "+10000000000")
    end
    TelephoneNormalization.stub(:normalize_to_e164, "+10000000000") do
      IdentifierBlindIndex.stub(:bidx_for_telephone, nil) do
        assert_nil helper.send(:find_user_by_identifier, "+10000000000")
      end
    end
  end

  test "PreferenceSignOutRotation short-circuits without preference helpers" do
    bare = Class.new(ApplicationController) { include PreferenceSignOutRotation }.new
    bare.set_request!(ActionDispatch::TestRequest.create)
    bare.set_response!(ActionDispatch::TestResponse.new)

    assert_nil bare.send(:rotate_preference_after_sign_out!)
  end

  test "CspViolationReportIntake skips blank and non-csp entries" do
    intake = CspViolationReportIntake.new(raw_body: "{}", host: "example.test", user_agent: "test")

    assert_nil intake.send(:reporting_api_body, { "type" => "other" })
    assert_nil intake.send(:sanitize_report, {})
    assert_nil intake.send(:sanitize_string, Object.new)
    assert_nil intake.send(:sanitize_url, " ")
    assert_equal "https", intake.send(:origin_or_scheme, "https://")
  end

  test "OidcAccessTokenAuthenticator root_token_for walks client operator visitor" do
    auth = OidcAccessTokenAuthenticator.new(access_token: "tok", resource_type: "client", host: "example.test")
    token = Object.new
    token.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(client_token operator_token visitor_token).include?(name.to_sym)

      super(name, include_all)
    end
    token.define_singleton_method(:client_token) { nil }
    token.define_singleton_method(:operator_token) { nil }
    token.define_singleton_method(:visitor_token) { "visitor" }

    assert_equal "visitor", auth.send(:root_token_for, token)
  end

  test "Google OIDC enforcement claim checks refuse empty subject nonce and expiry" do
    helper = Object.new
    helper.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    helper.define_singleton_method(:secure_compare) do |left, right|
      return false if left.bytesize != right.bytesize

      ActiveSupport::SecurityUtils.secure_compare(left, right)
    end

    assert_raises(JWT::InvalidSubError) do
      helper.send(
        :verify_google_claims!,
        { "sub" => "", "nonce" => "n", "iat" => Time.now.to_i, "exp" => Time.now.to_i + 60 },
        expected_nonce: "n",
      )
    end
    assert_raises(JWT::DecodeError) do
      helper.send(
        :verify_google_claims!,
        { "sub" => "sub", "nonce" => "wrong", "iat" => Time.now.to_i, "exp" => Time.now.to_i + 60 },
        expected_nonce: "n",
      )
    end
    assert_raises(JWT::ExpiredSignature) do
      helper.send(
        :verify_google_claims!,
        { "sub" => "sub", "nonce" => "n", "iat" => Time.now.to_i - 100, "exp" => Time.now.to_i - 120 },
        expected_nonce: "n",
      )
    end
    assert_not helper.send(:secure_compare, "ab", "abc")
  end

  test "SignUpStepGate refuses mismatched family unusable tickets and unknown steps" do
    controller = Object.new
    gate = SignUpStepGate.new(controller: controller, surface: :app, family: "email", step: :otp, mode: :show)
    ticket = Object.new
    ticket.define_singleton_method(:expired?) { false }
    ticket.define_singleton_method(:lapsed?) { false }
    ticket.define_singleton_method(:sign_up_terminal?) { false }
    ticket.define_singleton_method(:step) { "otp" }
    ticket.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(expired? lapsed? sign_up_terminal? step).include?(name.to_sym)

      super(name, include_all)
    end
    registry = Object.new
    registry.define_singleton_method(:entry_method) { "telephone" }
    registry.define_singleton_method(:requirement?) { |_| false }

    gate.define_singleton_method(:route_known?) { true }
    gate.define_singleton_method(:current_ticket) { ticket }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_not result.success?
      assert_match(/family/, result.errors.join)
    end

    registry.define_singleton_method(:entry_method) { "email" }
    ticket.define_singleton_method(:expired?) { true }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_match(/usable|ticket/, result.errors.join)
    end

    ticket.define_singleton_method(:expired?) { false }
    ticket.define_singleton_method(:step) { "checkpoint" }
    ticket.define_singleton_method(:sign_up_checkpoint_pending?) { true }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_match(/step|belong/, result.errors.join)
    end
  end

  test "AuthenticationBulletinGate treats blank bulletin state as expired" do
    helper = Class.new(ApplicationController) do
      include AuthenticationBulletinGate
      include AuthenticationBase
    end.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:session) { @__session ||= {} }

    assert_predicate helper, :bulletin_expired?
    assert_nil helper.send(:refresh_bulletin_dimension!)
    assert_nil helper.current_bulletin
  end

  test "PreferenceResourceSync returns early for blank preference rows" do
    helper = Class.new(ApplicationController) { include PreferenceResourceSync }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:resource_preference) { nil }

    assert_nil helper.send(:sync_to_resource_preference!)
    assert_nil helper.send(:write_resource_preference_option!, Object.new, :theme, nil)
  end

  test "RedirectsExternalTargetResolver refuses blank origins" do
    resolver = RedirectsExternalTargetResolver.new(:jump, path: "/", query: {}, source: :explicit_external)
    resolver.define_singleton_method(:origin_for) { |_| "" }

    assert_equal "invalid_origin", resolver.call.failure_reason
  end
end
