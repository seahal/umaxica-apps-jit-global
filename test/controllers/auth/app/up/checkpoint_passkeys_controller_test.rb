# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

module Auth::App::Up
  class CheckpointPasskeysControllerTest < ActionDispatch::IntegrationTest
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :client_statuses, :client_telephone_statuses, :client_passkey_statuses,
             :client_chronicle_events, :client_chronicle_levels

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
    end

    test "GET show returns 200 with passkey endpoint data attrs" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      get auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      assert_response :success
      assert_equal "auth/app/sign/up/checkpoint/passkeys/new", inertia_component
      props = inertia_props
      begin_path = auth_app_sign_up_check_telephone_passkey_path(ri: "jp")

      assert_equal begin_path, props.fetch("begin_url")
      finish_path = auth_app_sign_up_check_telephone_passkey_path(ri: "jp")

      assert_equal finish_path, props.fetch("finish_url")
      passcode_path = auth_app_sign_up_check_telephone_passcode_path(ri: "jp")

      assert_equal passcode_path, props.fetch("success_redirect_url")
      assert_equal cycle.checkpoint_version, props.fetch("checkpoint_version")
    end

    test "POST begin returns challenge and options" do
      verify_telephone_via_otp!

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      assert_response :ok
      json = response.parsed_body

      assert_predicate json["challenge_id"], :present?
      assert_kind_of Hash, json["options"]
      assert_predicate json.dig("options", "challenge"), :present?
      assert_predicate json.dig("options", "user", "id"), :present?

      challenge = session[:passkey_challenges][json["challenge_id"]]

      assert_predicate challenge, :present?
      assert_equal "registration", challenge["purpose"]
    end

    test "POST begin excludes existing passkey credentials" do
      telephone = verify_telephone_via_otp!
      telephone.user.client_passkeys.create!(
        webauthn_id: "existing_webauthn_id",
        public_key: "existing_public_key",
        sign_count: 0,
      )

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      assert_response :ok
      excluded_ids = response.parsed_body.dig("options", "excludeCredentials").to_a.pluck("id")

      assert_includes excluded_ids, "existing_webauthn_id"
    end

    test "POST begin returns not found when registration session is missing" do
      post auth_app_sign_up_check_telephone_passkey_url, as: :json

      assert_response :not_found
    end

    test "GET show returns not found when registration session is missing" do
      get auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      assert_response :not_found
    end

    test "POST begin rejects unverified telephone registration" do
      telephone = verify_telephone_via_otp!
      telephone.update!(user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED)

      post auth_app_sign_up_check_telephone_passkey_url, as: :json

      assert_response :unprocessable_content
      assert_predicate response.parsed_body["error"], :present?
    end

    test "GET show redirects unverified telephone registration to edit" do
      telephone = verify_telephone_via_otp!
      telephone.update!(user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED)

      get auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      assert_redirected_to auth_app_sign_up_check_telephone_otp_path(ri: "jp")
    end

    test "POST create saves passkey and returns checkpoint redirect on success" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "new_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "new_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          assert_difference("ClientPasskey.count", 1) do
            patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
              challenge_id: challenge_id,
              checkpoint_version: cycle.checkpoint_version,
              credential: {
                id: "new_webauthn_id",
                response: { clientDataJSON: "e30=", attestationObject: "e30=" },
              },
              description: "Signup Passkey",
            }
          end
        end
      end

      assert_response :created
      assert_equal "ok", response.parsed_body["status"]
      assert_equal auth_app_sign_up_check_telephone_passcode_path(ri: "jp"), response.parsed_body["redirect_url"]
      assert_predicate session[:user_telephone_registration], :present?
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      assert cycle.reload.requirement_cleared?(:passkey)
      assert_not cycle.requirement_cleared?(:birthdate)
      assert_not cycle.requirement_cleared?(:passcode)
    end

    test "POST create requires challenge id" do
      verify_telephone_via_otp!
      cycle = current_sign_up_flow(registration_telephone)

      patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
        checkpoint_version: cycle.checkpoint_version,
        credential: {
          id: "new_webauthn_id",
          response: { clientDataJSON: "e30=", attestationObject: "e30=" },
        },
      }

      assert_response :bad_request
      assert_predicate response.parsed_body["error"], :present?
    end

    test "POST create does not establish login session before finalization" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "login_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "login_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "login_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "login_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Login Passkey",
          }
        end
      end

      assert_response :created

      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      get auth_app_root_url(ri: "jp", host: auth_host)

      assert_response :success
      assert_no_match(
        /#{Regexp.escape(::AuthenticationClient::ACCESS_COOKIE_KEY.to_s)}=/,
        response.headers["Set-Cookie"].to_s,
      )
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
    end

    test "POST create respects pt parameter for redirect" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "rt_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "rt_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      pt = "/welcome?ri=jp"

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "rt_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
            pt: pt,
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "rt_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "PT Passkey",
          }
        end
      end

      assert_response :created
      assert_equal auth_app_sign_up_check_telephone_passcode_path(ri: "jp"),
                   response.parsed_body["redirect_url"]
    end

    test "POST create does not create signup or login audit before finalization" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "audit_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "audit_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "audit_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          assert_no_difference("ClientChronicle.count") do
            patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
              challenge_id: challenge_id,
              checkpoint_version: cycle.checkpoint_version,
              credential: {
                id: "audit_webauthn_id",
                response: { clientDataJSON: "e30=", attestationObject: "e30=" },
              },
              description: "Audit Passkey",
            }
          end
        end
      end
    end

    test "POST create returns unprocessable on verifier error" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      Webauthn::RegistrationVerifier.stub(
        :verify!, ->(**) { raise WebAuthn::Error, "verification failed" },
      ) do
        assert_no_difference("ClientPasskey.count") do
          patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "new_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
          }
        end
      end

      assert_response :unprocessable_content
      assert_predicate response.parsed_body["error"], :present?
    end

    test "telephone sign up finalizes and establishes login after otp passkey passcode and birthdate" do
      telephone, cycle = advance_telephone_signup_to_birthdate_checkpoint!("finalize")

      patch auth_app_sign_up_check_telephone_birthdate_url(ri: "jp"), params: {
        requirement: "birthdate",
        birthdate: "2000-01-01",
        checkpoint_version: cycle.reload.checkpoint_version,
      }

      assert_response :redirect

      user = telephone.user.reload

      assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
      assert ClientToken.exists?(user_id: user.id)
    end

    test "telephone sign up rejects one day before the sixteenth birthday with sixteen birthday copy" do
      travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
        telephone, cycle = advance_telephone_signup_to_birthdate_checkpoint!("under16")

        patch auth_app_sign_up_check_telephone_birthdate_url(ri: "jp"), params: {
          requirement: "birthdate",
          birthdate: "2010-06-26",
          checkpoint_version: cycle.reload.checkpoint_version,
        }

        assert_response :success
        assert_includes response.body, "16歳の誕生日"
        assert_not_includes response.body, "13歳の誕生日"
        assert_equal ClientSignUpFlowStatus::FAILED, cycle.reload.status_id
        assert_not cycle.requirement_cleared?(:birthdate)
        assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      end
    end

    test "telephone sign up allows the sixteenth birthday" do
      travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
        telephone, cycle = advance_telephone_signup_to_birthdate_checkpoint!("sixteen")

        patch auth_app_sign_up_check_telephone_birthdate_url(ri: "jp"), params: {
          requirement: "birthdate",
          birthdate: "2010-06-25",
          checkpoint_version: cycle.reload.checkpoint_version,
        }

        assert_response :redirect
        assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
        assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      end
    end

    test "sign-in failure after durable sign-up does not delete completed account data" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "failure_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "failure_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "failure_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "failure_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Failure Test Passkey",
          }
        end
      end

      assert_response :created

      patch auth_app_sign_up_check_telephone_passcode_url(ri: "jp"), params: {
        checkpoint_version: cycle.reload.checkpoint_version,
      }

      assert cycle.reload.requirement_cleared?(:passcode)

      # Simulate sign-in boundary failure by marking the actor as RESERVED before finalization.
      # SignAppUpTelephoneRegistrationFinalizer skips the VERIFIED_WITH_SIGN_UP status upgrade
      # when the actor is not UNVERIFIED_WITH_SIGN_UP, and then login_allowed? returns false
      # for RESERVED actors, triggering the sign_in_handoff_failed path.
      user = telephone.user
      user.update_column(:status_id, ClientStatus::RESERVED)

      get auth_app_sign_up_check_telephone_birthdate_url(ri: "jp")

      assert_response :success

      patch auth_app_sign_up_check_telephone_birthdate_url(ri: "jp"), params: {
        requirement: "birthdate",
        birthdate: "2000-01-01",
        checkpoint_version: cycle.reload.checkpoint_version,
      }

      # Finalization ran but sign-in handoff failed: 422 is the expected response.
      assert_response :unprocessable_content

      user.reload

      # The actor must not be deleted after finalization, even though sign-in failed.
      assert_not_nil Client.find_by(id: user.id),
                     "actor must not be deleted after a sign-in failure post-finalization"
      # No token should be issued since sign-in failed.
      assert_not ClientToken.exists?(user_id: user.id)
      # Ticket is finalized but NOT completed (handoff failed, complete event never ran).
      assert_not_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    end

    test "POST create rejects stale checkpoint version before creating passkey" do
      verify_telephone_via_otp!

      post auth_app_sign_up_check_telephone_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "stale_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "stale_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_no_difference("ClientPasskey.count") do
          patch auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: 999,
            credential: {
              id: "stale_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Stale Passkey",
          }
        end
      end

      assert_response :conflict
      assert_equal "stale_checkpoint", response.parsed_body["error"]
    end

    private

    def verify_telephone_via_otp!
      post(
        auth_app_sign_up_telephone_url,
        params: {
          user_telephone: {
            raw_number: "+1234567890",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        },
      )

      telephone = registration_telephone
      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      patch(
        auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
          user_telephone: { pass_code: code },
        },
      )

      assert_redirected_to auth_app_sign_up_guard_telephone_url(ri: "jp")

      get(auth_app_sign_up_guard_telephone_url(ri: "jp"))

      assert_redirected_to auth_app_sign_up_check_telephone_passkey_url(ri: "jp")

      get(auth_app_sign_up_check_telephone_passkey_url(ri: "jp"))

      assert_response :success

      telephone.reload
    end

    def current_sign_up_flow(telephone)
      ClientSignUpFlow.order(:id).find_by!(
        principal_id: telephone.user_id,
        pending_contact_type: "telephone",
        pending_contact_id: telephone.id,
      )
    end

    def advance_telephone_signup_to_birthdate_checkpoint!(webauthn_suffix)
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post(auth_app_sign_up_check_telephone_passkey_url(ri: "jp"))
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "#{webauthn_suffix}_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "#{webauthn_suffix}_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      registration_context = Struct.new(
        :webauthn_id, :sign_count, :aaguid, :transports,
        :backup_eligible, :backup_state, :authenticator_attachment,
      ).new(
        "#{webauthn_suffix}_webauthn_id", 1,
      )
      Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
        WebAuthn::Credential.stub(:from_create, mock_credential) do
          patch(
            auth_app_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
              challenge_id: challenge_id,
              checkpoint_version: cycle.checkpoint_version,
              credential: {
                id: "#{webauthn_suffix}_webauthn_id",
                response: { clientDataJSON: "e30=", attestationObject: "e30=" },
              },
              description: "Signup Passkey",
            },
          )
        end
      end

      assert_response :created
      assert_equal auth_app_sign_up_check_telephone_passcode_path(ri: "jp"),
                   response.parsed_body["redirect_url"]
      assert cycle.reload.requirement_cleared?(:passkey)

      patch(
        auth_app_sign_up_check_telephone_passcode_url(ri: "jp"), params: {
          checkpoint_version: cycle.reload.checkpoint_version,
        },
      )

      assert_redirected_to auth_app_sign_up_check_telephone_birthdate_url(ri: "jp")
      assert cycle.reload.requirement_cleared?(:passcode)

      get(auth_app_sign_up_check_telephone_birthdate_url(ri: "jp"))

      assert_response :success

      [telephone, cycle]
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      ClientTelephone.find_by!(public_id: public_id)
    end
  end
end
