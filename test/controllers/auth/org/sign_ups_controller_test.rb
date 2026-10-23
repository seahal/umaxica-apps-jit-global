# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = configured_host(:sign_staff)
    host! @host
  end

  test "direct entry without a login challenge is refused without admission" do
    get auth_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_code_verifier]
    assert_nil session[:oidc_state]
  end

  test "local ceremony does not render sign in link on sign up page" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(prompt: "create"),
    )

    begin
      fv5340 = admission_reference(issuance)
      fv5339 = { ri: "jp" }
      begin
        fv5338 = auth_org_sign_up_path
        fv5337 = fv5340
        fv5336 = :entry_ref
        fv5335 = fv5339
        fv5334 = { "Host" => @host }
        fv5333 = false
        fv5332 = nil
        fv5331 = nil
        begin
          fv5277 = self
          fv5285 = fv5338
          fv5329 = fv5337
          fv5330 = fv5336
          fv5294 = fv5335
          fv5287 = fv5334
          fv5317 = fv5333
          fv5316 = fv5332
          fv5290 = fv5331
          fv5284 = fv5294.merge(fv5330 => fv5329)
          fv5277.get(
            fv5285,
            params: fv5284, headers: fv5287,
          )
          fv5323 =
            begin
              fv5328 = fv5277.response.body
              fv5327 = true
              fv5326 = Nokogiri::HTML(fv5328).at_css("form")
              if fv5326.nil? && fv5327
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5326

                fv5325 = fv5326.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5325.blank?

                fv5324 = fv5326.css("input[type='hidden']").to_h do |fv5281|
                  [fv5281["name"], fv5281["value"]]
                end.except("authenticity_token")
                [fv5326["action"], fv5325,
                 fv5324,]
              end
            end
          if fv5323

            fv5322, fv5320, fv5321 = fv5323

            fv5277.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5277.post(
              fv5322,
              params: fv5321.merge(authenticity_token: fv5320), headers: fv5287,
            )
            fv5319 = fv5277.response.location
            if fv5319.present?

              fv5315 = URI.parse(fv5319)
              fv5314 = fv5315.host
              fv5289 =
                begin
                  fv5318 = fv5314
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5318)
                end
              fv5288 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5289, reference: fv5315.path.split("/").fetch(-2),
              )

              if fv5317
                fv5296 = fv5316 || fv5277
                fv5296.host!(fv5314)
                fv5296.https!
                fv5296.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5313 = fv5315.request_uri
                fv5304 = fv5287.merge(
                  "Host" => fv5314,
                  "Origin" => "https://#{fv5314}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5296.get(
                  fv5313,
                  headers: fv5304,
                )
                fv5307, fv5305, fv5306 =
                  begin
                    fv5312 = fv5296.response.body
                    fv5311 = false
                    fv5310 = Nokogiri::HTML(fv5312).at_css("form")
                    if fv5310.nil? && fv5311
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5310

                      fv5309 = fv5310.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5309.blank?

                      fv5308 = fv5310.css("input[type='hidden']").to_h do |fv5281|
                        [fv5281["name"], fv5281["value"]]
                      end.except("authenticity_token")
                      [fv5310["action"], fv5309,
                       fv5308,]
                    end
                  end
                fv5296.post(
                  fv5307,
                  params: fv5306.merge(authenticity_token: fv5305),
                  headers: fv5304,
                )
                begin
                  fv5297 = fv5296
                  fv5299 = "session"
                  fv5298 = fv5297.response.cookies[fv5299]
                  if fv5298.nil?
                    fv5303 = fv5297.response.headers["Set-Cookie"] || fv5297.response.headers["set-cookie"]
                    fv5302 =
                      if fv5303.is_a?(String) && fv5303.start_with?("[")
                        JSON.parse(fv5303)
                      else
                        Array(fv5303)
                      end
                    fv5300 =
                      fv5302.flat_map { |fv5301|
                        fv5301.to_s.split("\n")
                      }.find do |fv5301|
                        fv5301.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5299}=")
                      end
                    if fv5300

                      _, fv5298 = fv5300.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5298 = Rack::Utils.unescape(fv5298.to_s)
                    end
                  end

                  unless fv5298.nil?
                    fv5297.cookies.delete(fv5299)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5297.cookies.merge(
                      "#{fv5299}=#{Rack::Utils.escape(fv5298)}",
                      URI.parse("https://#{fv5297.host}/"),
                    )
                  end
                end
                fv5295 = fv5296.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5295.blank?

                fv5292 = URI.parse(fv5295)
                if fv5294[:ri].present?
                  fv5293 = Rack::Utils.parse_nested_query(fv5292.query.to_s)
                  fv5293["ri"] ||= fv5294[:ri].to_s
                  fv5292.query = URI.encode_www_form(fv5293)
                end
                fv5277.host!(fv5292.host)
                fv5277.https!
                fv5291 = fv5292.request_uri
                fv5273 = fv5287.merge("Host" => fv5292.host)
                fv5277.get(
                  fv5291,
                  headers: fv5273,
                )
              else
                fv5288.confirm_base!(
                  base_token: fv5290,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5289,
                    entry_ref: fv5288.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5286 = fv5277.host
                fv5277.host!(fv5286)
                fv5277.https!
                fv5273 = fv5287.merge("Host" => fv5286)
                fv5277.get(
                  fv5285,
                  params: fv5284, headers: fv5273,
                )
              end
              fv5276, fv5274, fv5275 =
                begin
                  fv5283 = fv5277.response.body
                  fv5282 = false
                  fv5280 = Nokogiri::HTML(fv5283).at_css("form")
                  if fv5280.nil? && fv5282
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5280

                    fv5279 = fv5280.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5279.blank?

                    fv5278 = fv5280.css("input[type='hidden']").to_h do |fv5281|
                      [fv5281["name"], fv5281["value"]]
                    end.except("authenticity_token")
                    [fv5280["action"], fv5279,
                     fv5278,]
                  end
                end
              fv5277.post(
                fv5276,
                params: fv5275.merge(authenticity_token: fv5274),
                headers: fv5273,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_nil inertia_props["sign_in_link"]
    assert_equal I18n.t("actions.cancel"), inertia_props.fetch("cancel_link").fetch("label")
    assert_equal auth_org_root_path(ri: "jp"), inertia_props.fetch("cancel_link").fetch("href")
    assert_not inertia_props.key?("back_to_root")
  end

  test "valid login challenge renders local ceremony" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(prompt: "create"),
    )

    begin
      fv5272 = admission_reference(issuance)
      fv5271 = { ri: "jp" }
      begin
        fv5270 = auth_org_sign_up_path
        fv5269 = fv5272
        fv5268 = :entry_ref
        fv5267 = fv5271
        fv5266 = { "Host" => @host }
        fv5265 = false
        fv5264 = nil
        fv5263 = nil
        begin
          fv5209 = self
          fv5217 = fv5270
          fv5261 = fv5269
          fv5262 = fv5268
          fv5226 = fv5267
          fv5219 = fv5266
          fv5249 = fv5265
          fv5248 = fv5264
          fv5222 = fv5263
          fv5216 = fv5226.merge(fv5262 => fv5261)
          fv5209.get(
            fv5217,
            params: fv5216, headers: fv5219,
          )
          fv5255 =
            begin
              fv5260 = fv5209.response.body
              fv5259 = true
              fv5258 = Nokogiri::HTML(fv5260).at_css("form")
              if fv5258.nil? && fv5259
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5258

                fv5257 = fv5258.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5257.blank?

                fv5256 = fv5258.css("input[type='hidden']").to_h do |fv5213|
                  [fv5213["name"], fv5213["value"]]
                end.except("authenticity_token")
                [fv5258["action"], fv5257,
                 fv5256,]
              end
            end
          if fv5255

            fv5254, fv5252, fv5253 = fv5255

            fv5209.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5209.post(
              fv5254,
              params: fv5253.merge(authenticity_token: fv5252), headers: fv5219,
            )
            fv5251 = fv5209.response.location
            if fv5251.present?

              fv5247 = URI.parse(fv5251)
              fv5246 = fv5247.host
              fv5221 =
                begin
                  fv5250 = fv5246
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5250)
                end
              fv5220 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5221, reference: fv5247.path.split("/").fetch(-2),
              )

              if fv5249
                fv5228 = fv5248 || fv5209
                fv5228.host!(fv5246)
                fv5228.https!
                fv5228.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5245 = fv5247.request_uri
                fv5236 = fv5219.merge(
                  "Host" => fv5246,
                  "Origin" => "https://#{fv5246}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5228.get(
                  fv5245,
                  headers: fv5236,
                )
                fv5239, fv5237, fv5238 =
                  begin
                    fv5244 = fv5228.response.body
                    fv5243 = false
                    fv5242 = Nokogiri::HTML(fv5244).at_css("form")
                    if fv5242.nil? && fv5243
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5242

                      fv5241 = fv5242.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5241.blank?

                      fv5240 = fv5242.css("input[type='hidden']").to_h do |fv5213|
                        [fv5213["name"], fv5213["value"]]
                      end.except("authenticity_token")
                      [fv5242["action"], fv5241,
                       fv5240,]
                    end
                  end
                fv5228.post(
                  fv5239,
                  params: fv5238.merge(authenticity_token: fv5237),
                  headers: fv5236,
                )
                begin
                  fv5229 = fv5228
                  fv5231 = "session"
                  fv5230 = fv5229.response.cookies[fv5231]
                  if fv5230.nil?
                    fv5235 = fv5229.response.headers["Set-Cookie"] || fv5229.response.headers["set-cookie"]
                    fv5234 =
                      if fv5235.is_a?(String) && fv5235.start_with?("[")
                        JSON.parse(fv5235)
                      else
                        Array(fv5235)
                      end
                    fv5232 =
                      fv5234.flat_map { |fv5233|
                        fv5233.to_s.split("\n")
                      }.find do |fv5233|
                        fv5233.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5231}=")
                      end
                    if fv5232

                      _, fv5230 = fv5232.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5230 = Rack::Utils.unescape(fv5230.to_s)
                    end
                  end

                  unless fv5230.nil?
                    fv5229.cookies.delete(fv5231)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5229.cookies.merge(
                      "#{fv5231}=#{Rack::Utils.escape(fv5230)}",
                      URI.parse("https://#{fv5229.host}/"),
                    )
                  end
                end
                fv5227 = fv5228.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5227.blank?

                fv5224 = URI.parse(fv5227)
                if fv5226[:ri].present?
                  fv5225 = Rack::Utils.parse_nested_query(fv5224.query.to_s)
                  fv5225["ri"] ||= fv5226[:ri].to_s
                  fv5224.query = URI.encode_www_form(fv5225)
                end
                fv5209.host!(fv5224.host)
                fv5209.https!
                fv5223 = fv5224.request_uri
                fv5205 = fv5219.merge("Host" => fv5224.host)
                fv5209.get(
                  fv5223,
                  headers: fv5205,
                )
              else
                fv5220.confirm_base!(
                  base_token: fv5222,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5221,
                    entry_ref: fv5220.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5218 = fv5209.host
                fv5209.host!(fv5218)
                fv5209.https!
                fv5205 = fv5219.merge("Host" => fv5218)
                fv5209.get(
                  fv5217,
                  params: fv5216, headers: fv5205,
                )
              end
              fv5208, fv5206, fv5207 =
                begin
                  fv5215 = fv5209.response.body
                  fv5214 = false
                  fv5212 = Nokogiri::HTML(fv5215).at_css("form")
                  if fv5212.nil? && fv5214
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5212

                    fv5211 = fv5212.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5211.blank?

                    fv5210 = fv5212.css("input[type='hidden']").to_h do |fv5213|
                      [fv5213["name"], fv5213["value"]]
                    end.except("authenticity_token")
                    [fv5212["action"], fv5211,
                     fv5210,]
                  end
                end
              fv5209.post(
                fv5208,
                params: fv5207.merge(authenticity_token: fv5206),
                headers: fv5205,
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

  test "local ceremony does not show registration method choices" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(prompt: "create"),
    )

    begin
      fv5204 = admission_reference(issuance)
      fv5203 = { ri: "jp" }
      begin
        fv5202 = auth_org_sign_up_path
        fv5201 = fv5204
        fv5200 = :entry_ref
        fv5199 = fv5203
        fv5198 = { "Host" => @host }
        fv5197 = false
        fv5196 = nil
        fv5195 = nil
        begin
          fv5141 = self
          fv5149 = fv5202
          fv5193 = fv5201
          fv5194 = fv5200
          fv5158 = fv5199
          fv5151 = fv5198
          fv5181 = fv5197
          fv5180 = fv5196
          fv5154 = fv5195
          fv5148 = fv5158.merge(fv5194 => fv5193)
          fv5141.get(
            fv5149,
            params: fv5148, headers: fv5151,
          )
          fv5187 =
            begin
              fv5192 = fv5141.response.body
              fv5191 = true
              fv5190 = Nokogiri::HTML(fv5192).at_css("form")
              if fv5190.nil? && fv5191
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5190

                fv5189 = fv5190.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5189.blank?

                fv5188 = fv5190.css("input[type='hidden']").to_h do |fv5145|
                  [fv5145["name"], fv5145["value"]]
                end.except("authenticity_token")
                [fv5190["action"], fv5189,
                 fv5188,]
              end
            end
          if fv5187

            fv5186, fv5184, fv5185 = fv5187

            fv5141.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5141.post(
              fv5186,
              params: fv5185.merge(authenticity_token: fv5184), headers: fv5151,
            )
            fv5183 = fv5141.response.location
            if fv5183.present?

              fv5179 = URI.parse(fv5183)
              fv5178 = fv5179.host
              fv5153 =
                begin
                  fv5182 = fv5178
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5182)
                end
              fv5152 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5153, reference: fv5179.path.split("/").fetch(-2),
              )

              if fv5181
                fv5160 = fv5180 || fv5141
                fv5160.host!(fv5178)
                fv5160.https!
                fv5160.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5177 = fv5179.request_uri
                fv5168 = fv5151.merge(
                  "Host" => fv5178,
                  "Origin" => "https://#{fv5178}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5160.get(
                  fv5177,
                  headers: fv5168,
                )
                fv5171, fv5169, fv5170 =
                  begin
                    fv5176 = fv5160.response.body
                    fv5175 = false
                    fv5174 = Nokogiri::HTML(fv5176).at_css("form")
                    if fv5174.nil? && fv5175
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5174

                      fv5173 = fv5174.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5173.blank?

                      fv5172 = fv5174.css("input[type='hidden']").to_h do |fv5145|
                        [fv5145["name"], fv5145["value"]]
                      end.except("authenticity_token")
                      [fv5174["action"], fv5173,
                       fv5172,]
                    end
                  end
                fv5160.post(
                  fv5171,
                  params: fv5170.merge(authenticity_token: fv5169),
                  headers: fv5168,
                )
                begin
                  fv5161 = fv5160
                  fv5163 = "session"
                  fv5162 = fv5161.response.cookies[fv5163]
                  if fv5162.nil?
                    fv5167 = fv5161.response.headers["Set-Cookie"] || fv5161.response.headers["set-cookie"]
                    fv5166 =
                      if fv5167.is_a?(String) && fv5167.start_with?("[")
                        JSON.parse(fv5167)
                      else
                        Array(fv5167)
                      end
                    fv5164 =
                      fv5166.flat_map { |fv5165|
                        fv5165.to_s.split("\n")
                      }.find do |fv5165|
                        fv5165.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5163}=")
                      end
                    if fv5164

                      _, fv5162 = fv5164.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5162 = Rack::Utils.unescape(fv5162.to_s)
                    end
                  end

                  unless fv5162.nil?
                    fv5161.cookies.delete(fv5163)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5161.cookies.merge(
                      "#{fv5163}=#{Rack::Utils.escape(fv5162)}",
                      URI.parse("https://#{fv5161.host}/"),
                    )
                  end
                end
                fv5159 = fv5160.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5159.blank?

                fv5156 = URI.parse(fv5159)
                if fv5158[:ri].present?
                  fv5157 = Rack::Utils.parse_nested_query(fv5156.query.to_s)
                  fv5157["ri"] ||= fv5158[:ri].to_s
                  fv5156.query = URI.encode_www_form(fv5157)
                end
                fv5141.host!(fv5156.host)
                fv5141.https!
                fv5155 = fv5156.request_uri
                fv5137 = fv5151.merge("Host" => fv5156.host)
                fv5141.get(
                  fv5155,
                  headers: fv5137,
                )
              else
                fv5152.confirm_base!(
                  base_token: fv5154,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5153,
                    entry_ref: fv5152.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5150 = fv5141.host
                fv5141.host!(fv5150)
                fv5141.https!
                fv5137 = fv5151.merge("Host" => fv5150)
                fv5141.get(
                  fv5149,
                  params: fv5148, headers: fv5137,
                )
              end
              fv5140, fv5138, fv5139 =
                begin
                  fv5147 = fv5141.response.body
                  fv5146 = false
                  fv5144 = Nokogiri::HTML(fv5147).at_css("form")
                  if fv5144.nil? && fv5146
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5144

                    fv5143 = fv5144.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5143.blank?

                    fv5142 = fv5144.css("input[type='hidden']").to_h do |fv5145|
                      [fv5145["name"], fv5145["value"]]
                    end.except("authenticity_token")
                    [fv5144["action"], fv5143,
                     fv5142,]
                  end
                end
              fv5141.post(
                fv5140,
                params: fv5139.merge(authenticity_token: fv5138),
                headers: fv5137,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # The org surface has no registration methods at all: recruitment is the only entry point.
    assert_nil inertia_props["methods"]
    assert_no_match(%r{/sign/up/email/new|/social/auth/google|/social/auth/apple}, response.body)
  end

  test "local ceremony does not show google signup button even if legacy flag is set" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(prompt: "create"),
    )

    with_env("ORG_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      begin
        fv5136 = admission_reference(issuance)
        fv5135 = { ri: "jp" }
        begin
          fv5134 = auth_org_sign_up_path
          fv5133 = fv5136
          fv5132 = :entry_ref
          fv5131 = fv5135
          fv5130 = { "Host" => @host }
          fv5129 = false
          fv5128 = nil
          fv5127 = nil
          begin
            fv5073 = self
            fv5081 = fv5134
            fv5125 = fv5133
            fv5126 = fv5132
            fv5090 = fv5131
            fv5083 = fv5130
            fv5113 = fv5129
            fv5112 = fv5128
            fv5086 = fv5127
            fv5080 = fv5090.merge(fv5126 => fv5125)
            fv5073.get(
              fv5081,
              params: fv5080, headers: fv5083,
            )
            fv5119 =
              begin
                fv5124 = fv5073.response.body
                fv5123 = true
                fv5122 = Nokogiri::HTML(fv5124).at_css("form")
                if fv5122.nil? && fv5123
                  nil
                else
                  raise RuntimeError,
                        "Auth continuation form is missing" unless fv5122

                  fv5121 = fv5122.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5121.blank?

                  fv5120 = fv5122.css("input[type='hidden']").to_h do |fv5077|
                    [fv5077["name"], fv5077["value"]]
                  end.except("authenticity_token")
                  [fv5122["action"], fv5121,
                   fv5120,]
                end
              end
            if fv5119

              fv5118, fv5116, fv5117 = fv5119

              fv5073.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5073.post(
                fv5118,
                params: fv5117.merge(authenticity_token: fv5116), headers: fv5083,
              )
              fv5115 = fv5073.response.location
              if fv5115.present?

                fv5111 = URI.parse(fv5115)
                fv5110 = fv5111.host
                fv5085 =
                  begin
                    fv5114 = fv5110
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5114)
                  end
                fv5084 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5085, reference: fv5111.path.split("/").fetch(-2),
                )

                if fv5113
                  fv5092 = fv5112 || fv5073
                  fv5092.host!(fv5110)
                  fv5092.https!
                  fv5092.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5109 = fv5111.request_uri
                  fv5100 = fv5083.merge(
                    "Host" => fv5110,
                    "Origin" => "https://#{fv5110}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5092.get(
                    fv5109,
                    headers: fv5100,
                  )
                  fv5103, fv5101, fv5102 =
                    begin
                      fv5108 = fv5092.response.body
                      fv5107 = false
                      fv5106 = Nokogiri::HTML(fv5108).at_css("form")
                      if fv5106.nil? && fv5107
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5106

                        fv5105 = fv5106.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5105.blank?

                        fv5104 = fv5106.css("input[type='hidden']").to_h do |fv5077|
                          [fv5077["name"], fv5077["value"]]
                        end.except("authenticity_token")
                        [fv5106["action"], fv5105,
                         fv5104,]
                      end
                    end
                  fv5092.post(
                    fv5103,
                    params: fv5102.merge(authenticity_token: fv5101),
                    headers: fv5100,
                  )
                  begin
                    fv5093 = fv5092
                    fv5095 = "session"
                    fv5094 = fv5093.response.cookies[fv5095]
                    if fv5094.nil?
                      fv5099 = fv5093.response.headers["Set-Cookie"] || fv5093.response.headers["set-cookie"]
                      fv5098 =
                        if fv5099.is_a?(String) && fv5099.start_with?("[")
                          JSON.parse(fv5099)
                        else
                          Array(fv5099)
                        end
                      fv5096 =
                        fv5098.flat_map { |fv5097|
                          fv5097.to_s.split("\n")
                        }.find do |fv5097|
                          fv5097.split(
                            ";",
                            2,
                          ).first.to_s.start_with?("#{fv5095}=")
                        end
                      if fv5096

                        _, fv5094 = fv5096.split(";", 2).first.to_s.split(
                          "=", 2,
                        )
                        fv5094 = Rack::Utils.unescape(fv5094.to_s)
                      end
                    end

                    unless fv5094.nil?
                      fv5093.cookies.delete(fv5095)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5093.cookies.merge(
                        "#{fv5095}=#{Rack::Utils.escape(fv5094)}",
                        URI.parse("https://#{fv5093.host}/"),
                      )
                    end
                  end
                  fv5091 = fv5092.response.location
                  raise RuntimeError,
                        "Base confirmation did not return to Auth" if fv5091.blank?

                  fv5088 = URI.parse(fv5091)
                  if fv5090[:ri].present?
                    fv5089 = Rack::Utils.parse_nested_query(fv5088.query.to_s)
                    fv5089["ri"] ||= fv5090[:ri].to_s
                    fv5088.query = URI.encode_www_form(fv5089)
                  end
                  fv5073.host!(fv5088.host)
                  fv5073.https!
                  fv5087 = fv5088.request_uri
                  fv5069 = fv5083.merge("Host" => fv5088.host)
                  fv5073.get(
                    fv5087,
                    headers: fv5069,
                  )
                else
                  fv5084.confirm_base!(
                    base_token: fv5086,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5085,
                      entry_ref: fv5084.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5082 = fv5073.host
                  fv5073.host!(fv5082)
                  fv5073.https!
                  fv5069 = fv5083.merge("Host" => fv5082)
                  fv5073.get(
                    fv5081,
                    params: fv5080, headers: fv5069,
                  )
                end
                fv5072, fv5070, fv5071 =
                  begin
                    fv5079 = fv5073.response.body
                    fv5078 = false
                    fv5076 = Nokogiri::HTML(fv5079).at_css("form")
                    if fv5076.nil? && fv5078
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5076

                      fv5075 = fv5076.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5075.blank?

                      fv5074 = fv5076.css("input[type='hidden']").to_h do |fv5077|
                        [fv5077["name"], fv5077["value"]]
                      end.except("authenticity_token")
                      [fv5076["action"], fv5075,
                       fv5074,]
                    end
                  end
                fv5073.post(
                  fv5072,
                  params: fv5071.merge(authenticity_token: fv5070),
                  headers: fv5069,
                )
              end
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_no_match(%r{/social/auth/google|/auth/google}, response.body)
  end

  test "local ceremony renders recruit contact and home links" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(prompt: "create"),
    )

    begin
      fv5068 = admission_reference(issuance)
      fv5067 = { ri: "jp" }
      begin
        fv5066 = auth_org_sign_up_path
        fv5065 = fv5068
        fv5064 = :entry_ref
        fv5063 = fv5067
        fv5062 = { "Host" => @host }
        fv5061 = false
        fv5060 = nil
        fv5059 = nil
        begin
          fv5005 = self
          fv5013 = fv5066
          fv5057 = fv5065
          fv5058 = fv5064
          fv5022 = fv5063
          fv5015 = fv5062
          fv5045 = fv5061
          fv5044 = fv5060
          fv5018 = fv5059
          fv5012 = fv5022.merge(fv5058 => fv5057)
          fv5005.get(
            fv5013,
            params: fv5012, headers: fv5015,
          )
          fv5051 =
            begin
              fv5056 = fv5005.response.body
              fv5055 = true
              fv5054 = Nokogiri::HTML(fv5056).at_css("form")
              if fv5054.nil? && fv5055
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5054

                fv5053 = fv5054.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5053.blank?

                fv5052 = fv5054.css("input[type='hidden']").to_h do |fv5009|
                  [fv5009["name"], fv5009["value"]]
                end.except("authenticity_token")
                [fv5054["action"], fv5053,
                 fv5052,]
              end
            end
          if fv5051

            fv5050, fv5048, fv5049 = fv5051

            fv5005.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5005.post(
              fv5050,
              params: fv5049.merge(authenticity_token: fv5048), headers: fv5015,
            )
            fv5047 = fv5005.response.location
            if fv5047.present?

              fv5043 = URI.parse(fv5047)
              fv5042 = fv5043.host
              fv5017 =
                begin
                  fv5046 = fv5042
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5046)
                end
              fv5016 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5017, reference: fv5043.path.split("/").fetch(-2),
              )

              if fv5045
                fv5024 = fv5044 || fv5005
                fv5024.host!(fv5042)
                fv5024.https!
                fv5024.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5041 = fv5043.request_uri
                fv5032 = fv5015.merge(
                  "Host" => fv5042,
                  "Origin" => "https://#{fv5042}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5024.get(
                  fv5041,
                  headers: fv5032,
                )
                fv5035, fv5033, fv5034 =
                  begin
                    fv5040 = fv5024.response.body
                    fv5039 = false
                    fv5038 = Nokogiri::HTML(fv5040).at_css("form")
                    if fv5038.nil? && fv5039
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5038

                      fv5037 = fv5038.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5037.blank?

                      fv5036 = fv5038.css("input[type='hidden']").to_h do |fv5009|
                        [fv5009["name"], fv5009["value"]]
                      end.except("authenticity_token")
                      [fv5038["action"], fv5037,
                       fv5036,]
                    end
                  end
                fv5024.post(
                  fv5035,
                  params: fv5034.merge(authenticity_token: fv5033),
                  headers: fv5032,
                )
                begin
                  fv5025 = fv5024
                  fv5027 = "session"
                  fv5026 = fv5025.response.cookies[fv5027]
                  if fv5026.nil?
                    fv5031 = fv5025.response.headers["Set-Cookie"] || fv5025.response.headers["set-cookie"]
                    fv5030 =
                      if fv5031.is_a?(String) && fv5031.start_with?("[")
                        JSON.parse(fv5031)
                      else
                        Array(fv5031)
                      end
                    fv5028 =
                      fv5030.flat_map { |fv5029|
                        fv5029.to_s.split("\n")
                      }.find do |fv5029|
                        fv5029.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5027}=")
                      end
                    if fv5028

                      _, fv5026 = fv5028.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5026 = Rack::Utils.unescape(fv5026.to_s)
                    end
                  end

                  unless fv5026.nil?
                    fv5025.cookies.delete(fv5027)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5025.cookies.merge(
                      "#{fv5027}=#{Rack::Utils.escape(fv5026)}",
                      URI.parse("https://#{fv5025.host}/"),
                    )
                  end
                end
                fv5023 = fv5024.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5023.blank?

                fv5020 = URI.parse(fv5023)
                if fv5022[:ri].present?
                  fv5021 = Rack::Utils.parse_nested_query(fv5020.query.to_s)
                  fv5021["ri"] ||= fv5022[:ri].to_s
                  fv5020.query = URI.encode_www_form(fv5021)
                end
                fv5005.host!(fv5020.host)
                fv5005.https!
                fv5019 = fv5020.request_uri
                fv5001 = fv5015.merge("Host" => fv5020.host)
                fv5005.get(
                  fv5019,
                  headers: fv5001,
                )
              else
                fv5016.confirm_base!(
                  base_token: fv5018,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5017,
                    entry_ref: fv5016.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5014 = fv5005.host
                fv5005.host!(fv5014)
                fv5005.https!
                fv5001 = fv5015.merge("Host" => fv5014)
                fv5005.get(
                  fv5013,
                  params: fv5012, headers: fv5001,
                )
              end
              fv5004, fv5002, fv5003 =
                begin
                  fv5011 = fv5005.response.body
                  fv5010 = false
                  fv5008 = Nokogiri::HTML(fv5011).at_css("form")
                  if fv5008.nil? && fv5010
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5008

                    fv5007 = fv5008.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5007.blank?

                    fv5006 = fv5008.css("input[type='hidden']").to_h do |fv5009|
                      [fv5009["name"], fv5009["value"]]
                    end.except("authenticity_token")
                    [fv5008["action"], fv5007,
                     fv5006,]
                  end
                end
              fv5005.post(
                fv5004,
                params: fv5003.merge(authenticity_token: fv5002),
                headers: fv5001,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success

    recruit = inertia_props.fetch("recruit")

    assert_equal I18n.t("sign.org.ups.new.recruit_link_text"), recruit.fetch("label")
    assert_match(/ri=jp/, recruit.fetch("href"))
  end

  test "direct app-style email sign up route is not available" do
    get "/sign/up/email/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "direct app-style telephone sign up route is not available" do
    get "/sign/up/telephone/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "legacy invitation email sign up routes are not available" do
    get "/sign/up/invitations/emails/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    post "/sign/up/invitations/emails?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    get "/sign/up/invitations/emails/invite-code/edit?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    patch "/sign/up/invitations/emails/invite-code?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "rejects direct entry when logged in" do
    staff = operators(:one)

    get auth_org_sign_up_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :forbidden
  end

  private

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

  def authorize_params(prompt: nil)
    params = {
      response_type: "code",
      client_id: "core-org-jp",
      redirect_uri: OidcClientRegistry.find!("core-org-jp").redirect_uris.first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
    params[:prompt] = prompt if prompt.present?
    params
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::Org::SignUpsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::Org::SignUpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

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

  def csrf_token_value
    "test-csrf-token"
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
class Auth::Org::SignUpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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
