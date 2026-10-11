# typed: false
# frozen_string_literal: true

require "test_helper"

# Focused arms that close the remaining ~0.5-1.2 branch points to the 90% floor.
# Prefer calling real methods; stubs only fill collaborators.
class BranchCoverageBatch37ThresholdCloseTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AppleOnlyCredentialStatus returns false for blank client" do
    assert_not AppleOnlyCredentialStatus.call(nil)
    assert_not AppleOnlyCredentialStatus.new(false).call
  end

  test "JitSecurityTurnstileConfig fetch early-returns when Rails is undefined" do
    rails = Object.const_get(:Rails)
    Object.send(:remove_const, :Rails)
    begin
      assert_nil JitSecurityTurnstileConfig.send(:fetch, :CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY)
    ensure
      Object.const_set(:Rails, rails)
    end
  end

  test "OrgOperatorLifecycleApprove rejects non-pending requests" do
    request = Object.new
    request.define_singleton_method(:pending?) { false }
    actor = Object.new
    result = OrgOperatorLifecycleApprove.call(request: request, actor: actor)

    assert_not result.success
    assert_match(/pending/i, result.error.to_s)
  end

  test "SignInDashboardParticipant normalize_item blank and wrong type" do
    participant = SignInDashboardParticipant.allocate

    assert_nil participant.send(:normalize_item, nil)
    assert_nil participant.send(:normalize_item, "")
    assert_raises(ArgumentError) { participant.send(:normalize_item, { a: 1 }) }
  end

  test "BaseSwitcherAuthority current_selection blank session" do
    authority = BaseSwitcherAuthority.allocate
    authority.instance_variable_set(:@session, nil)

    assert_nil authority.send(:current_selection)
  end

  test "ClientSecretCredentialsDestroy audit_class Operator vs Client" do
    destroyer = ClientSecretCredentialsDestroy.allocate
    destroyer.instance_variable_set(:@actor, Operator.new)

    assert_equal OperatorChronicle, destroyer.send(:audit_class)
    destroyer.instance_variable_set(:@actor, Client.new)
    destroyer.instance_variable_set(:@audit_class, nil)

    assert_equal ClientChronicle, destroyer.send(:audit_class)
  end

  test "Publishing archive and end forms message_for else arms" do
    archive = Publishing::ArchiveEntryForm.new

    assert_equal "too_long", archive.send(:message_for, :reason, :too_long)
    assert_equal "blank", archive.send(:message_for, :other, :blank)

    ending = Publishing::EndPublicationForm.new

    assert_equal "too_long", ending.send(:message_for, :reason, :too_long)
    assert_equal "blank", ending.send(:message_for, :other, :blank)
  end

  test "Publishing ArchiveEntryOperation refuses active publications" do
    publications = Object.new
    publications.define_singleton_method(:active) { publications }
    publications.define_singleton_method(:exists?) { true }

    entry = Object.new
    entry.define_singleton_method(:archived?) { false }
    entry.define_singleton_method(:publications) { publications }
    entry.define_singleton_method(:with_lock) { |&block| block.call }

    result = Publishing::ArchiveEntryOperation.new(
      entry: entry,
      reason: "cleanup",
      operator_public_id: "op-1",
    ).call

    assert_not result.ok?
    assert_match(/published entry cannot be archived/i, result.errors[:base].to_s)
  end

  test "OperatorPreferenceDensityOption name covers STANDARD id" do
    option = OperatorPreferenceDensityOption.allocate
    option.define_singleton_method(:id) { OperatorPreferenceDensityOption::STANDARD }

    assert_equal "standard", option.name
    option.define_singleton_method(:id) { OperatorPreferenceDensityOption::COMPACT }

    assert_equal "compact", option.name
  end

  test "WithdrawalOccurrenceRecording unsupported subject and actor paths" do
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_class_for(Object.new) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.surface_for(Object.new) }

    subject = Client.new
    subject.define_singleton_method(:public_id) { "client-pub" }
    actor = Visitor.new
    actor.define_singleton_method(:public_id) { "visitor-pub" }
    request = ActionDispatch::TestRequest.create
    request.request_id = "req-1"
    request.user_agent = "CoverageAgent/1.0"

    ctx = WithdrawalOccurrenceRecording.allowed_context(
      subject: subject,
      actor: actor,
      request: request,
      occurred_at: Time.zone.parse("2026-01-02 03:04:05 UTC"),
      context: { reason_code: "user_request" },
    )

    assert_equal "Visitor", ctx["actor_type"]
    assert_equal "visitor-pub", ctx["actor_public_id"]
    assert_equal "app", ctx["surface"]
    assert_equal "req-1", ctx["request_id"]
    assert_predicate ctx["user_agent_digest"], :present?
  end

  test "IdentityTotpCeremonyCandidateStore candidate_from rejects invalid record" do
    store = IdentityTotpCeremonyCandidateStore.new
    record = IdentityTotpCeremonyCandidate.new
    record.define_singleton_method(:valid?) { false }
    assert_raises(IdentityTotpCeremonyContract::Error) { store.send(:candidate_from, record) }
  end

  test "Webauthn AuthenticatorMetadata nil resolution safe navigation then arms" do
    context = Object.new
    %i(
      aaguid transports backup_eligible backup_state authenticator_attachment
    ).each do |m|
      context.define_singleton_method(m) { nil }
    end
    Webauthn::AuthenticatorNameResolver.stub(:resolve, nil) do
      result = Webauthn::AuthenticatorMetadata.attributes_from(context)

      assert_nil result[:provider_name]
      assert_nil result[:metadata_source]
    end
  end
