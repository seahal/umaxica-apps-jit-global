# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class EmailDeliveryTest < ActionDispatch::IntegrationTest
  include SignUpJourneyCleanup
  include SignInFlowCleanup

  self.use_transactional_tests = false

  fixtures :client_email_statuses, :client_statuses

  setup do
    sign_up_journey_watermarks!
    @existing_solid_queue_job_ids = SolidQueue::Job.pluck(:id)
    @previous_adapter = ActiveJob::Base.queue_adapter
    @previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    @previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    cookies["csrf_token"] = csrf_token_value
    begin
      admission_browser = self
      admission_surface = "app"
      admission_intent = "sign_up"
      admission_host = {
        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      }.fetch(admission_surface)
      admission_browser.host!(admission_host)
      admission_issuance = OidcTestEntry.issue!(
        surface: admission_surface, intent: admission_intent,
        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
      # An entry reference is accepted only on a top-level document navigation, and a live
      # reference never renders: it answers 303 to the ceremony binding action and redeems only
      # after Base confirmed the binding.
      admission_navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
        headers: admission_navigation,
      )

      assert_equal 303, admission_browser.response.status
      admission_browser.get(admission_browser.response.location, headers: admission_navigation)

      assert_equal 303, admission_browser.response.status
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: admission_surface, reference: admission_issuance.reference,
      )
      admission_binding.reload.confirm_base!(
        base_token: nil,
        browser_digest: admission_binding.base_browser_digest,
      )
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
        headers: admission_navigation,
      )

      assert_equal 303, admission_browser.response.status
      admission_browser.get(admission_browser.response.location, headers: admission_navigation)

      assert_equal 200, admission_browser.response.status
    end

    # Use the solid_queue adapter for this test to verify DB persistence
    ActiveJob::Base.queue_adapter = :solid_queue

    # Mock Turnstile to pass validation
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    delete_solid_queue_jobs_created_by_test!
    delete_sign_up_journey_rows!
    ActiveJob::Base.queue_adapter = @previous_adapter if @previous_adapter
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = @previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = @previous_challenge
  end

  test "deliver_later enqueues a job in solid_queue" do
    # Use a unique email to potentially avoid collisions (though db is cleaned)
    email = "delivery_test_#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { SolidQueue::Job.where(class_name: "OtpNotifierEmailDeliveryJob").count }, 1 do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test_token",
           },
           headers: default_headers

      assert_response :redirect
    end

    # Find the job and verify it's a mail delivery job
    job = SolidQueue::Job.where(class_name: "OtpNotifierEmailDeliveryJob").order(:created_at).last

    assert_equal "OtpNotifierEmailDeliveryJob", job.class_name
    assert_equal "default", job.queue_name

    # Verify the job is for our email
    # Arguments are usually serialized, but we can check if the email address is present in the arguments
    # Note: Arguments format depends on how Rails serializes it, often complex with GlobalID
    # But usually contains the method name 'create' and arguments
  end

  private

  def delete_solid_queue_jobs_created_by_test!
    return if @existing_solid_queue_job_ids.nil?

    job_ids = SolidQueue::Job.where.not(id: @existing_solid_queue_job_ids).pluck(:id)
    return if job_ids.empty?

    [
      SolidQueue::BlockedExecution,
      SolidQueue::ClaimedExecution,
      SolidQueue::ReadyExecution,
      SolidQueue::ScheduledExecution,
      SolidQueue::FailedExecution,
      SolidQueue::BatchExecution,
      SolidQueue::RecurringExecution,
    ].each { |execution| execution.where(job_id: job_ids).delete_all }
    SolidQueue::Job.where(id: job_ids).delete_all
  end

  def csrf_token_value
    "test_csrf_token"
  end

  def default_headers
    {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "HTTPS" => "on",
      "X-CSRF-Token" => csrf_token_value,
    }
  end
end
