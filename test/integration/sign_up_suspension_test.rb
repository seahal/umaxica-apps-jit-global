# typed: false
# frozen_string_literal: true

require "test_helper"

# `sign_up_suspended_{surface}` is an operational kill switch: it closes new
# registration on one trust boundary without touching sign-in and without
# affecting the other two surfaces.
#
# Ceremony entry pages require Base-issued opaque admission before they render.
# Suspension itself is enforced in a before_action, so 503 assertions still hit
# the entry URL directly; "open" / "unaffected" assertions redeem admission first.
class SignUpSuspensionRequestTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: { host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), feature: :sign_up_suspended_app },
    com: { host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), feature: :sign_up_suspended_com },
    org: { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"), feature: :sign_up_suspended_org },
  }.freeze

  FIRST_PARTY_CLIENT_IDS = {
    app: "core-app",
    com: "core-com",
    org: "core-org",
  }.freeze

  teardown do
    SURFACES.each_value { |surface| Flipper.disable(surface.fetch(:feature)) }
  end

  SURFACES.each do |surface, config|
    test "#{surface} sign-up entry is open while the switch is off" do
      begin
        fv5287 = { surface: surface, intent: "sign_up" }
        fv5285 = fv5287.fetch(:surface)
        fv5286 = fv5287.fetch(:intent)
        fv5282 = SURFACES.fetch(fv5285).fetch(:host)
        host!(fv5282)
        _, fv5283 = issue_admission!(surface: fv5285.to_s, intent: fv5286)

        fv5284 =
          if fv5286 == "sign_up"
            public_send(:"auth_#{fv5285}_sign_up_path")
          else
            public_send(:"auth_#{fv5285}_sign_in_path")
          end

        begin
          fv5281 = fv5284
          fv5280 = fv5283
          fv5279 = :entry_ref
          fv5278 = { ri: "jp" }
          fv5277 = { "Host" => fv5282 }
          fv5276 = false
          fv5275 = nil
          fv5274 = nil
          begin
            fv5220 = self
            fv5228 = fv5281
            fv5272 = fv5280
            fv5273 = fv5279
            fv5237 = fv5278
            fv5230 = fv5277
            fv5260 = fv5276
            fv5259 = fv5275
            fv5233 = fv5274
            fv5227 = fv5237.merge(fv5273 => fv5272)
            fv5220.get(fv5228, params: fv5227, headers: fv5230)
            fv5266 =
              begin
                fv5271 = fv5220.response.body
                fv5270 = true
                fv5269 = Nokogiri::HTML(fv5271).at_css("form")
                if fv5269.nil? && fv5270
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5269

                  fv5268 = fv5269.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5268.blank?

                  fv5267 = fv5269.css("input[type='hidden']").to_h do |fv5224|
                    [fv5224["name"], fv5224["value"]]
                  end.except("authenticity_token")
                  [fv5269["action"], fv5268, fv5267]
                end
              end
            if fv5266

              fv5265, fv5263, fv5264 = fv5266

              fv5220.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5220.post(
                fv5265,
                params: fv5264.merge(authenticity_token: fv5263), headers: fv5230,
              )
              fv5262 = fv5220.response.location
              if fv5262.present?

                fv5258 = URI.parse(fv5262)
                fv5257 = fv5258.host
                fv5232 =
                  begin
                    fv5261 = fv5257
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5261)
                  end
                fv5231 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5232, reference: fv5258.path.split("/").fetch(-2),
                )

                if fv5260
                  fv5239 = fv5259 || fv5220
                  fv5239.host!(fv5257)
                  fv5239.https!
                  fv5239.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5256 = fv5258.request_uri
                  fv5247 = fv5230.merge(
                    "Host" => fv5257,
                    "Origin" => "https://#{fv5257}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5239.get(fv5256, headers: fv5247)
                  fv5250, fv5248, fv5249 =
                    begin
                      fv5255 = fv5239.response.body
                      fv5254 = false
                      fv5253 = Nokogiri::HTML(fv5255).at_css("form")
                      if fv5253.nil? && fv5254
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5253

                        fv5252 = fv5253.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5252.blank?

                        fv5251 = fv5253.css("input[type='hidden']").to_h do |fv5224|
                          [fv5224["name"], fv5224["value"]]
                        end.except("authenticity_token")
                        [fv5253["action"], fv5252, fv5251]
                      end
                    end
                  fv5239.post(
                    fv5250,
                    params: fv5249.merge(authenticity_token: fv5248),
                    headers: fv5247,
                  )
                  begin
                    fv5240 = fv5239
                    fv5242 = "session"
                    fv5241 = fv5240.response.cookies[fv5242]
                    if fv5241.nil?
                      fv5246 = fv5240.response.headers["Set-Cookie"] || fv5240.response.headers["set-cookie"]
                      fv5245 =
                        if fv5246.is_a?(String) && fv5246.start_with?("[")
                          JSON.parse(fv5246)
                        else
                          Array(fv5246)
                        end
                      fv5243 =
                        fv5245.flat_map { |fv5244|
                          fv5244.to_s.split("\n")
                        }.find do |fv5244|
                          fv5244.split(";", 2).first.to_s.start_with?("#{fv5242}=")
                        end
                      if fv5243

                        _, fv5241 = fv5243.split(";", 2).first.to_s.split("=", 2)
                        fv5241 = Rack::Utils.unescape(fv5241.to_s)
                      end
                    end

                    unless fv5241.nil?
                      fv5240.cookies.delete(fv5242)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5240.cookies.merge(
                        "#{fv5242}=#{Rack::Utils.escape(fv5241)}",
                        URI.parse("https://#{fv5240.host}/"),
                      )
                    end
                  end
                  fv5238 = fv5239.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5238.blank?

                  fv5235 = URI.parse(fv5238)
                  if fv5237[:ri].present?
                    fv5236 = Rack::Utils.parse_nested_query(fv5235.query.to_s)
                    fv5236["ri"] ||= fv5237[:ri].to_s
                    fv5235.query = URI.encode_www_form(fv5236)
                  end
                  fv5220.host!(fv5235.host)
                  fv5220.https!
                  fv5234 = fv5235.request_uri
                  fv5216 = fv5230.merge("Host" => fv5235.host)
                  fv5220.get(fv5234, headers: fv5216)
                else
                  fv5231.confirm_base!(
                    base_token: fv5233,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5232,
                      entry_ref: fv5231.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5229 = fv5220.host
                  fv5220.host!(fv5229)
                  fv5220.https!
                  fv5216 = fv5230.merge("Host" => fv5229)
                  fv5220.get(
                    fv5228, params: fv5227,
                            headers: fv5216,
                  )
                end
                fv5219, fv5217, fv5218 =
                  begin
                    fv5226 = fv5220.response.body
                    fv5225 = false
                    fv5223 = Nokogiri::HTML(fv5226).at_css("form")
                    if fv5223.nil? && fv5225
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5223

                      fv5222 = fv5223.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5222.blank?

                      fv5221 = fv5223.css("input[type='hidden']").to_h do |fv5224|
                        [fv5224["name"], fv5224["value"]]
                      end.except("authenticity_token")
                      [fv5223["action"], fv5222, fv5221]
                    end
                  end
                fv5220.post(
                  fv5219,
                  params: fv5218.merge(authenticity_token: fv5217),
                  headers: fv5216,
                )
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!
      end

      assert_response :success
    end

    test "#{surface} sign-up entry answers 503 while suspended" do
      Flipper.enable(config.fetch(:feature))
      host! config.fetch(:host)

      get sign_up_path_for(surface)

      assert_response :service_unavailable
      # The suspension notice is the prop the entry page renders in place of its registration
      # entry points; its presence is what "the page says sign-up is suspended" means now.
      assert_equal I18n.t("errors.messages.sign_up_suspended"), inertia_props.fetch("suspended_notice")
    end

    test "#{surface} sign-in entry is unaffected by the sign-up switch" do
      Flipper.enable(config.fetch(:feature))
      begin
        fv5215 = { surface: surface, intent: "sign_in" }
        fv5213 = fv5215.fetch(:surface)
        fv5214 = fv5215.fetch(:intent)
        fv5210 = SURFACES.fetch(fv5213).fetch(:host)
        host!(fv5210)
        _, fv5211 = issue_admission!(surface: fv5213.to_s, intent: fv5214)

        fv5212 =
          if fv5214 == "sign_up"
            public_send(:"auth_#{fv5213}_sign_up_path")
          else
            public_send(:"auth_#{fv5213}_sign_in_path")
          end

        begin
          fv5209 = fv5212
          fv5208 = fv5211
          fv5207 = :entry_ref
          fv5206 = { ri: "jp" }
          fv5205 = { "Host" => fv5210 }
          fv5204 = false
          fv5203 = nil
          fv5202 = nil
          begin
            fv5148 = self
            fv5156 = fv5209
            fv5200 = fv5208
            fv5201 = fv5207
            fv5165 = fv5206
            fv5158 = fv5205
            fv5188 = fv5204
            fv5187 = fv5203
            fv5161 = fv5202
            fv5155 = fv5165.merge(fv5201 => fv5200)
            fv5148.get(fv5156, params: fv5155, headers: fv5158)
            fv5194 =
              begin
                fv5199 = fv5148.response.body
                fv5198 = true
                fv5197 = Nokogiri::HTML(fv5199).at_css("form")
                if fv5197.nil? && fv5198
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5197

                  fv5196 = fv5197.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5196.blank?

                  fv5195 = fv5197.css("input[type='hidden']").to_h do |fv5152|
                    [fv5152["name"], fv5152["value"]]
                  end.except("authenticity_token")
                  [fv5197["action"], fv5196, fv5195]
                end
              end
            if fv5194

              fv5193, fv5191, fv5192 = fv5194

              fv5148.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5148.post(
                fv5193,
                params: fv5192.merge(authenticity_token: fv5191), headers: fv5158,
              )
              fv5190 = fv5148.response.location
              if fv5190.present?

                fv5186 = URI.parse(fv5190)
                fv5185 = fv5186.host
                fv5160 =
                  begin
                    fv5189 = fv5185
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5189)
                  end
                fv5159 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5160, reference: fv5186.path.split("/").fetch(-2),
                )

                if fv5188
                  fv5167 = fv5187 || fv5148
                  fv5167.host!(fv5185)
                  fv5167.https!
                  fv5167.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5184 = fv5186.request_uri
                  fv5175 = fv5158.merge(
                    "Host" => fv5185,
                    "Origin" => "https://#{fv5185}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5167.get(fv5184, headers: fv5175)
                  fv5178, fv5176, fv5177 =
                    begin
                      fv5183 = fv5167.response.body
                      fv5182 = false
                      fv5181 = Nokogiri::HTML(fv5183).at_css("form")
                      if fv5181.nil? && fv5182
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5181

                        fv5180 = fv5181.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5180.blank?

                        fv5179 = fv5181.css("input[type='hidden']").to_h do |fv5152|
                          [fv5152["name"], fv5152["value"]]
                        end.except("authenticity_token")
                        [fv5181["action"], fv5180, fv5179]
                      end
                    end
                  fv5167.post(
                    fv5178,
                    params: fv5177.merge(authenticity_token: fv5176),
                    headers: fv5175,
                  )
                  begin
                    fv5168 = fv5167
                    fv5170 = "session"
                    fv5169 = fv5168.response.cookies[fv5170]
                    if fv5169.nil?
                      fv5174 = fv5168.response.headers["Set-Cookie"] || fv5168.response.headers["set-cookie"]
                      fv5173 =
                        if fv5174.is_a?(String) && fv5174.start_with?("[")
                          JSON.parse(fv5174)
                        else
                          Array(fv5174)
                        end
                      fv5171 =
                        fv5173.flat_map { |fv5172|
                          fv5172.to_s.split("\n")
                        }.find do |fv5172|
                          fv5172.split(";", 2).first.to_s.start_with?("#{fv5170}=")
                        end
                      if fv5171

                        _, fv5169 = fv5171.split(";", 2).first.to_s.split("=", 2)
                        fv5169 = Rack::Utils.unescape(fv5169.to_s)
                      end
                    end

                    unless fv5169.nil?
                      fv5168.cookies.delete(fv5170)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5168.cookies.merge(
                        "#{fv5170}=#{Rack::Utils.escape(fv5169)}",
                        URI.parse("https://#{fv5168.host}/"),
                      )
                    end
                  end
                  fv5166 = fv5167.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5166.blank?

                  fv5163 = URI.parse(fv5166)
                  if fv5165[:ri].present?
                    fv5164 = Rack::Utils.parse_nested_query(fv5163.query.to_s)
                    fv5164["ri"] ||= fv5165[:ri].to_s
                    fv5163.query = URI.encode_www_form(fv5164)
                  end
                  fv5148.host!(fv5163.host)
                  fv5148.https!
                  fv5162 = fv5163.request_uri
                  fv5144 = fv5158.merge("Host" => fv5163.host)
                  fv5148.get(fv5162, headers: fv5144)
                else
                  fv5159.confirm_base!(
                    base_token: fv5161,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5160,
                      entry_ref: fv5159.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5157 = fv5148.host
                  fv5148.host!(fv5157)
                  fv5148.https!
                  fv5144 = fv5158.merge("Host" => fv5157)
                  fv5148.get(
                    fv5156, params: fv5155,
                            headers: fv5144,
                  )
                end
                fv5147, fv5145, fv5146 =
                  begin
                    fv5154 = fv5148.response.body
                    fv5153 = false
                    fv5151 = Nokogiri::HTML(fv5154).at_css("form")
                    if fv5151.nil? && fv5153
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5151

                      fv5150 = fv5151.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5150.blank?

                      fv5149 = fv5151.css("input[type='hidden']").to_h do |fv5152|
                        [fv5152["name"], fv5152["value"]]
                      end.except("authenticity_token")
                      [fv5151["action"], fv5150, fv5149]
                    end
                  end
                fv5148.post(
                  fv5147,
                  params: fv5146.merge(authenticity_token: fv5145),
                  headers: fv5144,
                )
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!
      end

      assert_response :success
    end
  end

  test "suspending one surface leaves the others open" do
    Flipper.enable(:sign_up_suspended_app)

    begin
      fv5143 = { surface: :com, intent: "sign_up" }
      fv5141 = fv5143.fetch(:surface)
      fv5142 = fv5143.fetch(:intent)
      fv5138 = SURFACES.fetch(fv5141).fetch(:host)
      host!(fv5138)
      _, fv5139 = issue_admission!(surface: fv5141.to_s, intent: fv5142)

      fv5140 =
        if fv5142 == "sign_up"
          public_send(:"auth_#{fv5141}_sign_up_path")
        else
          public_send(:"auth_#{fv5141}_sign_in_path")
        end

      begin
        fv5137 = fv5140
        fv5136 = fv5139
        fv5135 = :entry_ref
        fv5134 = { ri: "jp" }
        fv5133 = { "Host" => fv5138 }
        fv5132 = false
        fv5131 = nil
        fv5130 = nil
        begin
          fv5076 = self
          fv5084 = fv5137
          fv5128 = fv5136
          fv5129 = fv5135
          fv5093 = fv5134
          fv5086 = fv5133
          fv5116 = fv5132
          fv5115 = fv5131
          fv5089 = fv5130
          fv5083 = fv5093.merge(fv5129 => fv5128)
          fv5076.get(fv5084, params: fv5083, headers: fv5086)
          fv5122 =
            begin
              fv5127 = fv5076.response.body
              fv5126 = true
              fv5125 = Nokogiri::HTML(fv5127).at_css("form")
              if fv5125.nil? && fv5126
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5125

                fv5124 = fv5125.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5124.blank?

                fv5123 = fv5125.css("input[type='hidden']").to_h do |fv5080|
                  [fv5080["name"], fv5080["value"]]
                end.except("authenticity_token")
                [fv5125["action"], fv5124, fv5123]
              end
            end
          if fv5122

            fv5121, fv5119, fv5120 = fv5122

            fv5076.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5076.post(
              fv5121,
              params: fv5120.merge(authenticity_token: fv5119), headers: fv5086,
            )
            fv5118 = fv5076.response.location
            if fv5118.present?

              fv5114 = URI.parse(fv5118)
              fv5113 = fv5114.host
              fv5088 =
                begin
                  fv5117 = fv5113
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5117)
                end
              fv5087 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5088, reference: fv5114.path.split("/").fetch(-2),
              )

              if fv5116
                fv5095 = fv5115 || fv5076
                fv5095.host!(fv5113)
                fv5095.https!
                fv5095.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5112 = fv5114.request_uri
                fv5103 = fv5086.merge(
                  "Host" => fv5113,
                  "Origin" => "https://#{fv5113}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5095.get(fv5112, headers: fv5103)
                fv5106, fv5104, fv5105 =
                  begin
                    fv5111 = fv5095.response.body
                    fv5110 = false
                    fv5109 = Nokogiri::HTML(fv5111).at_css("form")
                    if fv5109.nil? && fv5110
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5109

                      fv5108 = fv5109.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5108.blank?

                      fv5107 = fv5109.css("input[type='hidden']").to_h do |fv5080|
                        [fv5080["name"], fv5080["value"]]
                      end.except("authenticity_token")
                      [fv5109["action"], fv5108, fv5107]
                    end
                  end
                fv5095.post(
                  fv5106,
                  params: fv5105.merge(authenticity_token: fv5104),
                  headers: fv5103,
                )
                begin
                  fv5096 = fv5095
                  fv5098 = "session"
                  fv5097 = fv5096.response.cookies[fv5098]
                  if fv5097.nil?
                    fv5102 = fv5096.response.headers["Set-Cookie"] || fv5096.response.headers["set-cookie"]
                    fv5101 =
                      if fv5102.is_a?(String) && fv5102.start_with?("[")
                        JSON.parse(fv5102)
                      else
                        Array(fv5102)
                      end
                    fv5099 =
                      fv5101.flat_map { |fv5100| fv5100.to_s.split("\n") }.find do |fv5100|
                        fv5100.split(";", 2).first.to_s.start_with?("#{fv5098}=")
                      end
                    if fv5099

                      _, fv5097 = fv5099.split(";", 2).first.to_s.split("=", 2)
                      fv5097 = Rack::Utils.unescape(fv5097.to_s)
                    end
                  end

                  unless fv5097.nil?
                    fv5096.cookies.delete(fv5098)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5096.cookies.merge(
                      "#{fv5098}=#{Rack::Utils.escape(fv5097)}",
                      URI.parse("https://#{fv5096.host}/"),
                    )
                  end
                end
                fv5094 = fv5095.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5094.blank?

                fv5091 = URI.parse(fv5094)
                if fv5093[:ri].present?
                  fv5092 = Rack::Utils.parse_nested_query(fv5091.query.to_s)
                  fv5092["ri"] ||= fv5093[:ri].to_s
                  fv5091.query = URI.encode_www_form(fv5092)
                end
                fv5076.host!(fv5091.host)
                fv5076.https!
                fv5090 = fv5091.request_uri
                fv5072 = fv5086.merge("Host" => fv5091.host)
                fv5076.get(fv5090, headers: fv5072)
              else
                fv5087.confirm_base!(
                  base_token: fv5089,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5088,
                    entry_ref: fv5087.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5085 = fv5076.host
                fv5076.host!(fv5085)
                fv5076.https!
                fv5072 = fv5086.merge("Host" => fv5085)
                fv5076.get(
                  fv5084, params: fv5083,
                          headers: fv5072,
                )
              end
              fv5075, fv5073, fv5074 =
                begin
                  fv5082 = fv5076.response.body
                  fv5081 = false
                  fv5079 = Nokogiri::HTML(fv5082).at_css("form")
                  if fv5079.nil? && fv5081
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5079

                    fv5078 = fv5079.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5078.blank?

                    fv5077 = fv5079.css("input[type='hidden']").to_h do |fv5080|
                      [fv5080["name"], fv5080["value"]]
                    end.except("authenticity_token")
                    [fv5079["action"], fv5078, fv5077]
                  end
                end
              fv5076.post(
                fv5075,
                params: fv5074.merge(authenticity_token: fv5073),
                headers: fv5072,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!
    end

    assert_response :success

    begin
      fv5071 = { surface: :org, intent: "sign_up" }
      fv5069 = fv5071.fetch(:surface)
      fv5070 = fv5071.fetch(:intent)
      fv5066 = SURFACES.fetch(fv5069).fetch(:host)
      host!(fv5066)
      _, fv5067 = issue_admission!(surface: fv5069.to_s, intent: fv5070)

      fv5068 =
        if fv5070 == "sign_up"
          public_send(:"auth_#{fv5069}_sign_up_path")
        else
          public_send(:"auth_#{fv5069}_sign_in_path")
        end

      begin
        fv5065 = fv5068
        fv5064 = fv5067
        fv5063 = :entry_ref
        fv5062 = { ri: "jp" }
        fv5061 = { "Host" => fv5066 }
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
          fv5004.get(fv5012, params: fv5011, headers: fv5014)
          fv5050 =
            begin
              fv5055 = fv5004.response.body
              fv5054 = true
              fv5053 = Nokogiri::HTML(fv5055).at_css("form")
              if fv5053.nil? && fv5054
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5053

                fv5052 = fv5053.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5052.blank?

                fv5051 = fv5053.css("input[type='hidden']").to_h do |fv5008|
                  [fv5008["name"], fv5008["value"]]
                end.except("authenticity_token")
                [fv5053["action"], fv5052, fv5051]
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
                fv5023.get(fv5040, headers: fv5031)
                fv5034, fv5032, fv5033 =
                  begin
                    fv5039 = fv5023.response.body
                    fv5038 = false
                    fv5037 = Nokogiri::HTML(fv5039).at_css("form")
                    if fv5037.nil? && fv5038
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5037

                      fv5036 = fv5037.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5036.blank?

                      fv5035 = fv5037.css("input[type='hidden']").to_h do |fv5008|
                        [fv5008["name"], fv5008["value"]]
                      end.except("authenticity_token")
                      [fv5037["action"], fv5036, fv5035]
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
                      fv5029.flat_map { |fv5028| fv5028.to_s.split("\n") }.find do |fv5028|
                        fv5028.split(";", 2).first.to_s.start_with?("#{fv5026}=")
                      end
                    if fv5027

                      _, fv5025 = fv5027.split(";", 2).first.to_s.split("=", 2)
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
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5022.blank?

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
                fv5004.get(fv5018, headers: fv5000)
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
                  fv5012, params: fv5011,
                          headers: fv5000,
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
                    raise RuntimeError, "Auth continuation form is missing" unless fv5007

                    fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5006.blank?

                    fv5005 = fv5007.css("input[type='hidden']").to_h do |fv5008|
                      [fv5008["name"], fv5008["value"]]
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
    end

    assert_response :success
  end

  # The identifier entry is where a registration actually starts, so a suspended
  # surface must reject it too -- a landing page that merely hides its links
  # would still accept a direct POST.
  test "app email registration entry answers 503 while suspended" do
    host! SURFACES.fetch(:app).fetch(:host)

    begin
      admission_browser = self
      admission_surface = "app"
      admission_intent = "sign_up"
      admission_host = {
        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      }.fetch(admission_surface)
      admission_browser.host!(admission_host)
      admission_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: admission_surface, intent: admission_intent,
        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        "/ceremony_bindings",
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: admission_surface, reference: admission_issuance.reference,
      )
      admission_binding.reload.confirm_base!(
        base_token: nil,
        browser_digest: admission_binding.base_browser_digest,
      )
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        admission_path,
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
    end

    Flipper.enable(:sign_up_suspended_app)
    get new_auth_app_sign_up_email_path(ri: "jp")

    assert_response :service_unavailable
  end

  # The social ceremony entry shares its concern with sign-in, so only the
  # sign-up branch may be closed, and it must be closed before any ceremony
  # state is written.
  test "app social registration entry answers 503 and issues no sign-up flow while suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    assert_no_difference -> { ClientSignUpFlow.count } do
      post auth_app_social_google_registration_path
    end

    assert_response :service_unavailable
  end

  test "app social sign-in entry still starts its ceremony while sign-up is suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    begin
      admission_browser = self
      admission_surface = "app"
      admission_intent = "sign_in"
      admission_host = {
        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      }.fetch(admission_surface)
      admission_browser.host!(admission_host)
      admission_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: admission_surface, intent: admission_intent,
        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        "/ceremony_bindings",
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: admission_surface, reference: admission_issuance.reference,
      )
      admission_binding.reload.confirm_base!(
        base_token: nil,
        browser_digest: admission_binding.base_browser_digest,
      )
      admission_browser.get(
        admission_path,
        params: { entry_ref: admission_issuance.reference, ri: "jp" },
      )
      admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      admission_browser.post(
        admission_path,
        params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
      )

      assert_equal 303, admission_browser.response.status
    end

    post auth_app_social_google_session_path

    assert_response :temporary_redirect
  end

  private

  # `ri` is supplied so the region normalization that precedes the guard does not answer first;
  # these assertions are about the guard, not about that redirect.
  def sign_up_path_for(surface)
    public_send(:"auth_#{surface}_sign_up_path", ri: "jp")
  end

  def sign_in_path_for(surface)
    public_send(:"auth_#{surface}_sign_in_path", ri: "jp")
  end

  def issue_admission!(surface:, intent:)
    client_id = FIRST_PARTY_CLIENT_IDS.fetch(surface.to_sym)
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: intent,
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      )
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: issuance.transaction,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    [issuance.transaction, handoff.reference]
  end
end
