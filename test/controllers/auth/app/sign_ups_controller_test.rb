# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup { host! host }

  test "direct entry without a login challenge is refused without admission" do
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "direct entry without a login challenge starts no OIDC handoff state" do
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_nil session[:oidc_code_verifier]
    assert_nil session[:oidc_state]
    assert_nil session[:oidc_nonce]
    assert_nil session["oidc_pending_flows"]
  end

  test "valid login challenge renders local ceremony" do
    begin
      fv5603 = { ri: "jp" }
      begin
        fv5602 = auth_app_sign_up_path(format: :html)
        fv5601 = login_challenge
        fv5600 = :entry_ref
        fv5599 = fv5603
        fv5598 = { "Host" => host }
        fv5597 = false
        fv5596 = nil
        fv5595 = nil
        begin
          fv5541 = self
          fv5549 = fv5602
          fv5593 = fv5601
          fv5594 = fv5600
          fv5558 = fv5599
          fv5551 = fv5598
          fv5581 = fv5597
          fv5580 = fv5596
          fv5554 = fv5595
          fv5548 = fv5558.merge(fv5594 => fv5593)
          fv5541.get(
            fv5549,
            params: fv5548, headers: fv5551,
          )
          fv5587 =
            begin
              fv5592 = fv5541.response.body
              fv5591 = true
              fv5590 = Nokogiri::HTML(fv5592).at_css("form")
              if fv5590.nil? && fv5591
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5590

                fv5589 = fv5590.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5589.blank?

                fv5588 = fv5590.css("input[type='hidden']").to_h do |fv5545|
                  [fv5545["name"], fv5545["value"]]
                end.except("authenticity_token")
                [fv5590["action"], fv5589,
                 fv5588,]
              end
            end
          if fv5587

            fv5586, fv5584, fv5585 = fv5587

            fv5541.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5541.post(
              fv5586,
              params: fv5585.merge(authenticity_token: fv5584), headers: fv5551,
            )
            fv5583 = fv5541.response.location
            if fv5583.present?

              fv5579 = URI.parse(fv5583)
              fv5578 = fv5579.host
              fv5553 =
                begin
                  fv5582 = fv5578
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5582)
                end
              fv5552 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5553, reference: fv5579.path.split("/").fetch(-2),
              )

              if fv5581
                fv5560 = fv5580 || fv5541
                fv5560.host!(fv5578)
                fv5560.https!
                fv5560.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5577 = fv5579.request_uri
                fv5568 = fv5551.merge(
                  "Host" => fv5578,
                  "Origin" => "https://#{fv5578}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5560.get(
                  fv5577,
                  headers: fv5568,
                )
                fv5571, fv5569, fv5570 =
                  begin
                    fv5576 = fv5560.response.body
                    fv5575 = false
                    fv5574 = Nokogiri::HTML(fv5576).at_css("form")
                    if fv5574.nil? && fv5575
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5574

                      fv5573 = fv5574.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5573.blank?

                      fv5572 = fv5574.css("input[type='hidden']").to_h do |fv5545|
                        [fv5545["name"], fv5545["value"]]
                      end.except("authenticity_token")
                      [fv5574["action"], fv5573,
                       fv5572,]
                    end
                  end
                fv5560.post(
                  fv5571,
                  params: fv5570.merge(authenticity_token: fv5569),
                  headers: fv5568,
                )
                begin
                  fv5561 = fv5560
                  fv5563 = "session"
                  fv5562 = fv5561.response.cookies[fv5563]
                  if fv5562.nil?
                    fv5567 = fv5561.response.headers["Set-Cookie"] || fv5561.response.headers["set-cookie"]
                    fv5566 =
                      if fv5567.is_a?(String) && fv5567.start_with?("[")
                        JSON.parse(fv5567)
                      else
                        Array(fv5567)
                      end
                    fv5564 =
                      fv5566.flat_map { |fv5565|
                        fv5565.to_s.split("\n")
                      }.find do |fv5565|
                        fv5565.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5563}=")
                      end
                    if fv5564

                      _, fv5562 = fv5564.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5562 = Rack::Utils.unescape(fv5562.to_s)
                    end
                  end

                  unless fv5562.nil?
                    fv5561.cookies.delete(fv5563)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5561.cookies.merge(
                      "#{fv5563}=#{Rack::Utils.escape(fv5562)}",
                      URI.parse("https://#{fv5561.host}/"),
                    )
                  end
                end
                fv5559 = fv5560.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5559.blank?

                fv5556 = URI.parse(fv5559)
                if fv5558[:ri].present?
                  fv5557 = Rack::Utils.parse_nested_query(fv5556.query.to_s)
                  fv5557["ri"] ||= fv5558[:ri].to_s
                  fv5556.query = URI.encode_www_form(fv5557)
                end
                fv5541.host!(fv5556.host)
                fv5541.https!
                fv5555 = fv5556.request_uri
                fv5537 = fv5551.merge("Host" => fv5556.host)
                fv5541.get(
                  fv5555,
                  headers: fv5537,
                )
              else
                fv5552.confirm_base!(
                  base_token: fv5554,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5553,
                    entry_ref: fv5552.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5550 = fv5541.host
                fv5541.host!(fv5550)
                fv5541.https!
                fv5537 = fv5551.merge("Host" => fv5550)
                fv5541.get(
                  fv5549,
                  params: fv5548, headers: fv5537,
                )
              end
              fv5540, fv5538, fv5539 =
                begin
                  fv5547 = fv5541.response.body
                  fv5546 = false
                  fv5544 = Nokogiri::HTML(fv5547).at_css("form")
                  if fv5544.nil? && fv5546
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5544

                    fv5543 = fv5544.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5543.blank?

                    fv5542 = fv5544.css("input[type='hidden']").to_h do |fv5545|
                      [fv5545["name"], fv5545["value"]]
                    end.except("authenticity_token")
                    [fv5544["action"], fv5543,
                     fv5542,]
                  end
                end
              fv5541.post(
                fv5540,
                params: fv5539.merge(authenticity_token: fv5538),
                headers: fv5537,
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

  test "sets lang attribute on html element" do
    begin
      fv5536 = { ri: "jp" }
      begin
        fv5535 = auth_app_sign_up_path(format: :html)
        fv5534 = login_challenge
        fv5533 = :entry_ref
        fv5532 = fv5536
        fv5531 = { "Host" => host }
        fv5530 = false
        fv5529 = nil
        fv5528 = nil
        begin
          fv5474 = self
          fv5482 = fv5535
          fv5526 = fv5534
          fv5527 = fv5533
          fv5491 = fv5532
          fv5484 = fv5531
          fv5514 = fv5530
          fv5513 = fv5529
          fv5487 = fv5528
          fv5481 = fv5491.merge(fv5527 => fv5526)
          fv5474.get(
            fv5482,
            params: fv5481, headers: fv5484,
          )
          fv5520 =
            begin
              fv5525 = fv5474.response.body
              fv5524 = true
              fv5523 = Nokogiri::HTML(fv5525).at_css("form")
              if fv5523.nil? && fv5524
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5523

                fv5522 = fv5523.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5522.blank?

                fv5521 = fv5523.css("input[type='hidden']").to_h do |fv5478|
                  [fv5478["name"], fv5478["value"]]
                end.except("authenticity_token")
                [fv5523["action"], fv5522,
                 fv5521,]
              end
            end
          if fv5520

            fv5519, fv5517, fv5518 = fv5520

            fv5474.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5474.post(
              fv5519,
              params: fv5518.merge(authenticity_token: fv5517), headers: fv5484,
            )
            fv5516 = fv5474.response.location
            if fv5516.present?

              fv5512 = URI.parse(fv5516)
              fv5511 = fv5512.host
              fv5486 =
                begin
                  fv5515 = fv5511
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5515)
                end
              fv5485 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5486, reference: fv5512.path.split("/").fetch(-2),
              )

              if fv5514
                fv5493 = fv5513 || fv5474
                fv5493.host!(fv5511)
                fv5493.https!
                fv5493.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5510 = fv5512.request_uri
                fv5501 = fv5484.merge(
                  "Host" => fv5511,
                  "Origin" => "https://#{fv5511}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5493.get(
                  fv5510,
                  headers: fv5501,
                )
                fv5504, fv5502, fv5503 =
                  begin
                    fv5509 = fv5493.response.body
                    fv5508 = false
                    fv5507 = Nokogiri::HTML(fv5509).at_css("form")
                    if fv5507.nil? && fv5508
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5507

                      fv5506 = fv5507.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5506.blank?

                      fv5505 = fv5507.css("input[type='hidden']").to_h do |fv5478|
                        [fv5478["name"], fv5478["value"]]
                      end.except("authenticity_token")
                      [fv5507["action"], fv5506,
                       fv5505,]
                    end
                  end
                fv5493.post(
                  fv5504,
                  params: fv5503.merge(authenticity_token: fv5502),
                  headers: fv5501,
                )
                begin
                  fv5494 = fv5493
                  fv5496 = "session"
                  fv5495 = fv5494.response.cookies[fv5496]
                  if fv5495.nil?
                    fv5500 = fv5494.response.headers["Set-Cookie"] || fv5494.response.headers["set-cookie"]
                    fv5499 =
                      if fv5500.is_a?(String) && fv5500.start_with?("[")
                        JSON.parse(fv5500)
                      else
                        Array(fv5500)
                      end
                    fv5497 =
                      fv5499.flat_map { |fv5498|
                        fv5498.to_s.split("\n")
                      }.find do |fv5498|
                        fv5498.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5496}=")
                      end
                    if fv5497

                      _, fv5495 = fv5497.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5495 = Rack::Utils.unescape(fv5495.to_s)
                    end
                  end

                  unless fv5495.nil?
                    fv5494.cookies.delete(fv5496)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5494.cookies.merge(
                      "#{fv5496}=#{Rack::Utils.escape(fv5495)}",
                      URI.parse("https://#{fv5494.host}/"),
                    )
                  end
                end
                fv5492 = fv5493.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5492.blank?

                fv5489 = URI.parse(fv5492)
                if fv5491[:ri].present?
                  fv5490 = Rack::Utils.parse_nested_query(fv5489.query.to_s)
                  fv5490["ri"] ||= fv5491[:ri].to_s
                  fv5489.query = URI.encode_www_form(fv5490)
                end
                fv5474.host!(fv5489.host)
                fv5474.https!
                fv5488 = fv5489.request_uri
                fv5470 = fv5484.merge("Host" => fv5489.host)
                fv5474.get(
                  fv5488,
                  headers: fv5470,
                )
              else
                fv5485.confirm_base!(
                  base_token: fv5487,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5486,
                    entry_ref: fv5485.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5483 = fv5474.host
                fv5474.host!(fv5483)
                fv5474.https!
                fv5470 = fv5484.merge("Host" => fv5483)
                fv5474.get(
                  fv5482,
                  params: fv5481, headers: fv5470,
                )
              end
              fv5473, fv5471, fv5472 =
                begin
                  fv5480 = fv5474.response.body
                  fv5479 = false
                  fv5477 = Nokogiri::HTML(fv5480).at_css("form")
                  if fv5477.nil? && fv5479
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5477

                    fv5476 = fv5477.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5476.blank?

                    fv5475 = fv5477.css("input[type='hidden']").to_h do |fv5478|
                      [fv5478["name"], fv5478["value"]]
                    end.except("authenticity_token")
                    [fv5477["action"], fv5476,
                     fv5475,]
                  end
                end
              fv5474.post(
                fv5473,
                params: fv5472.merge(authenticity_token: fv5471),
                headers: fv5470,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_select("html[lang=?]", "ja")
    assert_not_select("html[lang=?]", "")
  end

  test "shows registration methods and social providers" do
    begin
      fv5469 = { ri: "jp" }
      begin
        fv5468 = auth_app_sign_up_path(format: :html)
        fv5467 = login_challenge
        fv5466 = :entry_ref
        fv5465 = fv5469
        fv5464 = { "Host" => host }
        fv5463 = false
        fv5462 = nil
        fv5461 = nil
        begin
          fv5407 = self
          fv5415 = fv5468
          fv5459 = fv5467
          fv5460 = fv5466
          fv5424 = fv5465
          fv5417 = fv5464
          fv5447 = fv5463
          fv5446 = fv5462
          fv5420 = fv5461
          fv5414 = fv5424.merge(fv5460 => fv5459)
          fv5407.get(
            fv5415,
            params: fv5414, headers: fv5417,
          )
          fv5453 =
            begin
              fv5458 = fv5407.response.body
              fv5457 = true
              fv5456 = Nokogiri::HTML(fv5458).at_css("form")
              if fv5456.nil? && fv5457
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5456

                fv5455 = fv5456.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5455.blank?

                fv5454 = fv5456.css("input[type='hidden']").to_h do |fv5411|
                  [fv5411["name"], fv5411["value"]]
                end.except("authenticity_token")
                [fv5456["action"], fv5455,
                 fv5454,]
              end
            end
          if fv5453

            fv5452, fv5450, fv5451 = fv5453

            fv5407.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5407.post(
              fv5452,
              params: fv5451.merge(authenticity_token: fv5450), headers: fv5417,
            )
            fv5449 = fv5407.response.location
            if fv5449.present?

              fv5445 = URI.parse(fv5449)
              fv5444 = fv5445.host
              fv5419 =
                begin
                  fv5448 = fv5444
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5448)
                end
              fv5418 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5419, reference: fv5445.path.split("/").fetch(-2),
              )

              if fv5447
                fv5426 = fv5446 || fv5407
                fv5426.host!(fv5444)
                fv5426.https!
                fv5426.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5443 = fv5445.request_uri
                fv5434 = fv5417.merge(
                  "Host" => fv5444,
                  "Origin" => "https://#{fv5444}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5426.get(
                  fv5443,
                  headers: fv5434,
                )
                fv5437, fv5435, fv5436 =
                  begin
                    fv5442 = fv5426.response.body
                    fv5441 = false
                    fv5440 = Nokogiri::HTML(fv5442).at_css("form")
                    if fv5440.nil? && fv5441
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5440

                      fv5439 = fv5440.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5439.blank?

                      fv5438 = fv5440.css("input[type='hidden']").to_h do |fv5411|
                        [fv5411["name"], fv5411["value"]]
                      end.except("authenticity_token")
                      [fv5440["action"], fv5439,
                       fv5438,]
                    end
                  end
                fv5426.post(
                  fv5437,
                  params: fv5436.merge(authenticity_token: fv5435),
                  headers: fv5434,
                )
                begin
                  fv5427 = fv5426
                  fv5429 = "session"
                  fv5428 = fv5427.response.cookies[fv5429]
                  if fv5428.nil?
                    fv5433 = fv5427.response.headers["Set-Cookie"] || fv5427.response.headers["set-cookie"]
                    fv5432 =
                      if fv5433.is_a?(String) && fv5433.start_with?("[")
                        JSON.parse(fv5433)
                      else
                        Array(fv5433)
                      end
                    fv5430 =
                      fv5432.flat_map { |fv5431|
                        fv5431.to_s.split("\n")
                      }.find do |fv5431|
                        fv5431.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5429}=")
                      end
                    if fv5430

                      _, fv5428 = fv5430.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5428 = Rack::Utils.unescape(fv5428.to_s)
                    end
                  end

                  unless fv5428.nil?
                    fv5427.cookies.delete(fv5429)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5427.cookies.merge(
                      "#{fv5429}=#{Rack::Utils.escape(fv5428)}",
                      URI.parse("https://#{fv5427.host}/"),
                    )
                  end
                end
                fv5425 = fv5426.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5425.blank?

                fv5422 = URI.parse(fv5425)
                if fv5424[:ri].present?
                  fv5423 = Rack::Utils.parse_nested_query(fv5422.query.to_s)
                  fv5423["ri"] ||= fv5424[:ri].to_s
                  fv5422.query = URI.encode_www_form(fv5423)
                end
                fv5407.host!(fv5422.host)
                fv5407.https!
                fv5421 = fv5422.request_uri
                fv5403 = fv5417.merge("Host" => fv5422.host)
                fv5407.get(
                  fv5421,
                  headers: fv5403,
                )
              else
                fv5418.confirm_base!(
                  base_token: fv5420,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5419,
                    entry_ref: fv5418.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5416 = fv5407.host
                fv5407.host!(fv5416)
                fv5407.https!
                fv5403 = fv5417.merge("Host" => fv5416)
                fv5407.get(
                  fv5415,
                  params: fv5414, headers: fv5403,
                )
              end
              fv5406, fv5404, fv5405 =
                begin
                  fv5413 = fv5407.response.body
                  fv5412 = false
                  fv5410 = Nokogiri::HTML(fv5413).at_css("form")
                  if fv5410.nil? && fv5412
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5410

                    fv5409 = fv5410.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5409.blank?

                    fv5408 = fv5410.css("input[type='hidden']").to_h do |fv5411|
                      [fv5411["name"], fv5411["value"]]
                    end.except("authenticity_token")
                    [fv5410["action"], fv5409,
                     fv5408,]
                  end
                end
              fv5407.post(
                fv5406,
                params: fv5405.merge(authenticity_token: fv5404),
                headers: fv5403,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success

    # The four entry points the page offers: two contact methods and two providers.
    assert_equal 4, inertia_props.fetch("methods").size + inertia_props.fetch("social_providers").size
    assert_equal I18n.t("actions.cancel"), inertia_props.fetch("cancel_label")
  end

  test "shows telephone registration link" do
    begin
      fv5402 = { ri: "jp" }
      begin
        fv5401 = auth_app_sign_up_path(format: :html)
        fv5400 = login_challenge
        fv5399 = :entry_ref
        fv5398 = fv5402
        fv5397 = { "Host" => host }
        fv5396 = false
        fv5395 = nil
        fv5394 = nil
        begin
          fv5340 = self
          fv5348 = fv5401
          fv5392 = fv5400
          fv5393 = fv5399
          fv5357 = fv5398
          fv5350 = fv5397
          fv5380 = fv5396
          fv5379 = fv5395
          fv5353 = fv5394
          fv5347 = fv5357.merge(fv5393 => fv5392)
          fv5340.get(
            fv5348,
            params: fv5347, headers: fv5350,
          )
          fv5386 =
            begin
              fv5391 = fv5340.response.body
              fv5390 = true
              fv5389 = Nokogiri::HTML(fv5391).at_css("form")
              if fv5389.nil? && fv5390
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5389

                fv5388 = fv5389.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5388.blank?

                fv5387 = fv5389.css("input[type='hidden']").to_h do |fv5344|
                  [fv5344["name"], fv5344["value"]]
                end.except("authenticity_token")
                [fv5389["action"], fv5388,
                 fv5387,]
              end
            end
          if fv5386

            fv5385, fv5383, fv5384 = fv5386

            fv5340.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5340.post(
              fv5385,
              params: fv5384.merge(authenticity_token: fv5383), headers: fv5350,
            )
            fv5382 = fv5340.response.location
            if fv5382.present?

              fv5378 = URI.parse(fv5382)
              fv5377 = fv5378.host
              fv5352 =
                begin
                  fv5381 = fv5377
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5381)
                end
              fv5351 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5352, reference: fv5378.path.split("/").fetch(-2),
              )

              if fv5380
                fv5359 = fv5379 || fv5340
                fv5359.host!(fv5377)
                fv5359.https!
                fv5359.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5376 = fv5378.request_uri
                fv5367 = fv5350.merge(
                  "Host" => fv5377,
                  "Origin" => "https://#{fv5377}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5359.get(
                  fv5376,
                  headers: fv5367,
                )
                fv5370, fv5368, fv5369 =
                  begin
                    fv5375 = fv5359.response.body
                    fv5374 = false
                    fv5373 = Nokogiri::HTML(fv5375).at_css("form")
                    if fv5373.nil? && fv5374
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5373

                      fv5372 = fv5373.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5372.blank?

                      fv5371 = fv5373.css("input[type='hidden']").to_h do |fv5344|
                        [fv5344["name"], fv5344["value"]]
                      end.except("authenticity_token")
                      [fv5373["action"], fv5372,
                       fv5371,]
                    end
                  end
                fv5359.post(
                  fv5370,
                  params: fv5369.merge(authenticity_token: fv5368),
                  headers: fv5367,
                )
                begin
                  fv5360 = fv5359
                  fv5362 = "session"
                  fv5361 = fv5360.response.cookies[fv5362]
                  if fv5361.nil?
                    fv5366 = fv5360.response.headers["Set-Cookie"] || fv5360.response.headers["set-cookie"]
                    fv5365 =
                      if fv5366.is_a?(String) && fv5366.start_with?("[")
                        JSON.parse(fv5366)
                      else
                        Array(fv5366)
                      end
                    fv5363 =
                      fv5365.flat_map { |fv5364|
                        fv5364.to_s.split("\n")
                      }.find do |fv5364|
                        fv5364.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5362}=")
                      end
                    if fv5363

                      _, fv5361 = fv5363.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5361 = Rack::Utils.unescape(fv5361.to_s)
                    end
                  end

                  unless fv5361.nil?
                    fv5360.cookies.delete(fv5362)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5360.cookies.merge(
                      "#{fv5362}=#{Rack::Utils.escape(fv5361)}",
                      URI.parse("https://#{fv5360.host}/"),
                    )
                  end
                end
                fv5358 = fv5359.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5358.blank?

                fv5355 = URI.parse(fv5358)
                if fv5357[:ri].present?
                  fv5356 = Rack::Utils.parse_nested_query(fv5355.query.to_s)
                  fv5356["ri"] ||= fv5357[:ri].to_s
                  fv5355.query = URI.encode_www_form(fv5356)
                end
                fv5340.host!(fv5355.host)
                fv5340.https!
                fv5354 = fv5355.request_uri
                fv5336 = fv5350.merge("Host" => fv5355.host)
                fv5340.get(
                  fv5354,
                  headers: fv5336,
                )
              else
                fv5351.confirm_base!(
                  base_token: fv5353,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5352,
                    entry_ref: fv5351.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5349 = fv5340.host
                fv5340.host!(fv5349)
                fv5340.https!
                fv5336 = fv5350.merge("Host" => fv5349)
                fv5340.get(
                  fv5348,
                  params: fv5347, headers: fv5336,
                )
              end
              fv5339, fv5337, fv5338 =
                begin
                  fv5346 = fv5340.response.body
                  fv5345 = false
                  fv5343 = Nokogiri::HTML(fv5346).at_css("form")
                  if fv5343.nil? && fv5345
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5343

                    fv5342 = fv5343.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5342.blank?

                    fv5341 = fv5343.css("input[type='hidden']").to_h do |fv5344|
                      [fv5344["name"], fv5344["value"]]
                    end.except("authenticity_token")
                    [fv5343["action"], fv5342,
                     fv5341,]
                  end
                end
              fv5340.post(
                fv5339,
                params: fv5338.merge(authenticity_token: fv5337),
                headers: fv5336,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal(
      [new_auth_app_sign_up_telephone_path(ri: "jp")],
      inertia_props.fetch("methods").filter_map { |method| method.fetch("href") if method.fetch("key") == "telephone" },
    )
  end

  test "shows social login buttons" do
    begin
      fv5335 = { ri: "jp" }
      begin
        fv5334 = auth_app_sign_up_path(format: :html)
        fv5333 = login_challenge
        fv5332 = :entry_ref
        fv5331 = fv5335
        fv5330 = { "Host" => host }
        fv5329 = false
        fv5328 = nil
        fv5327 = nil
        begin
          fv5273 = self
          fv5281 = fv5334
          fv5325 = fv5333
          fv5326 = fv5332
          fv5290 = fv5331
          fv5283 = fv5330
          fv5313 = fv5329
          fv5312 = fv5328
          fv5286 = fv5327
          fv5280 = fv5290.merge(fv5326 => fv5325)
          fv5273.get(
            fv5281,
            params: fv5280, headers: fv5283,
          )
          fv5319 =
            begin
              fv5324 = fv5273.response.body
              fv5323 = true
              fv5322 = Nokogiri::HTML(fv5324).at_css("form")
              if fv5322.nil? && fv5323
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5322

                fv5321 = fv5322.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5321.blank?

                fv5320 = fv5322.css("input[type='hidden']").to_h do |fv5277|
                  [fv5277["name"], fv5277["value"]]
                end.except("authenticity_token")
                [fv5322["action"], fv5321,
                 fv5320,]
              end
            end
          if fv5319

            fv5318, fv5316, fv5317 = fv5319

            fv5273.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5273.post(
              fv5318,
              params: fv5317.merge(authenticity_token: fv5316), headers: fv5283,
            )
            fv5315 = fv5273.response.location
            if fv5315.present?

              fv5311 = URI.parse(fv5315)
              fv5310 = fv5311.host
              fv5285 =
                begin
                  fv5314 = fv5310
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5314)
                end
              fv5284 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5285, reference: fv5311.path.split("/").fetch(-2),
              )

              if fv5313
                fv5292 = fv5312 || fv5273
                fv5292.host!(fv5310)
                fv5292.https!
                fv5292.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5309 = fv5311.request_uri
                fv5300 = fv5283.merge(
                  "Host" => fv5310,
                  "Origin" => "https://#{fv5310}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5292.get(
                  fv5309,
                  headers: fv5300,
                )
                fv5303, fv5301, fv5302 =
                  begin
                    fv5308 = fv5292.response.body
                    fv5307 = false
                    fv5306 = Nokogiri::HTML(fv5308).at_css("form")
                    if fv5306.nil? && fv5307
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5306

                      fv5305 = fv5306.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5305.blank?

                      fv5304 = fv5306.css("input[type='hidden']").to_h do |fv5277|
                        [fv5277["name"], fv5277["value"]]
                      end.except("authenticity_token")
                      [fv5306["action"], fv5305,
                       fv5304,]
                    end
                  end
                fv5292.post(
                  fv5303,
                  params: fv5302.merge(authenticity_token: fv5301),
                  headers: fv5300,
                )
                begin
                  fv5293 = fv5292
                  fv5295 = "session"
                  fv5294 = fv5293.response.cookies[fv5295]
                  if fv5294.nil?
                    fv5299 = fv5293.response.headers["Set-Cookie"] || fv5293.response.headers["set-cookie"]
                    fv5298 =
                      if fv5299.is_a?(String) && fv5299.start_with?("[")
                        JSON.parse(fv5299)
                      else
                        Array(fv5299)
                      end
                    fv5296 =
                      fv5298.flat_map { |fv5297|
                        fv5297.to_s.split("\n")
                      }.find do |fv5297|
                        fv5297.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5295}=")
                      end
                    if fv5296

                      _, fv5294 = fv5296.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5294 = Rack::Utils.unescape(fv5294.to_s)
                    end
                  end

                  unless fv5294.nil?
                    fv5293.cookies.delete(fv5295)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5293.cookies.merge(
                      "#{fv5295}=#{Rack::Utils.escape(fv5294)}",
                      URI.parse("https://#{fv5293.host}/"),
                    )
                  end
                end
                fv5291 = fv5292.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5291.blank?

                fv5288 = URI.parse(fv5291)
                if fv5290[:ri].present?
                  fv5289 = Rack::Utils.parse_nested_query(fv5288.query.to_s)
                  fv5289["ri"] ||= fv5290[:ri].to_s
                  fv5288.query = URI.encode_www_form(fv5289)
                end
                fv5273.host!(fv5288.host)
                fv5273.https!
                fv5287 = fv5288.request_uri
                fv5269 = fv5283.merge("Host" => fv5288.host)
                fv5273.get(
                  fv5287,
                  headers: fv5269,
                )
              else
                fv5284.confirm_base!(
                  base_token: fv5286,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5285,
                    entry_ref: fv5284.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5282 = fv5273.host
                fv5273.host!(fv5282)
                fv5273.https!
                fv5269 = fv5283.merge("Host" => fv5282)
                fv5273.get(
                  fv5281,
                  params: fv5280, headers: fv5269,
                )
              end
              fv5272, fv5270, fv5271 =
                begin
                  fv5279 = fv5273.response.body
                  fv5278 = false
                  fv5276 = Nokogiri::HTML(fv5279).at_css("form")
                  if fv5276.nil? && fv5278
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5276

                    fv5275 = fv5276.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5275.blank?

                    fv5274 = fv5276.css("input[type='hidden']").to_h do |fv5277|
                      [fv5277["name"], fv5277["value"]]
                    end.except("authenticity_token")
                    [fv5276["action"], fv5275,
                     fv5274,]
                  end
                end
              fv5273.post(
                fv5272,
                params: fv5271.merge(authenticity_token: fv5270),
                headers: fv5269,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # The provider buttons keep posting to the ceremony endpoints; the button markup and its
    # CSRF field are covered by gait/features/auth/signup/social_provider_button.test.tsx.
    providers = inertia_props.fetch("social_providers")

    assert_equal(
      [["google", auth_app_social_google_registration_path(ri: "jp")],
       ["apple", auth_app_social_apple_registration_path(ri: "jp")],],
      providers.map { |provider| [provider.fetch("provider"), provider.fetch("url")] },
    )
  end

  test "renders registration layout structure" do
    begin
      fv5268 = { ri: "jp" }
      begin
        fv5267 = auth_app_sign_up_path(format: :html)
        fv5266 = login_challenge
        fv5265 = :entry_ref
        fv5264 = fv5268
        fv5263 = { "Host" => host }
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

    expected_brand = brand_name

    # The header, the main region and the footer are the React surface layout's; what the server
    # still owns is the chrome payload it renders them from.
    assert_select "head", count: 1
    assert_select "body", count: 1
    assert_match(/^©.*#{Regexp.escape(expected_brand)}$/, inertia_props.fetch("chrome").fetch("copyright"))
  end

  test "page renders the registration heading and no sign-in/up chrome navigation" do
    begin
      fv5201 = { ri: "jp" }
      begin
        fv5200 = auth_app_sign_up_path(format: :html)
        fv5199 = login_challenge
        fv5198 = :entry_ref
        fv5197 = fv5201
        fv5196 = { "Host" => host }
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
    # The auth surface is itself the sign-in/sign-up entry point, so its shared header carries no
    # navigation back to those flows.
    assert_not inertia_props.fetch("chrome").key?("primary_navigation")
    assert_equal I18n.t("sign.app.registration.new.page_title"), inertia_props.fetch("title")
  end

  test "footer contains navigation links" do
    begin
      fv5134 = { ri: "jp" }
      begin
        fv5133 = auth_app_sign_up_path(format: :html)
        fv5132 = login_challenge
        fv5131 = :entry_ref
        fv5130 = fv5134
        fv5129 = { "Host" => host }
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
    # Footer should contain copyright and links
    assert_not_empty inertia_props.fetch("chrome").fetch("footer_navigation")
    assert_not_empty inertia_props.fetch("chrome").fetch("copyright")
  end

  test "renders specific cta text" do
    begin
      fv5067 = { ri: "jp" }
      begin
        fv5066 = auth_app_sign_up_path(format: :html)
        fv5065 = login_challenge
        fv5064 = :entry_ref
        fv5063 = fv5067
        fv5062 = { "Host" => host }
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
    # Check for Japanese text (since previous test asserted lang=ja)
    assert_includes inertia_props.fetch("methods").map { |method| method.fetch("label") }, "メールで登録する"
  end

  test "logged in direct entry is refused with a plain 403" do
    user = clients(:one)
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: as_user_headers(user, host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
  end

  test "checkpoint without active registration redirects to sign up start" do
    get auth_app_sign_up_guard_email_path(ri: "jp"), headers: { "Host" => host }

    assert_redirected_to auth_app_sign_up_url(ri: "jp")
  end

  private

  def host
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
  end

  def brand_name
    (ENV["BRAND_NAME"].presence || ENV["NAME"]).to_s
  end

  def login_challenge
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
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
      client_id: "core-app-jp",
      redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(16),
      nonce: SecureRandom.urlsafe_base64(16),
      scope: "openid profile",
    }
  end
  private
end

# DAMP auth header helpers for this test class.
class Auth::App::SignUpsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Auth::App::SignUpsControllerTest
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
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
end
