# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

module Auth::App::Up
  class TelephonesControllerTest < ActionDispatch::IntegrationTest
    counts_rate_limits!
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :client_statuses, :client_telephone_statuses,
             :client_chronicle_events, :client_chronicle_levels
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      cookies["csrf_token"] = csrf_token_value
      # Mock Cloudflare Turnstile validation
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
    end

    test "should get new" do
      get new_auth_app_sign_up_telephone_url(ri: "jp")

      assert_response :success
    end

    test "new redirects to dashboard when user is already logged in" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

      get new_auth_app_sign_up_telephone_url(ri: "jp"),
          headers: as_user_headers(user, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))

      assert_response :unauthorized
      assert_equal "すでにログインしています", response.body
    end

    test "create rejects when user is already logged in" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

      assert_no_difference("ClientTelephone.count") do
        post auth_app_sign_up_telephone_url(ri: "jp"),
             params: {
               user_telephone: {
                 raw_number: "+1234567890",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: as_user_headers(user, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))
      end

      assert_response :unauthorized
      assert_equal "すでにログインしています", response.body
    end

    test "edit route uses registration session" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      get auth_app_sign_up_check_telephone_otp_url(ri: "jp")

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

    test "should create telephone and redirect to edit" do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        assert_difference("ClientTelephone.count") do
          post auth_app_sign_up_telephone_url, params: {
            client_telephone: {
              raw_number: "+1234567890",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      registration_telephone

      assert_redirected_to auth_app_sign_up_check_telephone_otp_url
      assert_not_nil session[:user_telephone_registration]
      assert_predicate session[:app_sign_up_flow_locator], :present?
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
      assert_equal "telephone", cycle.entry_method
      assert_equal registration_telephone.id, cycle.pending_contact_id
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

    test "create with existing telephone still redirects without sending or creating records" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567898",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post auth_app_sign_up_telephone_url, params: {
              user_telephone: {
                raw_number: existing_telephone.number,
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_redirected_to auth_app_sign_up_check_telephone_otp_url

      patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"),
            params: { user_telephone: { pass_code: "000000" } }

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("sign.app.registration.telephone.update.invalid_code")
    end

    test "create is refused while a verified telephone of the same number is locked out" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567801",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )
      existing_telephone.update!(locked_at: 10.minutes.from_now)

      assert_no_difference("ClientTelephone.count") do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: existing_telephone.number, confirm_policy: "1", confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :too_many_requests
      assert_equal I18n.t("sign.app.registration.email.create.otp_resend_too_soon"), response.body
    end

    test "create is refused while a pending sign-up telephone of the same number is locked out" do
      user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567802",
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )
      existing_telephone.update!(locked_at: 10.minutes.from_now)

      assert_no_difference("ClientTelephone.count") do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: existing_telephone.number, confirm_policy: "1", confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :too_many_requests
    end

    test "create is refused when the creator reports the number rate limited under its own lock" do
      rate_limited = SignAppUpTelephoneSignupCreator::Result.new(
        status: :rate_limited, telephone: ClientTelephone.new, session_payload: nil,
      )

      SignAppUpTelephoneSignupCreator.stub(:call, rate_limited) do
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

      SignAppUpTelephoneSignupCreator.stub(:call, raiser) do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: { raw_number: "+1234567804", confirm_policy: "1", confirm_using_mfa: "1" },
          "cf-turnstile-response": "test",
        }
      end

      assert_response :unprocessable_content
    end

    test "create shows identical user-facing response for existing and new telephones" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+819012345678",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: existing_telephone.number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      existing_location = response.location

      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+819012300000",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      assert_match(%r{/up/check/telephone/otp}, response.location)
      assert_match(%r{/up/check/telephone/otp}, existing_location)
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
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      # 2. Retrieve OTP from DB
      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      # 3. Submit OTP
      patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        client_telephone: { pass_code: code },
      }

      assert_redirected_to auth_app_sign_up_guard_telephone_url(regional_defaults)

      telephone.reload
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      # OTP should be cleared (-infinity)
      expires = telephone.otp_expires_at

      assert expires.nil? || expires.to_s == "-infinity" || (expires.is_a?(Float) && expires == -Float::INFINITY)
      assert_equal [nil, nil], [telephone.confirm_policy, telephone.confirm_using_mfa]
      assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.status_id
      assert_equal "checkpoint", cycle.step
    end

    test "otp success keeps telephone pending and records cycle proof in session" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      assert_no_difference("ClientToken.count") do
        patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
          client_telephone: { pass_code: code },
        }
      end

      assert_redirected_to auth_app_sign_up_guard_telephone_url(regional_defaults)

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
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567891",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user

      ClientPasskey.create!(
        user: user,
        webauthn_id: Base64.urlsafe_encode64("preexisting_passkey", padding: false),
        public_key: "public_key",
        sign_count: 0,
        description: "Existing Passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      # A pre-existing passkey row must not let OTP success short-circuit into
      # a signed-in session: telephone sign-up always routes through the
      # passkey step and the durable finalizer.
      assert_no_difference("ClientToken.count") do
        patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
          client_telephone: { pass_code: code },
        }
      end

      assert_redirected_to auth_app_sign_up_guard_telephone_url(regional_defaults)
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.reload.status_id

      get auth_app_sign_up_guard_telephone_url(regional_defaults)

      assert_redirected_to auth_app_sign_up_check_telephone_passkey_url(regional_defaults)

      get auth_app_sign_up_check_telephone_passkey_url(regional_defaults)

      assert_response :success
      assert_equal "auth/app/sign/up/checkpoint/passkeys/new", inertia_component
      assert_equal auth_app_sign_up_check_telephone_passkey_path(regional_defaults),
                   inertia_props.fetch("begin_url")
    end

    test "abandoned telephone sign up after otp can re-register the same number" do
      number = "+1234567892"

      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      abandoned_user_id = telephone.user_id

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        client_telephone: { pass_code: code },
      }
      # Cycle abandoned here: OTP passed but passkey never completed.

      # Past the re-registration overwrite window the same number must be
      # registrable again -- the abandoned pending row/user is cleaned up.
      travel(CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second) do
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: number,
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      assert_redirected_to auth_app_sign_up_check_telephone_otp_url
      new_telephone = registration_telephone

      assert_not_equal telephone.id, new_telephone.id
      assert_not ClientTelephone.exists?(telephone.id)
      assert_not Client.exists?(abandoned_user_id)
      assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
                   new_telephone.user_telephone_status_id
    end

    test "should reject blank pass code" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        client_telephone: { pass_code: "" },
      }

      assert_response :unprocessable_content
    end

    test "should lockout after max failed otp attempts" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567893",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      completed_requirements = cycle.completed_requirements.deep_dup

      Prosopite.pause do
        Telephone::MAX_OTP_ATTEMPTS.times do
          patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
            client_telephone: { pass_code: "000000" },
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

    test "should cleanup existing unverified telephones on create" do
      # Create first registration
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567894",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
        # Create second registration with the same number
        post auth_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: "+1234567894",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      # First telephone and its pending user should be cleaned up
      assert_not ClientTelephone.exists?(first_telephone.id)
      assert_not Client.exists?(first_user.id)
    end

    test "create rejects duplicate unverified telephone inside overwrite window" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567895",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      assert_no_difference("ClientTelephone.count") do
        assert_no_difference("Client.count") do
          post auth_app_sign_up_telephone_url, params: {
            user_telephone: {
              raw_number: "+1234567895",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :too_many_requests
      assert ClientTelephone.exists?(first_telephone.id)
      assert Client.exists?(first_user.id)
    end

    test "resend sends code for active registration session" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_redirected_to auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      assert_predicate session[:user_telephone_otp_last_sent_at], :present?
    end

    test "resend without a registration session restarts sign-up" do
      assert_no_difference("ClientTelephone.count") do
        assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
          post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
      end

      assert_response :see_other
      assert_redirected_to auth_app_sign_up_path(ri: "jp")
    end

    test "resend rate limits repeated requests" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      end
      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_response :too_many_requests
      assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
    end

    test "resend cooldown is 30 seconds" do
      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567892",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect

      post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      sent_at = session[:user_telephone_otp_last_sent_at]
      telephone = registration_telephone
      otp_data = telephone.get_otp
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      completed_requirements = cycle.completed_requirements.deep_dup

      assert_predicate sent_at, :present?
      assert_redirected_to auth_app_sign_up_check_telephone_otp_url(ri: "jp")

      # Anchored to when the code was actually sent, not to now. `travel` moves
      # from the current moment, so on a slow run the setup requests alone can
      # push the gap past the cooldown and the case silently inverts.
      travel_to Time.zone.at(sent_at) + 29.seconds do
        assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
          post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
        assert_response :too_many_requests
        assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
        assert_equal sent_at, session[:user_telephone_otp_last_sent_at]
        assert_equal otp_data, telephone.reload.get_otp
        assert_equal completed_requirements, cycle.reload.completed_requirements
      end

      travel_to Time.zone.at(sent_at) + 31.seconds do
        assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
          post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
        assert_redirected_to auth_app_sign_up_check_telephone_otp_url(ri: "jp")
        assert_operator session[:user_telephone_otp_last_sent_at], :>, sent_at
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
      EnforcementCaseApplyOperation.call(enforcement_case: the_case)

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

    test "sign-up with an already verified telephone answers the otp page without creating records" do
      owner = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing = owner.client_telephones.create!(
        raw_number: "+819012388001",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      )

      assert_no_difference("Client.count") do
        assert_no_difference("ClientTelephone.count") do
          post auth_app_sign_up_telephone_url(ri: "jp"), params: {
            user_telephone: {
              raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :redirect

      get auth_app_sign_up_check_telephone_otp_url(ri: "jp")

      assert_response :success
      assert_not_includes response.body, I18n.t("errors.messages.taken")
    end

    test "resending the code for an already verified telephone answers without creating records" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567811",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: existing_telephone.number, confirm_policy: "1", confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect

      assert_no_difference("ClientTelephone.count") do
        post auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_response :redirect
      assert_includes response.location, "/sign/up/check/telephone/otp"

      # The second resend lands inside the send cooldown and must be refused with the
      # same message a real pending registration gets, so the two cannot be told apart.
      post auth_app_sign_up_check_telephone_otp_url(ri: "jp")

      assert_response :too_many_requests
      assert_equal I18n.t("sign.app.registration.email.create.otp_resend_too_soon"), response.body
    end

    test "the code page for an already verified telephone stops answering once the window closes" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567812",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      post auth_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: existing_telephone.number, confirm_policy: "1", confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect

      travel CommonOtp::OTP_EXPIRATION_MINUTES.minutes + 1.minute do
        get auth_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_response :redirect
      assert_includes response.location, "/sign/up/telephone"
    end

    test "a code submitted against an already verified telephone never starts an account" do
      owner = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing = owner.client_telephones.create!(
        raw_number: "+819012388002",
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      )
      post auth_app_sign_up_telephone_url(ri: "jp"), params: {
        user_telephone: { raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response": "test",
      }
      get auth_app_sign_up_check_telephone_otp_url(ri: "jp")

      assert_no_difference("Client.count") do
        patch auth_app_sign_up_check_telephone_otp_url(ri: "jp"),
              params: { user_telephone: { pass_code: "123456" } }
      end

      assert_response :unprocessable_content
      assert_equal ClientTelephoneStatus::VERIFIED, existing.reload.user_telephone_status_id
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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
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

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
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
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
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
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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
