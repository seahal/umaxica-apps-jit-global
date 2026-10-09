# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  include AuthCeremonyEntryHelper
  include ActiveJob::TestHelper

  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    reference_now = ClientSignInFlow.database_now
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = reference_now
        state.updated_at = reference_now
      end
    end
    ClientSignOutFlowKind.ensure_defaults!
    ClientSignOutFlowStatus.ensure_defaults!
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    ClientToken.where(user_id: clients(:one).id).delete_all
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "revoking one active session at the limit issues the new session and continues sign-in" do
    user = clients(:one)
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
      ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base =
      begin
        fv5072 = email
        fv5058 = open_session
        fv5064 = open_session
        fv5058.host!(@base_host)
        fv5058.https!
        fv5058.get("/sign", params: { ri: "jp" })
        fv5086 = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
        fv5076 = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "app",
          intent: "sign_in",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
          nonce_digest: ClientSignInFlow.digest_nonce(fv5086),
        )
        SignInCycleLocator.new(fv5058.session, surface: "app").issue!(
          fv5076.transaction,
          nonce: fv5086,
        )
        fv5083 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5084 = ActionDispatch::Cookies::CookieJar.build(
          fv5058.request,
          fv5058.request.cookies,
        )
        fv5085 = fv5058.session.to_hash.stringify_keys
        fv5084.encrypted[fv5083] =
          { value: fv5085 }
        fv5082 = fv5084[fv5083]
        fv5058.cookies.delete(fv5083)
        fv5058.cookies.merge( # rubocop:disable Lint/Void
          "#{fv5083}=#{Rack::Utils.escape(fv5082)}",
          URI.parse("https://#{@base_host}/"),
        )
        fv5081 = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "app", reference: fv5076.reference,
        )
        _, fv5077 =
          begin
            fv5080 = fv5081
            fv5079, fv5078 = fv5080.class.auth_admission_session_class.issue!
            fv5080.attach_auth_session!(
              auth_session: fv5079,
              confirmation_ref: SecureRandom.uuid,
            )
            fv5080.confirm_base!(
              base_token: nil,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5080.class.auth_admission_surface_name,
                entry_ref: fv5080.entry_ref,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            [fv5079,
             fv5078,]
          end
        fv5064.host!(@host)
        fv5064.https!
        fv5065 = {
          "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
        }
        fv5064.cookies.merge( # rubocop:disable Lint/Void
          "auth_sid=#{Rack::Utils.escape(fv5077)}",
          URI.parse("https://#{@host}/"),
        )
        fv5064.get(
          auth_app_sign_in_path(ri: "jp"),
          params: { entry_ref: fv5076.reference },
          headers: fv5065,
        )
        fv5075 = Nokogiri::HTML(fv5064.response.body).at_css("form")
        fv5074 =
          fv5075.css("input[type='hidden']").to_h do |fv5062|
            [fv5062["name"],
             fv5062["value"],]
          end
        fv5073 = fv5075.at_css('input[name="authenticity_token"]')["value"]
        fv5064.post(
          fv5075["action"],
          params: fv5074.merge("authenticity_token" => fv5073),
          headers: fv5065,
        )
        clear_enqueued_jobs
        OtpEmailNotifierRollout.stub(:enabled?, true) do
          fv5064.post(
            auth_app_sign_in_email_path(ri: "jp"),
            params: { :user_email => { address: fv5072.address },
                      "cf-turnstile-response" => "t", },
            headers: fv5065,
          )
        end

        assert_equal 302, fv5064.response.status
        fv5070 =
          enqueued_jobs.find { |fv5071|
            fv5071.fetch(:job) == OtpNotifierEmailDeliveryJob
          }

        assert_not_nil fv5070
        fv5069 = ActiveJob::Arguments.deserialize(fv5070.fetch(:args)).last.fetch(:params).symbolize_keys
        fv5068 = OutboundSensitivePayload.decrypt_email_otp(fv5069.fetch(:encrypted_hotp_token))
        fv5064.patch(
          auth_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: fv5068 },
                    "cf-turnstile-response" => "t", },
          headers: fv5065,
        )
        fv5064.follow_redirect! if fv5064.response.redirect?
        fv5064.follow_redirect! if fv5064.response.redirect?
        fv5067 = Nokogiri::HTML(fv5064.response.body).at_css("form")
        fv5066 = fv5067.at_css('input[name="authenticity_token"]')["value"]
        fv5064.post(
          auth_app_sign_handoff_path(ri: "jp"),
          params: {
            authenticity_token: fv5066,
            ri: "jp",
          }, headers: fv5065,
        )

        assert_equal 303, fv5064.response.status
        fv5063 = URI.parse(fv5064.response.location)
        fv5058.host!(@base_host)
        fv5058.https!
        fv5059 = {
          "Host" => @base_host,
          "Origin" => "https://#{@base_host}",
          "Sec-Fetch-Site" => "same-site",
        }
        fv5058.get(
          fv5063.request_uri,
          headers: fv5059,
        )

        assert_equal 200, fv5058.response.status
        fv5061 = Nokogiri::HTML(fv5058.response.body).at_css("form")
        fv5060 =
          fv5061.css("input[name]").to_h { |fv5062|
            [fv5062["name"],
             fv5062["value"],]
          }
        fv5058.post(
          fv5061["action"],
          params: fv5060,
          headers: fv5059,
        )
        fv5058.follow_redirect! if fv5058.response.redirect?
        fv5058
      end

    assert_equal 200, base.response.status
    assert_equal "base/app/sign/in/limitations/show", base.inertia_component
    items = base.inertia_props.fetch("sessions")

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, items.size
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first
    resolution = ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    assert_predicate cycle, :sign_in_session_issuance_pending?
    assert_predicate resolution, :open?

    selected = SessionLimitResolutionTokenRef.find_client_token(items.first.fetch("session_ref"))
    base.patch(base_app_sign_in_limitation_path(ri: "jp"), params: { session_ref: items.first.fetch("session_ref") })

    assert_equal 303, base.response.status
    assert_not_equal base_app_sign_in_limitation_path(ri: "jp"), base.response.location
    assert_predicate selected.reload, :revoked?

    cycle.reload

    assert_predicate cycle, :sign_in_completed?
    assert_predicate cycle.token_id, :present?
    assert_predicate base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
  end

  test "submitting the session limit form without a selection keeps the limit and explains why" do
    user = clients(:one)
    ClientToken::MAX_SESSIONS_PER_USER.times do
      ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base =
      begin
        fv5043 = email
        fv5029 = open_session
        fv5035 = open_session
        fv5029.host!(@base_host)
        fv5029.https!
        fv5029.get("/sign", params: { ri: "jp" })
        fv5057 = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
        fv5047 = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "app",
          intent: "sign_in",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
          nonce_digest: ClientSignInFlow.digest_nonce(fv5057),
        )
        SignInCycleLocator.new(fv5029.session, surface: "app").issue!(
          fv5047.transaction,
          nonce: fv5057,
        )
        fv5054 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5055 = ActionDispatch::Cookies::CookieJar.build(
          fv5029.request,
          fv5029.request.cookies,
        )
        fv5056 = fv5029.session.to_hash.stringify_keys
        fv5055.encrypted[fv5054] =
          { value: fv5056 }
        fv5053 = fv5055[fv5054]
        fv5029.cookies.delete(fv5054)
        fv5029.cookies.merge( # rubocop:disable Lint/Void
          "#{fv5054}=#{Rack::Utils.escape(fv5053)}",
          URI.parse("https://#{@base_host}/"),
        )
        fv5052 = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "app", reference: fv5047.reference,
        )
        _, fv5048 =
          begin
            fv5051 = fv5052
            fv5050, fv5049 = fv5051.class.auth_admission_session_class.issue!
            fv5051.attach_auth_session!(
              auth_session: fv5050,
              confirmation_ref: SecureRandom.uuid,
            )
            fv5051.confirm_base!(
              base_token: nil,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5051.class.auth_admission_surface_name,
                entry_ref: fv5051.entry_ref,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            [fv5050,
             fv5049,]
          end
        fv5035.host!(@host)
        fv5035.https!
        fv5036 = {
          "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
        }
        fv5035.cookies.merge( # rubocop:disable Lint/Void
          "auth_sid=#{Rack::Utils.escape(fv5048)}",
          URI.parse("https://#{@host}/"),
        )
        fv5035.get(
          auth_app_sign_in_path(ri: "jp"),
          params: { entry_ref: fv5047.reference },
          headers: fv5036,
        )
        fv5046 = Nokogiri::HTML(fv5035.response.body).at_css("form")
        fv5045 =
          fv5046.css("input[type='hidden']").to_h do |fv5033|
            [fv5033["name"],
             fv5033["value"],]
          end
        fv5044 = fv5046.at_css('input[name="authenticity_token"]')["value"]
        fv5035.post(
          fv5046["action"],
          params: fv5045.merge("authenticity_token" => fv5044),
          headers: fv5036,
        )
        clear_enqueued_jobs
        OtpEmailNotifierRollout.stub(:enabled?, true) do
          fv5035.post(
            auth_app_sign_in_email_path(ri: "jp"),
            params: { :user_email => { address: fv5043.address },
                      "cf-turnstile-response" => "t", },
            headers: fv5036,
          )
        end

        assert_equal 302, fv5035.response.status
        fv5041 =
          enqueued_jobs.find { |fv5042|
            fv5042.fetch(:job) == OtpNotifierEmailDeliveryJob
          }

        assert_not_nil fv5041
        fv5040 = ActiveJob::Arguments.deserialize(fv5041.fetch(:args)).last.fetch(:params).symbolize_keys
        fv5039 = OutboundSensitivePayload.decrypt_email_otp(fv5040.fetch(:encrypted_hotp_token))
        fv5035.patch(
          auth_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: fv5039 },
                    "cf-turnstile-response" => "t", },
          headers: fv5036,
        )
        fv5035.follow_redirect! if fv5035.response.redirect?
        fv5035.follow_redirect! if fv5035.response.redirect?
        fv5038 = Nokogiri::HTML(fv5035.response.body).at_css("form")
        fv5037 = fv5038.at_css('input[name="authenticity_token"]')["value"]
        fv5035.post(
          auth_app_sign_handoff_path(ri: "jp"),
          params: {
            authenticity_token: fv5037,
            ri: "jp",
          }, headers: fv5036,
        )

        assert_equal 303, fv5035.response.status
        fv5034 = URI.parse(fv5035.response.location)
        fv5029.host!(@base_host)
        fv5029.https!
        fv5030 = {
          "Host" => @base_host,
          "Origin" => "https://#{@base_host}",
          "Sec-Fetch-Site" => "same-site",
        }
        fv5029.get(
          fv5034.request_uri,
          headers: fv5030,
        )

        assert_equal 200, fv5029.response.status
        fv5032 = Nokogiri::HTML(fv5029.response.body).at_css("form")
        fv5031 =
          fv5032.css("input[name]").to_h { |fv5033|
            [fv5033["name"],
             fv5033["value"],]
          }
        fv5029.post(
          fv5032["action"],
          params: fv5031,
          headers: fv5030,
        )
        fv5029.follow_redirect! if fv5029.response.redirect?
        fv5029
      end

    base.patch(base_app_sign_in_limitation_path(ri: "jp"), params: { session_ref: "" })

    assert_equal 422, base.response.status
    assert_predicate ClientSessionLimitResolutionTransaction.order(:id).last, :open?
    assert_predicate ClientSignInFlow.where(principal_id: user.id).recent_first.first,
                     :sign_in_session_issuance_pending?
  end

  test "cancelling at the session limit fails the sign-in without issuing a session" do
    user = clients(:one)
    existing =
      Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
        ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      end
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    email.finalize_binding!
    base =
      begin
        fv5014 = email
        fv5000 = open_session
        fv5006 = open_session
        fv5000.host!(@base_host)
        fv5000.https!
        fv5000.get("/sign", params: { ri: "jp" })
        fv5028 = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
        fv5018 = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "app",
          intent: "sign_in",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
          nonce_digest: ClientSignInFlow.digest_nonce(fv5028),
        )
        SignInCycleLocator.new(fv5000.session, surface: "app").issue!(
          fv5018.transaction,
          nonce: fv5028,
        )
        fv5025 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5026 = ActionDispatch::Cookies::CookieJar.build(
          fv5000.request,
          fv5000.request.cookies,
        )
        fv5027 = fv5000.session.to_hash.stringify_keys
        fv5026.encrypted[fv5025] =
          { value: fv5027 }
        fv5024 = fv5026[fv5025]
        fv5000.cookies.delete(fv5025)
        fv5000.cookies.merge( # rubocop:disable Lint/Void
          "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
          URI.parse("https://#{@base_host}/"),
        )
        fv5023 = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "app", reference: fv5018.reference,
        )
        _, fv5019 =
          begin
            fv5022 = fv5023
            fv5021, fv5020 = fv5022.class.auth_admission_session_class.issue!
            fv5022.attach_auth_session!(
              auth_session: fv5021,
              confirmation_ref: SecureRandom.uuid,
            )
            fv5022.confirm_base!(
              base_token: nil,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5022.class.auth_admission_surface_name,
                entry_ref: fv5022.entry_ref,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            [fv5021,
             fv5020,]
          end
        fv5006.host!(@host)
        fv5006.https!
        fv5007 = {
          "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
        }
        fv5006.cookies.merge( # rubocop:disable Lint/Void
          "auth_sid=#{Rack::Utils.escape(fv5019)}",
          URI.parse("https://#{@host}/"),
        )
        fv5006.get(
          auth_app_sign_in_path(ri: "jp"),
          params: { entry_ref: fv5018.reference },
          headers: fv5007,
        )
        fv5017 = Nokogiri::HTML(fv5006.response.body).at_css("form")
        fv5016 =
          fv5017.css("input[type='hidden']").to_h do |fv5004|
            [fv5004["name"],
             fv5004["value"],]
          end
        fv5015 = fv5017.at_css('input[name="authenticity_token"]')["value"]
        fv5006.post(
          fv5017["action"],
          params: fv5016.merge("authenticity_token" => fv5015),
          headers: fv5007,
        )
        clear_enqueued_jobs
        OtpEmailNotifierRollout.stub(:enabled?, true) do
          fv5006.post(
            auth_app_sign_in_email_path(ri: "jp"),
            params: { :user_email => { address: fv5014.address },
                      "cf-turnstile-response" => "t", },
            headers: fv5007,
          )
        end

        assert_equal 302, fv5006.response.status
        fv5012 =
          enqueued_jobs.find { |fv5013|
            fv5013.fetch(:job) == OtpNotifierEmailDeliveryJob
          }

        assert_not_nil fv5012
        fv5011 = ActiveJob::Arguments.deserialize(fv5012.fetch(:args)).last.fetch(:params).symbolize_keys
        fv5010 = OutboundSensitivePayload.decrypt_email_otp(fv5011.fetch(:encrypted_hotp_token))
        fv5006.patch(
          auth_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: fv5010 },
                    "cf-turnstile-response" => "t", },
          headers: fv5007,
        )
        fv5006.follow_redirect! if fv5006.response.redirect?
        fv5006.follow_redirect! if fv5006.response.redirect?
        fv5009 = Nokogiri::HTML(fv5006.response.body).at_css("form")
        fv5008 = fv5009.at_css('input[name="authenticity_token"]')["value"]
        fv5006.post(
          auth_app_sign_handoff_path(ri: "jp"),
          params: {
            authenticity_token: fv5008,
            ri: "jp",
          }, headers: fv5007,
        )

        assert_equal 303, fv5006.response.status
        fv5005 = URI.parse(fv5006.response.location)
        fv5000.host!(@base_host)
        fv5000.https!
        fv5001 = {
          "Host" => @base_host,
          "Origin" => "https://#{@base_host}",
          "Sec-Fetch-Site" => "same-site",
        }
        fv5000.get(
          fv5005.request_uri,
          headers: fv5001,
        )

        assert_equal 200, fv5000.response.status
        fv5003 = Nokogiri::HTML(fv5000.response.body).at_css("form")
        fv5002 =
          fv5003.css("input[name]").to_h { |fv5004|
            [fv5004["name"],
             fv5004["value"],]
          }
        fv5000.post(
          fv5003["action"],
          params: fv5002,
          headers: fv5001,
        )
        fv5000.follow_redirect! if fv5000.response.redirect?
        fv5000
      end
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first
    resolution = ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    base.delete(base_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 303, base.response.status
    assert_predicate cycle.reload, :sign_in_cancelled?
    assert_predicate resolution.reload, :cancelled?
    assert(existing.all? { |token| token.reload.currently_usable? })
    assert_predicate base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :empty?
  end

  private

  # This browser journey binds email verification to the durable session-limit child.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
