# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @active_token = @token
    ClientEmail.create!(
      user: @user,
      address: "verified-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "new sends otp and redirects to edit" do
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
        grant = signed_step_up_grant_for(
          actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
        )
        get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
            headers: @headers

        assert_response :success

        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect

        assert_match %r{/verification/emails/.+/edit}, response.location

        follow_redirect!(headers: @headers)

        assert_response :success
        assert_equal "auth/app/verification/emails/edit", inertia_component
        assert_equal I18n.t("sign.app.verification.edit.title"), inertia_props.fetch("heading")
        assert_equal I18n.t("sign.app.verification.edit.code_label"), inertia_form.fetch("code_label")
        assert_equal I18n.t("sign.app.verification.edit.code_placeholder"), inertia_form.fetch("code_placeholder")
        assert_equal I18n.t("sign.app.verification.edit.submit"), inertia_form.fetch("submit_label")
        assert_includes inertia_props.fetch("description"), "メールアドレス"
        assert_equal I18n.t("sign.app.verification.edit.email_delivery_help"), inertia_props.fetch("delivery_help")
      end
    end
  end

  # An account with no verified address cannot receive an email code. Every entry
  # point into the email step-up has to say so on the page instead of advancing to
  # a code form that could never be satisfied.
  test "new re-renders the email step-up page when the account has no verified address" do
    @user.client_emails.destroy_all
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      grant = signed_step_up_grant_for(
        actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
      )
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
          headers: @headers

      assert_response :success

      get new_auth_app_verification_email_url(ri: "jp"), headers: @headers
    end

    assert_response :unprocessable_content
    assert_equal "auth/app/verification/emails/new", inertia_component
    assert_includes inertia_props.fetch("errors"),
                    I18n.t("sign.app.verification.errors.email_not_verified")
  end

  test "edit returns to the method chooser when the addressed email is gone" do
    email = @user.client_emails.last
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      grant = signed_step_up_grant_for(
        actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
      )
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
          headers: @headers

      assert_response :success
      @user.client_emails.destroy_all

      get edit_auth_app_verification_email_url(email.public_id, ri: "jp"), headers: @headers
    end

    assert_response :redirect
    assert_includes response.location, "/verification"
  end

  test "email selection from verification page reaches otp entry page" do
    return_to = "/settings/emails/#{@user.client_emails.last.public_id}/edit?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_equal "auth/app/verifications/show", inertia_component
      assert_match(
        %r{/verification/emails/new\?pt=.*&ri=jp&scope=settings_email},
        inertia_props.fetch("methods").map { |method| method.fetch("href") }.join(" "),
      )

      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end

      assert_response :redirect
      follow_redirect!(headers: @headers)

      assert_response :success
      assert_equal "auth/app/verification/emails/edit", inertia_component
      assert_equal I18n.t("sign.app.verification.edit.title"), inertia_props.fetch("heading")
      assert_equal I18n.t("sign.app.verification.edit.code_label"), inertia_form.fetch("code_label")
      assert_equal I18n.t("sign.app.verification.edit.code_placeholder"), inertia_form.fetch("code_placeholder")
      assert_equal I18n.t("sign.app.verification.edit.submit"), inertia_form.fetch("submit_label")
      assert_includes inertia_props.fetch("description"), "メールアドレス"
    end
  end

  test "new enqueues otp email while request is on readonly role" do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    return_to = "/settings/emails/#{@user.client_emails.last.public_id}/edit?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_difference -> { SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").count }, 1 do
        ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
          get(
            new_auth_app_verification_email_url(
              ri: "jp",
              scope: "settings_email",
              pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
            ), headers: @headers,
          )
        end
      end
    end

    assert_response :redirect
  ensure
    ActiveJob::Base.queue_adapter = @previous_adapter if @previous_adapter
  end

  test "new sends otp for email verified during signup" do
    @user.client_emails.update_all(user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP)
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      get new_auth_app_verification_email_url(
        ri: "jp",
        scope: "settings_email",
        pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
      ), headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new restores step_up session from scope and pt query parameters" do
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new resends otp when otp session is already active" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success
    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end
    end

    assert_response :redirect
    assert_match %r{/verification/emails/.+/edit}, response.location
  end

  test "edit sends otp when nonce is valid but otp session is missing" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)

    StepUpAvailableMethods.stub(:call, []) do
      with_email_nonce_stub(true) do
        assert_enqueued_emails 1 do
          get edit_auth_app_verification_email_url(nonce, ri: "jp"), headers: @headers
        end
      end
    end

    assert_response :success
    assert_equal "auth/app/verification/emails/edit", inertia_component
    assert_equal I18n.t("sign.app.verification.edit.code_label"), inertia_form.fetch("code_label")
  end

  test "edit does not resend otp when otp session is already active" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    StepUpAvailableMethods.stub(:call, []) do
      assert_enqueued_emails 0 do
        get edit_auth_app_verification_email_url(nonce, ri: "jp"), headers: @headers
      end
    end

    assert_response :success
    assert_equal "auth/app/verification/emails/edit", inertia_component
    assert_equal I18n.t("sign.app.verification.edit.code_label"), inertia_form.fetch("code_label")
  end

  test "update verifies otp and redirects to return_to" do
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
        grant = signed_step_up_grant_for(
          actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
        )
        get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
            headers: @headers

        assert_response :success

        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

        with_email_nonce_stub(true) do
          with_verify_email_otp_stub(true) do
            patch auth_app_verification_email_url(nonce, ri: "jp"),
                  params: { verification: { code: "123456" } },
                  headers: @headers

            assert_response :success
            assert_includes response.body, "step-up-completion-form"
            assert_nil @token.reload.step_up_session
            # sign no longer writes freshness; acme commits it on completion (asserted below).

            submit_step_up_completion_if_present!(
              host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
              headers: as_user_headers(
                @user,
                host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"),
                session_public_id: @token.public_id,
              ),
            )

            assert_response :redirect
            assert_predicate(
              @token.reload.last_step_up_at,
              :present?,
              "completion redirected to #{response.location.inspect}",
            )
            assert_equal "settings_email", @token.last_step_up_scope
          end
        end
      end
    end
  end

  test "email otp endpoint rejects a method excluded by the signed step-up grant" do
    return_to = "/settings/emails?ri=jp"
    grant = signed_step_up_grant_for(
      actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app", methods: [:passkey],
    )

    get auth_app_verification_url(
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
      ri: "jp",
      step_up_ceremony_grant: grant,
    ), headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_match %r{/verification/setup/new\?pt=}, response.location
  end

  test "email otp update rejects a direct request when the method is unavailable" do
    return_to = "/settings/emails?ri=jp"

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      get auth_app_verification_url(
        scope: "settings_email",
        pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ri: "jp",
      ), headers: @headers

      get new_auth_app_verification_email_url(ri: "jp"), headers: @headers
    end

    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    StepUpAvailableMethods.stub(:call, []) do
      patch auth_app_verification_email_url(nonce, ri: "jp"),
            params: { verification: { code: "123456" } },
            headers: @headers
    end

    assert_response :redirect
    assert_equal auth_app_verification_url(ri: "jp"), response.location
  end

  test "invalid otp keeps back link from step_up session when request params are missing" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    patch auth_app_verification_email_url(nonce, ri: "jp"),
          params: { verification: { code: "000000" } },
          headers: @headers

    assert_response :unprocessable_content
    assert_equal "auth/app/verification/emails/edit", inertia_component
    back = inertia_props.fetch("back")

    assert_equal I18n.t("sign.app.verification.edit.back"), back.fetch("label")
    assert_includes back.fetch("href"), "/verification?"
    assert_includes back.fetch("href"), "ri=jp"
    assert_includes back.fetch("href"), "scope=settings_email"
    assert_includes back.fetch("href"), "pt="
    assert_predicate inertia_form.fetch("pt"), :present?

    failed_step_up = ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.where(
        event_id: ClientChronicleEvent::STEP_UP_FAILED,
        subject_id: @user.id.to_s,
        subject_type: "Client",
      ).order(occurred_at: :desc).first
    end
    assert_predicate failed_step_up, :present?
    assert_empty failed_step_up.context
    refute_includes failed_step_up.context.to_s, "000000"
  end

  test "resend sends a new otp and returns to edit page" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    assert_enqueued_emails 1 do
      post auth_app_verification_email_redelivery_url(
        nonce,
        ri: "jp",
        scope: "settings_email",
        pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
      ), headers: @headers
    end

    assert_response :redirect
    assert_match %r{/verification/emails/#{Regexp.escape(nonce)}/edit\?pt=.*&ri=jp&scope=settings_email},
                 response.location
  end

  test "resend is rate limited" do
    return_to = "/settings/emails?ri=jp"

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    assert_enqueued_emails 1 do
      post auth_app_verification_email_redelivery_url(nonce, ri: "jp"), headers: @headers
    end

    assert_enqueued_emails 0 do
      post auth_app_verification_email_redelivery_url(nonce, ri: "jp"), headers: @headers
    end

    assert_response :redirect
  end

  test "settings email management requires sign step up" do
    stale_token = ClientToken.create!(user_id: @user.id, created_at: 20.minutes.ago, updated_at: 20.minutes.ago)
    @headers.merge!("X-TEST-SESSION-PUBLIC-ID" => stale_token.public_id)
    email = @user.client_emails.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES).first

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

      get edit_base_app_identity_email_path(email.public_id, ri: "jp"),
          headers: as_user_headers(
            @user, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
                   session_public_id: stale_token.public_id,
          )

      assert_response :success
      # The destination page is a base/app Inertia page; its form action is the same contract the
      # assert_select above checked, read from the props instead of the markup.
      assert_equal(
        base_app_identity_email_path(email.public_id, ri: "jp"),
        inertia_props.fetch("form").fetch("action"),
      )
    end
  end

  test "create restores step_up session only when scope and return_to are present" do
    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post auth_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: "", pt: "" } },
             headers: @headers

        assert_response :redirect
        assert_redirected_to auth_app_settings_url(ri: "jp")
      end

      return_to = "/settings/telephones?ri=jp"
      post auth_app_verification_emails_url(ri: "jp"),
           params: { verification: { scope: "settings_telephone",
                                     pt: signed_step_up_pt_for(
                                       return_to, surface: "app",
                                                  session_nonce: @token.public_id,
                                     ), } },
           headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  private

  def inertia_form
    inertia_props.fetch("form")
  end

  def with_verify_email_otp_stub(result)
    original_method = Auth::App::Verification::EmailsController.instance_method(:verify_email_otp!)
    Auth::App::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Auth::App::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end

  def with_email_nonce_stub(result)
    original_method = Auth::App::Verification::EmailsController.instance_method(:require_email_nonce!)
    Auth::App::Verification::EmailsController.define_method(:require_email_nonce!) { result }
    yield
  ensure
    Auth::App::Verification::EmailsController.define_method(:require_email_nonce!, original_method)
  end

  def current_step_up_session
    ClientStepUpSession.find_by!(user_token: @active_token).tap { |rs| @step_up_session_id = rs.id }
  end
  private
