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

  test "OrgOperatorLifecycleApprove rejects non-pending requests" do
    request = Object.new
    request.define_singleton_method(:pending?) { false }
    actor = Object.new
    result = OrgOperatorLifecycleApprove.call(request: request, actor: actor)

    assert_not result.success
    assert_match(/pending/i, result.error.to_s)
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
end
