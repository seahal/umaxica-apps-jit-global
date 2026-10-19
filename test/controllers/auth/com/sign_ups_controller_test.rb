# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Com::SignUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
  end

  test "direct entry without a login challenge is refused without admission" do
    get auth_com_sign_up_url(ct: "dr", ri: "jp"), headers: default_headers

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "local ceremony shows email and telephone registration methods" do
    begin
      fv5268 = { ct: "dr", ri: "jp" }
      begin
        fv5267 = auth_com_sign_up_path
        fv5266 = login_challenge
        fv5265 = :entry_ref
        fv5264 = fv5268
        fv5263 = default_headers
        fv5262 = false
        fv5261 = nil
        fv5260 = nil
        begin
          fv5206 = self
          fv5214 = fv5267
          fv5258 = fv5266
          fv5259 = fv5265
          fv5223 = fv5264
          fv5216 = fv5263
          fv5246 = fv5262
          fv5245 = fv5261
          fv5219 = fv5260
          fv5213 = fv5223.merge(fv5259 => fv5258)
          fv5206.get(
            fv5214,
            params: fv5213, headers: fv5216,
          )
          fv5252 =
            begin
              fv5257 = fv5206.response.body
              fv5256 = true
              fv5255 = Nokogiri::HTML(fv5257).at_css("form")
              if fv5255.nil? && fv5256
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5255

                fv5254 = fv5255.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5254.blank?

                fv5253 = fv5255.css("input[type='hidden']").to_h do |fv5210|
                  [fv5210["name"], fv5210["value"]]
                end.except("authenticity_token")
                [fv5255["action"], fv5254,
                 fv5253,]
              end
            end
          if fv5252

            fv5251, fv5249, fv5250 = fv5252

            fv5206.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5206.post(
              fv5251,
              params: fv5250.merge(authenticity_token: fv5249), headers: fv5216,
            )
            fv5248 = fv5206.response.location
            if fv5248.present?

              fv5244 = URI.parse(fv5248)
              fv5243 = fv5244.host
              fv5218 =
                begin
                  fv5247 = fv5243
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5247)
                end
              fv5217 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5218, reference: fv5244.path.split("/").fetch(-2),
              )

              if fv5246
                fv5225 = fv5245 || fv5206
                fv5225.host!(fv5243)
                fv5225.https!
                fv5225.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5242 = fv5244.request_uri
                fv5233 = fv5216.merge(
                  "Host" => fv5243,
                  "Origin" => "https://#{fv5243}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5225.get(
                  fv5242,
                  headers: fv5233,
                )
                fv5236, fv5234, fv5235 =
                  begin
                    fv5241 = fv5225.response.body
                    fv5240 = false
                    fv5239 = Nokogiri::HTML(fv5241).at_css("form")
                    if fv5239.nil? && fv5240
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5239

                      fv5238 = fv5239.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5238.blank?

                      fv5237 = fv5239.css("input[type='hidden']").to_h do |fv5210|
                        [fv5210["name"], fv5210["value"]]
                      end.except("authenticity_token")
                      [fv5239["action"], fv5238,
                       fv5237,]
                    end
                  end
                fv5225.post(
                  fv5236,
                  params: fv5235.merge(authenticity_token: fv5234),
                  headers: fv5233,
                )
                begin
                  fv5226 = fv5225
                  fv5228 = "session"
                  fv5227 = fv5226.response.cookies[fv5228]
                  if fv5227.nil?
                    fv5232 = fv5226.response.headers["Set-Cookie"] || fv5226.response.headers["set-cookie"]
                    fv5231 =
                      if fv5232.is_a?(String) && fv5232.start_with?("[")
                        JSON.parse(fv5232)
                      else
                        Array(fv5232)
                      end
                    fv5229 =
                      fv5231.flat_map { |fv5230|
                        fv5230.to_s.split("\n")
                      }.find do |fv5230|
                        fv5230.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5228}=")
                      end
                    if fv5229

                      _, fv5227 = fv5229.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5227 = Rack::Utils.unescape(fv5227.to_s)
                    end
                  end

                  unless fv5227.nil?
                    fv5226.cookies.delete(fv5228)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5226.cookies.merge(
                      "#{fv5228}=#{Rack::Utils.escape(fv5227)}",
                      URI.parse("https://#{fv5226.host}/"),
                    )
                  end
                end
                fv5224 = fv5225.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5224.blank?

                fv5221 = URI.parse(fv5224)
                if fv5223[:ri].present?
                  fv5222 = Rack::Utils.parse_nested_query(fv5221.query.to_s)
                  fv5222["ri"] ||= fv5223[:ri].to_s
                  fv5221.query = URI.encode_www_form(fv5222)
                end
                fv5206.host!(fv5221.host)
                fv5206.https!
                fv5220 = fv5221.request_uri
                fv5202 = fv5216.merge("Host" => fv5221.host)
                fv5206.get(
                  fv5220,
                  headers: fv5202,
                )
              else
                fv5217.confirm_base!(
                  base_token: fv5219,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5218,
                    entry_ref: fv5217.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5215 = fv5206.host
                fv5206.host!(fv5215)
                fv5206.https!
                fv5202 = fv5216.merge("Host" => fv5215)
                fv5206.get(
                  fv5214,
                  params: fv5213, headers: fv5202,
                )
              end
              fv5205, fv5203, fv5204 =
                begin
                  fv5212 = fv5206.response.body
                  fv5211 = false
                  fv5209 = Nokogiri::HTML(fv5212).at_css("form")
                  if fv5209.nil? && fv5211
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5209

                    fv5208 = fv5209.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5208.blank?

                    fv5207 = fv5209.css("input[type='hidden']").to_h do |fv5210|
                      [fv5210["name"], fv5210["value"]]
                    end.except("authenticity_token")
                    [fv5209["action"], fv5208,
                     fv5207,]
                  end
                end
              fv5206.post(
                fv5205,
                params: fv5204.merge(authenticity_token: fv5203),
                headers: fv5202,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal "auth/com/sign_ups/new", inertia_component
    # The first Sign Up page of an OIDC parent offers Cancel as a POST form (D09).
    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")

    methods = inertia_props.fetch("methods")

    assert_equal 2, methods.size
    assert_equal(
      [new_auth_com_sign_up_email_path(ri: "jp"), new_auth_com_sign_up_telephone_path(ri: "jp")],
      methods.map { |method| method.fetch("href") },
    )
  end

  test "does not show social login buttons when flag is off" do
    begin
      fv5201 = { ct: "dr", ri: "jp" }
      begin
        fv5200 = auth_com_sign_up_path
        fv5199 = login_challenge
        fv5198 = :entry_ref
        fv5197 = fv5201
        fv5196 = default_headers
        fv5195 = false
        fv5194 = nil
        fv5193 = nil
        begin
          fv5139 = self
          fv5147 = fv5200
          fv5191 = fv5199
          fv5192 = fv5198
          fv5156 = fv5197
          fv5149 = fv5196
          fv5179 = fv5195
          fv5178 = fv5194
          fv5152 = fv5193
          fv5146 = fv5156.merge(fv5192 => fv5191)
          fv5139.get(
            fv5147,
            params: fv5146, headers: fv5149,
          )
          fv5185 =
            begin
              fv5190 = fv5139.response.body
              fv5189 = true
              fv5188 = Nokogiri::HTML(fv5190).at_css("form")
              if fv5188.nil? && fv5189
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5188

                fv5187 = fv5188.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5187.blank?

                fv5186 = fv5188.css("input[type='hidden']").to_h do |fv5143|
                  [fv5143["name"], fv5143["value"]]
                end.except("authenticity_token")
                [fv5188["action"], fv5187,
                 fv5186,]
              end
            end
          if fv5185

            fv5184, fv5182, fv5183 = fv5185

            fv5139.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5139.post(
              fv5184,
              params: fv5183.merge(authenticity_token: fv5182), headers: fv5149,
            )
            fv5181 = fv5139.response.location
            if fv5181.present?

              fv5177 = URI.parse(fv5181)
              fv5176 = fv5177.host
              fv5151 =
                begin
                  fv5180 = fv5176
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5180)
                end
              fv5150 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5151, reference: fv5177.path.split("/").fetch(-2),
              )

              if fv5179
                fv5158 = fv5178 || fv5139
                fv5158.host!(fv5176)
                fv5158.https!
                fv5158.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5175 = fv5177.request_uri
                fv5166 = fv5149.merge(
                  "Host" => fv5176,
                  "Origin" => "https://#{fv5176}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5158.get(
                  fv5175,
                  headers: fv5166,
                )
                fv5169, fv5167, fv5168 =
                  begin
                    fv5174 = fv5158.response.body
                    fv5173 = false
                    fv5172 = Nokogiri::HTML(fv5174).at_css("form")
                    if fv5172.nil? && fv5173
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5172

                      fv5171 = fv5172.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5171.blank?

                      fv5170 = fv5172.css("input[type='hidden']").to_h do |fv5143|
                        [fv5143["name"], fv5143["value"]]
                      end.except("authenticity_token")
                      [fv5172["action"], fv5171,
                       fv5170,]
                    end
                  end
                fv5158.post(
                  fv5169,
                  params: fv5168.merge(authenticity_token: fv5167),
                  headers: fv5166,
                )
                begin
                  fv5159 = fv5158
                  fv5161 = "session"
                  fv5160 = fv5159.response.cookies[fv5161]
                  if fv5160.nil?
                    fv5165 = fv5159.response.headers["Set-Cookie"] || fv5159.response.headers["set-cookie"]
                    fv5164 =
                      if fv5165.is_a?(String) && fv5165.start_with?("[")
                        JSON.parse(fv5165)
                      else
                        Array(fv5165)
                      end
                    fv5162 =
                      fv5164.flat_map { |fv5163|
                        fv5163.to_s.split("\n")
                      }.find do |fv5163|
                        fv5163.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5161}=")
                      end
                    if fv5162

                      _, fv5160 = fv5162.split(";", 2).first.to_s.split(
                        "=", 2,
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
                fv5157 = fv5158.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5157.blank?

                fv5154 = URI.parse(fv5157)
                if fv5156[:ri].present?
                  fv5155 = Rack::Utils.parse_nested_query(fv5154.query.to_s)
                  fv5155["ri"] ||= fv5156[:ri].to_s
                  fv5154.query = URI.encode_www_form(fv5155)
                end
                fv5139.host!(fv5154.host)
                fv5139.https!
                fv5153 = fv5154.request_uri
                fv5135 = fv5149.merge("Host" => fv5154.host)
                fv5139.get(
                  fv5153,
                  headers: fv5135,
                )
              else
                fv5150.confirm_base!(
                  base_token: fv5152,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5151,
                    entry_ref: fv5150.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5148 = fv5139.host
                fv5139.host!(fv5148)
                fv5139.https!
                fv5135 = fv5149.merge("Host" => fv5148)
                fv5139.get(
                  fv5147,
                  params: fv5146, headers: fv5135,
                )
              end
              fv5138, fv5136, fv5137 =
                begin
                  fv5145 = fv5139.response.body
                  fv5144 = false
                  fv5142 = Nokogiri::HTML(fv5145).at_css("form")
                  if fv5142.nil? && fv5144
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5142

                    fv5141 = fv5142.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5141.blank?

                    fv5140 = fv5142.css("input[type='hidden']").to_h do |fv5143|
                      [fv5143["name"], fv5143["value"]]
                    end.except("authenticity_token")
                    [fv5142["action"], fv5141,
                     fv5140,]
                  end
                end
              fv5139.post(
                fv5138,
                params: fv5137.merge(authenticity_token: fv5136),
                headers: fv5135,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal "auth/com/sign_ups/new", inertia_component
    assert_equal %w(email telephone), inertia_props.fetch("methods").map { |method| method.fetch("key") }
  end

  test "does not show temporary google signup button when legacy flag is on" do
    with_env("COM_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      begin
        fv5134 = { ct: "dr", ri: "jp" }
        begin
          fv5133 = auth_com_sign_up_path
          fv5132 = login_challenge
          fv5131 = :entry_ref
          fv5130 = fv5134
          fv5129 = default_headers
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
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal "auth/com/sign_ups/new", inertia_component
    assert_equal %w(email telephone), inertia_props.fetch("methods").map { |method| method.fetch("key") }
  end

  test "rejects direct entry when logged in" do
    visitor = create_verified_visitor_with_email(email_address: "com-up-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002224",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get auth_com_sign_up_url(ri: "jp"), headers: as_visitor_headers(visitor, host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "sign up entry renders without an active registration" do
    begin
      fv5067 = { ri: "jp" }
      begin
        fv5066 = auth_com_sign_up_path
        fv5065 = login_challenge
        fv5064 = :entry_ref
        fv5063 = fv5067
        fv5062 = default_headers
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
  end

  private

  def login_challenge
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com",
      intent: "sign_up",
      params: authorize_params,
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    ).reference
  end

  def authorize_params
    {
      response_type: "code",
      client_id: "core-com-jp",
      redirect_uri: OidcClientRegistry.find!("core-com-jp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(16),
      nonce: SecureRandom.urlsafe_base64(16),
      scope: "openid profile",
    }
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
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
class Auth::Com::SignUpsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::Com::SignUpsControllerTest
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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
class Auth::Com::SignUpsControllerTest
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
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
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
