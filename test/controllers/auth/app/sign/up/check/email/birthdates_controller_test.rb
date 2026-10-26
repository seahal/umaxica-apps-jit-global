# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../../../../support/oidc_auth_admission_test_helper"

class Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper
  include OidcAuthAdmissionTestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    browser = self
    auth_host = @host
    bootstrap_auth_sign_in_admission!(surface: "app")
    switch_browser_to_sign_up!(integration_session, surface: "app", base_browser: @base_browser)
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    @headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  # Regression: email sign-up hands off to the sign-in checkpoint on Sign.
  # Initial completion and denied replay form one durable browser journey.
  # rubocop:disable Minitest/MultipleAssertions
  test "clearing the birthdate completes the sign-up on sign" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "birthdate-finalize@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_not_nil transaction.reload.otp_consumed_at
    assert_nil transaction.otp_verifier
    assert_not_nil transaction.otp_receipt_verifier
    flow = cycle.reload

    assert_equal contact_owner_for_test(email).id, flow.principal_id
    assert_equal email.id, flow.pending_contact_id
    assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: @headers

    assert_response :redirect
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
    assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
    source_before = [contact_owner_for_test(email).reload.attributes, email.reload.attributes]
    flow_before = flow.attributes
    roots_before = ClientToken.order(:id).map(&:attributes)
    proof_before = transaction.reload.attributes

    # A committed completion is not the retained pending receipt retry boundary.
    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.reload.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: @headers

    assert_response :conflict
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("errors.messages.phase_violation_refused", locale: :ja), response.body
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    # Boolean snapshots keep credential and keyed proof material out of failure output.
    assert_withheld { source_before == [contact_owner_for_test(email).reload.attributes, email.reload.attributes] }
    assert_withheld { flow_before == flow.reload.attributes }
    assert_withheld { roots_before == ClientToken.order(:id).map(&:attributes) }
    assert_withheld { proof_before == transaction.reload.attributes }
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "update without a sign-up ticket does not raise an unsafe cross-host redirect" do
    user = clients(:one)
    token = client_tokens(:one)
    access = AuthenticationToken.encode(
      user, host: @host, session_public_id: token.public_id, resource_type: "client",
            jwt_issuer_id: JitSecurityJwtRegistry.surface("AUTH_APP").id,
    )

    source_before = [user.reload.attributes, ClientEmail.where(user_id: user.id).order(:id).map(&:attributes)]
    flows_before = ClientSignUpFlow.order(:id).map(&:attributes)
    roots_before = ClientToken.order(:id).map(&:attributes)
    credential_cookies_before = [cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                 cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
    request_started_at = Time.current

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
          headers: @headers.merge("Authorization" => "Bearer #{access}")
    request_finished_at = Time.current

    # A missing flow refuses in place; it never redirects with inferred authority.
    assert_response :conflict
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("errors.messages.phase_violation_refused", locale: :ja), response.body
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_withheld {
      source_before == [user.reload.attributes, ClientEmail.where(user_id: user.id).order(:id).map(&:attributes)]
    }
    assert_withheld { flows_before == ClientSignUpFlow.order(:id).map(&:attributes) }
    roots_after = ClientToken.order(:id).map(&:attributes)

    assert_equal roots_before.length, roots_after.length, "Denied signup must not issue or remove a Root"
    changed_columns = roots_before.zip(roots_after).flat_map do |before, after|
      before.keys.select { |column| before.fetch(column) != after.fetch(column) }
    end.uniq.sort

    # Authenticated unsafe requests track activity even when their signup phase is refused.
    assert_equal ["last_used_at"], changed_columns
    roots_before.zip(roots_after).each do |before, after|
      assert_withheld("Denied signup must preserve every Root authority, proof, freshness and binding field") {
        before.except("last_used_at") == after.except("last_used_at")
      }
      if before.fetch("id") == token.id
        assert_withheld { after.fetch("last_used_at") >= request_started_at }
        assert_withheld { after.fetch("last_used_at") <= request_finished_at }
        unless before.fetch("last_used_at").nil?
          assert_withheld { after.fetch("last_used_at") >= before.fetch("last_used_at") }
        end
      else
        assert_withheld("Other Roots must not acquire activity or authority changes") { before == after }
      end
    end

    assert_withheld {
      credential_cookies_before == [cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                    cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
    }
  end

  test "rejects app client signup one day before the sixteenth birthday with sixteen birthday copy" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    ClientSignUpFlow.stub(:database_now, instant) do
      ClientEmailCeremonyTransaction.stub(:database_now, instant) do
        ClientEmail.stub(:database_now, instant) do
          Client.stub(:database_now, instant) do
            ClientSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_app_sign_up_email_url(ri: "jp"),
                     params: { :client_email => { raw_address: "birthdate-under16@example.com",
                                                  confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
                email = ClientEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = ClientEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

                assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal contact_owner_for_test(email).id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                principal_id = flow.principal_id
                birthdate_writes = []
                record_write =
                  lambda do |*, payload|
                    birthdate_writes << payload[:sql] if payload[:sql].match?(/\AUPDATE "clients" SET .*"birthdate"/)
                  end
                ActiveSupport::Notifications.subscribed(record_write, "sql.active_record") do
                  patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                        params: {
                          requirement: "birthdate",
                          checkpoint_version: flow.checkpoint_version,
                          birthdate: "2010-06-26",
                        },
                        headers: @headers
                end

                assert_response :success
                assert_includes response.body, "16歳の誕生日"
                assert_not_includes response.body, "13歳の誕生日"
                assert_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
                assert_not flow.requirement_cleared?(:birthdate)
                # D-178: the underage birthdate is never written, and the refusal removes the artifacts.
                assert_empty birthdate_writes
                assert_predicate flow, :cleanup_completed?
                assert_not Client.where(id: principal_id).where.not(birthdate: nil).exists?
              end
            end
          end
        end
      end
    end
  end

  test "allows app client signup on the sixteenth birthday" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    ClientSignUpFlow.stub(:database_now, instant) do
      ClientEmailCeremonyTransaction.stub(:database_now, instant) do
        ClientEmail.stub(:database_now, instant) do
          Client.stub(:database_now, instant) do
            ClientSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_app_sign_up_email_url(ri: "jp"),
                     params: { :client_email => { raw_address: "birthdate-sixteen@example.com",
                                                  confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
                email = ClientEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = ClientEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

                assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal contact_owner_for_test(email).id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2010-06-25",
                      },
                      headers: @headers

                assert_response :redirect
                assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
                assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
              end
            end
          end
        end
      end
    end
  end

  test "allows app client signup after the sixteenth birthday" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    ClientSignUpFlow.stub(:database_now, instant) do
      ClientEmailCeremonyTransaction.stub(:database_now, instant) do
        ClientEmail.stub(:database_now, instant) do
          Client.stub(:database_now, instant) do
            ClientSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_app_sign_up_email_url(ri: "jp"),
                     params: { :client_email => { raw_address: "birthdate-over16@example.com",
                                                  confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
                email = ClientEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = ClientEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

                assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal contact_owner_for_test(email).id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2000-01-01",
                      },
                      headers: @headers

                assert_response :redirect
                assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
                assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
              end
            end
          end
        end
      end
    end
  end

  test "allows app client signup one day after the sixteenth birthday" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    ClientSignUpFlow.stub(:database_now, instant) do
      ClientEmailCeremonyTransaction.stub(:database_now, instant) do
        ClientEmail.stub(:database_now, instant) do
          Client.stub(:database_now, instant) do
            ClientSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_app_sign_up_email_url(ri: "jp"),
                     params: { :client_email => { raw_address: "birthdate-sixteen-plus-one-day@example.com",
                                                  confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
                email = ClientEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = ClientEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

                assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal contact_owner_for_test(email).id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2010-06-24",
                      },
                      headers: @headers

                assert_response :redirect
                assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
                assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
              end
            end
          end
        end
      end
    end
  end

  # The OTP page offers no link back to /sign/up: that left the ticket in the session and the next
  # attempt ended in `invalid_transition`. Its only exit is the DELETE cancellation, which ends the
  # ticket so a new sign-up can start cleanly in the same session.
  # Keep cancellation, denied reuse and the subsequent new signup in one browser journey.
  # rubocop:disable Minitest/MultipleAssertions
  test "the email OTP page ends sign-up through its DELETE cancellation" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "cancel-a-#{SecureRandom.hex(3)}@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    first_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == first_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == first_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(first_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    first_flow = cycle.reload

    assert_equal contact_owner_for_test(first_email).id, first_flow.principal_id
    assert_equal first_email.id, first_flow.pending_contact_id
    get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_not props.key?("return_link")
    cancel = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("cancel")

    assert_equal "delete", cancel.fetch("method")
    assert_equal auth_app_sign_up_check_email_otp_path(ri: "jp"), URI.parse(cancel.fetch("action")).path + "?ri=jp"

    assert_no_difference(["Client.count", "ClientToken.count"]) do
      delete cancel.fetch("action"), headers: @headers
    end

    assert_response :see_other
    assert_redirected_to auth_app_sign_up_url(ri: "jp")
    assert_equal ClientSignUpFlowStatus::CANCELLED, first_flow.reload.status_id

    # The cancelled ticket's code no longer advances anything.
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_not_equal auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding), response.location
    assert_equal ClientSignUpFlowStatus::CANCELLED, first_flow.reload.status_id

    # A new sign-up in the same session proceeds instead of ending in `invalid_transition`.
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "cancel-b-#{SecureRandom.hex(3)}@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_not_nil transaction.reload.otp_consumed_at
    assert_nil transaction.otp_verifier
    assert_not_nil transaction.otp_receipt_verifier

    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
  end

  # rubocop:enable Minitest/MultipleAssertions

  # An address that already has an account runs a decoy flow with no real ticket; its cancellation
  # must answer exactly like a real one so the response does not reveal the address exists.
  test "cancelling the decoy flow of an existing address answers like a real cancellation" do
    existing = "cancel-existing-#{SecureRandom.hex(3)}@example.com"
    ClientEmail.create!(
      user: Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
      ), address: existing, user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: existing, confirm_policy: "1" },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    cancel = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("cancel")

    delete cancel.fetch("action"), headers: @headers

    assert_response :see_other
    assert_redirected_to auth_app_sign_up_url(ri: "jp")
  end

  # Birthdate rejections map the validation reason to a fixed public message key, so the actor can
  # correct the input while the model's own error wording is not the response contract.
  {
    "2999-01-01" => "sign.shared.birthdate.errors.not_before_today",
    "19900115" => "sign.shared.birthdate.errors.format",
  }.each do |birthdate, key|
    test "a rejected birthdate #{birthdate} answers with the public message #{key}" do
      clear_enqueued_jobs
      post auth_app_sign_up_email_url(ri: "jp"),
           params: { :client_email => { raw_address: "birthdate-reject-#{SecureRandom.hex(3)}@example.com",
                                        confirm_policy: "1", },
                     "cf-turnstile-response" => "test", },
           headers: @headers

      assert_response :redirect
      @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
      cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
      email = ClientEmail.find(cycle.pending_contact_id)
      job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

      assert_not_nil job
      notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
      delivery = notification.fetch(:params).symbolize_keys
      transaction = ClientEmailCeremonyTransaction.find_by!(
        transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
      )
      otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

      # Boolean assertions keep ceremony binding material out of failure output.
      assert_withheld("Delivery must address this flow's Email candidate") {
        notification.fetch(:recipient).public_id == email.public_id
      }
      assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
      assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
      assert_withheld { transaction.email_candidate_ref == email.public_id }
      assert_withheld { transaction.purpose == "sign_up" }
      assert_withheld { transaction.operation == "sign_up" }
      assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
      assert_withheld {
        transaction.session_ref ==
          Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
      }
      assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
            headers: @headers

      assert_response :redirect
      @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

      assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
      assert_not_nil transaction.reload.otp_consumed_at
      assert_nil transaction.otp_verifier
      assert_not_nil transaction.otp_receipt_verifier
      flow = cycle.reload

      assert_equal contact_owner_for_test(email).id, flow.principal_id
      assert_equal email.id, flow.pending_contact_id
      assert Client.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

      patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
            params: { requirement: "birthdate", checkpoint_version: flow.checkpoint_version, birthdate: birthdate },
            headers: @headers

      assert_response :unprocessable_content
      assert_equal "text/plain", response.media_type
      assert_equal I18n.t(key, raise: true), response.body
      assert_nil response.location
      assert_not flow.reload.requirement_cleared?(:birthdate)
    end
  end

  # The state machine's own classification (here `invalid_transition`) stays server-side; the body
  # is a fixed public message with no redirect and no markup.
  # The superseded and replacement flows must be observed in the same browser.
  test "an Email resubmission during an in-progress attempt is refused and keeps the earlier proof" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "transition-a-#{SecureRandom.hex(3)}@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_not_nil transaction.reload.otp_consumed_at
    assert_nil transaction.otp_verifier
    assert_not_nil transaction.otp_receipt_verifier
    old_flow = cycle
    old_binding = @flow_binding
    old_transaction = transaction
    # D-177: a second entry submit while this attempt is in progress is refused and changes nothing.
    clear_enqueued_jobs
    assert_no_difference(["ClientSignUpFlow.count", "ClientEmail.count"]) do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: { :client_email => { raw_address: "transition-b-#{SecureRandom.hex(3)}@example.com",
                                        confirm_policy: "1", },
                     "cf-turnstile-response" => "test", },
           headers: @headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.contact_held")
    assert_no_enqueued_jobs only: OtpNotifierEmailDeliveryJob
    assert_not_predicate old_flow.reload, :sign_up_terminal?
    assert_not_nil old_transaction.reload.otp_receipt_verifier
    assert_equal old_flow.public_id, session.fetch(:auth_app_up_sequence_id)
    assert old_binding
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
