# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "job does not mark an unimplemented client processor as notified" do
    client = create_client
    privacy_request = ClientPrivacyRequest.create!(client: client)
    notification = ClientProcessorErasureNotification.create!(
      client_privacy_request: privacy_request,
      processor_key: "email_delivery",
    )

    ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)

    notification.reload

    assert_equal ClientProcessorErasureNotification.status_id_for("FAILED"), notification.status_id
    assert_equal "processor_unavailable", notification.last_error_code
    assert_not_predicate ClientOccurrence.where(event_type: "processor_erasure.notified"), :exists?
    assert_predicate ClientOccurrence.where(event_type: "processor_erasure.failed"), :exists?
  end

  test "job is idempotent for notified visitor notification" do
    visitor = create_visitor
    privacy_request = VisitorPrivacyRequest.create!(visitor: visitor)
    notification = VisitorProcessorErasureNotification.create!(
      visitor_privacy_request: privacy_request,
      processor_key: "email_delivery",
      status_id: VisitorProcessorErasureNotification.status_id_for("NOTIFIED"),
      notified_at: Time.current,
    )

    assert_no_difference -> { VisitorOccurrence.count } do
      ProcessorErasureNotificationJob.perform_now(surface: "com", public_id: notification.public_id)
    end

    assert_equal VisitorProcessorErasureNotification.status_id_for("NOTIFIED"), notification.reload.status_id
  end

  test "job marks an unsupported visitor processor failed and records the reason" do
    visitor = create_visitor
    privacy_request = VisitorPrivacyRequest.create!(visitor: visitor)
    notification = VisitorProcessorErasureNotification.create!(
      visitor_privacy_request: privacy_request,
      processor_key: "payment",
    )

    ProcessorErasureNotificationJob.perform_now(surface: "com", public_id: notification.public_id)

    assert_equal VisitorProcessorErasureNotification.status_id_for("FAILED"), notification.reload.status_id
    occurrence = VisitorOccurrence.where(event_type: "processor_erasure.failed").order(:id).last

    assert_equal "processor_unavailable", occurrence.context.fetch("reason_code")
  end

  test "job rejects unsupported surfaces" do
    error =
      assert_raises(ArgumentError) do
        ProcessorErasureNotificationJob.perform_now(surface: "org", public_id: "missing")
      end

    assert_equal 'unsupported processor erasure surface: "org"', error.message
  end

  test "private mappings reject unsupported notification classes" do
    job = ProcessorErasureNotificationJob.new
    notification = Object.new

    assert_raises(ArgumentError) { job.send(:subject_for, notification) }
    assert_raises(ArgumentError) { job.send(:privacy_request_for, notification) }
  end

  private

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
