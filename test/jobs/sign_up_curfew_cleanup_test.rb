# frozen_string_literal: true

require "test_helper"

# WU-38 (D-126 (2), D-131, D-135, D-176): an unfinished registration is cleaned up by the recurring
# SignUpExpiryJob once its Flow passes the Admission Binding curfew; the contact is then free for a
# new sign-up. A registered identity is never touched.
class SignUpCurfewCleanupTest < ActiveJob::TestCase
  setup do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
  end

  test "the Flow deadline is the Admission Binding curfew" do
    flow, = app_unfinished_registration("curfew-cap@example.com")

    assert_equal flow.auth_admission_binding.curfew_at, flow.expires_at
  end

  test "one second before the curfew the APP registration still holds its contact" do
    flow, contact, owner = app_unfinished_registration("curfew-before@example.com")

    run_expiry_at(flow.expires_at - 1.second)

    assert_predicate flow.reload, :sign_up_in_progress?
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.user_email_status_id
    assert_equal Float::INFINITY, owner.reload.discard_at
    assert SignUpContactHoldQuery.call(contact: ClientEmail.new(raw_address: contact.address).tap(&:validate))
  end

  test "at the curfew the APP registration is cleaned up and its contact is free" do
    flow, contact, owner = app_unfinished_registration("curfew-at@example.com")

    run_expiry_at(flow.expires_at)

    assert_equal ClientSignUpFlowStatus::EXPIRED, flow.reload.status_id
    assert_predicate flow, :cleanup_completed?
    assert_equal ClientEmailStatus::DELETED, contact.reload.user_email_status_id
    assert_not_equal Float::INFINITY, owner.reload.discard_at
    assert_not SignUpContactHoldQuery.call(contact: ClientEmail.new(raw_address: contact.address).tap(&:validate))
  end

  test "one second after the curfew the COM registration is cleaned up and its contact is free" do
    owner = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    contact = VisitorEmail.create!(
      visitor: owner, raw_address: "curfew-after-com@example.com", confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = create_flow(VisitorSignUpFlow, principal: owner, contact:)

    run_expiry_at(flow.expires_at + 1.second)

    assert_equal VisitorSignUpFlowStatus::EXPIRED, flow.reload.status_id
    assert_equal VisitorEmailStatus::DELETED, contact.reload.visitor_email_status_id
    assert_not SignUpContactHoldQuery.call(contact: VisitorEmail.new(raw_address: contact.address).tap(&:validate))
  end

  test "a registered identity behind an expired Flow is never touched" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    contact = ClientEmail.create!(
      user: owner, raw_address: "curfew-registered@example.com", confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = create_flow(ClientSignUpFlow, principal: owner, contact:)
    owner_facts = owner.reload.attributes
    contact_facts = contact.reload.attributes

    run_expiry_at(flow.expires_at + 1.second)

    assert_equal ClientSignUpFlowStatus::EXPIRED, flow.reload.status_id
    assert_equal owner_facts, owner.reload.attributes
    assert_equal contact_facts, contact.reload.attributes
  end

  private

  def app_unfinished_registration(address)
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    contact = ClientEmail.create!(
      user: owner, raw_address: address, confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    [create_flow(ClientSignUpFlow, principal: owner, contact:), contact, owner]
  end

  # The requested lifetime exceeds the curfew, so the Flow's own expiry is capped at the curfew.
  def create_flow(model, principal:, contact:)
    now = model.database_now
    model.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(model),
      principal_id: principal.id, pending_contact_type: "email", pending_contact_id: contact.id,
      status_id: model::STATUS_MODEL::STARTED, step: "start", entry_method: "email",
      nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
      issued_at: now - 1.minute, expires_at: now + 1.day,
    )
  end

  def run_expiry_at(time)
    travel_to(time) do
      ClientSignUpFlow.stub(:database_now, time) do
        VisitorSignUpFlow.stub(:database_now, time) { SignUpExpiryJob.perform_now }
      end
    end
  end
end
