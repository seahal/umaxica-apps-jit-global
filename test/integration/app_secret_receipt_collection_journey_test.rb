# frozen_string_literal: true

require "test_helper"

class AppSecretReceiptCollectionJourneyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous_lifetimes = ENV.to_h.slice(
      "APP_SECRET_PROOF_RETENTION_SECONDS", "APP_SECRET_OUTBOX_RETENTION_SECONDS", "APP_SECRET_PURGE_DELAY_SECONDS",
    )
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    ClientIdentityState.ensure_defaults!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    %w(APP_SECRET_PROOF_RETENTION_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS
       APP_SECRET_PURGE_DELAY_SECONDS).each do |key|
      ENV[key] = @previous_lifetimes[key]
    end
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "receipt scan continues past a held canonical login and collects a later committed receipt" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    receipts = []
    credentials = [client_secret_credentials(:one), client_secret_credentials(:two)]
    identifiers =
      credentials.to_h do |credential|
        email = credential.client.client_emails.create!(
          address: "receipt-#{credential.client.public_id}-#{SecureRandom.hex(4)}@example.com",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        email.finalize_binding!
        [credential.client_id, email.address]
      end
    transactions = []
    ["a" * 32, "b" * 32].each do |raw|
      reset!
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host! base_host
      https!
      get "/sign", params: { ri: "jp" }
      entry_form = css_select("form").first
      entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      post entry_form["action"], params: entry_fields,
                                 headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))

      assert_equal base_host, target.host
      get target.request_uri
      form = css_select("form#base-authorization-ceremony-start-form").first
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      post form["action"], params: fields,
                           headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      base_nonce = request.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)
      host! @host
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app", intent: "sign_in", ttl: 10.seconds, login_challenge_ttl: 10.seconds,
        params: {
          response_type: "code",
          client_id: "core-app",
          redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris_by_realm.fetch("client").first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: "state",
          nonce: "nonce",
          scope: "openid profile",
        },
      ).transaction
      reference = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: base_nonce, base_token: nil,
      ).reference
      begin
        fv5063 = self
        fv5062 = auth_app_sign_in_path
        fv5061 = reference
        fv5060 = :entry_ref
        fv5059 = { ri: "jp" }
        fv5058 = {
          "Host" => @host,
          "Origin" => "https://#{@host}",
          "Sec-Fetch-Site" => "same-origin",
        }
        fv5057 = false
        fv5056 = nil
        begin
          fv5004 = fv5063
          fv5011 = fv5062
          fv5054 = fv5061
          fv5055 = fv5060
          fv5020 = fv5059
          fv5013 = fv5058
          fv5042 = fv5057
          fv5041 = fv5056
          fv5016 = nil
          fv5010 = fv5020.merge(fv5055 => fv5054)
          fv5004.get(fv5011, params: fv5010, headers: fv5013)
          fv5048 =
            begin
              fv5053 = fv5004.response.body
              fv5052 = true
              fv5051 = Nokogiri::HTML(fv5053).at_css("form")
              if fv5051.nil? && fv5052
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5051

                fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5050.blank?

                fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5051["action"], fv5050, fv5049]
              end
            end
          if fv5048

            fv5047, fv5045, fv5046 = fv5048
            fv5004.post(fv5047, params: fv5046.merge(authenticity_token: fv5045), headers: fv5013)
            fv5044 = fv5004.response.location
            if fv5044.present?

              fv5040 = URI.parse(fv5044)
              fv5039 = fv5040.host
              fv5015 =
                begin
                  fv5043 = fv5039
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5043)
                end
              fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
              )

              if fv5042
                fv5022 = fv5041 || fv5004
                fv5022.host!(fv5039)
                fv5022.https!
                fv5038 = fv5040.request_uri
                fv5029 = fv5013.merge(
                  "Host" => fv5039,
                  "Origin" => "https://#{fv5039}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5022.get(fv5038, headers: fv5029)
                fv5032, fv5030, fv5031 =
                  begin
                    fv5037 = fv5022.response.body
                    fv5036 = false
                    fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                    if fv5035.nil? && fv5036
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5035

                      fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5034.blank?

                      fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5035["action"], fv5034, fv5033]
                    end
                  end
                fv5022.post(
                  fv5032,
                  params: fv5031.merge(authenticity_token: fv5030),
                  headers: fv5029,
                )
                begin
                  fv5023 = fv5022
                  fv5025 = "session"
                  fv5024 = fv5023.response.cookies[fv5025]
                  if fv5024.nil?
                    fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                    fv5027 =
                      if fv5028.is_a?(String) && fv5028.start_with?("[")
                        JSON.parse(fv5028)
                      else
                        Array(fv5028)
                      end
                    fv5026 =
                      fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                      end
                    if fv5026

                      _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                      fv5024 = Rack::Utils.unescape(fv5024.to_s)
                    end
                  end

                  unless fv5024.nil?
                    fv5023.cookies.delete(fv5025)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5023.cookies.merge(
                      "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                      URI.parse("https://#{fv5023.host}/"),
                    )
                  end
                end
                fv5021 = fv5022.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

                fv5018 = URI.parse(fv5021)
                if fv5020[:ri].present?
                  fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                  fv5019["ri"] ||= fv5020[:ri].to_s
                  fv5018.query = URI.encode_www_form(fv5019)
                end
                fv5004.host!(fv5018.host)
                fv5004.https!
                fv5017 = fv5018.request_uri
                fv5000 = fv5013.merge("Host" => fv5018.host)
                fv5004.get(fv5017, headers: fv5000)
              else
                fv5014.confirm_base!(
                  base_token: fv5016,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5015,
                    entry_ref: fv5014.entry_ref,
                    nonce: base_nonce,
                  ),
                )
                fv5012 = fv5004.host
                fv5004.host!(fv5012)
                fv5004.https!
                fv5000 = fv5013.merge("Host" => fv5012)
                fv5004.get(fv5011, params: fv5010, headers: fv5000)
              end
              fv5003, fv5001, fv5002 =
                begin
                  fv5009 = fv5004.response.body
                  fv5008 = false
                  fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                  if fv5007.nil? && fv5008
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5007

                    fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5006.blank?

                    fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5007["action"], fv5006, fv5005]
                  end
                end
              fv5004.post(
                fv5003,
                params: fv5002.merge(authenticity_token: fv5001),
                headers: fv5000,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!
      get new_auth_app_sign_in_secret_path(ri: "jp")
      post auth_app_sign_in_secret_path(ri: "jp"), params: {
        identifier: identifiers.fetch(credentials[transactions.length].client_id),
        secret: raw,
        "cf-turnstile-response": "test_token",
      }

      assert_response :see_other
      follow_redirect!
      follow_redirect!
      handoff_csrf = css_select("input[name=authenticity_token]").first["value"]
      post auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: handoff_csrf }, headers: {
        "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :see_other
      result_uri = URI.parse(response.location)
      host!(result_uri.host)
      https!
      get result_uri.request_uri, headers: { "Host" => result_uri.host }

      assert_response :success
      result_form = css_select("form#oidc-authorization-result-form").first
      result_ref = result_form.at_css('input[name="result_ref"]')["value"]
      transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
      action = result_form["action"]
      assert_difference("ClientToken.count", 1) do
        post action, params: { transaction_ref: transaction_ref, result_ref: result_ref },
                     headers: { "Origin" => OidcIssuer.absolute_url(result_uri.host) }

        assert_response :redirect
      end
      transactions << transaction
      receipts << ClientSecretSignInReceipt.find_by!(sign_in_flow_id: transaction.reload.secret_sign_in_flow_id)
    end
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    Timeout.timeout(3) do
      sleep 0.01 while credentials.any? { |credential| credential.reload.purge_eligible_at > Client.database_now }
    end
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert credentials.none? { |credential| ClientSecretCredential.exists?(credential.id) }
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    deadline = transactions.flat_map do |transaction|
      [transaction.expires_at, transaction.login_challenge_expires_at,
       ClientSignInFlow.find(transaction.secret_sign_in_flow_id).expires_at,]
    end.max + 1.second
    Timeout.timeout(15) { sleep 0.01 while ClientSignInFlow.database_now < deadline }
    hold = ClientRetentionHold.create!(client: clients(:one), hold_kind: "legal_hold", reason_code: "legal_hold")
    assert_enqueued_with(
      job: ClientSecretLifecycleJob,
      args: [{ batch_size: 1, phase: "receipts", after_id: receipts.first.id, through_id: receipts.last.id }],
    ) do
      ClientSecretLifecycleJob.perform_now(batch_size: 1)
    end
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretLifecycleJob }
      perform_enqueued_jobs(only: ClientSecretLifecycleJob)
    end

    assert ClientSecretSignInReceipt.exists?(receipts.first.id)
    assert_not ClientSecretSignInReceipt.exists?(receipts.last.id)
    assert hold.reload.active_at?(Client.database_now)
    receipts.each do |receipt|
      token = ClientToken.find_by!(public_id: receipt.root_token_ref)

      assert token.currently_usable?(ClientToken.database_now)
    end
  end
end
