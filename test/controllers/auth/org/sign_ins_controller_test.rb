# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::SignInsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! @host
  end

  test "direct entry without a login challenge is refused without admission" do
    get auth_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :bad_request
    assert_nil response.location
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[:oidc_authorization_login_challenge]
  end

  # Normal sign-in has one entry, Entra, because the passkey and secret
  # ceremonies are its second stage and refuse to run on their own. Emergency
  # Access is the other entry, and it is a different ceremony, not another way
  # to sign in normally.
  test "direct entry lists entra and emergency access as siblings in one list" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )
    begin
      fv5407 = admission_reference(issuance)
      fv5406 = { ri: "jp" }
      begin
        fv5405 = auth_org_sign_in_path
        fv5404 = fv5407
        fv5403 = :entry_ref
        fv5402 = fv5406
        fv5401 = { "Host" => @host }
        fv5400 = false
        fv5399 = nil
        fv5398 = nil
        begin
          fv5344 = self
          fv5352 = fv5405
          fv5396 = fv5404
          fv5397 = fv5403
          fv5361 = fv5402
          fv5354 = fv5401
          fv5384 = fv5400
          fv5383 = fv5399
          fv5357 = fv5398
          fv5351 = fv5361.merge(fv5397 => fv5396)
          fv5344.get(
            fv5352,
            params: fv5351, headers: fv5354,
          )
          fv5390 =
            begin
              fv5395 = fv5344.response.body
              fv5394 = true
              fv5393 = Nokogiri::HTML(fv5395).at_css("form")
              if fv5393.nil? && fv5394
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5393

                fv5392 = fv5393.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5392.blank?

                fv5391 = fv5393.css("input[type='hidden']").to_h do |fv5348|
                  [fv5348["name"], fv5348["value"]]
                end.except("authenticity_token")
                [fv5393["action"], fv5392,
                 fv5391,]
              end
            end
          if fv5390

            fv5389, fv5387, fv5388 = fv5390

            fv5344.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5344.post(
              fv5389,
              params: fv5388.merge(authenticity_token: fv5387), headers: fv5354,
            )
            fv5386 = fv5344.response.location
            if fv5386.present?

              fv5382 = URI.parse(fv5386)
              fv5381 = fv5382.host
              fv5356 =
                begin
                  fv5385 = fv5381
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5385)
                end
              fv5355 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5356, reference: fv5382.path.split("/").fetch(-2),
              )

              if fv5384
                fv5363 = fv5383 || fv5344
                fv5363.host!(fv5381)
                fv5363.https!
                fv5363.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5380 = fv5382.request_uri
                fv5371 = fv5354.merge(
                  "Host" => fv5381,
                  "Origin" => "https://#{fv5381}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5363.get(
                  fv5380,
                  headers: fv5371,
                )
                fv5374, fv5372, fv5373 =
                  begin
                    fv5379 = fv5363.response.body
                    fv5378 = false
                    fv5377 = Nokogiri::HTML(fv5379).at_css("form")
                    if fv5377.nil? && fv5378
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5377

                      fv5376 = fv5377.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5376.blank?

                      fv5375 = fv5377.css("input[type='hidden']").to_h do |fv5348|
                        [fv5348["name"], fv5348["value"]]
                      end.except("authenticity_token")
                      [fv5377["action"], fv5376,
                       fv5375,]
                    end
                  end
                fv5363.post(
                  fv5374,
                  params: fv5373.merge(authenticity_token: fv5372),
                  headers: fv5371,
                )
                begin
                  fv5364 = fv5363
                  fv5366 = "session"
                  fv5365 = fv5364.response.cookies[fv5366]
                  if fv5365.nil?
                    fv5370 = fv5364.response.headers["Set-Cookie"] || fv5364.response.headers["set-cookie"]
                    fv5369 =
                      if fv5370.is_a?(String) && fv5370.start_with?("[")
                        JSON.parse(fv5370)
                      else
                        Array(fv5370)
                      end
                    fv5367 =
                      fv5369.flat_map { |fv5368|
                        fv5368.to_s.split("\n")
                      }.find do |fv5368|
                        fv5368.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5366}=")
                      end
                    if fv5367

                      _, fv5365 = fv5367.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5365 = Rack::Utils.unescape(fv5365.to_s)
                    end
                  end

                  unless fv5365.nil?
                    fv5364.cookies.delete(fv5366)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5364.cookies.merge(
                      "#{fv5366}=#{Rack::Utils.escape(fv5365)}",
                      URI.parse("https://#{fv5364.host}/"),
                    )
                  end
                end
                fv5362 = fv5363.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5362.blank?

                fv5359 = URI.parse(fv5362)
                if fv5361[:ri].present?
                  fv5360 = Rack::Utils.parse_nested_query(fv5359.query.to_s)
                  fv5360["ri"] ||= fv5361[:ri].to_s
                  fv5359.query = URI.encode_www_form(fv5360)
                end
                fv5344.host!(fv5359.host)
                fv5344.https!
                fv5358 = fv5359.request_uri
                fv5340 = fv5354.merge("Host" => fv5359.host)
                fv5344.get(
                  fv5358,
                  headers: fv5340,
                )
              else
                fv5355.confirm_base!(
                  base_token: fv5357,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5356,
                    entry_ref: fv5355.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5353 = fv5344.host
                fv5344.host!(fv5353)
                fv5344.https!
                fv5340 = fv5354.merge("Host" => fv5353)
                fv5344.get(
                  fv5352,
                  params: fv5351, headers: fv5340,
                )
              end
              fv5343, fv5341, fv5342 =
                begin
                  fv5350 = fv5344.response.body
                  fv5349 = false
                  fv5347 = Nokogiri::HTML(fv5350).at_css("form")
                  if fv5347.nil? && fv5349
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5347

                    fv5346 = fv5347.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5346.blank?

                    fv5345 = fv5347.css("input[type='hidden']").to_h do |fv5348|
                      [fv5348["name"], fv5348["value"]]
                    end.except("authenticity_token")
                    [fv5347["action"], fv5346,
                     fv5345,]
                  end
                end
              fv5344.post(
                fv5343,
                params: fv5342.merge(authenticity_token: fv5341),
                headers: fv5340,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    methods = inertia_props.fetch("methods")

    # The first Sign In page of an OIDC parent offers Cancel; Org has no public Sign Up, so no Switch.
    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")

    assert_equal 2, methods.length
    assert_equal "provider", method_for("entra").fetch("kind")
    assert_equal auth_org_social_entra_session_path(ri: "jp"), method_for("entra").fetch("href")
    assert_equal "link", method_for("emergency").fetch("kind")
    assert_equal new_auth_org_sign_in_emergency_passkey_path(ri: "jp"), method_for("emergency").fetch("href")

    # The second stage is not offered as an entry point of its own.
    assert_not_includes method_hrefs, new_auth_org_sign_in_passkey_path(ri: "jp")
  end

  test "valid login challenge renders local ceremony" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5339 = admission_reference(issuance)
      fv5338 = { ri: "jp" }
      begin
        fv5337 = auth_org_sign_in_path
        fv5336 = fv5339
        fv5335 = :entry_ref
        fv5334 = fv5338
        fv5333 = { "Host" => @host }
        fv5332 = false
        fv5331 = nil
        fv5330 = nil
        begin
          fv5276 = self
          fv5284 = fv5337
          fv5328 = fv5336
          fv5329 = fv5335
          fv5293 = fv5334
          fv5286 = fv5333
          fv5316 = fv5332
          fv5315 = fv5331
          fv5289 = fv5330
          fv5283 = fv5293.merge(fv5329 => fv5328)
          fv5276.get(
            fv5284,
            params: fv5283, headers: fv5286,
          )
          fv5322 =
            begin
              fv5327 = fv5276.response.body
              fv5326 = true
              fv5325 = Nokogiri::HTML(fv5327).at_css("form")
              if fv5325.nil? && fv5326
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5325

                fv5324 = fv5325.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5324.blank?

                fv5323 = fv5325.css("input[type='hidden']").to_h do |fv5280|
                  [fv5280["name"], fv5280["value"]]
                end.except("authenticity_token")
                [fv5325["action"], fv5324,
                 fv5323,]
              end
            end
          if fv5322

            fv5321, fv5319, fv5320 = fv5322

            fv5276.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5276.post(
              fv5321,
              params: fv5320.merge(authenticity_token: fv5319), headers: fv5286,
            )
            fv5318 = fv5276.response.location
            if fv5318.present?

              fv5314 = URI.parse(fv5318)
              fv5313 = fv5314.host
              fv5288 =
                begin
                  fv5317 = fv5313
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5317)
                end
              fv5287 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5288, reference: fv5314.path.split("/").fetch(-2),
              )

              if fv5316
                fv5295 = fv5315 || fv5276
                fv5295.host!(fv5313)
                fv5295.https!
                fv5295.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5312 = fv5314.request_uri
                fv5303 = fv5286.merge(
                  "Host" => fv5313,
                  "Origin" => "https://#{fv5313}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5295.get(
                  fv5312,
                  headers: fv5303,
                )
                fv5306, fv5304, fv5305 =
                  begin
                    fv5311 = fv5295.response.body
                    fv5310 = false
                    fv5309 = Nokogiri::HTML(fv5311).at_css("form")
                    if fv5309.nil? && fv5310
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5309

                      fv5308 = fv5309.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5308.blank?

                      fv5307 = fv5309.css("input[type='hidden']").to_h do |fv5280|
                        [fv5280["name"], fv5280["value"]]
                      end.except("authenticity_token")
                      [fv5309["action"], fv5308,
                       fv5307,]
                    end
                  end
                fv5295.post(
                  fv5306,
                  params: fv5305.merge(authenticity_token: fv5304),
                  headers: fv5303,
                )
                begin
                  fv5296 = fv5295
                  fv5298 = "session"
                  fv5297 = fv5296.response.cookies[fv5298]
                  if fv5297.nil?
                    fv5302 = fv5296.response.headers["Set-Cookie"] || fv5296.response.headers["set-cookie"]
                    fv5301 =
                      if fv5302.is_a?(String) && fv5302.start_with?("[")
                        JSON.parse(fv5302)
                      else
                        Array(fv5302)
                      end
                    fv5299 =
                      fv5301.flat_map { |fv5300|
                        fv5300.to_s.split("\n")
                      }.find do |fv5300|
                        fv5300.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5298}=")
                      end
                    if fv5299

                      _, fv5297 = fv5299.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5297 = Rack::Utils.unescape(fv5297.to_s)
                    end
                  end

                  unless fv5297.nil?
                    fv5296.cookies.delete(fv5298)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5296.cookies.merge(
                      "#{fv5298}=#{Rack::Utils.escape(fv5297)}",
                      URI.parse("https://#{fv5296.host}/"),
                    )
                  end
                end
                fv5294 = fv5295.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5294.blank?

                fv5291 = URI.parse(fv5294)
                if fv5293[:ri].present?
                  fv5292 = Rack::Utils.parse_nested_query(fv5291.query.to_s)
                  fv5292["ri"] ||= fv5293[:ri].to_s
                  fv5291.query = URI.encode_www_form(fv5292)
                end
                fv5276.host!(fv5291.host)
                fv5276.https!
                fv5290 = fv5291.request_uri
                fv5272 = fv5286.merge("Host" => fv5291.host)
                fv5276.get(
                  fv5290,
                  headers: fv5272,
                )
              else
                fv5287.confirm_base!(
                  base_token: fv5289,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5288,
                    entry_ref: fv5287.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5285 = fv5276.host
                fv5276.host!(fv5285)
                fv5276.https!
                fv5272 = fv5286.merge("Host" => fv5285)
                fv5276.get(
                  fv5284,
                  params: fv5283, headers: fv5272,
                )
              end
              fv5275, fv5273, fv5274 =
                begin
                  fv5282 = fv5276.response.body
                  fv5281 = false
                  fv5279 = Nokogiri::HTML(fv5282).at_css("form")
                  if fv5279.nil? && fv5281
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5279

                    fv5278 = fv5279.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5278.blank?

                    fv5277 = fv5279.css("input[type='hidden']").to_h do |fv5280|
                      [fv5280["name"], fv5280["value"]]
                    end.except("authenticity_token")
                    [fv5279["action"], fv5278,
                     fv5277,]
                  end
                end
              fv5276.post(
                fv5275,
                params: fv5274.merge(authenticity_token: fv5273),
                headers: fv5272,
              )
            end
          end
        end
      end
    end

    assert_response :see_other

    follow_redirect!

    assert_response :success
    transaction_ref = auth_ceremony_record.authorization_transaction_ref
    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: "org",
      transaction_id: transaction_ref,
    )

    assert_equal issuance.transaction.login_challenge, transaction.login_challenge
  end

  test "local ceremony renders authentication links only" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5271 = admission_reference(issuance)
      fv5270 = { ri: "jp" }
      begin
        fv5269 = auth_org_sign_in_path
        fv5268 = fv5271
        fv5267 = :entry_ref
        fv5266 = fv5270
        fv5265 = { "Host" => @host }
        fv5264 = false
        fv5263 = nil
        fv5262 = nil
        begin
          fv5208 = self
          fv5216 = fv5269
          fv5260 = fv5268
          fv5261 = fv5267
          fv5225 = fv5266
          fv5218 = fv5265
          fv5248 = fv5264
          fv5247 = fv5263
          fv5221 = fv5262
          fv5215 = fv5225.merge(fv5261 => fv5260)
          fv5208.get(
            fv5216,
            params: fv5215, headers: fv5218,
          )
          fv5254 =
            begin
              fv5259 = fv5208.response.body
              fv5258 = true
              fv5257 = Nokogiri::HTML(fv5259).at_css("form")
              if fv5257.nil? && fv5258
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5257

                fv5256 = fv5257.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5256.blank?

                fv5255 = fv5257.css("input[type='hidden']").to_h do |fv5212|
                  [fv5212["name"], fv5212["value"]]
                end.except("authenticity_token")
                [fv5257["action"], fv5256,
                 fv5255,]
              end
            end
          if fv5254

            fv5253, fv5251, fv5252 = fv5254

            fv5208.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5208.post(
              fv5253,
              params: fv5252.merge(authenticity_token: fv5251), headers: fv5218,
            )
            fv5250 = fv5208.response.location
            if fv5250.present?

              fv5246 = URI.parse(fv5250)
              fv5245 = fv5246.host
              fv5220 =
                begin
                  fv5249 = fv5245
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5249)
                end
              fv5219 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5220, reference: fv5246.path.split("/").fetch(-2),
              )

              if fv5248
                fv5227 = fv5247 || fv5208
                fv5227.host!(fv5245)
                fv5227.https!
                fv5227.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5244 = fv5246.request_uri
                fv5235 = fv5218.merge(
                  "Host" => fv5245,
                  "Origin" => "https://#{fv5245}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5227.get(
                  fv5244,
                  headers: fv5235,
                )
                fv5238, fv5236, fv5237 =
                  begin
                    fv5243 = fv5227.response.body
                    fv5242 = false
                    fv5241 = Nokogiri::HTML(fv5243).at_css("form")
                    if fv5241.nil? && fv5242
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5241

                      fv5240 = fv5241.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5240.blank?

                      fv5239 = fv5241.css("input[type='hidden']").to_h do |fv5212|
                        [fv5212["name"], fv5212["value"]]
                      end.except("authenticity_token")
                      [fv5241["action"], fv5240,
                       fv5239,]
                    end
                  end
                fv5227.post(
                  fv5238,
                  params: fv5237.merge(authenticity_token: fv5236),
                  headers: fv5235,
                )
                begin
                  fv5228 = fv5227
                  fv5230 = "session"
                  fv5229 = fv5228.response.cookies[fv5230]
                  if fv5229.nil?
                    fv5234 = fv5228.response.headers["Set-Cookie"] || fv5228.response.headers["set-cookie"]
                    fv5233 =
                      if fv5234.is_a?(String) && fv5234.start_with?("[")
                        JSON.parse(fv5234)
                      else
                        Array(fv5234)
                      end
                    fv5231 =
                      fv5233.flat_map { |fv5232|
                        fv5232.to_s.split("\n")
                      }.find do |fv5232|
                        fv5232.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5230}=")
                      end
                    if fv5231

                      _, fv5229 = fv5231.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5229 = Rack::Utils.unescape(fv5229.to_s)
                    end
                  end

                  unless fv5229.nil?
                    fv5228.cookies.delete(fv5230)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5228.cookies.merge(
                      "#{fv5230}=#{Rack::Utils.escape(fv5229)}",
                      URI.parse("https://#{fv5228.host}/"),
                    )
                  end
                end
                fv5226 = fv5227.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5226.blank?

                fv5223 = URI.parse(fv5226)
                if fv5225[:ri].present?
                  fv5224 = Rack::Utils.parse_nested_query(fv5223.query.to_s)
                  fv5224["ri"] ||= fv5225[:ri].to_s
                  fv5223.query = URI.encode_www_form(fv5224)
                end
                fv5208.host!(fv5223.host)
                fv5208.https!
                fv5222 = fv5223.request_uri
                fv5204 = fv5218.merge("Host" => fv5223.host)
                fv5208.get(
                  fv5222,
                  headers: fv5204,
                )
              else
                fv5219.confirm_base!(
                  base_token: fv5221,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5220,
                    entry_ref: fv5219.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5217 = fv5208.host
                fv5208.host!(fv5217)
                fv5208.https!
                fv5204 = fv5218.merge("Host" => fv5217)
                fv5208.get(
                  fv5216,
                  params: fv5215, headers: fv5204,
                )
              end
              fv5207, fv5205, fv5206 =
                begin
                  fv5214 = fv5208.response.body
                  fv5213 = false
                  fv5211 = Nokogiri::HTML(fv5214).at_css("form")
                  if fv5211.nil? && fv5213
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5211

                    fv5210 = fv5211.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5210.blank?

                    fv5209 = fv5211.css("input[type='hidden']").to_h do |fv5212|
                      [fv5212["name"], fv5212["value"]]
                    end.except("authenticity_token")
                    [fv5211["action"], fv5210,
                     fv5209,]
                  end
                end
              fv5208.post(
                fv5207,
                params: fv5206.merge(authenticity_token: fv5205),
                headers: fv5204,
              )
            end
          end
        end
      end
    end

    assert_response :see_other

    follow_redirect!

    assert_response :success

    query = { ri: "jp" }

    assert_includes method_hrefs, auth_org_social_entra_session_path(query)
    assert_includes method_hrefs, new_auth_org_sign_in_emergency_passkey_path(query)
    # The org surface offers no consumer social providers.
    assert_empty method_hrefs.grep(%r{/social/auth/|/auth/google|/auth/apple})
  end

  test "local ceremony ignores inbound pt and keeps authentication links on ceremony flow" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5203 = admission_reference(issuance)
      fv5202 = { ri: "jp",
                 pt: Base64.urlsafe_encode64(
                   "https://log.umaxica.org/settings/sessions?ri=jp",
                   padding: false,
                 ), }
      begin
        fv5201 = auth_org_sign_in_path
        fv5200 = fv5203
        fv5199 = :entry_ref
        fv5198 = fv5202
        fv5197 = { "Host" => @host }
        fv5196 = false
        fv5195 = nil
        fv5194 = nil
        begin
          fv5140 = self
          fv5148 = fv5201
          fv5192 = fv5200
          fv5193 = fv5199
          fv5157 = fv5198
          fv5150 = fv5197
          fv5180 = fv5196
          fv5179 = fv5195
          fv5153 = fv5194
          fv5147 = fv5157.merge(fv5193 => fv5192)
          fv5140.get(
            fv5148,
            params: fv5147, headers: fv5150,
          )
          fv5186 =
            begin
              fv5191 = fv5140.response.body
              fv5190 = true
              fv5189 = Nokogiri::HTML(fv5191).at_css("form")
              if fv5189.nil? && fv5190
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5189

                fv5188 = fv5189.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5188.blank?

                fv5187 = fv5189.css("input[type='hidden']").to_h do |fv5144|
                  [fv5144["name"], fv5144["value"]]
                end.except("authenticity_token")
                [fv5189["action"], fv5188,
                 fv5187,]
              end
            end
          if fv5186

            fv5185, fv5183, fv5184 = fv5186

            fv5140.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5140.post(
              fv5185,
              params: fv5184.merge(authenticity_token: fv5183), headers: fv5150,
            )
            fv5182 = fv5140.response.location
            if fv5182.present?

              fv5178 = URI.parse(fv5182)
              fv5177 = fv5178.host
              fv5152 =
                begin
                  fv5181 = fv5177
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5181)
                end
              fv5151 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5152, reference: fv5178.path.split("/").fetch(-2),
              )

              if fv5180
                fv5159 = fv5179 || fv5140
                fv5159.host!(fv5177)
                fv5159.https!
                fv5159.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5176 = fv5178.request_uri
                fv5167 = fv5150.merge(
                  "Host" => fv5177,
                  "Origin" => "https://#{fv5177}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5159.get(
                  fv5176,
                  headers: fv5167,
                )
                fv5170, fv5168, fv5169 =
                  begin
                    fv5175 = fv5159.response.body
                    fv5174 = false
                    fv5173 = Nokogiri::HTML(fv5175).at_css("form")
                    if fv5173.nil? && fv5174
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5173

                      fv5172 = fv5173.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5172.blank?

                      fv5171 = fv5173.css("input[type='hidden']").to_h do |fv5144|
                        [fv5144["name"], fv5144["value"]]
                      end.except("authenticity_token")
                      [fv5173["action"], fv5172,
                       fv5171,]
                    end
                  end
                fv5159.post(
                  fv5170,
                  params: fv5169.merge(authenticity_token: fv5168),
                  headers: fv5167,
                )
                begin
                  fv5160 = fv5159
                  fv5162 = "session"
                  fv5161 = fv5160.response.cookies[fv5162]
                  if fv5161.nil?
                    fv5166 = fv5160.response.headers["Set-Cookie"] || fv5160.response.headers["set-cookie"]
                    fv5165 =
                      if fv5166.is_a?(String) && fv5166.start_with?("[")
                        JSON.parse(fv5166)
                      else
                        Array(fv5166)
                      end
                    fv5163 =
                      fv5165.flat_map { |fv5164|
                        fv5164.to_s.split("\n")
                      }.find do |fv5164|
                        fv5164.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5162}=")
                      end
                    if fv5163

                      _, fv5161 = fv5163.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5161 = Rack::Utils.unescape(fv5161.to_s)
                    end
                  end

                  unless fv5161.nil?
                    fv5160.cookies.delete(fv5162)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5160.cookies.merge(
                      "#{fv5162}=#{Rack::Utils.escape(fv5161)}",
                      URI.parse("https://#{fv5160.host}/"),
                    )
                  end
                end
                fv5158 = fv5159.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5158.blank?

                fv5155 = URI.parse(fv5158)
                if fv5157[:ri].present?
                  fv5156 = Rack::Utils.parse_nested_query(fv5155.query.to_s)
                  fv5156["ri"] ||= fv5157[:ri].to_s
                  fv5155.query = URI.encode_www_form(fv5156)
                end
                fv5140.host!(fv5155.host)
                fv5140.https!
                fv5154 = fv5155.request_uri
                fv5136 = fv5150.merge("Host" => fv5155.host)
                fv5140.get(
                  fv5154,
                  headers: fv5136,
                )
              else
                fv5151.confirm_base!(
                  base_token: fv5153,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5152,
                    entry_ref: fv5151.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5149 = fv5140.host
                fv5140.host!(fv5149)
                fv5140.https!
                fv5136 = fv5150.merge("Host" => fv5149)
                fv5140.get(
                  fv5148,
                  params: fv5147, headers: fv5136,
                )
              end
              fv5139, fv5137, fv5138 =
                begin
                  fv5146 = fv5140.response.body
                  fv5145 = false
                  fv5143 = Nokogiri::HTML(fv5146).at_css("form")
                  if fv5143.nil? && fv5145
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5143

                    fv5142 = fv5143.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5142.blank?

                    fv5141 = fv5143.css("input[type='hidden']").to_h do |fv5144|
                      [fv5144["name"], fv5144["value"]]
                    end.except("authenticity_token")
                    [fv5143["action"], fv5142,
                     fv5141,]
                  end
                end
              fv5140.post(
                fv5139,
                params: fv5138.merge(authenticity_token: fv5137),
                headers: fv5136,
              )
            end
          end
        end
      end
    end

    assert_response :see_other

    follow_redirect!

    assert_response :success
    assert_includes method_hrefs, auth_org_social_entra_session_path(ri: "jp")
    assert_includes method_hrefs, new_auth_org_sign_in_emergency_passkey_path(ri: "jp")
  end

  test "local ceremony does not render sign up link on sign in page" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5135 = admission_reference(issuance)
      fv5134 = { ri: "jp" }
      begin
        fv5133 = auth_org_sign_in_path
        fv5132 = fv5135
        fv5131 = :entry_ref
        fv5130 = fv5134
        fv5129 = { "Host" => @host }
        fv5128 = false
        fv5127 = nil
        fv5126 = nil
        begin
          fv5072 = self
          fv5080 = fv5133
          fv5124 = fv5132
          fv5125 = fv5131
          fv5089 = fv5130
          fv5082 = fv5129
          fv5112 = fv5128
          fv5111 = fv5127
          fv5085 = fv5126
          fv5079 = fv5089.merge(fv5125 => fv5124)
          fv5072.get(
            fv5080,
            params: fv5079, headers: fv5082,
          )
          fv5118 =
            begin
              fv5123 = fv5072.response.body
              fv5122 = true
              fv5121 = Nokogiri::HTML(fv5123).at_css("form")
              if fv5121.nil? && fv5122
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5121

                fv5120 = fv5121.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5120.blank?

                fv5119 = fv5121.css("input[type='hidden']").to_h do |fv5076|
                  [fv5076["name"], fv5076["value"]]
                end.except("authenticity_token")
                [fv5121["action"], fv5120,
                 fv5119,]
              end
            end
          if fv5118

            fv5117, fv5115, fv5116 = fv5118

            fv5072.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5072.post(
              fv5117,
              params: fv5116.merge(authenticity_token: fv5115), headers: fv5082,
            )
            fv5114 = fv5072.response.location
            if fv5114.present?

              fv5110 = URI.parse(fv5114)
              fv5109 = fv5110.host
              fv5084 =
                begin
                  fv5113 = fv5109
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5113)
                end
              fv5083 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5084, reference: fv5110.path.split("/").fetch(-2),
              )

              if fv5112
                fv5091 = fv5111 || fv5072
                fv5091.host!(fv5109)
                fv5091.https!
                fv5091.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5108 = fv5110.request_uri
                fv5099 = fv5082.merge(
                  "Host" => fv5109,
                  "Origin" => "https://#{fv5109}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5091.get(
                  fv5108,
                  headers: fv5099,
                )
                fv5102, fv5100, fv5101 =
                  begin
                    fv5107 = fv5091.response.body
                    fv5106 = false
                    fv5105 = Nokogiri::HTML(fv5107).at_css("form")
                    if fv5105.nil? && fv5106
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5105

                      fv5104 = fv5105.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5104.blank?

                      fv5103 = fv5105.css("input[type='hidden']").to_h do |fv5076|
                        [fv5076["name"], fv5076["value"]]
                      end.except("authenticity_token")
                      [fv5105["action"], fv5104,
                       fv5103,]
                    end
                  end
                fv5091.post(
                  fv5102,
                  params: fv5101.merge(authenticity_token: fv5100),
                  headers: fv5099,
                )
                begin
                  fv5092 = fv5091
                  fv5094 = "session"
                  fv5093 = fv5092.response.cookies[fv5094]
                  if fv5093.nil?
                    fv5098 = fv5092.response.headers["Set-Cookie"] || fv5092.response.headers["set-cookie"]
                    fv5097 =
                      if fv5098.is_a?(String) && fv5098.start_with?("[")
                        JSON.parse(fv5098)
                      else
                        Array(fv5098)
                      end
                    fv5095 =
                      fv5097.flat_map { |fv5096|
                        fv5096.to_s.split("\n")
                      }.find do |fv5096|
                        fv5096.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5094}=")
                      end
                    if fv5095

                      _, fv5093 = fv5095.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5093 = Rack::Utils.unescape(fv5093.to_s)
                    end
                  end

                  unless fv5093.nil?
                    fv5092.cookies.delete(fv5094)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5092.cookies.merge(
                      "#{fv5094}=#{Rack::Utils.escape(fv5093)}",
                      URI.parse("https://#{fv5092.host}/"),
                    )
                  end
                end
                fv5090 = fv5091.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5090.blank?

                fv5087 = URI.parse(fv5090)
                if fv5089[:ri].present?
                  fv5088 = Rack::Utils.parse_nested_query(fv5087.query.to_s)
                  fv5088["ri"] ||= fv5089[:ri].to_s
                  fv5087.query = URI.encode_www_form(fv5088)
                end
                fv5072.host!(fv5087.host)
                fv5072.https!
                fv5086 = fv5087.request_uri
                fv5068 = fv5082.merge("Host" => fv5087.host)
                fv5072.get(
                  fv5086,
                  headers: fv5068,
                )
              else
                fv5083.confirm_base!(
                  base_token: fv5085,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5084,
                    entry_ref: fv5083.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5081 = fv5072.host
                fv5072.host!(fv5081)
                fv5072.https!
                fv5068 = fv5082.merge("Host" => fv5081)
                fv5072.get(
                  fv5080,
                  params: fv5079, headers: fv5068,
                )
              end
              fv5071, fv5069, fv5070 =
                begin
                  fv5078 = fv5072.response.body
                  fv5077 = false
                  fv5075 = Nokogiri::HTML(fv5078).at_css("form")
                  if fv5075.nil? && fv5077
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5075

                    fv5074 = fv5075.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5074.blank?

                    fv5073 = fv5075.css("input[type='hidden']").to_h do |fv5076|
                      [fv5076["name"], fv5076["value"]]
                    end.except("authenticity_token")
                    [fv5075["action"], fv5074,
                     fv5073,]
                  end
                end
              fv5072.post(
                fv5071,
                params: fv5070.merge(authenticity_token: fv5069),
                headers: fv5068,
              )
            end
          end
        end
      end
    end

    assert_response :see_other

    follow_redirect!

    assert_response :success
    assert_nil inertia_props["registration_link"]
  end

  test "first Sign In page offers RP Cancel, no Switch and no back link" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5067 = admission_reference(issuance)
      fv5066 = { ri: "jp" }
      begin
        fv5065 = auth_org_sign_in_path
        fv5064 = fv5067
        fv5063 = :entry_ref
        fv5062 = fv5066
        fv5061 = { "Host" => @host }
        fv5060 = false
        fv5059 = nil
        fv5058 = nil
        begin
          fv5004 = self
          fv5012 = fv5065
          fv5056 = fv5064
          fv5057 = fv5063
          fv5021 = fv5062
          fv5014 = fv5061
          fv5044 = fv5060
          fv5043 = fv5059
          fv5017 = fv5058
          fv5011 = fv5021.merge(fv5057 => fv5056)
          fv5004.get(
            fv5012,
            params: fv5011, headers: fv5014,
          )
          fv5050 =
            begin
              fv5055 = fv5004.response.body
              fv5054 = true
              fv5053 = Nokogiri::HTML(fv5055).at_css("form")
              if fv5053.nil? && fv5054
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5053

                fv5052 = fv5053.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5052.blank?

                fv5051 = fv5053.css("input[type='hidden']").to_h do |fv5008|
                  [fv5008["name"], fv5008["value"]]
                end.except("authenticity_token")
                [fv5053["action"], fv5052,
                 fv5051,]
              end
            end
          if fv5050

            fv5049, fv5047, fv5048 = fv5050

            fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5004.post(
              fv5049,
              params: fv5048.merge(authenticity_token: fv5047), headers: fv5014,
            )
            fv5046 = fv5004.response.location
            if fv5046.present?

              fv5042 = URI.parse(fv5046)
              fv5041 = fv5042.host
              fv5016 =
                begin
                  fv5045 = fv5041
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5045)
                end
              fv5015 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5016, reference: fv5042.path.split("/").fetch(-2),
              )

              if fv5044
                fv5023 = fv5043 || fv5004
                fv5023.host!(fv5041)
                fv5023.https!
                fv5023.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5040 = fv5042.request_uri
                fv5031 = fv5014.merge(
                  "Host" => fv5041,
                  "Origin" => "https://#{fv5041}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5023.get(
                  fv5040,
                  headers: fv5031,
                )
                fv5034, fv5032, fv5033 =
                  begin
                    fv5039 = fv5023.response.body
                    fv5038 = false
                    fv5037 = Nokogiri::HTML(fv5039).at_css("form")
                    if fv5037.nil? && fv5038
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5037

                      fv5036 = fv5037.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5036.blank?

                      fv5035 = fv5037.css("input[type='hidden']").to_h do |fv5008|
                        [fv5008["name"], fv5008["value"]]
                      end.except("authenticity_token")
                      [fv5037["action"], fv5036,
                       fv5035,]
                    end
                  end
                fv5023.post(
                  fv5034,
                  params: fv5033.merge(authenticity_token: fv5032),
                  headers: fv5031,
                )
                begin
                  fv5024 = fv5023
                  fv5026 = "session"
                  fv5025 = fv5024.response.cookies[fv5026]
                  if fv5025.nil?
                    fv5030 = fv5024.response.headers["Set-Cookie"] || fv5024.response.headers["set-cookie"]
                    fv5029 =
                      if fv5030.is_a?(String) && fv5030.start_with?("[")
                        JSON.parse(fv5030)
                      else
                        Array(fv5030)
                      end
                    fv5027 =
                      fv5029.flat_map { |fv5028|
                        fv5028.to_s.split("\n")
                      }.find do |fv5028|
                        fv5028.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5026}=")
                      end
                    if fv5027

                      _, fv5025 = fv5027.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5025 = Rack::Utils.unescape(fv5025.to_s)
                    end
                  end

                  unless fv5025.nil?
                    fv5024.cookies.delete(fv5026)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5024.cookies.merge(
                      "#{fv5026}=#{Rack::Utils.escape(fv5025)}",
                      URI.parse("https://#{fv5024.host}/"),
                    )
                  end
                end
                fv5022 = fv5023.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5022.blank?

                fv5019 = URI.parse(fv5022)
                if fv5021[:ri].present?
                  fv5020 = Rack::Utils.parse_nested_query(fv5019.query.to_s)
                  fv5020["ri"] ||= fv5021[:ri].to_s
                  fv5019.query = URI.encode_www_form(fv5020)
                end
                fv5004.host!(fv5019.host)
                fv5004.https!
                fv5018 = fv5019.request_uri
                fv5000 = fv5014.merge("Host" => fv5019.host)
                fv5004.get(
                  fv5018,
                  headers: fv5000,
                )
              else
                fv5015.confirm_base!(
                  base_token: fv5017,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5016,
                    entry_ref: fv5015.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5013 = fv5004.host
                fv5004.host!(fv5013)
                fv5004.https!
                fv5000 = fv5014.merge("Host" => fv5013)
                fv5004.get(
                  fv5012,
                  params: fv5011, headers: fv5000,
                )
              end
              fv5003, fv5001, fv5002 =
                begin
                  fv5010 = fv5004.response.body
                  fv5009 = false
                  fv5007 = Nokogiri::HTML(fv5010).at_css("form")
                  if fv5007.nil? && fv5009
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5007

                    fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5006.blank?

                    fv5005 = fv5007.css("input[type='hidden']").to_h do |fv5008|
                      [fv5008["name"], fv5008["value"]]
                    end.except("authenticity_token")
                    [fv5007["action"], fv5006,
                     fv5005,]
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
    end

    assert_response :see_other

    follow_redirect!

    assert_response :success

    assert_not inertia_props.key?("back_to_root")
    # The first Sign In page of an OIDC parent offers Cancel; Org has no public Sign Up, so no Switch.
    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")
  end

  test "rejects direct entry when logged in without account-switching guidance" do
    staff = operators(:one)

    get auth_org_sign_in_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :forbidden
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  private

  def method_hrefs
    inertia_props.fetch("methods").map { |method| method.fetch("href") }
  end

  def method_for(key)
    inertia_props.fetch("methods").find { |method| method.fetch("key") == key }
  end

  def admission_reference(issuance)
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: issuance.transaction,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    ).reference
  end

  def auth_ceremony_record
    raw_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
    OperatorAuthCeremonySession.find_active_by_raw_sid(raw_sid)
  end

  def authorize_params
    {
      response_type: "code",
      client_id: "core-org-jp",
      redirect_uri: OidcClientRegistry.find!("core-org-jp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
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
class Auth::Org::SignInsControllerTest
  private
end
