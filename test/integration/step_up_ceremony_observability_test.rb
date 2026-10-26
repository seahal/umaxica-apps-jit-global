# frozen_string_literal: true

require "test_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "admission, acceptance and cancellation of one ceremony share a keyed reference and log no identifier" do
    actor, token =
      begin
        fv5401 = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        ClientTotpCredential.create_for_user!(
          user: fv5401, private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        )
        [fv5401, ClientToken.create!(authentication_epoch: 0, user: fv5401)]
      end
    base, auth, transaction =
      begin
        fv5400 = actor
        fv5299 = token
        fv5390 = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        fv5368 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        fv5301 =
          begin
            fv5396 = fv5400
            fv5394 = fv5299
            fv5395 = fv5390
            BaseSelectorBootstrapAuthority.call(
              surface: :app,
              principal: fv5396,
            )
            BaseSelectorAuthority.prepare(
              surface: :app,
              principal: fv5396,
              session: fv5394,
            )
            fv5399 = OidcClientRegistry.find!("base-app-ww")
            fv5397 = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: fv5394,
              oidc_client_id: fv5399.client_id,
              oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid,
              oidc_nonce: SecureRandom.hex(16),
              oidc_auth_time: 1.minute.ago,
              refresh_token_expires_at: 10.minutes.from_now,
            )
            fv5398 = AuthenticationTokenService.encode(
              fv5396,
              host: fv5395,
              resource_type: "client",
              session_public_id: fv5394.public_id,
              base_session_public_id: fv5394.public_id,
              oidc_sid: fv5397.public_id,
              oidc_jti: fv5397.oidc_jti,
              expires_at: 10.minutes.from_now,
              scopes: %w(openid profile),
              issuer: OidcIssuer.for_client(fv5399),
              audiences: [fv5399.aud],
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5399),
              subject: OidcSubject.for(
                fv5396,
                resource_type: "client",
              ),
              client_id: fv5399.client_id,
            )
            fv5393 = open_session
            fv5393.host!(fv5395)
            fv5393.https!
            fv5393.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
              fv5398
            fv5393.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
              fv5397.issue_refresh_token!
            # Base's authority endpoints (binding confirmation, cancellation, completion) authenticate the
            # root session and never accept the RP cookies above.
            fv5393.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
              fv5396,
              host: fv5395,
              session_public_id: fv5394.public_id,
              resource_type: "client",
              jwt_issuer_id: "surface:BASE_APP",
            )
            fv5393
          end
        fv5301.get(base_app_identity_birthdate_path(ri: "jp"))
        fv5301.follow_redirect!
        fv5392 = Nokogiri::HTML(fv5301.response.body)
        fv5391 = JSON.parse(fv5392.at_css("script[data-page='app']").text).fetch("props").fetch("form")
        fv5301.post(
          fv5391.fetch("action"),
          params: {
            scope: fv5391.fetch("scope"),
            pt: fv5391.fetch("pt"),
          },
          headers: {
            "Origin" => "https://#{fv5390}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        # An unsafe Base request rotates the RP credentials; carry all three cookies forward.
        begin
          fv5384 = fv5301
          fv5386 = "session"
          fv5385 = fv5384.response.cookies[fv5386]
          if fv5385.nil?
            fv5389 = fv5384.response.headers["Set-Cookie"] || fv5384.response.headers["set-cookie"]
            fv5388 =
              if fv5389.is_a?(String) && fv5389.start_with?("[")
                JSON.parse(fv5389)
              else
                Array(fv5389)
              end
            fv5387 =
              fv5388.flat_map { |fv5330| fv5330.to_s.split("\n") }.find do |fv5330|
                fv5330.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5386}=")
              end
            if fv5387

              _, fv5385 = fv5387.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5385 = Rack::Utils.unescape(fv5385.to_s)
            end
          end

          unless fv5385.nil?
            fv5384.cookies.delete(fv5386)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5384.cookies.merge(
              "#{fv5386}=#{Rack::Utils.escape(fv5385)}",
              URI.parse("https://#{fv5384.host}/"),
            )
          end
        end
        begin
          fv5378 = fv5301
          fv5380 = OidcRpBrowserCredentialContract::ACCESS_COOKIE
          fv5379 = fv5378.response.cookies[fv5380]
          if fv5379.nil?
            fv5383 = fv5378.response.headers["Set-Cookie"] || fv5378.response.headers["set-cookie"]
            fv5382 =
              if fv5383.is_a?(String) && fv5383.start_with?("[")
                JSON.parse(fv5383)
              else
                Array(fv5383)
              end
            fv5381 =
              fv5382.flat_map { |fv5330| fv5330.to_s.split("\n") }.find do |fv5330|
                fv5330.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5380}=")
              end
            if fv5381

              _, fv5379 = fv5381.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5379 = Rack::Utils.unescape(fv5379.to_s)
            end
          end

          unless fv5379.nil?
            fv5378.cookies.delete(fv5380)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5378.cookies.merge(
              "#{fv5380}=#{Rack::Utils.escape(fv5379)}",
              URI.parse("https://#{fv5378.host}/"),
            )
          end
        end
        begin
          fv5372 = fv5301
          fv5374 = OidcRpBrowserCredentialContract::REFRESH_COOKIE
          fv5373 = fv5372.response.cookies[fv5374]
          if fv5373.nil?
            fv5377 = fv5372.response.headers["Set-Cookie"] || fv5372.response.headers["set-cookie"]
            fv5376 =
              if fv5377.is_a?(String) && fv5377.start_with?("[")
                JSON.parse(fv5377)
              else
                Array(fv5377)
              end
            fv5375 =
              fv5376.flat_map { |fv5330| fv5330.to_s.split("\n") }.find do |fv5330|
                fv5330.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5374}=")
              end
            if fv5375

              _, fv5373 = fv5375.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5373 = Rack::Utils.unescape(fv5373.to_s)
            end
          end

          unless fv5373.nil?
            fv5372.cookies.delete(fv5374)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5372.cookies.merge(
              "#{fv5374}=#{Rack::Utils.escape(fv5373)}",
              URI.parse("https://#{fv5372.host}/"),
            )
          end
        end
        fv5371 = Rack::Utils.parse_query(URI.parse(fv5301.response.location).query).fetch("rt")
        # The Jump token is read only for its destination; its signature is the gateway's concern.
        fv5370 = URI.parse(
          JWT.decode(
            fv5371,
            nil,
            false,
          ).first.fetch("url"),
        )
        fv5369 = Rack::Utils.parse_query(fv5370.query).fetch("entry_ref")
        fv5300 = open_session
        fv5300.host!(fv5368)
        fv5300.https!
        begin
          fv5367 = fv5300
          fv5366 = fv5370.path
          fv5365 = fv5369
          fv5364 = :entry_ref
          fv5363 = { ri: "jp" }
          fv5362 = {
            "Host" => fv5368,
            "Origin" => "https://#{fv5368}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5361 = true
          fv5360 = fv5301
          begin
            fv5306 = fv5367
            fv5314 = fv5366
            fv5358 = fv5365
            fv5359 = fv5364
            fv5323 = fv5363
            fv5316 = fv5362
            fv5346 = fv5361
            fv5345 = fv5360
            fv5319 = nil
            fv5313 = fv5323.merge(fv5359 => fv5358)
            fv5306.get(
              fv5314,
              params: fv5313,
              headers: fv5316,
            )
            fv5352 =
              begin
                fv5357 = fv5306.response.body
                fv5356 = true
                fv5355 = Nokogiri::HTML(fv5357).at_css("form")
                if fv5355.nil? && fv5356
                  nil
                else
                  raise RuntimeError,
                        "Auth continuation form is missing" unless fv5355

                  fv5354 = fv5355.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5354.blank?

                  fv5353 = fv5355.css("input[type='hidden']").to_h do |fv5310|
                    [fv5310["name"], fv5310["value"]]
                  end.except("authenticity_token")
                  [fv5355["action"], fv5354, fv5353]
                end
              end
            if fv5352

              fv5351, fv5349, fv5350 = fv5352

              fv5306.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5306.post(
                fv5351,
                params: fv5350.merge(authenticity_token: fv5349),
                headers: fv5316,
              )
              fv5348 = fv5306.response.location
              if fv5348.present?

                fv5344 = URI.parse(fv5348)
                fv5343 = fv5344.host
                fv5318 =
                  begin
                    fv5347 = fv5343
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                    }.fetch(fv5347)
                  end
                fv5317 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5318,
                  reference: fv5344.path.split("/").fetch(-2),
                )

                if fv5346
                  fv5325 = fv5345 || fv5306
                  fv5325.host!(fv5343)
                  fv5325.https!
                  fv5325.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5342 = fv5344.request_uri
                  fv5333 = fv5316.merge(
                    "Host" => fv5343,
                    "Origin" => "https://#{fv5343}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5325.get(
                    fv5342,
                    headers: fv5333,
                  )
                  fv5336, fv5334, fv5335 =
                    begin
                      fv5341 = fv5325.response.body
                      fv5340 = false
                      fv5339 = Nokogiri::HTML(fv5341).at_css("form")
                      if fv5339.nil? && fv5340
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5339

                        fv5338 = fv5339.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5338.blank?

                        fv5337 = fv5339.css("input[type='hidden']").to_h do |fv5310|
                          [fv5310["name"], fv5310["value"]]
                        end.except("authenticity_token")
                        [fv5339["action"], fv5338, fv5337]
                      end
                    end
                  fv5325.post(
                    fv5336,
                    params: fv5335.merge(authenticity_token: fv5334),
                    headers: fv5333,
                  )
                  begin
                    fv5326 = fv5325
                    fv5328 = "session"
                    fv5327 = fv5326.response.cookies[fv5328]
                    if fv5327.nil?
                      fv5332 = fv5326.response.headers["Set-Cookie"] || fv5326.response.headers["set-cookie"]
                      fv5331 =
                        if fv5332.is_a?(String) && fv5332.start_with?("[")
                          JSON.parse(fv5332)
                        else
                          Array(fv5332)
                        end
                      fv5329 =
                        fv5331.flat_map { |fv5330| fv5330.to_s.split("\n") }.find do |fv5330|
                          fv5330.split(
                            ";",
                            2,
                          ).first.to_s.start_with?("#{fv5328}=")
                        end
                      if fv5329

                        _, fv5327 = fv5329.split(
                          ";",
                          2,
                        ).first.to_s.split(
                          "=",
                          2,
                        )
                        fv5327 = Rack::Utils.unescape(fv5327.to_s)
                      end
                    end

                    unless fv5327.nil?
                      fv5326.cookies.delete(fv5328)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5326.cookies.merge(
                        "#{fv5328}=#{Rack::Utils.escape(fv5327)}",
                        URI.parse("https://#{fv5326.host}/"),
                      )
                    end
                  end
                  fv5324 = fv5325.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5324.blank?

                  fv5321 = URI.parse(fv5324)
                  if fv5323[:ri].present?
                    fv5322 = Rack::Utils.parse_nested_query(fv5321.query.to_s)
                    fv5322["ri"] ||= fv5323[:ri].to_s
                    fv5321.query = URI.encode_www_form(fv5322)
                  end
                  fv5306.host!(fv5321.host)
                  fv5306.https!
                  fv5320 = fv5321.request_uri
                  fv5302 = fv5316.merge("Host" => fv5321.host)
                  fv5306.get(
                    fv5320,
                    headers: fv5302,
                  )
                else
                  fv5317.confirm_base!(
                    base_token: fv5319,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5318,
                      entry_ref: fv5317.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5315 = fv5306.host
                  fv5306.host!(fv5315)
                  fv5306.https!
                  fv5302 = fv5316.merge("Host" => fv5315)
                  fv5306.get(
                    fv5314,
                    params: fv5313,
                    headers: fv5302,
                  )
                end
                fv5305, fv5303, fv5304 =
                  begin
                    fv5312 = fv5306.response.body
                    fv5311 = false
                    fv5309 = Nokogiri::HTML(fv5312).at_css("form")
                    if fv5309.nil? && fv5311
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5309

                      fv5308 = fv5309.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5308.blank?

                      fv5307 = fv5309.css("input[type='hidden']").to_h do |fv5310|
                        [fv5310["name"], fv5310["value"]]
                      end.except("authenticity_token")
                      [fv5309["action"], fv5308, fv5307]
                    end
                  end
                fv5306.post(
                  fv5305,
                  params: fv5304.merge(authenticity_token: fv5303),
                  headers: fv5302,
                )
              end
            end
          end
        end
        fv5300.get(new_auth_app_verification_totp_path(ri: "jp"))
        [fv5301, fv5300, ClientStepUpCeremonyTransaction.find_by!(session_ref: fv5299.public_id)]
      end
    transaction_id = transaction.transaction_id
    auth_csrf =
      begin
        fv5298 = auth
        fv5297 = Nokogiri::HTML(fv5298.response.body).at_css("script[data-page='app']")
        JSON.parse(fv5297.text).fetch("props").fetch("form").fetch("csrf_token")
      end

    cancellation =
      begin
        fv5293 = base
        fv5294 = auth
        fv5296 = { csrf: auth_csrf }
        fv5295 = fv5296.fetch(:csrf)
        fv5294.post(
          auth_app_verification_cancellation_path(ri: "jp"),
          params: { authenticity_token: fv5295 },
          headers: { "Origin" => "https://#{fv5294.host}" },
        )

        assert_equal 303, fv5294.response.status
        fv5293.get(URI.parse(fv5294.response.location).request_uri)

        assert_equal 200, fv5293.response.status
        fv5291 = Nokogiri::HTML(fv5293.response.body).at_css("form")
        fv5290 =
          fv5291.css("input[type='hidden']").to_h { |fv5292|
            [fv5292["name"], fv5292["value"]]
          }
        {
          action: fv5291["action"],
          params: fv5290,
        }
      end

    assert_equal "pending", transaction.reload.status
    begin
      fv5288 = base
      fv5289 = cancellation
      fv5288.post(
        fv5289.fetch(:action),
        params: fv5289.fetch(:params),
        headers: {
          "Origin" => "https://#{fv5288.host}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_equal 303, base.response.status
    assert_equal "canceled", transaction.reload.status

    events = @log.string.lines.filter_map { |line| JSON.parse(line) if line.start_with?('{"event":"auth.step_up.') }
    accepted = events.find { |event| event.fetch("event") == "auth.step_up.ceremony_accepted" }.fetch("data")
    canceled = events.find { |event| event.fetch("event") == "auth.step_up.canceled" }.fetch("data")
    expected_reference = StepUpObservabilityDigest.ceremony_ref(transaction_id)

    assert_equal expected_reference, accepted.fetch("ceremony_ref")
    assert_equal expected_reference, canceled.fetch("ceremony_ref")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), canceled.fetch("browser_session_digest")
    assert_equal "step_up", canceled.fetch("purpose")
    assert_equal "settings_birthdate", canceled.fetch("scope")
    assert_equal "base_cancellation", canceled.fetch("stage")
    assert_equal "pending", canceled.fetch("state_before")
    assert_equal "canceled", canceled.fetch("state_after")
    assert_predicate canceled.fetch("request_id"), :present?
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, canceled.fetch("occurred_at"))

    step_up_log = events.to_json

    assert_not_includes step_up_log, transaction_id
    assert_not_includes step_up_log, token.public_id
    assert_not_includes step_up_log, actor.public_id
    assert_not_includes step_up_log, auth_csrf
    assert_not_includes step_up_log, transaction.cancellation_handoff_ciphertext
    assert_not_includes step_up_log, cancellation.fetch(:params).fetch("cancellation_ref")
  end

  test "an Auth ceremony page opened without admission is refused generically and logged as invalid_admission" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "invalid_admission", refusal.fetch("error_code")
    assert_equal "auth_ceremony_context", refusal.fetch("stage")
    assert_equal "refused", refusal.fetch("outcome")
    assert_not refusal.key?("ceremony_ref")
    assert_not_includes response.body, "invalid_admission"
  end

  test "an exact Base cancellation retry answers the same redirect and changes nothing" do
    actor, token =
      begin
        fv5287 = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        ClientTotpCredential.create_for_user!(
          user: fv5287, private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        )
        [fv5287, ClientToken.create!(authentication_epoch: 0, user: fv5287)]
      end
    base, auth, transaction =
      begin
        fv5286 = actor
        fv5045 = token
        fv5276 = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        fv5012 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        fv5189 =
          begin
            fv5282 = fv5286
            fv5280 = fv5045
            fv5281 = fv5276
            BaseSelectorBootstrapAuthority.call(
              surface: :app,
              principal: fv5282,
            )
            BaseSelectorAuthority.prepare(
              surface: :app,
              principal: fv5282,
              session: fv5280,
            )
            fv5285 = OidcClientRegistry.find!("base-app-ww")
            fv5283 = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: fv5280,
              oidc_client_id: fv5285.client_id,
              oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid,
              oidc_nonce: SecureRandom.hex(16),
              oidc_auth_time: 1.minute.ago,
              refresh_token_expires_at: 10.minutes.from_now,
            )
            fv5284 = AuthenticationTokenService.encode(
              fv5282,
              host: fv5281,
              resource_type: "client",
              session_public_id: fv5280.public_id,
              base_session_public_id: fv5280.public_id,
              oidc_sid: fv5283.public_id,
              oidc_jti: fv5283.oidc_jti,
              expires_at: 10.minutes.from_now,
              scopes: %w(openid profile),
              issuer: OidcIssuer.for_client(fv5285),
              audiences: [fv5285.aud],
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5285),
              subject: OidcSubject.for(
                fv5282,
                resource_type: "client",
              ),
              client_id: fv5285.client_id,
            )
            fv5279 = open_session
            fv5279.host!(fv5281)
            fv5279.https!
            fv5279.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
              fv5284
            fv5279.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
              fv5283.issue_refresh_token!
            # Base's authority endpoints (binding confirmation, cancellation, completion) authenticate the
            # root session and never accept the RP cookies above.
            fv5279.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
              fv5282,
              host: fv5281,
              session_public_id: fv5280.public_id,
              resource_type: "client",
              jwt_issuer_id: "surface:BASE_APP",
            )
            fv5279
          end
        fv5189.get(base_app_identity_birthdate_path(ri: "jp"))
        fv5189.follow_redirect!
        fv5278 = Nokogiri::HTML(fv5189.response.body)
        fv5277 = JSON.parse(fv5278.at_css("script[data-page='app']").text).fetch("props").fetch("form")
        fv5189.post(
          fv5277.fetch("action"),
          params: {
            scope: fv5277.fetch("scope"),
            pt: fv5277.fetch("pt"),
          },
          headers: {
            "Origin" => "https://#{fv5276}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        # An unsafe Base request rotates the RP credentials; carry all three cookies forward.
        begin
          fv5270 = fv5189
          fv5272 = "session"
          fv5271 = fv5270.response.cookies[fv5272]
          if fv5271.nil?
            fv5275 = fv5270.response.headers["Set-Cookie"] || fv5270.response.headers["set-cookie"]
            fv5274 =
              if fv5275.is_a?(String) && fv5275.start_with?("[")
                JSON.parse(fv5275)
              else
                Array(fv5275)
              end
            fv5273 =
              fv5274.flat_map { |fv5218| fv5218.to_s.split("\n") }.find do |fv5218|
                fv5218.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5272}=")
              end
            if fv5273

              _, fv5271 = fv5273.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5271 = Rack::Utils.unescape(fv5271.to_s)
            end
          end

          unless fv5271.nil?
            fv5270.cookies.delete(fv5272)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5270.cookies.merge(
              "#{fv5272}=#{Rack::Utils.escape(fv5271)}",
              URI.parse("https://#{fv5270.host}/"),
            )
          end
        end
        begin
          fv5264 = fv5189
          fv5266 = OidcRpBrowserCredentialContract::ACCESS_COOKIE
          fv5265 = fv5264.response.cookies[fv5266]
          if fv5265.nil?
            fv5269 = fv5264.response.headers["Set-Cookie"] || fv5264.response.headers["set-cookie"]
            fv5268 =
              if fv5269.is_a?(String) && fv5269.start_with?("[")
                JSON.parse(fv5269)
              else
                Array(fv5269)
              end
            fv5267 =
              fv5268.flat_map { |fv5218| fv5218.to_s.split("\n") }.find do |fv5218|
                fv5218.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5266}=")
              end
            if fv5267

              _, fv5265 = fv5267.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5265 = Rack::Utils.unescape(fv5265.to_s)
            end
          end

          unless fv5265.nil?
            fv5264.cookies.delete(fv5266)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5264.cookies.merge(
              "#{fv5266}=#{Rack::Utils.escape(fv5265)}",
              URI.parse("https://#{fv5264.host}/"),
            )
          end
        end
        begin
          fv5258 = fv5189
          fv5260 = OidcRpBrowserCredentialContract::REFRESH_COOKIE
          fv5259 = fv5258.response.cookies[fv5260]
          if fv5259.nil?
            fv5263 = fv5258.response.headers["Set-Cookie"] || fv5258.response.headers["set-cookie"]
            fv5262 =
              if fv5263.is_a?(String) && fv5263.start_with?("[")
                JSON.parse(fv5263)
              else
                Array(fv5263)
              end
            fv5261 =
              fv5262.flat_map { |fv5218| fv5218.to_s.split("\n") }.find do |fv5218|
                fv5218.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5260}=")
              end
            if fv5261

              _, fv5259 = fv5261.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5259 = Rack::Utils.unescape(fv5259.to_s)
            end
          end

          unless fv5259.nil?
            fv5258.cookies.delete(fv5260)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5258.cookies.merge(
              "#{fv5260}=#{Rack::Utils.escape(fv5259)}",
              URI.parse("https://#{fv5258.host}/"),
            )
          end
        end
        fv5257 = Rack::Utils.parse_query(URI.parse(fv5189.response.location).query).fetch("rt")
        # The Jump token is read only for its destination; its signature is the gateway's concern.
        fv5256 = URI.parse(
          JWT.decode(
            fv5257,
            nil,
            false,
          ).first.fetch("url"),
        )
        fv5054 = Rack::Utils.parse_query(fv5256.query).fetch("entry_ref")
        fv5188 = open_session
        fv5188.host!(fv5012)
        fv5188.https!
        begin
          fv5255 = fv5188
          fv5254 = fv5256.path
          fv5253 = fv5054
          fv5252 = :entry_ref
          fv5251 = { ri: "jp" }
          fv5250 = {
            "Host" => fv5012,
            "Origin" => "https://#{fv5012}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5249 = true
          fv5248 = fv5189
          begin
            fv5194 = fv5255
            fv5202 = fv5254
            fv5246 = fv5253
            fv5247 = fv5252
            fv5211 = fv5251
            fv5204 = fv5250
            fv5234 = fv5249
            fv5233 = fv5248
            fv5207 = nil
            fv5201 = fv5211.merge(fv5247 => fv5246)
            fv5194.get(
              fv5202,
              params: fv5201,
              headers: fv5204,
            )
            fv5240 =
              begin
                fv5245 = fv5194.response.body
                fv5244 = true
                fv5243 = Nokogiri::HTML(fv5245).at_css("form")
                if fv5243.nil? && fv5244
                  nil
                else
                  raise RuntimeError,
                        "Auth continuation form is missing" unless fv5243

                  fv5242 = fv5243.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5242.blank?

                  fv5241 = fv5243.css("input[type='hidden']").to_h do |fv5198|
                    [fv5198["name"], fv5198["value"]]
                  end.except("authenticity_token")
                  [fv5243["action"], fv5242, fv5241]
                end
              end
            if fv5240

              fv5239, fv5237, fv5238 = fv5240

              fv5194.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5194.post(
                fv5239,
                params: fv5238.merge(authenticity_token: fv5237),
                headers: fv5204,
              )
              fv5236 = fv5194.response.location
              if fv5236.present?

                fv5232 = URI.parse(fv5236)
                fv5231 = fv5232.host
                fv5206 =
                  begin
                    fv5235 = fv5231
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                    }.fetch(fv5235)
                  end
                fv5205 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5206,
                  reference: fv5232.path.split("/").fetch(-2),
                )

                if fv5234
                  fv5213 = fv5233 || fv5194
                  fv5213.host!(fv5231)
                  fv5213.https!
                  fv5213.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5230 = fv5232.request_uri
                  fv5221 = fv5204.merge(
                    "Host" => fv5231,
                    "Origin" => "https://#{fv5231}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5213.get(
                    fv5230,
                    headers: fv5221,
                  )
                  fv5224, fv5222, fv5223 =
                    begin
                      fv5229 = fv5213.response.body
                      fv5228 = false
                      fv5227 = Nokogiri::HTML(fv5229).at_css("form")
                      if fv5227.nil? && fv5228
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5227

                        fv5226 = fv5227.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5226.blank?

                        fv5225 = fv5227.css("input[type='hidden']").to_h do |fv5198|
                          [fv5198["name"], fv5198["value"]]
                        end.except("authenticity_token")
                        [fv5227["action"], fv5226, fv5225]
                      end
                    end
                  fv5213.post(
                    fv5224,
                    params: fv5223.merge(authenticity_token: fv5222),
                    headers: fv5221,
                  )
                  begin
                    fv5214 = fv5213
                    fv5216 = "session"
                    fv5215 = fv5214.response.cookies[fv5216]
                    if fv5215.nil?
                      fv5220 = fv5214.response.headers["Set-Cookie"] || fv5214.response.headers["set-cookie"]
                      fv5219 =
                        if fv5220.is_a?(String) && fv5220.start_with?("[")
                          JSON.parse(fv5220)
                        else
                          Array(fv5220)
                        end
                      fv5217 =
                        fv5219.flat_map { |fv5218| fv5218.to_s.split("\n") }.find do |fv5218|
                          fv5218.split(
                            ";",
                            2,
                          ).first.to_s.start_with?("#{fv5216}=")
                        end
                      if fv5217

                        _, fv5215 = fv5217.split(
                          ";",
                          2,
                        ).first.to_s.split(
                          "=",
                          2,
                        )
                        fv5215 = Rack::Utils.unescape(fv5215.to_s)
                      end
                    end

                    unless fv5215.nil?
                      fv5214.cookies.delete(fv5216)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5214.cookies.merge(
                        "#{fv5216}=#{Rack::Utils.escape(fv5215)}",
                        URI.parse("https://#{fv5214.host}/"),
                      )
                    end
                  end
                  fv5212 = fv5213.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5212.blank?

                  fv5209 = URI.parse(fv5212)
                  if fv5211[:ri].present?
                    fv5210 = Rack::Utils.parse_nested_query(fv5209.query.to_s)
                    fv5210["ri"] ||= fv5211[:ri].to_s
                    fv5209.query = URI.encode_www_form(fv5210)
                  end
                  fv5194.host!(fv5209.host)
                  fv5194.https!
                  fv5208 = fv5209.request_uri
                  fv5190 = fv5204.merge("Host" => fv5209.host)
                  fv5194.get(
                    fv5208,
                    headers: fv5190,
                  )
                else
                  fv5205.confirm_base!(
                    base_token: fv5207,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5206,
                      entry_ref: fv5205.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5203 = fv5194.host
                  fv5194.host!(fv5203)
                  fv5194.https!
                  fv5190 = fv5204.merge("Host" => fv5203)
                  fv5194.get(
                    fv5202,
                    params: fv5201,
                    headers: fv5190,
                  )
                end
                fv5193, fv5191, fv5192 =
                  begin
                    fv5200 = fv5194.response.body
                    fv5199 = false
                    fv5197 = Nokogiri::HTML(fv5200).at_css("form")
                    if fv5197.nil? && fv5199
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5197

                      fv5196 = fv5197.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5196.blank?

                      fv5195 = fv5197.css("input[type='hidden']").to_h do |fv5198|
                        [fv5198["name"], fv5198["value"]]
                      end.except("authenticity_token")
                      [fv5197["action"], fv5196, fv5195]
                    end
                  end
                fv5194.post(
                  fv5193,
                  params: fv5192.merge(authenticity_token: fv5191),
                  headers: fv5190,
                )
              end
            end
          end
        end
        fv5188.get(new_auth_app_verification_totp_path(ri: "jp"))
        [fv5189, fv5188, ClientStepUpCeremonyTransaction.find_by!(session_ref: fv5045.public_id)]
      end
    cancellation =
      begin
        fv5182 = base
        fv5183 = auth
        fv5185 = { csrf: begin
          fv5187 = auth
          fv5186 = Nokogiri::HTML(fv5187.response.body).at_css("script[data-page='app']")
          JSON.parse(fv5186.text).fetch("props").fetch("form").fetch("csrf_token")
        end }
        fv5184 = fv5185.fetch(:csrf)
        fv5183.post(
          auth_app_verification_cancellation_path(ri: "jp"),
          params: { authenticity_token: fv5184 },
          headers: { "Origin" => "https://#{fv5183.host}" },
        )

        assert_equal 303, fv5183.response.status
        fv5182.get(URI.parse(fv5183.response.location).request_uri)

        assert_equal 200, fv5182.response.status
        fv5035 = Nokogiri::HTML(fv5182.response.body).at_css("form")
        fv5033 =
          fv5035.css("input[type='hidden']").to_h { |fv5181|
            [fv5181["name"], fv5181["value"]]
          }
        {
          action: fv5035["action"],
          params: fv5033,
        }
      end
    begin
      fv5179 = base
      fv5180 = cancellation
      fv5179.post(
        fv5180.fetch(:action),
        params: fv5180.fetch(:params),
        headers: {
          "Origin" => "https://#{fv5179.host}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    destination = base.response.location
    canceled_at = transaction.reload.canceled_at

    begin
      fv5177 = base
      fv5178 = cancellation
      fv5177.post(
        fv5178.fetch(:action),
        params: fv5178.fetch(:params),
        headers: {
          "Origin" => "https://#{fv5177.host}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_equal 303, base.response.status
    assert_equal destination, base.response.location
    assert_equal "canceled", transaction.reload.status
    assert_equal canceled_at, transaction.canceled_at
  end

  test "a second cancellation after the ceremony ended is refused and logged without changing the terminal state" do
    actor, token =
      begin
        fv5176 = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        ClientTotpCredential.create_for_user!(
          user: fv5176, private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        )
        [fv5176, ClientToken.create!(authentication_epoch: 0, user: fv5176)]
      end
    base, auth, transaction =
      begin
        fv5175 = actor
        fv5050 = token
        fv5165 = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        fv5143 = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        fv5076 =
          begin
            fv5171 = fv5175
            fv5169 = fv5050
            fv5170 = fv5165
            BaseSelectorBootstrapAuthority.call(
              surface: :app,
              principal: fv5171,
            )
            BaseSelectorAuthority.prepare(
              surface: :app,
              principal: fv5171,
              session: fv5169,
            )
            fv5174 = OidcClientRegistry.find!("base-app-ww")
            fv5172 = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: fv5169,
              oidc_client_id: fv5174.client_id,
              oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid,
              oidc_nonce: SecureRandom.hex(16),
              oidc_auth_time: 1.minute.ago,
              refresh_token_expires_at: 10.minutes.from_now,
            )
            fv5173 = AuthenticationTokenService.encode(
              fv5171,
              host: fv5170,
              resource_type: "client",
              session_public_id: fv5169.public_id,
              base_session_public_id: fv5169.public_id,
              oidc_sid: fv5172.public_id,
              oidc_jti: fv5172.oidc_jti,
              expires_at: 10.minutes.from_now,
              scopes: %w(openid profile),
              issuer: OidcIssuer.for_client(fv5174),
              audiences: [fv5174.aud],
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5174),
              subject: OidcSubject.for(
                fv5171,
                resource_type: "client",
              ),
              client_id: fv5174.client_id,
            )
            fv5168 = open_session
            fv5168.host!(fv5170)
            fv5168.https!
            fv5168.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
              fv5173
            fv5168.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
              fv5172.issue_refresh_token!
            # Base's authority endpoints (binding confirmation, cancellation, completion) authenticate the
            # root session and never accept the RP cookies above.
            fv5168.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
              fv5171,
              host: fv5170,
              session_public_id: fv5169.public_id,
              resource_type: "client",
              jwt_issuer_id: "surface:BASE_APP",
            )
            fv5168
          end
        fv5076.get(base_app_identity_birthdate_path(ri: "jp"))
        fv5076.follow_redirect!
        fv5167 = Nokogiri::HTML(fv5076.response.body)
        fv5166 = JSON.parse(fv5167.at_css("script[data-page='app']").text).fetch("props").fetch("form")
        fv5076.post(
          fv5166.fetch("action"),
          params: {
            scope: fv5166.fetch("scope"),
            pt: fv5166.fetch("pt"),
          },
          headers: {
            "Origin" => "https://#{fv5165}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        # An unsafe Base request rotates the RP credentials; carry all three cookies forward.
        begin
          fv5159 = fv5076
          fv5161 = "session"
          fv5160 = fv5159.response.cookies[fv5161]
          if fv5160.nil?
            fv5164 = fv5159.response.headers["Set-Cookie"] || fv5159.response.headers["set-cookie"]
            fv5163 =
              if fv5164.is_a?(String) && fv5164.start_with?("[")
                JSON.parse(fv5164)
              else
                Array(fv5164)
              end
            fv5162 =
              fv5163.flat_map { |fv5105| fv5105.to_s.split("\n") }.find do |fv5105|
                fv5105.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5161}=")
              end
            if fv5162

              _, fv5160 = fv5162.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5160 = Rack::Utils.unescape(fv5160.to_s)
            end
          end

          unless fv5160.nil?
            fv5159.cookies.delete(fv5161)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5159.cookies.merge(
              "#{fv5161}=#{Rack::Utils.escape(fv5160)}",
              URI.parse("https://#{fv5159.host}/"),
            )
          end
        end
        begin
          fv5153 = fv5076
          fv5155 = OidcRpBrowserCredentialContract::ACCESS_COOKIE
          fv5154 = fv5153.response.cookies[fv5155]
          if fv5154.nil?
            fv5158 = fv5153.response.headers["Set-Cookie"] || fv5153.response.headers["set-cookie"]
            fv5157 =
              if fv5158.is_a?(String) && fv5158.start_with?("[")
                JSON.parse(fv5158)
              else
                Array(fv5158)
              end
            fv5156 =
              fv5157.flat_map { |fv5105| fv5105.to_s.split("\n") }.find do |fv5105|
                fv5105.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5155}=")
              end
            if fv5156

              _, fv5154 = fv5156.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5154 = Rack::Utils.unescape(fv5154.to_s)
            end
          end

          unless fv5154.nil?
            fv5153.cookies.delete(fv5155)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5153.cookies.merge(
              "#{fv5155}=#{Rack::Utils.escape(fv5154)}",
              URI.parse("https://#{fv5153.host}/"),
            )
          end
        end
        begin
          fv5147 = fv5076
          fv5149 = OidcRpBrowserCredentialContract::REFRESH_COOKIE
          fv5148 = fv5147.response.cookies[fv5149]
          if fv5148.nil?
            fv5152 = fv5147.response.headers["Set-Cookie"] || fv5147.response.headers["set-cookie"]
            fv5151 =
              if fv5152.is_a?(String) && fv5152.start_with?("[")
                JSON.parse(fv5152)
              else
                Array(fv5152)
              end
            fv5150 =
              fv5151.flat_map { |fv5105| fv5105.to_s.split("\n") }.find do |fv5105|
                fv5105.split(
                  ";",
                  2,
                ).first.to_s.start_with?("#{fv5149}=")
              end
            if fv5150

              _, fv5148 = fv5150.split(
                ";",
                2,
              ).first.to_s.split(
                "=",
                2,
              )
              fv5148 = Rack::Utils.unescape(fv5148.to_s)
            end
          end

          unless fv5148.nil?
            fv5147.cookies.delete(fv5149)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5147.cookies.merge(
              "#{fv5149}=#{Rack::Utils.escape(fv5148)}",
              URI.parse("https://#{fv5147.host}/"),
            )
          end
        end
        fv5146 = Rack::Utils.parse_query(URI.parse(fv5076.response.location).query).fetch("rt")
        # The Jump token is read only for its destination; its signature is the gateway's concern.
        fv5145 = URI.parse(
          JWT.decode(
            fv5146,
            nil,
            false,
          ).first.fetch("url"),
        )
        fv5144 = Rack::Utils.parse_query(fv5145.query).fetch("entry_ref")
        fv5075 = open_session
        fv5075.host!(fv5143)
        fv5075.https!
        begin
          fv5142 = fv5075
          fv5141 = fv5145.path
          fv5140 = fv5144
          fv5139 = :entry_ref
          fv5138 = { ri: "jp" }
          fv5137 = {
            "Host" => fv5143,
            "Origin" => "https://#{fv5143}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5136 = true
          fv5135 = fv5076
          begin
            fv5081 = fv5142
            fv5089 = fv5141
            fv5133 = fv5140
            fv5134 = fv5139
            fv5098 = fv5138
            fv5091 = fv5137
            fv5121 = fv5136
            fv5120 = fv5135
            fv5094 = nil
            fv5088 = fv5098.merge(fv5134 => fv5133)
            fv5081.get(
              fv5089,
              params: fv5088,
              headers: fv5091,
            )
            fv5127 =
              begin
                fv5132 = fv5081.response.body
                fv5131 = true
                fv5130 = Nokogiri::HTML(fv5132).at_css("form")
                if fv5130.nil? && fv5131
                  nil
                else
                  raise RuntimeError,
                        "Auth continuation form is missing" unless fv5130

                  fv5129 = fv5130.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5129.blank?

                  fv5128 = fv5130.css("input[type='hidden']").to_h do |fv5085|
                    [fv5085["name"], fv5085["value"]]
                  end.except("authenticity_token")
                  [fv5130["action"], fv5129, fv5128]
                end
              end
            if fv5127

              fv5126, fv5124, fv5125 = fv5127

              fv5081.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5081.post(
                fv5126,
                params: fv5125.merge(authenticity_token: fv5124),
                headers: fv5091,
              )
              fv5123 = fv5081.response.location
              if fv5123.present?

                fv5119 = URI.parse(fv5123)
                fv5118 = fv5119.host
                fv5093 =
                  begin
                    fv5122 = fv5118
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                    }.fetch(fv5122)
                  end
                fv5092 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5093,
                  reference: fv5119.path.split("/").fetch(-2),
                )

                if fv5121
                  fv5100 = fv5120 || fv5081
                  fv5100.host!(fv5118)
                  fv5100.https!
                  fv5100.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5117 = fv5119.request_uri
                  fv5108 = fv5091.merge(
                    "Host" => fv5118,
                    "Origin" => "https://#{fv5118}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5100.get(
                    fv5117,
                    headers: fv5108,
                  )
                  fv5111, fv5109, fv5110 =
                    begin
                      fv5116 = fv5100.response.body
                      fv5115 = false
                      fv5114 = Nokogiri::HTML(fv5116).at_css("form")
                      if fv5114.nil? && fv5115
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5114

                        fv5113 = fv5114.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5113.blank?

                        fv5112 = fv5114.css("input[type='hidden']").to_h do |fv5085|
                          [fv5085["name"], fv5085["value"]]
                        end.except("authenticity_token")
                        [fv5114["action"], fv5113, fv5112]
                      end
                    end
                  fv5100.post(
                    fv5111,
                    params: fv5110.merge(authenticity_token: fv5109),
                    headers: fv5108,
                  )
                  begin
                    fv5101 = fv5100
                    fv5103 = "session"
                    fv5102 = fv5101.response.cookies[fv5103]
                    if fv5102.nil?
                      fv5107 = fv5101.response.headers["Set-Cookie"] || fv5101.response.headers["set-cookie"]
                      fv5106 =
                        if fv5107.is_a?(String) && fv5107.start_with?("[")
                          JSON.parse(fv5107)
                        else
                          Array(fv5107)
                        end
                      fv5104 =
                        fv5106.flat_map { |fv5105| fv5105.to_s.split("\n") }.find do |fv5105|
                          fv5105.split(
                            ";",
                            2,
                          ).first.to_s.start_with?("#{fv5103}=")
                        end
                      if fv5104

                        _, fv5102 = fv5104.split(
                          ";",
                          2,
                        ).first.to_s.split(
                          "=",
                          2,
                        )
                        fv5102 = Rack::Utils.unescape(fv5102.to_s)
                      end
                    end

                    unless fv5102.nil?
                      fv5101.cookies.delete(fv5103)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5101.cookies.merge(
                        "#{fv5103}=#{Rack::Utils.escape(fv5102)}",
                        URI.parse("https://#{fv5101.host}/"),
                      )
                    end
                  end
                  fv5099 = fv5100.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5099.blank?

                  fv5096 = URI.parse(fv5099)
                  if fv5098[:ri].present?
                    fv5097 = Rack::Utils.parse_nested_query(fv5096.query.to_s)
                    fv5097["ri"] ||= fv5098[:ri].to_s
                    fv5096.query = URI.encode_www_form(fv5097)
                  end
                  fv5081.host!(fv5096.host)
                  fv5081.https!
                  fv5095 = fv5096.request_uri
                  fv5077 = fv5091.merge("Host" => fv5096.host)
                  fv5081.get(
                    fv5095,
                    headers: fv5077,
                  )
                else
                  fv5092.confirm_base!(
                    base_token: fv5094,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5093,
                      entry_ref: fv5092.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5090 = fv5081.host
                  fv5081.host!(fv5090)
                  fv5081.https!
                  fv5077 = fv5091.merge("Host" => fv5090)
                  fv5081.get(
                    fv5089,
                    params: fv5088,
                    headers: fv5077,
                  )
                end
                fv5080, fv5078, fv5079 =
                  begin
                    fv5087 = fv5081.response.body
                    fv5086 = false
                    fv5084 = Nokogiri::HTML(fv5087).at_css("form")
                    if fv5084.nil? && fv5086
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5084

                      fv5083 = fv5084.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5083.blank?

                      fv5082 = fv5084.css("input[type='hidden']").to_h do |fv5085|
                        [fv5085["name"], fv5085["value"]]
                      end.except("authenticity_token")
                      [fv5084["action"], fv5083, fv5082]
                    end
                  end
                fv5081.post(
                  fv5080,
                  params: fv5079.merge(authenticity_token: fv5078),
                  headers: fv5077,
                )
              end
            end
          end
        end
        fv5075.get(new_auth_app_verification_totp_path(ri: "jp"))
        [fv5076, fv5075, ClientStepUpCeremonyTransaction.find_by!(session_ref: fv5050.public_id)]
      end
    auth_csrf =
      begin
        fv5074 = auth
        fv5073 = Nokogiri::HTML(fv5074.response.body).at_css("script[data-page='app']")
        JSON.parse(fv5073.text).fetch("props").fetch("form").fetch("csrf_token")
      end
    begin
      fv5066 = base
      fv5067 =
        begin
          fv5069 = base
          fv5070 = auth
          fv5072 = { csrf: auth_csrf }
          fv5071 = fv5072.fetch(:csrf)
          fv5070.post(
            auth_app_verification_cancellation_path(ri: "jp"),
            params: { authenticity_token: fv5071 },
            headers: { "Origin" => "https://#{fv5070.host}" },
          )

          assert_equal 303, fv5070.response.status
          fv5069.get(URI.parse(fv5070.response.location).request_uri)

          assert_equal 200, fv5069.response.status
          fv5007 = Nokogiri::HTML(fv5069.response.body).at_css("form")
          fv5005 =
            fv5007.css("input[type='hidden']").to_h { |fv5068|
              [fv5068["name"], fv5068["value"]]
            }
          {
            action: fv5007["action"],
            params: fv5005,
          }
        end
      fv5066.post(
        fv5067.fetch(:action),
        params: fv5067.fetch(:params),
        headers: {
          "Origin" => "https://#{fv5066.host}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    canceled_at = transaction.reload.canceled_at

    auth.post(
      auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: auth_csrf },
                                                         headers: { "Origin" => "https://#{auth.host}" },
    )

    assert_equal 400, auth.response.status
    assert_equal I18n.t("errors.messages.invalid_request"), auth.response.body
    assert_equal "canceled", transaction.reload.status
    assert_equal canceled_at, transaction.canceled_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["invalid_admission"], refusals.map { |event| event.fetch("data").fetch("error_code") }
  end

  test "reading an expired ceremony is refused without rewriting its stored status" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: begin
        fv5064 = actor
        fv5065 = token
        StepUpRequirement.new(
          step_up_required: true,
          scope: "settings_birthdate",
          allowed_methods: [:totp],
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          ttl: StepUpRequirement::DEFAULT_TTL,
          purpose: "step_up",
          audience: "step_up:app",
          session_binding: fv5065.public_id,
          token_binding: fv5065.public_id,
          require_session_binding: true,
          actor_ref: fv5064.public_id,
          resource_ref: nil,
          tenant_ref: nil,
        )
      end, return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    begin
      fv5063 = auth_app_verification_path
      fv5062 = issuance.reference
      fv5061 = :entry_ref
      fv5060 = { ri: "jp" }
      fv5059 = {}
      fv5058 = false
      fv5057 = nil
      fv5056 = token
      begin
        fv5004 = self
        fv5011 = fv5063
        fv5054 = fv5062
        fv5055 = fv5061
        fv5020 = fv5060
        fv5013 = fv5059
        fv5042 = fv5058
        fv5041 = fv5057
        fv5016 = fv5056
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

          fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
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
                  ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                }.fetch(fv5043)
              end
            fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
            )

            if fv5042
              fv5022 = fv5041 || fv5004
              fv5022.host!(fv5039)
              fv5022.https!
              fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
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
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
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
    # Moves the deadline into the past; no public API shortens a live transaction.
    issuance.transaction.update_columns(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)
    updated_at = issuance.transaction.reload.updated_at

    [auth_app_verification_path(ri: "jp"), new_auth_app_verification_totp_path(ri: "jp"),
     auth_app_verification_handoff_path(ri: "jp"),].each do |path|
      before_refusals = @log.string.lines.count { |line| line.start_with?('{"event":"auth.step_up.refused"') }
      get path

      assert_response :bad_request, path
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_equal before_refusals + 1,
                   @log.string.lines.count { |line| line.start_with?('{"event":"auth.step_up.refused"') }, path
    end
    issuance.transaction.reload

    assert_equal "pending", issuance.transaction.status
    assert_equal updated_at, issuance.transaction.updated_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["transaction_expired"] * 3, refusals.map { |event| event.fetch("data").fetch("error_code") }
    assert_equal [StepUpObservabilityDigest.ceremony_ref(issuance.transaction.transaction_id)] * 3,
                 refusals.map { |event| event.fetch("data").fetch("ceremony_ref") }
  end

  test "an unauthenticated Base page request records which credentials the browser presented" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_identity_path(ri: "jp"), headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :redirect
    required = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
    }.sole.fetch("data")

    assert_equal "Base::App::IdentitiesController", required.fetch("controller")
    assert_equal "access_credential_missing", required.fetch("failure_reason")
    assert_not required.fetch("access_credential_presented")
    assert_not required.fetch("refresh_credential_presented")
    assert_equal "cross-site", required.fetch("fetch_site")
    assert_predicate required.fetch("occurred_at"), :present?
  end

  test "a Base page request with an unusable access credential is recorded as presented and invalid" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "not-a-token"
    get base_app_identity_path(ri: "jp")

    assert_response :redirect
    required = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
    }.sole.fetch("data")

    assert_equal "access_credential_invalid", required.fetch("failure_reason")
    assert required.fetch("access_credential_presented")
    assert_not required.fetch("refresh_credential_presented")
    assert_not_includes @log.string, "not-a-token"
  end

  # Sentinels of the header: empty, and a value outside the fetch-metadata vocabulary. An absent
  # header is not reachable here: the integration client supplies "same-origin" when none is given.
  test "the authentication-required record omits an empty or unknown fetch-site value" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    [{ "Sec-Fetch-Site" => "" }, { "Sec-Fetch-Site" => "https://evil.example/\u0000" }].each do |headers|
      get base_app_identity_path(ri: "jp"), headers: headers

      assert_response :redirect
    end
    records =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
      }

    assert_equal [nil, nil], records.map { |record| record.fetch("data")["fetch_site"] }
    assert_not_includes @log.string, "evil.example"
  end

  test "a Base completion without the browser transaction marker is refused as return_binding_mismatch" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB, user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    # Base authenticates only the Browser RP access cookie, so the request carries a real self-RP
    # chain. Both references are well-formed; only the browser marker is absent.
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token, oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_auth_time: 1.minute.ago, refresh_token_expires_at: 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
      session_public_id: token.public_id, base_session_public_id: token.public_id,
      oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti, expires_at: 10.minutes.from_now,
      scopes: %w(openid profile), issuer: OidcIssuer.for_client(oidc_client), audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
    )
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:totp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    result_reference = "5f0c1b1e-0000-4000-8000-000000000002"

    host! host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    post base_app_verification_completion_path(ri: "jp"),
         params: { transaction_ref: issuance.transaction.transaction_id, result_ref: result_reference }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "return_binding_mismatch", refusal.fetch("error_code")
    assert_equal "base_completion", refusal.fetch("stage")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), refusal.fetch("browser_session_digest")
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, result_reference
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, access_token
    assert_nil token.reload.last_step_up_at
  end
  private

  # Auth only issues the handoff; the returned form is Base's confirmation page, not yet submitted.

  # A Base browser holding the self-RP credentials for page requests and the root session cookie
  # for Base's authority endpoints.

  # Starts a TOTP Step-Up the way a browser does: the Base intent POST creates the transaction and
  # its browser marker, Jump carries the entry to Auth, and Base confirms the admission binding.
  # Returns the Base browser, the Auth browser on the TOTP page, and the transaction.
end
