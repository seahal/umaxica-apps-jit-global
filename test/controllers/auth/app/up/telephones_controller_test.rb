# typed: false
# frozen_string_literal: true

# Snapshot diffs would expose OTP material and token state on assertion failure.

require "test_helper"
# require "helpers/global_test_support"
require "base64"

module Auth::App::Up
  class TelephonesControllerTest < ActionDispatch::IntegrationTest
    # Rate-limit counters are a NullStore by default in test so unrelated tests
    # cannot accumulate them; this file asserts real limiting behavior, so it
    # opts into a deterministic MemoryStore.
    rate_limit_counters!

    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :client_statuses, :client_telephone_statuses,
             :client_chronicle_events, :client_chronicle_levels
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    setup do
      ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
      ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
      ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      cookies["csrf_token"] = csrf_token_value
      # Mock Cloudflare Turnstile validation
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      https!
      issuance = OidcTestEntry.issue!(
        surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      admit_auth_ceremony_entry!(auth_app_sign_up_path(ri: "jp"), reference: issuance.reference)

      assert_response :see_other
    end

    %w(confirm_policy confirm_using_mfa).each do |consent_field|
      { missing: :omit,
        null: nil,
        empty: "",
        unchecked: "0",
        false_value: false,
        zero: 0,
        unsupported: "yes", }.each do |label, consent_value|
        test "signup admission rejects #{consent_field} #{label} without creating artifacts" do
          contact_params = { raw_number: "+819012345671", confirm_policy: "1", confirm_using_mfa: "1" }
          if consent_value == :omit
            contact_params.delete(consent_field.to_sym)
          else
            contact_params[consent_field.to_sym] = consent_value
          end

          assert_no_difference(
            ["Client.count", "ClientTelephone.count", "ClientSignUpFlow.count", "ClientToken.count",
             "enqueued_jobs.size",],
          ) do
            post auth_app_sign_up_telephone_url(ri: "jp"),
                 params: { :client_telephone => contact_params, "cf-turnstile-response" => "test" },
                 as: :json,
                 headers: { "X-CSRF-Token" => "test-csrf-token", "Sec-Fetch-Site" => "same-origin" }
          end

          assert_response :unprocessable_content
          assert_nil session[:app_sign_up_flow_locator]
        end
      end
    end

    { missing_captcha: [nil, { "success" => false }],
      invalid_captcha: ["invalid-token", { "success" => false }],
      unavailable_captcha: ["outage-token", { "success" => false, "unavailable" => true }],
      missing_consent: ["test", { "success" => true }],
      invalid_identifier: ["test", { "success" => true }], }.each do |reason, (token, verification)|
      test "signup admission preserves the active flow after #{reason} on replacement" do
        post auth_app_sign_up_telephone_url(ri: "jp"),
             params: { :client_telephone =>
               { raw_number: "+819012345671", confirm_policy: "1", confirm_using_mfa: "1" },
                       "cf-turnstile-response" => "test", },
             headers: { "X-CSRF-Token" => "test-csrf-token", "Sec-Fetch-Site" => "same-origin" }

        assert_response :redirect
        original_locator = session[:app_sign_up_flow_locator].dup
        flow = ClientSignUpFlow.find_by!(public_id: original_locator.fetch("public_id"))
        candidate = ClientTelephone.find(flow.pending_contact_id)
        owner = Client.find(flow.principal_id)
        flow_facts = flow.attributes
        candidate_facts = candidate.attributes
        owner_facts = owner.attributes
        contact_params = { raw_number: "+819012345671", confirm_policy: "1", confirm_using_mfa: "1" }
        contact_params[:raw_number] = "+819012345672"
        contact_params.delete(:confirm_policy) if reason == :missing_consent
        contact_params[:raw_number] = "invalid" if reason == :invalid_identifier
        request_params = { client_telephone: contact_params }
        request_params["cf-turnstile-response"] = token if token
        TurnstileVerifierStub.challenge_response = verification

        assert_no_difference(
          ["Client.count", "ClientTelephone.count", "ClientSignUpFlow.count", "ClientToken.count",
           "enqueued_jobs.size",],
        ) do
          post auth_app_sign_up_telephone_url(ri: "jp"), params: request_params,
                                                         headers: {
                                                           "X-CSRF-Token" => "test-csrf-token",
                                                           "Sec-Fetch-Site" => "same-origin",
                                                         }
        end

        assert_response :unprocessable_content
        locator_preserved = session[:app_sign_up_flow_locator] == original_locator

        assert locator_preserved, "Rejected replacement must preserve the browser locator"
        flow_preserved = flow.reload.attributes == flow_facts

        assert flow_preserved, "Rejected replacement must preserve flow facts"
        candidate_preserved = candidate.reload.attributes == candidate_facts

        assert candidate_preserved, "Rejected replacement must preserve contact facts"
        owner_preserved = owner.reload.attributes == owner_facts

        assert owner_preserved, "Rejected replacement must preserve owner facts"
      end
    end

    test "signup admission accepts explicit JSON boolean consent" do
      assert_difference(["Client.count", "ClientTelephone.count", "ClientSignUpFlow.count"], 1) do
        post auth_app_sign_up_telephone_url(ri: "jp"),
             params: {
               :client_telephone => { raw_number: "+819012345673",
                                      confirm_policy: true,
                                      confirm_using_mfa: true, },
               "cf-turnstile-response" => "test",
             },
             as: :json,
             headers: { "X-CSRF-Token" => "test-csrf-token", "Sec-Fetch-Site" => "same-origin" }
      end

      assert_response :redirect
      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert_equal "telephone", flow.pending_contact_type
      assert_nil ClientTelephone.find(flow.pending_contact_id).binding_finalized_at
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
    end

    test "should get new" do
      get new_auth_app_sign_up_telephone_url(ri: "jp")

      assert_response :success
    end

    test "new keeps an admitted ceremony independent of a presented root token" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      token = ClientToken.create!(
        authentication_epoch: 0,
        user: visitor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      )
      original_token_facts = token.reload.attributes
      credential = AuthenticationToken.encode(
        visitor, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                 session_public_id: token.public_id, resource_type: "client",
      )
      headers = { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                  "HTTPS" => "on",
                  "Authorization" => "Bearer #{credential}", }

      assert_no_difference(["ClientToken.count", "ClientTelephone.count"]) do
        get new_auth_app_sign_up_telephone_url(ri: "jp"), headers: headers
      end

      assert_response :success
      assert_withheld("protected record facts remain unchanged") { original_token_facts == token.reload.attributes }
    end

    test "create keeps an admitted ceremony independent of a presented root token" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      token = ClientToken.create!(
        authentication_epoch: 0,
        user: visitor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      )
      original_token_facts = token.reload.attributes
      credential = AuthenticationToken.encode(
        visitor, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                 session_public_id: token.public_id, resource_type: "client",
      )
      headers = { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                  "HTTPS" => "on",
                  "Authorization" => "Bearer #{credential}", }

      assert_difference("ClientTelephone.count", 1) do
        assert_no_difference("ClientToken.count") do
          post auth_app_sign_up_telephone_url(ri: "jp"),
               params: { client_telephone: { raw_number: "+819012300099", confirm_policy: "1", confirm_using_mfa: "1" },
                         "cf-turnstile-response": "test", }, headers: headers
        end
      end

      assert_response :redirect
      target = URI.parse(response.location)

      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), target.host
      assert_equal URI.parse(auth_app_sign_up_check_telephone_otp_path(ri: "jp")).path, target.path
      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      candidate = ClientTelephone.find(flow.pending_contact_id)

      assert_not_equal visitor.id, candidate.user_id
      assert_nil candidate.binding_finalized_at
      assert_equal flow.public_id,
                   SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb")).flow_public_id
      assert_withheld("protected record facts remain unchanged") { original_token_facts == token.reload.attributes }
    end

    test "edit route uses registration session" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)

      get otp_target.request_uri

      assert_response :success
      assert_nil request.path_parameters[:id]
      assert_equal telephone.public_id, session.dig(:user_telephone_registration, "public_id")
      assert_equal "auth/app/sign/up/telephones/edit", inertia_component
      props = inertia_props

      assert_equal I18n.t("sign.app.registration.telephone.edit.page_title"), props.fetch("title")
      assert_equal I18n.t("sign.app.registration.telephone.edit.code_label"), props.fetch("code_label")
      assert_equal I18n.t("sign.app.registration.telephone.edit.code_placeholder"),
                   props.fetch("code_placeholder")
      # The page builds the one-time-code field from this scope: client_telephone[pass_code].
      assert_equal "client_telephone", props.fetch("scope")
      assert_equal I18n.t("sign.app.registration.telephone.edit.submit"), props.fetch("submit_label")
      assert_includes props.fetch("description"), "電話番号"
      assert_includes props.fetch("description"), "SMS"
      assert_equal I18n.t("sign.app.registration.telephone.edit.delivery_help"),
                   props.fetch("delivery_help")
      assert_empty props.fetch("errors")
      assert_nil props.fetch("error_heading")
    end

    test "create binds a new telephone candidate to the signed OTP continuation" do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        assert_difference("ClientTelephone.count", 1) do
          post auth_app_sign_up_telephone_url(ri: "jp"), params: {
            client_telephone: { raw_number: "+1234567890", confirm_policy: "1", confirm_using_mfa: "1" },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :redirect
      target = URI.parse(response.location)
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(cycle.pending_contact_id)

      assert_equal "https", target.scheme
      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), target.host
      assert_equal URI.parse(auth_app_sign_up_check_telephone_otp_path(ri: "jp")).path, target.path
      assert_equal "jp", Rack::Utils.parse_query(target.query).fetch("ri")
      assert_equal cycle.public_id, SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb")).flow_public_id
      assert_not_nil session[:user_telephone_registration]
      assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
      assert_equal "telephone", cycle.entry_method
      assert_equal telephone.public_id, session.fetch(:user_telephone_registration).fetch(:public_id)
      assert_nil telephone.binding_finalized_at
    end

    test "new page does not use sample wording in error summary" do
      post auth_app_sign_up_telephone_url, params: {
        client_telephone: {
          raw_number: "invalid-telephone",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :unprocessable_content
      assert_not_includes response.body, "prohibited this sample from being saved"
      assert_includes response.body, "prohibited this telephone from being saved"
    end

    test "create beside an effective telephone issues only an independent pending candidate" do
      user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing = ClientTelephone.create!(
        user: user, number: "+1234567898", user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1", confirm_using_mfa: "1", binding_finalized_at: ClientTelephone.database_now,
      )
      existing_facts = existing.reload.attributes
      owner_facts = user.reload.attributes

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        assert_difference("Client.count", 1) do
          assert_difference("ClientTelephone.count", 1) do
            post auth_app_sign_up_telephone_url(ri: "jp"), params: {
              client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :redirect
      target = URI.parse(response.location)
      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      candidate = ClientTelephone.find(flow.pending_contact_id)

      assert_not_equal existing.id, candidate.id
      assert_not_equal existing.user_id, candidate.user_id
      assert_equal existing.number_digest, candidate.number_digest
      assert_nil candidate.binding_finalized_at
      assert_withheld("effective binding is unchanged") { existing_facts == existing.reload.attributes }
      assert_withheld("effective owner is unchanged") { owner_facts == user.reload.attributes }
      get target.request_uri

      assert_response :success
      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: candidate.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      valid_code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)
      wrong_code = (valid_code[0] == "0") ? "1#{valid_code[1..]}" : "0#{valid_code[1..]}"
      assert_no_difference("ClientToken.count") do
        patch target.request_uri, params: {
          client_telephone: { pass_code: wrong_code }, "cf-turnstile-response": "test",
        }
      end

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("sign.app.registration.telephone.update.invalid_code")
      assert_withheld("wrong input cannot alter the existing binding") { existing_facts == existing.reload.attributes }
      assert_withheld("wrong input cannot alter the existing owner") { owner_facts == user.reload.attributes }
    end

    test "a verified telephone candidate lock cannot mutate an independent signup candidate" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = ClientTelephone.create!(
        user: visitor, raw_number: "+819012377901",
        confirm_policy: true, confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
        locked_at: 10.minutes.from_now,
      )
      original_facts = existing.reload.attributes
      owner_facts = visitor.reload.attributes

      assert_difference("ClientTelephone.count", 1) do
        assert_difference("Client.count", 1) do
          post auth_app_sign_up_telephone_url(ri: "jp"),
               params: { client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
                         "cf-turnstile-response": "test", },
               headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
        end
      end

      assert_response :redirect
      target = URI.parse(response.location)
      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      candidate = ClientTelephone.find(flow.pending_contact_id)

      assert_not_equal existing.id, candidate.id
      assert_not_equal existing.user_id, candidate.user_id
      assert_equal existing.number_digest, candidate.number_digest
      assert_nil candidate.binding_finalized_at
      assert_not_predicate candidate, :locked?
      assert_withheld("protected record facts remain unchanged") { original_facts == existing.reload.attributes }
      assert_withheld("protected record facts remain unchanged") { owner_facts == visitor.reload.attributes }
      get target.request_uri

      assert_response :success
    end

    test "a locked pending sign-up telephone candidate refuses a new sign-up unchanged (D-135)" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = ClientTelephone.create!(
        user: visitor, raw_number: "+819012377902",
        confirm_policy: true, confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        locked_at: 10.minutes.from_now,
      )
      original_facts = existing.reload.attributes
      owner_facts = visitor.reload.attributes

      assert_no_difference(%w(ClientTelephone.count Client.count)) do
        post auth_app_sign_up_telephone_url(ri: "jp"),
             params: { client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
                       "cf-turnstile-response": "test", },
             headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
      end

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("sign.app.registration.telephone.create.contact_held")
      assert_withheld("protected record facts remain unchanged") { original_facts == existing.reload.attributes }
      assert_withheld("protected record facts remain unchanged") { owner_facts == visitor.reload.attributes }
    end

    test "create is refused when the creator reports the number rate limited under its own lock" do
      rate_limited = TelephoneSignUpCandidateResult.new(
        status: :rate_limited, telephone: ClientTelephone.new, session_payload: nil,
      )

      TelephoneSignUpCandidateCreator.stub(:call, rate_limited) do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: { raw_number: "+1234567803", confirm_policy: "1", confirm_using_mfa: "1" },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :too_many_requests
    end

    test "create re-renders the telephone form when the creator rejects the record" do
      raiser =
        lambda do |**|
          raise ActiveRecord::RecordInvalid, ClientTelephone.new
        end

      TelephoneSignUpCandidateCreator.stub(:call, raiser) do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: { raw_number: "+1234567804", confirm_policy: "1", confirm_using_mfa: "1" },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :unprocessable_content
    end

    test "rejects invalid telephone format" do
      logged =
        capture_telephone_log do
          post(
            auth_app_sign_up_telephone_url, params: {
              user_telephone: {
                raw_number: "invalid-telephone",
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            },
          )
        end

      assert_includes logged, "sign.signup.telephone.create.received"
      assert_includes logged, "sign.signup.telephone.create.rejected"
      assert_includes logged, "telephone_invalid"

      assert_response :unprocessable_content
    end

    test "create renders unprocessable when user_telephone param missing" do
      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post auth_app_sign_up_telephone_url, params: {
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :unprocessable_content
    end

    test "create with turnstile failure returns unprocessable content" do
      TurnstileVerifierStub.challenge_response = { "success" => false }

      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post auth_app_sign_up_telephone_url, params: {
              user_telephone: {
                raw_number: "+1234567897",
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :unprocessable_content
    end

    def capture_telephone_log
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = original
    end

    test "should update telephone with valid otp" do
      # 1. Create telephone via request to set up session
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)

      # 2. Retrieve the code from the encrypted delivery for the bound ceremony.
      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: telephone.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)

      # 3. Submit OTP
      patch otp_target.request_uri, params: {
        client_telephone: { pass_code: code },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      guard_target = URI.parse(response.location)

      assert_equal "https", guard_target.scheme
      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), guard_target.host
      assert_equal URI.parse(auth_app_sign_up_guard_telephone_path(ri: "jp")).path, guard_target.path
      assert_equal "jp", Rack::Utils.parse_query(guard_target.query).fetch("ri")
      guard_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(guard_target.query).fetch("fb"))
      cycle = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id)

      assert_equal original_binding.flow_public_id, guard_binding.flow_public_id
      assert_equal cycle.reload.step, guard_binding.phase
      assert_equal cycle.checkpoint_version, guard_binding.generation
      assert_equal cycle.expires_at.to_i, guard_binding.expires_at

      telephone.reload
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      transaction = ClientTelephoneCeremonyTransaction.find_by!(transaction_id: transaction_ref)

      assert_equal telephone.public_id, transaction.telephone_candidate_ref
      assert_nil transaction.otp_verifier
      assert_predicate transaction.otp_consumed_at, :present?
      assert_predicate transaction.otp_receipt_verifier, :present?
      assert_equal transaction.otp_consumed_at + 60.seconds, transaction.otp_result_expires_at
      assert_equal [nil, nil], [telephone.confirm_policy, telephone.confirm_using_mfa]
      assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.status_id
      assert_equal "checkpoint", cycle.step
    end

    test "otp success keeps telephone pending and records cycle proof in session" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)

      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: telephone.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)

      assert_no_difference("ClientToken.count") do
        patch otp_target.request_uri, params: {
          client_telephone: { pass_code: code },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :redirect
      guard_target = URI.parse(response.location)

      assert_equal "https", guard_target.scheme
      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), guard_target.host
      assert_equal URI.parse(auth_app_sign_up_guard_telephone_path(ri: "jp")).path, guard_target.path
      assert_equal "jp", Rack::Utils.parse_query(guard_target.query).fetch("ri")
      guard_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(guard_target.query).fetch("fb"))
      current_flow = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id).reload

      assert_equal current_flow.public_id, guard_binding.flow_public_id
      assert_equal current_flow.step, guard_binding.phase
      assert_equal current_flow.checkpoint_version, guard_binding.generation
      assert_equal current_flow.expires_at.to_i, guard_binding.expires_at

      # The telephone must stay UNVERIFIED_WITH_SIGN_UP so an abandoned cycle
      # stays collectable by the pending-signup cleanup (no number lock).
      assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
                   telephone.reload.user_telephone_status_id
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence

      registration = session[:user_telephone_registration]
      otp_verified = registration[:otp_verified] || registration["otp_verified"]

      assert otp_verified
    end

    test "telephone sign up still requires passkey even if pending user has a passkey" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567891",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)
      user = contact_owner_for_test(telephone)

      ClientPasskey.create!(
        user: user,
        webauthn_id: Base64.urlsafe_encode64("preexisting_passkey", padding: false),
        public_key: "public_key",
        sign_count: 0,
        description: "Existing Passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: telephone.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)

      # A pre-existing passkey row must not let OTP success short-circuit into
      # a signed-in session: telephone sign-up always routes through the
      # passkey step and the durable finalizer.
      assert_no_difference("ClientToken.count") do
        patch otp_target.request_uri, params: {
          client_telephone: { pass_code: code },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :redirect
      guard_target = URI.parse(response.location)

      assert_equal "https", guard_target.scheme
      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), guard_target.host
      assert_equal URI.parse(auth_app_sign_up_guard_telephone_path(ri: "jp")).path, guard_target.path
      assert_equal "jp", Rack::Utils.parse_query(guard_target.query).fetch("ri")
      guard_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(guard_target.query).fetch("fb"))
      current_flow = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id).reload

      assert_equal current_flow.public_id, guard_binding.flow_public_id
      assert_equal current_flow.step, guard_binding.phase
      assert_equal current_flow.checkpoint_version, guard_binding.generation
      assert_equal current_flow.expires_at.to_i, guard_binding.expires_at
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.reload.status_id

      get guard_target.request_uri

      assert_response :redirect
      passkey_target = URI.parse(response.location)

      assert_equal URI.parse(auth_app_sign_up_check_telephone_passkey_path(ri: "jp")).path, passkey_target.path
      assert_equal guard_binding,
                   SignFlowBindingCodec.decode(Rack::Utils.parse_query(passkey_target.query).fetch("fb"))

      get passkey_target.request_uri

      assert_response :success
      assert_equal "auth/app/sign/up/checkpoint/passkeys/new", inertia_component
      page_props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      begin_url = URI.parse(page_props.fetch("begin_url"))

      assert_equal passkey_target.path, begin_url.path
      assert_equal guard_binding,
                   SignFlowBindingCodec.decode(Rack::Utils.parse_query(begin_url.query).fetch("fb"))
    end

    test "another admitted browser is refused beside an abandoned OTP-verified telephone " \
         "without changing its proof (D-135)" do
      number = "+1234567892"
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        client_telephone: { raw_number: number, confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      target = URI.parse(response.location)
      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)
      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: telephone.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)
      assert_no_difference("ClientToken.count") do
        patch target.request_uri, params: {
          client_telephone: { pass_code: code }, "cf-turnstile-response": "test",
        }
      end

      assert_response :redirect
      assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, flow.reload.status_id
      original_facts = telephone.reload.attributes
      original_owner_facts = contact_owner_for_test(telephone).reload.attributes
      original_flow_facts = flow.reload.attributes
      browser = open_session
      browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
      browser.https!
      issuance = OidcTestEntry.issue!(
        surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      admit_auth_ceremony_entry!(auth_app_sign_up_path(ri: "jp"), reference: issuance.reference, browser: browser)
      headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" }

      assert_equal 303, browser.response.status
      travel TelephoneOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
        assert_no_difference(%w(ClientTelephone.count Client.count)) do
          browser.post(
            auth_app_sign_up_telephone_url(ri: "jp"),
            params: { client_telephone: { raw_number: number, confirm_policy: "1", confirm_using_mfa: "1" },
                      "cf-turnstile-response": "test", }, headers: headers,
          )
        end
      end

      assert_equal 422, browser.response.status
      assert_includes browser.response.body, I18n.t("sign.app.registration.telephone.create.contact_held")
      assert_withheld("original verified OTP evidence remains unchanged") {
        original_facts == telephone.reload.attributes
      }
      assert_withheld("original owner remains unchanged") {
        original_owner_facts == contact_owner_for_test(telephone).reload.attributes
      }
      assert_withheld("original checkpoint proof remains unchanged") { original_flow_facts == flow.reload.attributes }
    end

    test "should reject blank pass code" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert ClientTelephone.exists?(flow.pending_contact_id)
      patch otp_target.request_uri, params: {
        client_telephone: { pass_code: "" },
        "cf-turnstile-response": "test",
      }

      assert_response :unprocessable_content
    end

    test "should lockout after max failed otp attempts" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567893",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      telephone = ClientTelephone.find(flow.pending_contact_id)
      user = contact_owner_for_test(telephone)
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      completed_requirements = cycle.completed_requirements.deep_dup

      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: telephone.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      valid_code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)
      wrong_code = (valid_code[0] == "0") ? "1#{valid_code[1..]}" : "0#{valid_code[1..]}"
      Prosopite.pause do
        Telephone::MAX_OTP_ATTEMPTS.times do
          patch otp_target.request_uri, params: {
            client_telephone: { pass_code: wrong_code },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :too_many_requests
      assert_includes response.body, I18n.t("sign.app.registration.telephone.update.attempts_exceeded")
      assert_empty flash.to_hash

      assert ClientTelephone.exists?(telephone.id)
      assert Client.exists?(user.id)
      assert_predicate telephone.reload, :locked?
      assert_nil session[:user_telephone_registration]
      assert_equal completed_requirements, cycle.reload.completed_requirements
      assert_nil cycle.completed_requirements["otp"]
    end

    test "a second entry submit while this browser's earlier attempt is unfinished is refused and changes nothing" do
      headers = { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
      post auth_app_sign_up_telephone_url(ri: "jp"),
           params: { client_telephone: { raw_number: "+819012300004", confirm_policy: "1", confirm_using_mfa: "1" },
                     "cf-turnstile-response": "test", },
           headers: headers

      assert_response :redirect
      original_locator = session[:app_sign_up_flow_locator].dup
      first_flow = ClientSignUpFlow.find_by!(public_id: original_locator.fetch("public_id"))
      first_flow_facts = first_flow.attributes
      first_candidate_facts = ClientTelephone.find(first_flow.pending_contact_id).attributes

      ["+819012300004", "+819012300005"].each do |destination|
        assert_no_difference(
          ["Client.count", "ClientTelephone.count", "ClientSignUpFlow.count",
           "enqueued_jobs.size",],
        ) do
          post auth_app_sign_up_telephone_url(ri: "jp"),
               params: { client_telephone: { raw_number: destination, confirm_policy: "1", confirm_using_mfa: "1" },
                         "cf-turnstile-response": "test", },
               headers: headers
        end

        assert_response :unprocessable_content
        assert_includes response.body, I18n.t("sign.app.registration.telephone.create.contact_held", locale: :ja)
      end

      assert_equal original_locator, session[:app_sign_up_flow_locator]
      assert_equal first_flow_facts, first_flow.reload.attributes
      assert_equal first_candidate_facts, ClientTelephone.find(first_flow.pending_contact_id).attributes
    end

    test "fresh sessions cannot distinguish pending and registered telephone sign-up" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = ClientTelephone.create!(
        user: visitor, raw_number: "+819012300006", confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )
      existing_facts = existing.reload.attributes
      existing_owner_facts = visitor.reload.attributes
      responses = []
      refusals = []
      candidates = []
      browsers = []
      targets = []

      [existing.number, "+819012300007"].each do |destination|
        2.times do |attempt|
          browser = open_session
          browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
          browser.https!
          issuance = OidcTestEntry.issue!(
            surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
          )
          ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
          admit_auth_ceremony_entry!(auth_app_sign_up_path(ri: "jp"), reference: issuance.reference, browser: browser)
          headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" }

          assert_equal 303, browser.response.status
          if attempt == 1
            # D-135: the first browser's unfinished registration now holds the destination,
            # registered or not, so the second browser is refused the same way for both.
            assert_no_difference("ClientTelephone.count") do
              browser.post(
                auth_app_sign_up_telephone_url(ri: "jp"),
                params: { client_telephone: { raw_number: destination, confirm_policy: "1", confirm_using_mfa: "1" },
                          "cf-turnstile-response": "test", }, headers: headers,
              )
            end

            refusals << browser.response.status
            next
          end

          assert_difference("ClientTelephone.count", 1) do
            browser.post(
              auth_app_sign_up_telephone_url(ri: "jp"),
              params: { client_telephone: { raw_number: destination, confirm_policy: "1", confirm_using_mfa: "1" },
                        "cf-turnstile-response": "test", }, headers: headers,
            )
          end

          assert_equal 302, browser.response.status
          target = URI.parse(browser.response.location)
          query = Rack::Utils.parse_query(target.query)

          assert_equal %w(fb ri), query.keys.sort
          assert_equal "jp", query.fetch("ri")
          responses << [browser.response.status, target.scheme, target.host, target.path, query.keys.sort]
          candidate = ClientTelephone.order(:created_at, :id).last
          candidates << candidate
          browsers << browser
          targets << target

          assert_equal destination, candidate.number
          assert_nil candidate.binding_finalized_at
        end
      end

      assert_equal 1, responses.uniq.length
      assert_equal [422, 422], refusals
      assert_equal 2, candidates.map(&:id).uniq.length
      assert_equal 2, candidates.map(&:user_id).uniq.length
      assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
      assert_withheld("protected record facts remain unchanged") { existing_owner_facts == visitor.reload.attributes }
      own_candidate_facts = candidates.last.reload.attributes
      foreign_candidate_facts = candidates.first.reload.attributes
      browsers.last.get(targets.first.request_uri)

      assert_equal 409, browsers.last.response.status
      assert_withheld("protected record facts remain unchanged") {
        own_candidate_facts == candidates.last.reload.attributes
      }
      assert_withheld("protected record facts remain unchanged") {
        foreign_candidate_facts == candidates.first.reload.attributes
      }
      transaction_ref =
        ClientTelephoneCeremonyTransaction.find_by!(
          telephone_candidate_ref: candidates.first.public_id,
        ).transaction_id
      queued =
        enqueued_jobs.reverse.find do |job|
          next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

          payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
          payload.fetch(:otp_binding)[3] == transaction_ref
        end
      foreign_code =
        OutboundSensitivePayload.decrypt_sms_delivery(
          queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
        ).fetch(:otp_code)
      assert_no_difference("ClientToken.count") do
        browsers.last.patch(
          targets.first.request_uri,
          params: { client_telephone: { pass_code: foreign_code }, "cf-turnstile-response": "test" },
          headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" },
        )
      end

      assert_equal 409, browsers.last.response.status
      assert_withheld("foreign proof cannot affect this candidate") {
        own_candidate_facts == candidates.last.reload.attributes
      }
      assert_withheld("foreign proof cannot consume its candidate") {
        foreign_candidate_facts == candidates.first.reload.attributes
      }
      browsers.last.get(targets.last.request_uri)

      assert_equal 200, browsers.last.response.status
    end

    test "resend sends code for active registration session after the initial delivery cooldown" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert ClientTelephone.exists?(flow.pending_contact_id)
      telephone = ClientTelephone.find(flow.pending_contact_id)
      decision_time = telephone.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + 1.second
      travel_to decision_time do
        ClientTelephone.stub(:database_now, decision_time) do
          assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
            post otp_target.request_uri
          end
        end
      end

      assert_response :redirect
      actual_target = URI.parse(response.location)

      assert_equal "https", actual_target.scheme
      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), actual_target.host
      assert_equal URI.parse(auth_app_sign_up_check_telephone_otp_path(ri: "jp")).path, actual_target.path
      assert_equal "jp", Rack::Utils.parse_query(actual_target.query).fetch("ri")
      assert_equal original_binding,
                   SignFlowBindingCodec.decode(Rack::Utils.parse_query(actual_target.query).fetch("fb"))
      assert_predicate session[:user_telephone_otp_last_sent_at], :present?
    end

    test "resend without a signed flow locator refuses without allocating or sending" do
      assert_no_difference(["ClientTelephone.count", "ClientSignUpFlow.count", "ClientToken.count"]) do
        assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
          post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
      end

      assert_response :conflict
      assert_nil response.headers["Location"]
    end

    test "resend rate limits repeated requests" do
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      otp_target = URI.parse(response.location)
      SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert ClientTelephone.exists?(flow.pending_contact_id)
      telephone = ClientTelephone.find(flow.pending_contact_id)
      decision_time = telephone.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + 1.second
      travel_to decision_time do
        ClientTelephone.stub(:database_now, decision_time) do
          assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
            post otp_target.request_uri
          end
          assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
            post otp_target.request_uri
          end
        end
      end

      assert_response :too_many_requests
      assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
    end

    test "resend cooldown is 30 seconds" do
      ClientTelephone.stub(:database_now, -> { Time.current }) do
        post auth_app_sign_up_telephone_url(ri: "jp"), params: {
          user_telephone: {
            raw_number: "+1234567892",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }

        assert_response :redirect
        otp_target = URI.parse(response.location)
        original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_target.query).fetch("fb"))

        assert_response :redirect

        initial_flow = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id)
        initial_candidate = ClientTelephone.find(initial_flow.pending_contact_id)
        travel_to initial_candidate.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + 1.second do
          post otp_target.request_uri
        end
        sent_at = session[:user_telephone_otp_last_sent_at]
        flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
        telephone = ClientTelephone.find(flow.pending_contact_id)
        otp_data =
          ClientTelephoneCeremonyTransaction.find_by!(
            telephone_candidate_ref: telephone.public_id,
          ).otp_generation
        cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
        completed_requirements = cycle.completed_requirements.deep_dup

        assert_predicate sent_at, :present?
        assert_response :redirect
        actual_target = URI.parse(response.location)

        assert_equal "https", actual_target.scheme
        assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), actual_target.host
        assert_equal URI.parse(auth_app_sign_up_check_telephone_otp_path(ri: "jp")).path, actual_target.path
        assert_equal "jp", Rack::Utils.parse_query(actual_target.query).fetch("ri")
        assert_equal original_binding,
                     SignFlowBindingCodec.decode(Rack::Utils.parse_query(actual_target.query).fetch("fb"))

        # Anchored to when the code was actually sent, not to now. `travel` moves
        # from the current moment, so on a slow run the setup requests alone can
        # push the gap past the cooldown and the case silently inverts.
        source_sent_at = telephone.otp_last_sent_at
        travel_to source_sent_at + 29.seconds do
          assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
            post otp_target.request_uri
          end
          assert_response :too_many_requests
          assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
          assert_equal sent_at, session[:user_telephone_otp_last_sent_at]
          assert_withheld("refusal preserves the existing OTP generation") {
            otp_data == ClientTelephoneCeremonyTransaction.find_by!(
              telephone_candidate_ref: telephone.public_id,
            ).otp_generation
          }
          assert_equal completed_requirements, cycle.reload.completed_requirements
        end

        travel_to source_sent_at + 31.seconds do
          assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
            post otp_target.request_uri
          end
          assert_response :redirect
          actual_target = URI.parse(response.location)

          assert_equal "https", actual_target.scheme
          assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), actual_target.host
          assert_equal URI.parse(auth_app_sign_up_check_telephone_otp_path(ri: "jp")).path, actual_target.path
          assert_equal "jp", Rack::Utils.parse_query(actual_target.query).fetch("ri")
          assert_equal original_binding,
                       SignFlowBindingCodec.decode(Rack::Utils.parse_query(actual_target.query).fetch("fb"))
          assert_operator session[:user_telephone_otp_last_sent_at], :>, sent_at
        end
      end
    end

    test "telephone resend accepts exactly the 30-second cooldown boundary without changing its flow" do
      ClientTelephone.stub(:database_now, -> { Time.current }) do
        post auth_app_sign_up_telephone_url(ri: "jp"), params: {
          client_telephone: { raw_number: "+819012300031", confirm_policy: "1", confirm_using_mfa: "1" },
          "cf-turnstile-response": "test",
        }

        assert_response :redirect
        target = URI.parse(response.location)
        original_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb"))
        initial_flow = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id)
        initial_candidate = ClientTelephone.find(initial_flow.pending_contact_id)
        travel_to initial_candidate.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + 1.second do
          post target.request_uri
        end

        assert_response :redirect
        assert_predicate session.fetch(:user_telephone_otp_last_sent_at), :present?
        flow = ClientSignUpFlow.find_by!(public_id: original_binding.flow_public_id)
        candidate = ClientTelephone.find(flow.pending_contact_id)
        candidate.reload
        old_otp =
          ClientTelephoneCeremonyTransaction.find_by!(
            telephone_candidate_ref: candidate.public_id,
          ).otp_generation
        old_attempts = candidate.otp_attempts_count
        completed_requirements = flow.reload.completed_requirements.deep_dup

        travel_to candidate.otp_last_sent_at + 30.seconds do
          assert_no_difference("ClientToken.count") do
            assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
              post target.request_uri
            end
          end

          assert_response :redirect
          actual_target = URI.parse(response.location)

          assert_equal "https", actual_target.scheme
          assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), actual_target.host
          assert_equal target.path, actual_target.path
          assert_equal "jp", Rack::Utils.parse_query(actual_target.query).fetch("ri")
          assert_equal original_binding,
                       SignFlowBindingCodec.decode(Rack::Utils.parse_query(actual_target.query).fetch("fb"))
          current_generation = ClientTelephoneCeremonyTransaction.find_by!(
            telephone_candidate_ref: candidate.public_id,
          ).otp_generation
          generation_changed = old_otp != current_generation

          assert generation_changed, "resend rotates only this candidate's OTP generation"
          assert_equal old_attempts, candidate.otp_attempts_count
          assert_equal completed_requirements, flow.reload.completed_requirements
        end
      end
    end

    test "create rejects signup for a telephone number blocked by an in-force registration_blocked Identifier " \
         "Effect, sending no OTP" do
      operator = operators(:one)
      the_case = AppEnforcementCase.new(
        kind: "permanent_ban",
        duration_mode: "permanent",
        visibility: "visible",
        release_mode: "break_glass_only",
        effective_at: Time.current,
        reason_code: "abuse",
        principal_public_id: "some_prior_client_public_id",
        applied_by_operator_public_id: operator.public_id,
      )
      digest = EnforcementIdentifierDigest.for_telephone(realm: "app", value: "+15551234567")
      the_case.identifier_effects.build(**digest, registration_blocked: true, effective_at: Time.current)
      EnforcementCaseApplyOperation.call(
        enforcement_case: the_case,
        actor_operator_public_id: the_case.applied_by_operator_public_id,
      )

      assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
        assert_no_difference("ClientTelephone.count") do
          post auth_app_sign_up_telephone_url, params: {
            client_telephone: {
              raw_number: "+15551234567",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :unprocessable_content
    end

    test "sign-up beside an effective telephone creates only its own pending candidate" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = visitor.client_telephones.create!(
        raw_number: "+819012377001",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )
      existing_facts = existing.reload.attributes

      assert_difference("Client.count", 1) do
        assert_difference("ClientTelephone.count", 1) do
          post auth_app_sign_up_telephone_url(ri: "jp"),
               params: {
                 client_telephone: {
                   raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1",
                 },
                 "cf-turnstile-response": "test",
               }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
        end
      end

      assert_response :redirect
      assert_includes response.location, "/sign/up/check/telephone/otp"

      target = URI.parse(response.location)
      get target.request_uri, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :success
      assert_not_includes response.body, I18n.t("errors.messages.taken")
      assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
      candidate = ClientTelephone.order(:created_at, :id).last

      assert_not_equal existing.id, candidate.id
      assert_not_equal existing.user_id, candidate.user_id
      assert_equal existing.number_digest, candidate.number_digest
      assert_nil candidate.binding_finalized_at
    end

    test "resending the code for an already verified telephone answers without creating records" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = visitor.client_telephones.create!(
        raw_number: "+819012377801",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )
      existing_facts = existing.reload.attributes

      post auth_app_sign_up_telephone_url(ri: "jp"),
           params: {
             client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
             "cf-turnstile-response": "test",
           }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :redirect
      target = URI.parse(response.location)

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      candidate = ClientTelephone.find(flow.pending_contact_id)
      decision_time = candidate.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + 1.second
      travel_to decision_time do
        ClientTelephone.stub(:database_now, decision_time) do
          assert_no_difference("ClientTelephone.count") do
            post target.request_uri, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
          end
        end
      end

      assert_response :redirect
      assert_includes response.location, "/sign/up/check/telephone/otp"

      # The second resend lands inside the send cooldown and must be refused with the
      # same message a real pending registration gets, so the two cannot be told apart.
      target = URI.parse(response.location)
      post target.request_uri, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :too_many_requests
      assert_equal I18n.t("sign.app.registration.email.create.otp_resend_too_soon"), response.body
      assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
    end

    test "the code page for an already verified telephone stops answering once the window closes" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = visitor.client_telephones.create!(
        raw_number: "+819012377802",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )

      post auth_app_sign_up_telephone_url(ri: "jp"),
           params: {
             client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
             "cf-turnstile-response": "test",
           }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :redirect
      target = URI.parse(response.location)

      flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      candidate = ClientTelephone.find(flow.pending_contact_id)
      original_facts = candidate.reload.attributes
      original_existing_facts = existing.reload.attributes
      travel TelephoneOtpPolicy::AUTHENTICATION_TTL + 1.minute do
        ClientTelephoneCeremonyTransaction.stub(
          :database_now,
          ClientTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: candidate.public_id).otp_expires_at,
        ) do
          get target.request_uri, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
        end
      end

      assert_response :redirect
      expired_target = URI.parse(response.location)

      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), expired_target.host
      assert_equal URI.parse(new_auth_app_sign_up_telephone_path(ri: "jp")).path, expired_target.path
      assert_withheld("expired evidence is not revived") { original_facts == candidate.reload.attributes }
      assert_withheld("effective binding is unchanged") { original_existing_facts == existing.reload.attributes }
    end

    test "a code submitted against an already verified telephone never starts an account" do
      visitor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER,
      )
      existing = visitor.client_telephones.create!(
        raw_number: "+819012377002",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )
      existing_facts = existing.reload.attributes
      post auth_app_sign_up_telephone_url(ri: "jp"),
           params: {
             client_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
             "cf-turnstile-response": "test",
           }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :redirect
      target = URI.parse(response.location)
      get target.request_uri, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }

      assert_response :success

      assert_no_difference("Client.count") do
        patch target.request_uri,
              params: { client_telephone: { pass_code: "123456" }, "cf-turnstile-response": "test" },
              headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "HTTPS" => "on" }
      end

      assert_response :unprocessable_content
      assert_equal ClientTelephoneStatus::VERIFIED, existing.reload.user_telephone_status_id
      assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
    end

    private

    def regional_defaults
      { ri: "jp" }
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      ClientTelephone.find_by!(public_id: public_id)
    end

    def post(path, **options)
      options[:headers] = browser_headers.merge(options[:headers] || {})
      super
    end

    def patch(path, **options)
      options[:headers] = browser_headers.merge(options[:headers] || {})
      super
    end
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Up::TelephonesControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Up::TelephonesControllerTest
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
class Auth::App::Up::TelephonesControllerTest
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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
