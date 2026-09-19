# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch29ServiceEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "SignSecretVerify blank stored digest mismatch path" do
    result = SignSecretVerify.call(secret_credential: nil, raw_secret_credential: "secret")

    assert_equal :secret_credential_mismatch, result.reason
  end

  test "PalmAccessTokenAuthenticator blank token arms" do
    missing = PalmAccessTokenAuthenticator.new(
      access_token: nil, host: "example.test", authorization_scheme: "Bearer",
    ).call
    blank = PalmAccessTokenAuthenticator.new(
      access_token: "", host: "example.test", authorization_scheme: "Bearer",
    ).call

    assert_equal "invalid_token", missing.error
    assert_not missing.success?
    assert_equal "invalid_token", blank.error
    assert_not blank.success?
  end

  test "OidcAccessTokenAuthenticator blank token arms" do
    missing = OidcAccessTokenAuthenticator.new(
      access_token: nil, resource_type: "client", host: "example.test",
    ).call
    blank = OidcAccessTokenAuthenticator.new(
      access_token: "", resource_type: "client", host: "example.test",
    ).call

    assert_equal "invalid_token", missing.error
    assert_not missing.success?
    assert_equal "invalid_token", blank.error
  end

  test "OidcEndSessionRequest blank params helpers" do
    request = OidcEndSessionRequest.new(params: {}, request: ActionDispatch::TestRequest.create)
    request.define_singleton_method(:actor) { nil }

    assert_nil request.send(:current_subject)

    unauth = Object.new
    unauth.define_singleton_method(:unauthenticated?) { true }
    request.define_singleton_method(:actor) { unauth }

    assert_nil request.send(:current_actor)
  end

  test "DbscVerificationService blank proof arms" do
    missing_record = DbscVerificationService.new(record: nil, session_id: "s", proof: "p").call
    record = Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
      .new("s", "k", "c", Time.current)
    missing_proof = DbscVerificationService.new(record: record, session_id: "s", proof: nil).call

    assert_equal "record_missing", missing_record[:error_code]
    assert_equal "missing_proof", missing_proof[:error_code]
  end

  test "CredentialSecurityTransition blank actor arms" do
    assert_raises(ArgumentError) do
      CredentialSecurityTransition.new(
        actor: nil,
        current_session: nil,
        reason: CredentialSecurityTransition::REASONS.first,
        affected_surface: "app",
        revoke_current: false,
        revoke_step_up: false,
        revoke_other_sessions: true,
        request: ActionDispatch::TestRequest.create,
      ).send(:validate!)
    end
  end

  test "SignUpStateMachine blank transition guards" do
    result = SignUpStateMachine.call(ticket: nil, event: :nope, actor_context: {}, payload: {})

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown event"
  end

  test "SignRiskEnforcer and SignRiskEmitter blank context arms" do
    assert_nil SignRiskEnforcer.call(nil)
    assert_nil SignRiskEmitter.emit("test")
  end

  test "SocialAuthLoginHandler and LinkHandler blank provider arms" do
    login_error = assert_raises(ArgumentError) { SocialAuthLoginHandler.new(provider: nil, actor: nil) }
    link_error = assert_raises(ArgumentError) { SocialAuthLinkHandler.new(provider: nil, actor: nil) }

    assert_match(/missing keyword/, login_error.message)
    assert_match(/missing keyword/, link_error.message)
  end

  test "Policies SignUpStepGate and JumpRtReturnPolicy easy refuses" do
    controller = Object.new
    controller.define_singleton_method(:current_sign_up_flow_ticket) { nil }
    controller.define_singleton_method(:session) { {} }
    gate = SignUpStepGate.new(
      controller: controller, surface: :app, family: "nope", step: :otp, mode: :show,
    ).call

    assert_equal :invalid, gate.status
    assert_includes gate.errors, "unsupported sign-up route"
    assert_nil JumpRtReturnPolicy.normalize_origin("javascript:alert(1)")
  end

  test "OrganizationPolicy and ApplicationPolicy edge denies" do
    policy = OrganizationPolicy.new(Object.new)
    policy.define_singleton_method(:user) { Client.new }

    assert_not policy.send(:organization_has_current_principal_membership?)
    assert_not ApplicationPolicy.new(Object.new).index?
  end

  test "lib JitSecurityJwtJtiGenerator and KeyMaterial arms" do
    jti = JitSecurityJwtJtiGenerator.generate

    assert_match(/\A[A-Za-z0-9_-]+\z/, jti)
    assert_equal JitSecurityJwtJtiGenerator.encoded_length(20), jti.length
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(nil))
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(""))
  end

  test "lib ObjectStorage and LocalEnvironment arms" do
    assert_raises(KeyError) { ObjectStorage::Environment.fetch("UMX_MISSING_OBJECT_STORAGE_KEY") }
    assert_nil LocalEnvironment.parse("# comment")[0]
    assert_nil LocalEnvironment.parse("")[0]
    assert_equal %w(FOO bar), LocalEnvironment.parse("FOO=bar")
  end

  test "RefreshTokenable concern currently_usable false arms" do
    token = ClientToken.new
    token.define_singleton_method(:expired?) { true }

    assert_not token.currently_usable?
  end

  test "AcmeSelectableContext inactive membership next [] arm" do
    helper = Class.new do
      include AcmeSelectableContext

      def config
        @config ||=
          begin
            c = Object.new
            c.define_singleton_method(:requires_avatar) { false }
            c.define_singleton_method(:account_class) { Client }
            c
          end
      end

      def principal = nil

      def session = nil

      def accounts
        account = Object.new
        membership = Object.new
        membership.define_singleton_method(:active?) { false }
        account.define_singleton_method(:current_memberships) { [membership] }
        [account]
      end
    end.new

    assert_equal [], helper.selectable_candidates
  end
end