end

class BranchCoverageBatch37ControllerArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Org verification passkeys props errors_sentence then arm" do
    controller = Auth::Org::Verification::PasskeysController.new
    controller.instance_variable_set(:@verification_errors, %w(alpha beta))
    controller.instance_variable_set(:@passkey_challenge_id, "chal")
    controller.instance_variable_set(:@passkey_request_options, { challenge: "x" })
    controller.define_singleton_method(:t) { |*_a, **_k| "t" }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:auth_org_verification_passkey_path) { |**_| "/passkey" }
    controller.define_singleton_method(:auth_org_verification_path) { |**_| "/verification" }

    props = controller.send(:verification_passkey_props)

    assert_includes props[:errors_sentence], "alpha"
  end

  test "BirthdatesController show props with birthdate present" do
    controller = Base::App::Identity::BirthdatesController.new
    client = Object.new
    client.define_singleton_method(:birthdate) { Date.new(1999, 12, 31) }
    controller.define_singleton_method(:current_client) { client }
    controller.define_singleton_method(:t) { |*_a, **_k| "t" }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:base_app_identity_path) { |**_| "/identity" }

    captured = nil
    controller.define_singleton_method(:render) do |**kwargs|
      captured = kwargs[:props]
    end
    controller.show

    assert_equal "1999-12-31", captured[:birthdate]
  end

  test "AppealReviewsController create raises when appeal missing" do
    controller = Base::Org::Support::EnforcementCases::AppealReviewsController.new
    enforcement_case = Object.new
    enforcement_case.define_singleton_method(:appeal) { nil }
    controller.instance_variable_set(:@enforcement_case, enforcement_case)
    controller.define_singleton_method(:authorize!) { |*_a, **_k| true }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(resolution_code: "uphold") }

    assert_raises(ActiveRecord::RecordNotFound) { controller.create }
  end

  test "ErasuresController new returns early when already performed" do
    controller = Base::App::Identity::Privacy::ErasuresController.new
    subject = Object.new
    controller.define_singleton_method(:current_withdrawal_subject) { subject }
    controller.define_singleton_method(:render_privacy_erasure_new) { |_s| true }
    controller.define_singleton_method(:performed?) { true }
    rendered = false
    controller.define_singleton_method(:render) { |*_a, **_k| rendered = true }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:base_app_identity_privacy_erasure_path) { |**_| "/erasure" }

    controller.new

    assert_not rendered
  end

  test "ProblemDetailsRendering includes errors when present" do
    controller = Class.new(ApplicationController) { include ProblemDetailsRendering }.new
    request = ActionDispatch::TestRequest.create
    controller.set_request!(request)
    problem = Struct.new(:uri, :title, :status_code).new("about:blank", "Bad", 422)
    doc = controller.send(:problem_document, problem, detail: "x", errors: [{ detail: "y" }])

    assert_equal [{ detail: "y" }], doc[:errors]
  end

  test "McpEndpoint render_mcp_response blank payload uses head" do
    controller = Class.new(ApplicationController) do
      include McpEndpoint

      def mcp_surface_identity
        Struct.new(:server_name, :surface, :realm).new("test", :app, :base)
      end

      def mcp_allowed_hosts
        ["example.test"]
      end
    end.new
    request = ActionDispatch::TestRequest.create
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)

    transport = Object.new
    transport.define_singleton_method(:handle_request) { |_r| [204, { "X-Test" => "1" }, [""]] }
    MCP::Server::Transports::StreamableHTTPTransport.stub(:new, transport) do
      controller.send(:render_mcp_response)
    end

    assert_equal 204, controller.response.status
  end

  test "AuthenticationClient sign_app_redirect_host returns matching request host" do
    controller = Class.new(ApplicationController) { include AuthenticationClient }.new
    request = ActionDispatch::TestRequest.create
    request.host = "auth.app.localhost"
    controller.set_request!(request)

    old = ENV["PUBLIC_AUTH_SERVICE_URL"]
    ENV["PUBLIC_AUTH_SERVICE_URL"] = "https://auth.app.localhost"
    begin
      assert_equal "auth.app.localhost", controller.send(:sign_app_redirect_host)
    ensure
      if old.nil?
        ENV.delete("PUBLIC_AUTH_SERVICE_URL")
      else
        ENV["PUBLIC_AUTH_SERVICE_URL"] = old
      end
    end
  end

  test "IdentityRecoveryPage appeal nil when case is not appealable" do
    controller = Class.new(ApplicationController) do
      include IdentityRecoveryPage

      def t(*_args, **_kwargs) = "t"

      def base_app_identity_recovery_completion_path(**_) = "/restore"

      def base_app_identity_recovery_appeals_path(**_) = "/appeals"
    end.new
    enforcement_case = Object.new
    enforcement_case.define_singleton_method(:public_id) { "ec-1" }
    enforcement_case.define_singleton_method(:kind) { "method_protection" }
    enforcement_case.define_singleton_method(:appeal) { nil }
    props = controller.send(:serialize_recovery_case, enforcement_case)

    assert_nil props[:appeal]
  end
end
