# typed: false
# frozen_string_literal: true

require "test_helper"

# Phase regression contract for the app email sign-up ceremony, exercised through the public HTTP
# boundary. The refusal body is fixed Japanese customer copy required by the contract, so it is
# asserted literally here.
class SignUpPhaseRegressionAppTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  REFUSAL_BODY = "戻るはだめです"

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "reloading the current otp phase with its flow binding renders it again without changing the flow" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-reload@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    flow = ClientSignUpFlow.order(:created_at).last

    get otp_url

    assert_response :success

    get otp_url

    assert_response :success
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
  end

  test "get of the earlier otp phase after it was cleared is refused with 409 and leaves the flow unchanged" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-past-get@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    otp_data = ClientEmail.order(:created_at).last.get_otp
    patch otp_url,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s } }
    flow = ClientSignUpFlow.order(:created_at).last
    updated_at = flow.updated_at

    get otp_url

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, flow.reload.status_id
    assert_equal updated_at, flow.updated_at
  end

  test "get of the later birthdate phase before the otp is cleared is refused with 409 and leaves the flow unchanged" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-future-get@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = ClientSignUpFlow.order(:created_at).last

    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: binding)

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
  end

  test "mutation from the earlier otp phase halts the active flow and issues no new otp" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-past-post@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    otp_data = ClientEmail.order(:created_at).last.get_otp
    patch otp_url,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s } }
    flow = ClientSignUpFlow.order(:created_at).last
    deliveries_before = ActionMailer::Base.deliveries.size

    post otp_url

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
    assert_equal deliveries_before, ActionMailer::Base.deliveries.size
  end

  test "mutation from the later birthdate phase before the otp is cleared halts the active flow" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-future-patch@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = ClientSignUpFlow.order(:created_at).last

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: binding),
          params: { requirement: "birthdate", checkpoint_version: flow.checkpoint_version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
  end

  test "a halted flow stays halted and issues no session when its current-phase form is submitted again" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-halted-retry@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    binding = Rack::Utils.parse_query(URI.parse(otp_url).query).fetch("fb")
    otp_data = ClientEmail.order(:created_at).last.get_otp
    patch otp_url,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s } }
    flow = ClientSignUpFlow.order(:created_at).last
    post otp_url
    tokens_before = ClientToken.count
    sign_in_flows_before = ClientSignInFlow.count

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: binding),
          params: { requirement: "birthdate",
                    checkpoint_version: flow.reload.checkpoint_version,
                    birthdate: "1990-01-15", }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
    assert_equal tokens_before, ClientToken.count
    assert_equal sign_in_flows_before, ClientSignInFlow.count
  end

  test "halting a flow for a phase violation records a durable audit event without the binding" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-audit@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    binding = Rack::Utils.parse_query(URI.parse(otp_url).query).fetch("fb")
    otp_data = ClientEmail.order(:created_at).last.get_otp
    patch otp_url,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s } }
    flow = ClientSignUpFlow.order(:created_at).last

    post otp_url

    audit = ClientChronicle.where(event_id: ClientChronicleEvent::SIGN_FLOW_HALTED).order(:created_at).last

    assert_not_nil audit
    assert_equal flow.principal_id.to_s, audit.subject_id
    assert_equal "phase_regression", audit.context["reason_code"]
    assert_equal flow.public_id, audit.context["flow_public_id"]
    assert_equal "sign_up", audit.context["flow_kind"]
    assert_equal "app", audit.context["surface"]
    assert_not_includes audit.context.to_json, binding
    assert_not_includes audit.context.to_json, "phase-audit@example.com"
  end

  test "starting again from the entry halts the earlier flow, and its stale page cannot halt the new flow" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-flow-a@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url_a = response.location
    binding_a = Rack::Utils.parse_query(URI.parse(otp_url_a).query).fetch("fb")
    otp_data_a = ClientEmail.order(:created_at).last.get_otp
    patch otp_url_a,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data_a[:otp_private_key]).at(otp_data_a[:otp_counter]).to_s } }
    flow_a = ClientSignUpFlow.order(:created_at).last

    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-flow-b@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url_b = response.location
    flow_b = ClientSignUpFlow.order(:created_at).last

    assert_not_equal flow_a.id, flow_b.id
    assert_equal ClientSignUpFlowStatus::HALTED, flow_a.reload.status_id
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow_b.status_id

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: binding_a),
          params: { requirement: "birthdate", checkpoint_version: flow_a.checkpoint_version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::HALTED, flow_a.reload.status_id
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow_b.reload.status_id

    otp_data_b = ClientEmail.order(:created_at).last.get_otp
    patch otp_url_b,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data_b[:otp_private_key]).at(otp_data_b[:otp_counter]).to_s } }
    birthdate_url_b = response.location
    patch birthdate_url_b,
          params: { requirement: "birthdate",
                    checkpoint_version: flow_b.reload.checkpoint_version,
                    birthdate: "1990-01-15", }

    assert_response :redirect
    assert_equal ClientSignUpFlowStatus::COMPLETED, flow_b.reload.status_id
  end

  test "a second tab that submits the otp after the first tab advanced the flow halts it before finalization" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-two-tabs@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    otp_data = ClientEmail.order(:created_at).last.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
    patch otp_url, params: { client_email: { pass_code: pass_code } }
    flow = ClientSignUpFlow.order(:created_at).last

    patch otp_url, params: { client_email: { pass_code: pass_code } }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
  end

  test "a stale page submitted after finalization is refused and does not delete the committed account" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-committed@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    email = ClientEmail.order(:created_at).last
    otp_data = email.get_otp
    patch otp_url,
          params: { client_email: { pass_code: ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s } }
    birthdate_url = response.location
    flow = ClientSignUpFlow.order(:created_at).last
    version = flow.checkpoint_version
    patch birthdate_url, params: { requirement: "birthdate", checkpoint_version: version, birthdate: "1990-01-15" }
    warn "DBG " + response.body.gsub(/<script.*?<\/script>/m, "").gsub(/<style.*?<\/style>/m, "").gsub(/<[^>]+>/, " ").squish[0,
                                                                                                                              500,]

    assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id

    patch birthdate_url, params: { requirement: "birthdate", checkpoint_version: version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert Client.exists?(id: flow.principal_id)
    assert ClientEmail.exists?(id: email.id)

    post otp_url

    assert_response :conflict
    assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert Client.exists?(id: flow.principal_id)
  end

  test "requests without a usable flow binding are refused and never halt the current flow" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :user_email => { raw_address: "phase-binding@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    flow = ClientSignUpFlow.order(:created_at).last
    other_flow = ClientSignUpFlow.create!(
      status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact", entry_method: "email",
      nonce_digest: ClientSignUpFlow.digest_nonce("other-nonce"), issued_at: Time.current,
      expires_at: 10.minutes.from_now,
    )
    visitor_flow = VisitorSignUpFlow.create!(
      status_id: VisitorSignUpFlowStatus::CONTACT_PENDING, step: "contact", entry_method: "email",
      nonce_digest: VisitorSignUpFlow.digest_nonce("visitor-nonce"), issued_at: Time.current,
      expires_at: 10.minutes.from_now,
    )
    bindings = {
      "missing" => nil,
      "empty" => "",
      "zero" => "0",
      "nul byte" => "a\u0000b",
      "malformed" => "not-a-signed-binding",
      "another flow" => SignFlowBindingCodec.encode(flow: other_flow, surface: :app),
      "another surface" => SignFlowBindingCodec.encode(flow: visitor_flow, surface: :com),
    }

    bindings.each do |label, binding|
      get auth_app_sign_up_check_email_otp_url({ ri: "jp", fb: binding }.compact)

      assert_response :conflict, "GET with #{label} binding"
      assert_equal REFUSAL_BODY, response.body

      patch auth_app_sign_up_check_email_otp_url({ ri: "jp", fb: binding }.compact),
            params: { client_email: { pass_code: "000000" } }

      assert_response :conflict, "PATCH with #{label} binding"
      assert_equal REFUSAL_BODY, response.body
      assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id, "#{label} binding"
      assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, other_flow.reload.status_id, "#{label} binding"
    end
  end

  test "the otp phase is served one second before expiry and refused without a halt at and after expiry" do
    travel_to Time.zone.local(2026, 10, 6, 12, 0, 0) do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: { :user_email => { raw_address: "phase-expiry@example.com", confirm_policy: "1" },
                     "cf-turnstile-response" => "test", }
    end
    otp_url = response.location
    flow = ClientSignUpFlow.order(:created_at).last

    travel_to flow.expires_at - 1.second do
      get otp_url

      assert_response :success
    end

    [flow.expires_at, flow.expires_at + 1.second].each do |instant|
      travel_to instant do
        get otp_url

        assert_not_equal 200, response.status, "GET at #{instant.iso8601}"
        assert_nil response.location

        post otp_url

        assert_not_equal 302, response.status, "POST at #{instant.iso8601}"
        assert_not_equal ClientSignUpFlowStatus::HALTED, flow.reload.status_id
      end
    end
  end
end