end

# DAMP auth header helpers for this test class.
class Auth::App::Verification::EmailsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Verification::EmailsControllerTest
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
    service = (normalized.include?("base") || normalized.include?("www.")) ? "BASE" : "SIGN"
    surface =
      if resource_type == "operator" || normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif resource_type == "visitor" || normalized.include?(".com") || normalized.include?("com.")
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
                               aal: StepUpRequirement::NO_AAL)
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
class Auth::App::Verification::EmailsControllerTest
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

class AuthAppVerificationEmailsBranchTest < ActiveSupport::TestCase
  def build_controller
    Auth::App::Verification::EmailsController.new.tap do |controller|
      controller.define_singleton_method(:render) { |**options| @rendered = options }
      controller.define_singleton_method(:redirect_to) { |*args| @redirected = args }
      controller.define_singleton_method(:new_page_props) { {} }
      controller.define_singleton_method(:edit_page_props) { {} }
      controller.define_singleton_method(:ensure_email_nonce!) { "nonce" }
      controller.define_singleton_method(:current_step_up_scope) { "scope" }
      controller.define_singleton_method(:current_step_up_pt_param) { "pt" }
      controller.define_singleton_method(:params) { { ri: "jp" } }
      controller.define_singleton_method(:auth_app_verification_emails_path) { |**| "/emails" }
      controller.define_singleton_method(:edit_auth_app_verification_email_path) { |*args, **|
        "/emails/#{args.first}/edit"
      }
    end
  end

  test "email verification actions cover guard, delivery, and invalid-code branches" do
    controller = build_controller
    controller.define_singleton_method(:require_step_up_session!) { false }

    assert_nil controller.new
    assert_nil controller.edit
    assert_nil controller.create
    assert_nil controller.update

    controller.define_singleton_method(:require_step_up_session!) { true }
    controller.define_singleton_method(:redirect_if_recent_verification_for_get!) { true }

    assert_nil controller.new
    assert_nil controller.edit
    controller.define_singleton_method(:redirect_if_recent_verification_for_get!) { false }
    controller.define_singleton_method(:redirect_if_recent_verification_for_post!) { true }

    assert_nil controller.create
    assert_nil controller.update
    controller.define_singleton_method(:redirect_if_recent_verification_for_post!) { false }

    controller.define_singleton_method(:require_method_available!) { |_method| false }

    assert_nil controller.new
    assert_nil controller.create
    controller.define_singleton_method(:require_method_available!) { |_method| true }
    controller.define_singleton_method(:send_email_otp!) { false }

    assert_nil controller.new
    assert_nil controller.create

    controller.define_singleton_method(:send_email_otp!) { true }
    controller.new

    assert_equal ["/emails/nonce/edit"], controller.instance_variable_get(:@redirected)

    controller.define_singleton_method(:require_email_nonce!) { false }

    assert_nil controller.edit
    controller.define_singleton_method(:require_email_nonce!) { true }
    controller.define_singleton_method(:email_otp_session_active?) { true }

    assert_nil controller.edit
    controller.define_singleton_method(:email_otp_session_active?) { false }
    controller.define_singleton_method(:send_email_otp!) { false }

    assert_nil controller.edit
    controller.define_singleton_method(:send_email_otp!) { true }

    assert_equal({ inertia: "auth/app/verification/emails/edit", props: {} }, controller.edit)

    controller.define_singleton_method(:require_method_available!) { |_method| true }
    controller.define_singleton_method(:verify_email_otp!) { true }
    controller.define_singleton_method(:consume_step_up_session!) { |**| @consumed = true }
    controller.update

    assert controller.instance_variable_get(:@consumed)
    controller.define_singleton_method(:verify_email_otp!) { false }
    controller.define_singleton_method(:record_failed_step_up_attempt!) { |_method| @failed = true }
    controller.update

    assert controller.instance_variable_get(:@failed)
  end
end
