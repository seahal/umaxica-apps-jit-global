# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  module App
    class AuthInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host! @host
      end

      test "direct entry without login challenge is refused without admission" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :bad_request
        assert_nil response.location
        assert_includes response.headers["Cache-Control"], "no-store"

        assert_nil session[:oidc_authorization_login_challenge]
      end

      test "direct entry without login challenge starts no OIDC handoff state" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_nil session[:oidc_authorization_login_challenge]
        assert_nil session[:oidc_code_verifier]
        assert_nil session[:oidc_state]
        assert_nil session[:oidc_nonce]
        assert_nil session["oidc_pending_flows"]
      end

      test "local ceremony renders supported authentication links without the device mock" do
        begin
          fv5669 = { ri: "jp" }
          begin
            fv5668 = auth_app_sign_in_path
            fv5667 = login_challenge
            fv5666 = :entry_ref
            fv5665 = fv5669
            fv5664 = { "Host" => @host }
            fv5663 = false
            fv5662 = nil
            fv5661 = nil
            begin
              fv5607 = self
              fv5615 = fv5668
              fv5659 = fv5667
              fv5660 = fv5666
              fv5624 = fv5665
              fv5617 = fv5664
              fv5647 = fv5663
              fv5646 = fv5662
              fv5620 = fv5661
              fv5614 = fv5624.merge(fv5660 => fv5659)
              fv5607.get(
                fv5615,
                params: fv5614, headers: fv5617,
              )
              fv5653 =
                begin
                  fv5658 = fv5607.response.body
                  fv5657 = true
                  fv5656 = Nokogiri::HTML(fv5658).at_css("form")
                  if fv5656.nil? && fv5657
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5656

                    fv5655 = fv5656.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5655.blank?

                    fv5654 = fv5656.css("input[type='hidden']").to_h do |fv5611|
                      [fv5611["name"], fv5611["value"]]
                    end.except("authenticity_token")
                    [fv5656["action"], fv5655,
                     fv5654,]
                  end
                end
              if fv5653

                fv5652, fv5650, fv5651 = fv5653

                fv5607.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5607.post(
                  fv5652, params: fv5651.merge(authenticity_token: fv5650),
                          headers: fv5617,
                )
                fv5649 = fv5607.response.location
                if fv5649.present?

                  fv5645 = URI.parse(fv5649)
                  fv5644 = fv5645.host
                  fv5619 =
                    begin
                      fv5648 = fv5644
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5648)
                    end
                  fv5618 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5619, reference: fv5645.path.split("/").fetch(-2),
                  )

                  if fv5647
                    fv5626 = fv5646 || fv5607
                    fv5626.host!(fv5644)
                    fv5626.https!
                    fv5626.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5643 = fv5645.request_uri
                    fv5634 = fv5617.merge(
                      "Host" => fv5644,
                      "Origin" => "https://#{fv5644}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5626.get(
                      fv5643,
                      headers: fv5634,
                    )
                    fv5637, fv5635, fv5636 =
                      begin
                        fv5642 = fv5626.response.body
                        fv5641 = false
                        fv5640 = Nokogiri::HTML(fv5642).at_css("form")
                        if fv5640.nil? && fv5641
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5640

                          fv5639 = fv5640.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5639.blank?

                          fv5638 = fv5640.css("input[type='hidden']").to_h do |fv5611|
                            [fv5611["name"], fv5611["value"]]
                          end.except("authenticity_token")
                          [fv5640["action"], fv5639,
                           fv5638,]
                        end
                      end
                    fv5626.post(
                      fv5637,
                      params: fv5636.merge(authenticity_token: fv5635),
                      headers: fv5634,
                    )
                    begin
                      fv5627 = fv5626
                      fv5629 = "session"
                      fv5628 = fv5627.response.cookies[fv5629]
                      if fv5628.nil?
                        fv5633 = fv5627.response.headers["Set-Cookie"] || fv5627.response.headers["set-cookie"]
                        fv5632 =
                          if fv5633.is_a?(String) && fv5633.start_with?("[")
                            JSON.parse(fv5633)
                          else
                            Array(fv5633)
                          end
                        fv5630 =
                          fv5632.flat_map { |fv5631|
                            fv5631.to_s.split("\n")
                          }.find do |fv5631|
                            fv5631.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5629}=")
                          end
                        if fv5630

                          _, fv5628 = fv5630.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5628 = Rack::Utils.unescape(fv5628.to_s)
                        end
                      end

                      unless fv5628.nil?
                        fv5627.cookies.delete(fv5629)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5627.cookies.merge(
                          "#{fv5629}=#{Rack::Utils.escape(fv5628)}",
                          URI.parse("https://#{fv5627.host}/"),
                        )
                      end
                    end
                    fv5625 = fv5626.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5625.blank?

                    fv5622 = URI.parse(fv5625)
                    if fv5624[:ri].present?
                      fv5623 = Rack::Utils.parse_nested_query(fv5622.query.to_s)
                      fv5623["ri"] ||= fv5624[:ri].to_s
                      fv5622.query = URI.encode_www_form(fv5623)
                    end
                    fv5607.host!(fv5622.host)
                    fv5607.https!
                    fv5621 = fv5622.request_uri
                    fv5603 = fv5617.merge("Host" => fv5622.host)
                    fv5607.get(
                      fv5621,
                      headers: fv5603,
                    )
                  else
                    fv5618.confirm_base!(
                      base_token: fv5620,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5619,
                        entry_ref: fv5618.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5616 = fv5607.host
                    fv5607.host!(fv5616)
                    fv5607.https!
                    fv5603 = fv5617.merge("Host" => fv5616)
                    fv5607.get(
                      fv5615,
                      params: fv5614, headers: fv5603,
                    )
                  end
                  fv5606, fv5604, fv5605 =
                    begin
                      fv5613 = fv5607.response.body
                      fv5612 = false
                      fv5610 = Nokogiri::HTML(fv5613).at_css("form")
                      if fv5610.nil? && fv5612
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5610

                        fv5609 = fv5610.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5609.blank?

                        fv5608 = fv5610.css("input[type='hidden']").to_h do |fv5611|
                          [fv5611["name"], fv5611["value"]]
                        end.except("authenticity_token")
                        [fv5610["action"], fv5609,
                         fv5608,]
                      end
                    end
                  fv5607.post(
                    fv5606,
                    params: fv5605.merge(authenticity_token: fv5604),
                    headers: fv5603,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success

        query = {}

        assert_equal [
          [new_auth_app_sign_in_email_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.email")],
          [new_auth_app_sign_in_passkey_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.passkey")],
          [new_auth_app_sign_in_secret_url(query, ri: "jp", host: @host),
           I18n.t("sign.app.authentication.new.links.secret"),],
        ], inertia_props.fetch("methods").map { |method| [method.fetch("href"), method.fetch("label")] }
        assert_equal %w(email passkey secret), inertia_props.fetch("methods").map { |method|
          method.fetch("key")
        }
        assert_equal %w(google apple), inertia_props.fetch("social_providers").map { |provider| provider.fetch("key") }
        # This page is admitted for an OIDC parent and is still its first page: Cancel and Switch are
        # offered as POST forms, and the plain Auth-to-Auth link to Sign Up is not (D06/D09).
        assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
        assert_equal "sign_up", inertia_props.fetch("switch_form").fetch("to")
        assert_nil inertia_props.fetch("registration_link")
      end

      test "should get new with existing preference refresh cookie" do
        token, verifier = AppPreference.generate_refresh_token(public_id: "app-pref-existingxxxx")
        preference = AppPreference.create!(
          public_id: "app-pref-existingxxxx",
          token_digest: AppPreference.digest_refresh_token(verifier),
          jti: SecureRandom.uuid,
          status_id: AppPreferenceStatus::NOTHING,
          binding_method_id: AppPreferenceBindingMethod::LEGACY,
          dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
          expires_at: 20.years.from_now,
        )
        AppPreferenceCookie.create!(preference: preference)
        cookies[::PreferenceCookieName.refresh(surface: :app)] = token

        begin
          fv5602 = { ri: "jp" }
          begin
            fv5601 = auth_app_sign_in_path
            fv5600 = login_challenge
            fv5599 = :entry_ref
            fv5598 = fv5602
            fv5597 = { "Host" => @host }
            fv5596 = false
            fv5595 = nil
            fv5594 = nil
            begin
              fv5540 = self
              fv5548 = fv5601
              fv5592 = fv5600
              fv5593 = fv5599
              fv5557 = fv5598
              fv5550 = fv5597
              fv5580 = fv5596
              fv5579 = fv5595
              fv5553 = fv5594
              fv5547 = fv5557.merge(fv5593 => fv5592)
              fv5540.get(
                fv5548,
                params: fv5547, headers: fv5550,
              )
              fv5586 =
                begin
                  fv5591 = fv5540.response.body
                  fv5590 = true
                  fv5589 = Nokogiri::HTML(fv5591).at_css("form")
                  if fv5589.nil? && fv5590
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5589

                    fv5588 = fv5589.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5588.blank?

                    fv5587 = fv5589.css("input[type='hidden']").to_h do |fv5544|
                      [fv5544["name"], fv5544["value"]]
                    end.except("authenticity_token")
                    [fv5589["action"], fv5588,
                     fv5587,]
                  end
                end
              if fv5586

                fv5585, fv5583, fv5584 = fv5586

                fv5540.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5540.post(
                  fv5585, params: fv5584.merge(authenticity_token: fv5583),
                          headers: fv5550,
                )
                fv5582 = fv5540.response.location
                if fv5582.present?

                  fv5578 = URI.parse(fv5582)
                  fv5577 = fv5578.host
                  fv5552 =
                    begin
                      fv5581 = fv5577
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5581)
                    end
                  fv5551 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5552, reference: fv5578.path.split("/").fetch(-2),
                  )

                  if fv5580
                    fv5559 = fv5579 || fv5540
                    fv5559.host!(fv5577)
                    fv5559.https!
                    fv5559.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5576 = fv5578.request_uri
                    fv5567 = fv5550.merge(
                      "Host" => fv5577,
                      "Origin" => "https://#{fv5577}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5559.get(
                      fv5576,
                      headers: fv5567,
                    )
                    fv5570, fv5568, fv5569 =
                      begin
                        fv5575 = fv5559.response.body
                        fv5574 = false
                        fv5573 = Nokogiri::HTML(fv5575).at_css("form")
                        if fv5573.nil? && fv5574
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5573

                          fv5572 = fv5573.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5572.blank?

                          fv5571 = fv5573.css("input[type='hidden']").to_h do |fv5544|
                            [fv5544["name"], fv5544["value"]]
                          end.except("authenticity_token")
                          [fv5573["action"], fv5572,
                           fv5571,]
                        end
                      end
                    fv5559.post(
                      fv5570,
                      params: fv5569.merge(authenticity_token: fv5568),
                      headers: fv5567,
                    )
                    begin
                      fv5560 = fv5559
                      fv5562 = "session"
                      fv5561 = fv5560.response.cookies[fv5562]
                      if fv5561.nil?
                        fv5566 = fv5560.response.headers["Set-Cookie"] || fv5560.response.headers["set-cookie"]
                        fv5565 =
                          if fv5566.is_a?(String) && fv5566.start_with?("[")
                            JSON.parse(fv5566)
                          else
                            Array(fv5566)
                          end
                        fv5563 =
                          fv5565.flat_map { |fv5564|
                            fv5564.to_s.split("\n")
                          }.find do |fv5564|
                            fv5564.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5562}=")
                          end
                        if fv5563

                          _, fv5561 = fv5563.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5561 = Rack::Utils.unescape(fv5561.to_s)
                        end
                      end

                      unless fv5561.nil?
                        fv5560.cookies.delete(fv5562)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5560.cookies.merge(
                          "#{fv5562}=#{Rack::Utils.escape(fv5561)}",
                          URI.parse("https://#{fv5560.host}/"),
                        )
                      end
                    end
                    fv5558 = fv5559.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5558.blank?

                    fv5555 = URI.parse(fv5558)
                    if fv5557[:ri].present?
                      fv5556 = Rack::Utils.parse_nested_query(fv5555.query.to_s)
                      fv5556["ri"] ||= fv5557[:ri].to_s
                      fv5555.query = URI.encode_www_form(fv5556)
                    end
                    fv5540.host!(fv5555.host)
                    fv5540.https!
                    fv5554 = fv5555.request_uri
                    fv5536 = fv5550.merge("Host" => fv5555.host)
                    fv5540.get(
                      fv5554,
                      headers: fv5536,
                    )
                  else
                    fv5551.confirm_base!(
                      base_token: fv5553,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5552,
                        entry_ref: fv5551.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5549 = fv5540.host
                    fv5540.host!(fv5549)
                    fv5540.https!
                    fv5536 = fv5550.merge("Host" => fv5549)
                    fv5540.get(
                      fv5548,
                      params: fv5547, headers: fv5536,
                    )
                  end
                  fv5539, fv5537, fv5538 =
                    begin
                      fv5546 = fv5540.response.body
                      fv5545 = false
                      fv5543 = Nokogiri::HTML(fv5546).at_css("form")
                      if fv5543.nil? && fv5545
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5543

                        fv5542 = fv5543.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5542.blank?

                        fv5541 = fv5543.css("input[type='hidden']").to_h do |fv5544|
                          [fv5544["name"], fv5544["value"]]
                        end.except("authenticity_token")
                        [fv5543["action"], fv5542,
                         fv5541,]
                      end
                    end
                  fv5540.post(
                    fv5539,
                    params: fv5538.merge(authenticity_token: fv5537),
                    headers: fv5536,
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

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://log.umaxica.app/settings/sessions?ri=jp", padding: false)

        begin
          fv5535 = { ri: "jp", pt: pt }
          begin
            fv5534 = auth_app_sign_in_path
            fv5533 = login_challenge
            fv5532 = :entry_ref
            fv5531 = fv5535
            fv5530 = { "Host" => @host }
            fv5529 = false
            fv5528 = nil
            fv5527 = nil
            begin
              fv5473 = self
              fv5481 = fv5534
              fv5525 = fv5533
              fv5526 = fv5532
              fv5490 = fv5531
              fv5483 = fv5530
              fv5513 = fv5529
              fv5512 = fv5528
              fv5486 = fv5527
              fv5480 = fv5490.merge(fv5526 => fv5525)
              fv5473.get(
                fv5481,
                params: fv5480, headers: fv5483,
              )
              fv5519 =
                begin
                  fv5524 = fv5473.response.body
                  fv5523 = true
                  fv5522 = Nokogiri::HTML(fv5524).at_css("form")
                  if fv5522.nil? && fv5523
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5522

                    fv5521 = fv5522.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5521.blank?

                    fv5520 = fv5522.css("input[type='hidden']").to_h do |fv5477|
                      [fv5477["name"], fv5477["value"]]
                    end.except("authenticity_token")
                    [fv5522["action"], fv5521,
                     fv5520,]
                  end
                end
              if fv5519

                fv5518, fv5516, fv5517 = fv5519

                fv5473.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5473.post(
                  fv5518, params: fv5517.merge(authenticity_token: fv5516),
                          headers: fv5483,
                )
                fv5515 = fv5473.response.location
                if fv5515.present?

                  fv5511 = URI.parse(fv5515)
                  fv5510 = fv5511.host
                  fv5485 =
                    begin
                      fv5514 = fv5510
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5514)
                    end
                  fv5484 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5485, reference: fv5511.path.split("/").fetch(-2),
                  )

                  if fv5513
                    fv5492 = fv5512 || fv5473
                    fv5492.host!(fv5510)
                    fv5492.https!
                    fv5492.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5509 = fv5511.request_uri
                    fv5500 = fv5483.merge(
                      "Host" => fv5510,
                      "Origin" => "https://#{fv5510}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5492.get(
                      fv5509,
                      headers: fv5500,
                    )
                    fv5503, fv5501, fv5502 =
                      begin
                        fv5508 = fv5492.response.body
                        fv5507 = false
                        fv5506 = Nokogiri::HTML(fv5508).at_css("form")
                        if fv5506.nil? && fv5507
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5506

                          fv5505 = fv5506.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5505.blank?

                          fv5504 = fv5506.css("input[type='hidden']").to_h do |fv5477|
                            [fv5477["name"], fv5477["value"]]
                          end.except("authenticity_token")
                          [fv5506["action"], fv5505,
                           fv5504,]
                        end
                      end
                    fv5492.post(
                      fv5503,
                      params: fv5502.merge(authenticity_token: fv5501),
                      headers: fv5500,
                    )
                    begin
                      fv5493 = fv5492
                      fv5495 = "session"
                      fv5494 = fv5493.response.cookies[fv5495]
                      if fv5494.nil?
                        fv5499 = fv5493.response.headers["Set-Cookie"] || fv5493.response.headers["set-cookie"]
                        fv5498 =
                          if fv5499.is_a?(String) && fv5499.start_with?("[")
                            JSON.parse(fv5499)
                          else
                            Array(fv5499)
                          end
                        fv5496 =
                          fv5498.flat_map { |fv5497|
                            fv5497.to_s.split("\n")
                          }.find do |fv5497|
                            fv5497.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5495}=")
                          end
                        if fv5496

                          _, fv5494 = fv5496.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5494 = Rack::Utils.unescape(fv5494.to_s)
                        end
                      end

                      unless fv5494.nil?
                        fv5493.cookies.delete(fv5495)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5493.cookies.merge(
                          "#{fv5495}=#{Rack::Utils.escape(fv5494)}",
                          URI.parse("https://#{fv5493.host}/"),
                        )
                      end
                    end
                    fv5491 = fv5492.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5491.blank?

                    fv5488 = URI.parse(fv5491)
                    if fv5490[:ri].present?
                      fv5489 = Rack::Utils.parse_nested_query(fv5488.query.to_s)
                      fv5489["ri"] ||= fv5490[:ri].to_s
                      fv5488.query = URI.encode_www_form(fv5489)
                    end
                    fv5473.host!(fv5488.host)
                    fv5473.https!
                    fv5487 = fv5488.request_uri
                    fv5469 = fv5483.merge("Host" => fv5488.host)
                    fv5473.get(
                      fv5487,
                      headers: fv5469,
                    )
                  else
                    fv5484.confirm_base!(
                      base_token: fv5486,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5485,
                        entry_ref: fv5484.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5482 = fv5473.host
                    fv5473.host!(fv5482)
                    fv5473.https!
                    fv5469 = fv5483.merge("Host" => fv5482)
                    fv5473.get(
                      fv5481,
                      params: fv5480, headers: fv5469,
                    )
                  end
                  fv5472, fv5470, fv5471 =
                    begin
                      fv5479 = fv5473.response.body
                      fv5478 = false
                      fv5476 = Nokogiri::HTML(fv5479).at_css("form")
                      if fv5476.nil? && fv5478
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5476

                        fv5475 = fv5476.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5475.blank?

                        fv5474 = fv5476.css("input[type='hidden']").to_h do |fv5477|
                          [fv5477["name"], fv5477["value"]]
                        end.except("authenticity_token")
                        [fv5476["action"], fv5475,
                         fv5474,]
                      end
                    end
                  fv5473.post(
                    fv5472,
                    params: fv5471.merge(authenticity_token: fv5470),
                    headers: fv5469,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        assert_equal [
          new_auth_app_sign_in_email_path(ri: "jp"),
          new_auth_app_sign_in_passkey_path(ri: "jp"),
          new_auth_app_sign_in_secret_url(ri: "jp", host: @host),
        ], inertia_props.fetch("methods").map { |method| method.fetch("href") }
      end

      test "sign up link includes pt when pt is present" do
        begin
          fv5468 = { ri: "jp", pt: "abc" }
          begin
            fv5467 = auth_app_sign_in_path
            fv5466 = login_challenge
            fv5465 = :entry_ref
            fv5464 = fv5468
            fv5463 = { "Host" => @host }
            fv5462 = false
            fv5461 = nil
            fv5460 = nil
            begin
              fv5406 = self
              fv5414 = fv5467
              fv5458 = fv5466
              fv5459 = fv5465
              fv5423 = fv5464
              fv5416 = fv5463
              fv5446 = fv5462
              fv5445 = fv5461
              fv5419 = fv5460
              fv5413 = fv5423.merge(fv5459 => fv5458)
              fv5406.get(
                fv5414,
                params: fv5413, headers: fv5416,
              )
              fv5452 =
                begin
                  fv5457 = fv5406.response.body
                  fv5456 = true
                  fv5455 = Nokogiri::HTML(fv5457).at_css("form")
                  if fv5455.nil? && fv5456
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5455

                    fv5454 = fv5455.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5454.blank?

                    fv5453 = fv5455.css("input[type='hidden']").to_h do |fv5410|
                      [fv5410["name"], fv5410["value"]]
                    end.except("authenticity_token")
                    [fv5455["action"], fv5454,
                     fv5453,]
                  end
                end
              if fv5452

                fv5451, fv5449, fv5450 = fv5452

                fv5406.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5406.post(
                  fv5451, params: fv5450.merge(authenticity_token: fv5449),
                          headers: fv5416,
                )
                fv5448 = fv5406.response.location
                if fv5448.present?

                  fv5444 = URI.parse(fv5448)
                  fv5443 = fv5444.host
                  fv5418 =
                    begin
                      fv5447 = fv5443
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5447)
                    end
                  fv5417 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5418, reference: fv5444.path.split("/").fetch(-2),
                  )

                  if fv5446
                    fv5425 = fv5445 || fv5406
                    fv5425.host!(fv5443)
                    fv5425.https!
                    fv5425.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5442 = fv5444.request_uri
                    fv5433 = fv5416.merge(
                      "Host" => fv5443,
                      "Origin" => "https://#{fv5443}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5425.get(
                      fv5442,
                      headers: fv5433,
                    )
                    fv5436, fv5434, fv5435 =
                      begin
                        fv5441 = fv5425.response.body
                        fv5440 = false
                        fv5439 = Nokogiri::HTML(fv5441).at_css("form")
                        if fv5439.nil? && fv5440
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5439

                          fv5438 = fv5439.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5438.blank?

                          fv5437 = fv5439.css("input[type='hidden']").to_h do |fv5410|
                            [fv5410["name"], fv5410["value"]]
                          end.except("authenticity_token")
                          [fv5439["action"], fv5438,
                           fv5437,]
                        end
                      end
                    fv5425.post(
                      fv5436,
                      params: fv5435.merge(authenticity_token: fv5434),
                      headers: fv5433,
                    )
                    begin
                      fv5426 = fv5425
                      fv5428 = "session"
                      fv5427 = fv5426.response.cookies[fv5428]
                      if fv5427.nil?
                        fv5432 = fv5426.response.headers["Set-Cookie"] || fv5426.response.headers["set-cookie"]
                        fv5431 =
                          if fv5432.is_a?(String) && fv5432.start_with?("[")
                            JSON.parse(fv5432)
                          else
                            Array(fv5432)
                          end
                        fv5429 =
                          fv5431.flat_map { |fv5430|
                            fv5430.to_s.split("\n")
                          }.find do |fv5430|
                            fv5430.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5428}=")
                          end
                        if fv5429

                          _, fv5427 = fv5429.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5427 = Rack::Utils.unescape(fv5427.to_s)
                        end
                      end

                      unless fv5427.nil?
                        fv5426.cookies.delete(fv5428)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5426.cookies.merge(
                          "#{fv5428}=#{Rack::Utils.escape(fv5427)}",
                          URI.parse("https://#{fv5426.host}/"),
                        )
                      end
                    end
                    fv5424 = fv5425.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5424.blank?

                    fv5421 = URI.parse(fv5424)
                    if fv5423[:ri].present?
                      fv5422 = Rack::Utils.parse_nested_query(fv5421.query.to_s)
                      fv5422["ri"] ||= fv5423[:ri].to_s
                      fv5421.query = URI.encode_www_form(fv5422)
                    end
                    fv5406.host!(fv5421.host)
                    fv5406.https!
                    fv5420 = fv5421.request_uri
                    fv5402 = fv5416.merge("Host" => fv5421.host)
                    fv5406.get(
                      fv5420,
                      headers: fv5402,
                    )
                  else
                    fv5417.confirm_base!(
                      base_token: fv5419,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5418,
                        entry_ref: fv5417.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5415 = fv5406.host
                    fv5406.host!(fv5415)
                    fv5406.https!
                    fv5402 = fv5416.merge("Host" => fv5415)
                    fv5406.get(
                      fv5414,
                      params: fv5413, headers: fv5402,
                    )
                  end
                  fv5405, fv5403, fv5404 =
                    begin
                      fv5412 = fv5406.response.body
                      fv5411 = false
                      fv5409 = Nokogiri::HTML(fv5412).at_css("form")
                      if fv5409.nil? && fv5411
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5409

                        fv5408 = fv5409.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5408.blank?

                        fv5407 = fv5409.css("input[type='hidden']").to_h do |fv5410|
                          [fv5410["name"], fv5410["value"]]
                        end.except("authenticity_token")
                        [fv5409["action"], fv5408,
                         fv5407,]
                      end
                    end
                  fv5406.post(
                    fv5405,
                    params: fv5404.merge(authenticity_token: fv5403),
                    headers: fv5402,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "sign up link includes only ri when pt is absent" do
        begin
          fv5401 = { ri: "jp" }
          begin
            fv5400 = auth_app_sign_in_path
            fv5399 = login_challenge
            fv5398 = :entry_ref
            fv5397 = fv5401
            fv5396 = { "Host" => @host }
            fv5395 = false
            fv5394 = nil
            fv5393 = nil
            begin
              fv5339 = self
              fv5347 = fv5400
              fv5391 = fv5399
              fv5392 = fv5398
              fv5356 = fv5397
              fv5349 = fv5396
              fv5379 = fv5395
              fv5378 = fv5394
              fv5352 = fv5393
              fv5346 = fv5356.merge(fv5392 => fv5391)
              fv5339.get(
                fv5347,
                params: fv5346, headers: fv5349,
              )
              fv5385 =
                begin
                  fv5390 = fv5339.response.body
                  fv5389 = true
                  fv5388 = Nokogiri::HTML(fv5390).at_css("form")
                  if fv5388.nil? && fv5389
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5388

                    fv5387 = fv5388.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5387.blank?

                    fv5386 = fv5388.css("input[type='hidden']").to_h do |fv5343|
                      [fv5343["name"], fv5343["value"]]
                    end.except("authenticity_token")
                    [fv5388["action"], fv5387,
                     fv5386,]
                  end
                end
              if fv5385

                fv5384, fv5382, fv5383 = fv5385

                fv5339.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5339.post(
                  fv5384, params: fv5383.merge(authenticity_token: fv5382),
                          headers: fv5349,
                )
                fv5381 = fv5339.response.location
                if fv5381.present?

                  fv5377 = URI.parse(fv5381)
                  fv5376 = fv5377.host
                  fv5351 =
                    begin
                      fv5380 = fv5376
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5380)
                    end
                  fv5350 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5351, reference: fv5377.path.split("/").fetch(-2),
                  )

                  if fv5379
                    fv5358 = fv5378 || fv5339
                    fv5358.host!(fv5376)
                    fv5358.https!
                    fv5358.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5375 = fv5377.request_uri
                    fv5366 = fv5349.merge(
                      "Host" => fv5376,
                      "Origin" => "https://#{fv5376}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5358.get(
                      fv5375,
                      headers: fv5366,
                    )
                    fv5369, fv5367, fv5368 =
                      begin
                        fv5374 = fv5358.response.body
                        fv5373 = false
                        fv5372 = Nokogiri::HTML(fv5374).at_css("form")
                        if fv5372.nil? && fv5373
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5372

                          fv5371 = fv5372.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5371.blank?

                          fv5370 = fv5372.css("input[type='hidden']").to_h do |fv5343|
                            [fv5343["name"], fv5343["value"]]
                          end.except("authenticity_token")
                          [fv5372["action"], fv5371,
                           fv5370,]
                        end
                      end
                    fv5358.post(
                      fv5369,
                      params: fv5368.merge(authenticity_token: fv5367),
                      headers: fv5366,
                    )
                    begin
                      fv5359 = fv5358
                      fv5361 = "session"
                      fv5360 = fv5359.response.cookies[fv5361]
                      if fv5360.nil?
                        fv5365 = fv5359.response.headers["Set-Cookie"] || fv5359.response.headers["set-cookie"]
                        fv5364 =
                          if fv5365.is_a?(String) && fv5365.start_with?("[")
                            JSON.parse(fv5365)
                          else
                            Array(fv5365)
                          end
                        fv5362 =
                          fv5364.flat_map { |fv5363|
                            fv5363.to_s.split("\n")
                          }.find do |fv5363|
                            fv5363.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5361}=")
                          end
                        if fv5362

                          _, fv5360 = fv5362.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5360 = Rack::Utils.unescape(fv5360.to_s)
                        end
                      end

                      unless fv5360.nil?
                        fv5359.cookies.delete(fv5361)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5359.cookies.merge(
                          "#{fv5361}=#{Rack::Utils.escape(fv5360)}",
                          URI.parse("https://#{fv5359.host}/"),
                        )
                      end
                    end
                    fv5357 = fv5358.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5357.blank?

                    fv5354 = URI.parse(fv5357)
                    if fv5356[:ri].present?
                      fv5355 = Rack::Utils.parse_nested_query(fv5354.query.to_s)
                      fv5355["ri"] ||= fv5356[:ri].to_s
                      fv5354.query = URI.encode_www_form(fv5355)
                    end
                    fv5339.host!(fv5354.host)
                    fv5339.https!
                    fv5353 = fv5354.request_uri
                    fv5335 = fv5349.merge("Host" => fv5354.host)
                    fv5339.get(
                      fv5353,
                      headers: fv5335,
                    )
                  else
                    fv5350.confirm_base!(
                      base_token: fv5352,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5351,
                        entry_ref: fv5350.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5348 = fv5339.host
                    fv5339.host!(fv5348)
                    fv5339.https!
                    fv5335 = fv5349.merge("Host" => fv5348)
                    fv5339.get(
                      fv5347,
                      params: fv5346, headers: fv5335,
                    )
                  end
                  fv5338, fv5336, fv5337 =
                    begin
                      fv5345 = fv5339.response.body
                      fv5344 = false
                      fv5342 = Nokogiri::HTML(fv5345).at_css("form")
                      if fv5342.nil? && fv5344
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5342

                        fv5341 = fv5342.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5341.blank?

                        fv5340 = fv5342.css("input[type='hidden']").to_h do |fv5343|
                          [fv5343["name"], fv5343["value"]]
                        end.except("authenticity_token")
                        [fv5342["action"], fv5341,
                         fv5340,]
                      end
                    end
                  fv5339.post(
                    fv5338,
                    params: fv5337.merge(authenticity_token: fv5336),
                    headers: fv5335,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "sign up link preserves encoded-like pt value safely" do
        pt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        begin
          fv5334 = { ri: "jp", pt: pt }
          begin
            fv5333 = auth_app_sign_in_path
            fv5332 = login_challenge
            fv5331 = :entry_ref
            fv5330 = fv5334
            fv5329 = { "Host" => @host }
            fv5328 = false
            fv5327 = nil
            fv5326 = nil
            begin
              fv5272 = self
              fv5280 = fv5333
              fv5324 = fv5332
              fv5325 = fv5331
              fv5289 = fv5330
              fv5282 = fv5329
              fv5312 = fv5328
              fv5311 = fv5327
              fv5285 = fv5326
              fv5279 = fv5289.merge(fv5325 => fv5324)
              fv5272.get(
                fv5280,
                params: fv5279, headers: fv5282,
              )
              fv5318 =
                begin
                  fv5323 = fv5272.response.body
                  fv5322 = true
                  fv5321 = Nokogiri::HTML(fv5323).at_css("form")
                  if fv5321.nil? && fv5322
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5321

                    fv5320 = fv5321.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5320.blank?

                    fv5319 = fv5321.css("input[type='hidden']").to_h do |fv5276|
                      [fv5276["name"], fv5276["value"]]
                    end.except("authenticity_token")
                    [fv5321["action"], fv5320,
                     fv5319,]
                  end
                end
              if fv5318

                fv5317, fv5315, fv5316 = fv5318

                fv5272.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5272.post(
                  fv5317, params: fv5316.merge(authenticity_token: fv5315),
                          headers: fv5282,
                )
                fv5314 = fv5272.response.location
                if fv5314.present?

                  fv5310 = URI.parse(fv5314)
                  fv5309 = fv5310.host
                  fv5284 =
                    begin
                      fv5313 = fv5309
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5313)
                    end
                  fv5283 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5284, reference: fv5310.path.split("/").fetch(-2),
                  )

                  if fv5312
                    fv5291 = fv5311 || fv5272
                    fv5291.host!(fv5309)
                    fv5291.https!
                    fv5291.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5308 = fv5310.request_uri
                    fv5299 = fv5282.merge(
                      "Host" => fv5309,
                      "Origin" => "https://#{fv5309}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5291.get(
                      fv5308,
                      headers: fv5299,
                    )
                    fv5302, fv5300, fv5301 =
                      begin
                        fv5307 = fv5291.response.body
                        fv5306 = false
                        fv5305 = Nokogiri::HTML(fv5307).at_css("form")
                        if fv5305.nil? && fv5306
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5305

                          fv5304 = fv5305.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5304.blank?

                          fv5303 = fv5305.css("input[type='hidden']").to_h do |fv5276|
                            [fv5276["name"], fv5276["value"]]
                          end.except("authenticity_token")
                          [fv5305["action"], fv5304,
                           fv5303,]
                        end
                      end
                    fv5291.post(
                      fv5302,
                      params: fv5301.merge(authenticity_token: fv5300),
                      headers: fv5299,
                    )
                    begin
                      fv5292 = fv5291
                      fv5294 = "session"
                      fv5293 = fv5292.response.cookies[fv5294]
                      if fv5293.nil?
                        fv5298 = fv5292.response.headers["Set-Cookie"] || fv5292.response.headers["set-cookie"]
                        fv5297 =
                          if fv5298.is_a?(String) && fv5298.start_with?("[")
                            JSON.parse(fv5298)
                          else
                            Array(fv5298)
                          end
                        fv5295 =
                          fv5297.flat_map { |fv5296|
                            fv5296.to_s.split("\n")
                          }.find do |fv5296|
                            fv5296.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5294}=")
                          end
                        if fv5295

                          _, fv5293 = fv5295.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5293 = Rack::Utils.unescape(fv5293.to_s)
                        end
                      end

                      unless fv5293.nil?
                        fv5292.cookies.delete(fv5294)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5292.cookies.merge(
                          "#{fv5294}=#{Rack::Utils.escape(fv5293)}",
                          URI.parse("https://#{fv5292.host}/"),
                        )
                      end
                    end
                    fv5290 = fv5291.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5290.blank?

                    fv5287 = URI.parse(fv5290)
                    if fv5289[:ri].present?
                      fv5288 = Rack::Utils.parse_nested_query(fv5287.query.to_s)
                      fv5288["ri"] ||= fv5289[:ri].to_s
                      fv5287.query = URI.encode_www_form(fv5288)
                    end
                    fv5272.host!(fv5287.host)
                    fv5272.https!
                    fv5286 = fv5287.request_uri
                    fv5268 = fv5282.merge("Host" => fv5287.host)
                    fv5272.get(
                      fv5286,
                      headers: fv5268,
                    )
                  else
                    fv5283.confirm_base!(
                      base_token: fv5285,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5284,
                        entry_ref: fv5283.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5281 = fv5272.host
                    fv5272.host!(fv5281)
                    fv5272.https!
                    fv5268 = fv5282.merge("Host" => fv5281)
                    fv5272.get(
                      fv5280,
                      params: fv5279, headers: fv5268,
                    )
                  end
                  fv5271, fv5269, fv5270 =
                    begin
                      fv5278 = fv5272.response.body
                      fv5277 = false
                      fv5275 = Nokogiri::HTML(fv5278).at_css("form")
                      if fv5275.nil? && fv5277
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5275

                        fv5274 = fv5275.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5274.blank?

                        fv5273 = fv5275.css("input[type='hidden']").to_h do |fv5276|
                          [fv5276["name"], fv5276["value"]]
                        end.except("authenticity_token")
                        [fv5275["action"], fv5274,
                         fv5273,]
                      end
                    end
                  fv5272.post(
                    fv5271,
                    params: fv5270.merge(authenticity_token: fv5269),
                    headers: fv5268,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "should render in english when lx=en" do
        begin
          fv5267 = { lx: "en", ri: "jp" }
          begin
            fv5266 = auth_app_sign_in_path
            fv5265 = login_challenge
            fv5264 = :entry_ref
            fv5263 = fv5267
            fv5262 = { "Host" => @host }
            fv5261 = false
            fv5260 = nil
            fv5259 = nil
            begin
              fv5205 = self
              fv5213 = fv5266
              fv5257 = fv5265
              fv5258 = fv5264
              fv5222 = fv5263
              fv5215 = fv5262
              fv5245 = fv5261
              fv5244 = fv5260
              fv5218 = fv5259
              fv5212 = fv5222.merge(fv5258 => fv5257)
              fv5205.get(
                fv5213,
                params: fv5212, headers: fv5215,
              )
              fv5251 =
                begin
                  fv5256 = fv5205.response.body
                  fv5255 = true
                  fv5254 = Nokogiri::HTML(fv5256).at_css("form")
                  if fv5254.nil? && fv5255
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5254

                    fv5253 = fv5254.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5253.blank?

                    fv5252 = fv5254.css("input[type='hidden']").to_h do |fv5209|
                      [fv5209["name"], fv5209["value"]]
                    end.except("authenticity_token")
                    [fv5254["action"], fv5253,
                     fv5252,]
                  end
                end
              if fv5251

                fv5250, fv5248, fv5249 = fv5251

                fv5205.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5205.post(
                  fv5250, params: fv5249.merge(authenticity_token: fv5248),
                          headers: fv5215,
                )
                fv5247 = fv5205.response.location
                if fv5247.present?

                  fv5243 = URI.parse(fv5247)
                  fv5242 = fv5243.host
                  fv5217 =
                    begin
                      fv5246 = fv5242
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5246)
                    end
                  fv5216 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5217, reference: fv5243.path.split("/").fetch(-2),
                  )

                  if fv5245
                    fv5224 = fv5244 || fv5205
                    fv5224.host!(fv5242)
                    fv5224.https!
                    fv5224.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5241 = fv5243.request_uri
                    fv5232 = fv5215.merge(
                      "Host" => fv5242,
                      "Origin" => "https://#{fv5242}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5224.get(
                      fv5241,
                      headers: fv5232,
                    )
                    fv5235, fv5233, fv5234 =
                      begin
                        fv5240 = fv5224.response.body
                        fv5239 = false
                        fv5238 = Nokogiri::HTML(fv5240).at_css("form")
                        if fv5238.nil? && fv5239
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5238

                          fv5237 = fv5238.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5237.blank?

                          fv5236 = fv5238.css("input[type='hidden']").to_h do |fv5209|
                            [fv5209["name"], fv5209["value"]]
                          end.except("authenticity_token")
                          [fv5238["action"], fv5237,
                           fv5236,]
                        end
                      end
                    fv5224.post(
                      fv5235,
                      params: fv5234.merge(authenticity_token: fv5233),
                      headers: fv5232,
                    )
                    begin
                      fv5225 = fv5224
                      fv5227 = "session"
                      fv5226 = fv5225.response.cookies[fv5227]
                      if fv5226.nil?
                        fv5231 = fv5225.response.headers["Set-Cookie"] || fv5225.response.headers["set-cookie"]
                        fv5230 =
                          if fv5231.is_a?(String) && fv5231.start_with?("[")
                            JSON.parse(fv5231)
                          else
                            Array(fv5231)
                          end
                        fv5228 =
                          fv5230.flat_map { |fv5229|
                            fv5229.to_s.split("\n")
                          }.find do |fv5229|
                            fv5229.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5227}=")
                          end
                        if fv5228

                          _, fv5226 = fv5228.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5226 = Rack::Utils.unescape(fv5226.to_s)
                        end
                      end

                      unless fv5226.nil?
                        fv5225.cookies.delete(fv5227)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5225.cookies.merge(
                          "#{fv5227}=#{Rack::Utils.escape(fv5226)}",
                          URI.parse("https://#{fv5225.host}/"),
                        )
                      end
                    end
                    fv5223 = fv5224.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5223.blank?

                    fv5220 = URI.parse(fv5223)
                    if fv5222[:ri].present?
                      fv5221 = Rack::Utils.parse_nested_query(fv5220.query.to_s)
                      fv5221["ri"] ||= fv5222[:ri].to_s
                      fv5220.query = URI.encode_www_form(fv5221)
                    end
                    fv5205.host!(fv5220.host)
                    fv5205.https!
                    fv5219 = fv5220.request_uri
                    fv5201 = fv5215.merge("Host" => fv5220.host)
                    fv5205.get(
                      fv5219,
                      headers: fv5201,
                    )
                  else
                    fv5216.confirm_base!(
                      base_token: fv5218,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5217,
                        entry_ref: fv5216.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5214 = fv5205.host
                    fv5205.host!(fv5214)
                    fv5205.https!
                    fv5201 = fv5215.merge("Host" => fv5214)
                    fv5205.get(
                      fv5213,
                      params: fv5212, headers: fv5201,
                    )
                  end
                  fv5204, fv5202, fv5203 =
                    begin
                      fv5211 = fv5205.response.body
                      fv5210 = false
                      fv5208 = Nokogiri::HTML(fv5211).at_css("form")
                      if fv5208.nil? && fv5210
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5208

                        fv5207 = fv5208.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5207.blank?

                        fv5206 = fv5208.css("input[type='hidden']").to_h do |fv5209|
                          [fv5209["name"], fv5209["value"]]
                        end.except("authenticity_token")
                        [fv5208["action"], fv5207,
                         fv5206,]
                      end
                    end
                  fv5205.post(
                    fv5204,
                    params: fv5203.merge(authenticity_token: fv5202),
                    headers: fv5201,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        assert_select "html[lang=en]"
        assert_match(/Need an account/, inertia_props.fetch("switch_form").fetch("label"))
      end

      test "shows social login buttons" do
        begin
          fv5200 = { ri: "jp" }
          begin
            fv5199 = auth_app_sign_in_path
            fv5198 = login_challenge
            fv5197 = :entry_ref
            fv5196 = fv5200
            fv5195 = { "Host" => @host }
            fv5194 = false
            fv5193 = nil
            fv5192 = nil
            begin
              fv5138 = self
              fv5146 = fv5199
              fv5190 = fv5198
              fv5191 = fv5197
              fv5155 = fv5196
              fv5148 = fv5195
              fv5178 = fv5194
              fv5177 = fv5193
              fv5151 = fv5192
              fv5145 = fv5155.merge(fv5191 => fv5190)
              fv5138.get(
                fv5146,
                params: fv5145, headers: fv5148,
              )
              fv5184 =
                begin
                  fv5189 = fv5138.response.body
                  fv5188 = true
                  fv5187 = Nokogiri::HTML(fv5189).at_css("form")
                  if fv5187.nil? && fv5188
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5187

                    fv5186 = fv5187.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5186.blank?

                    fv5185 = fv5187.css("input[type='hidden']").to_h do |fv5142|
                      [fv5142["name"], fv5142["value"]]
                    end.except("authenticity_token")
                    [fv5187["action"], fv5186,
                     fv5185,]
                  end
                end
              if fv5184

                fv5183, fv5181, fv5182 = fv5184

                fv5138.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5138.post(
                  fv5183, params: fv5182.merge(authenticity_token: fv5181),
                          headers: fv5148,
                )
                fv5180 = fv5138.response.location
                if fv5180.present?

                  fv5176 = URI.parse(fv5180)
                  fv5175 = fv5176.host
                  fv5150 =
                    begin
                      fv5179 = fv5175
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5179)
                    end
                  fv5149 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5150, reference: fv5176.path.split("/").fetch(-2),
                  )

                  if fv5178
                    fv5157 = fv5177 || fv5138
                    fv5157.host!(fv5175)
                    fv5157.https!
                    fv5157.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5174 = fv5176.request_uri
                    fv5165 = fv5148.merge(
                      "Host" => fv5175,
                      "Origin" => "https://#{fv5175}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5157.get(
                      fv5174,
                      headers: fv5165,
                    )
                    fv5168, fv5166, fv5167 =
                      begin
                        fv5173 = fv5157.response.body
                        fv5172 = false
                        fv5171 = Nokogiri::HTML(fv5173).at_css("form")
                        if fv5171.nil? && fv5172
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5171

                          fv5170 = fv5171.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5170.blank?

                          fv5169 = fv5171.css("input[type='hidden']").to_h do |fv5142|
                            [fv5142["name"], fv5142["value"]]
                          end.except("authenticity_token")
                          [fv5171["action"], fv5170,
                           fv5169,]
                        end
                      end
                    fv5157.post(
                      fv5168,
                      params: fv5167.merge(authenticity_token: fv5166),
                      headers: fv5165,
                    )
                    begin
                      fv5158 = fv5157
                      fv5160 = "session"
                      fv5159 = fv5158.response.cookies[fv5160]
                      if fv5159.nil?
                        fv5164 = fv5158.response.headers["Set-Cookie"] || fv5158.response.headers["set-cookie"]
                        fv5163 =
                          if fv5164.is_a?(String) && fv5164.start_with?("[")
                            JSON.parse(fv5164)
                          else
                            Array(fv5164)
                          end
                        fv5161 =
                          fv5163.flat_map { |fv5162|
                            fv5162.to_s.split("\n")
                          }.find do |fv5162|
                            fv5162.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5160}=")
                          end
                        if fv5161

                          _, fv5159 = fv5161.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5159 = Rack::Utils.unescape(fv5159.to_s)
                        end
                      end

                      unless fv5159.nil?
                        fv5158.cookies.delete(fv5160)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5158.cookies.merge(
                          "#{fv5160}=#{Rack::Utils.escape(fv5159)}",
                          URI.parse("https://#{fv5158.host}/"),
                        )
                      end
                    end
                    fv5156 = fv5157.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5156.blank?

                    fv5153 = URI.parse(fv5156)
                    if fv5155[:ri].present?
                      fv5154 = Rack::Utils.parse_nested_query(fv5153.query.to_s)
                      fv5154["ri"] ||= fv5155[:ri].to_s
                      fv5153.query = URI.encode_www_form(fv5154)
                    end
                    fv5138.host!(fv5153.host)
                    fv5138.https!
                    fv5152 = fv5153.request_uri
                    fv5134 = fv5148.merge("Host" => fv5153.host)
                    fv5138.get(
                      fv5152,
                      headers: fv5134,
                    )
                  else
                    fv5149.confirm_base!(
                      base_token: fv5151,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5150,
                        entry_ref: fv5149.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5147 = fv5138.host
                    fv5138.host!(fv5147)
                    fv5138.https!
                    fv5134 = fv5148.merge("Host" => fv5147)
                    fv5138.get(
                      fv5146,
                      params: fv5145, headers: fv5134,
                    )
                  end
                  fv5137, fv5135, fv5136 =
                    begin
                      fv5144 = fv5138.response.body
                      fv5143 = false
                      fv5141 = Nokogiri::HTML(fv5144).at_css("form")
                      if fv5141.nil? && fv5143
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5141

                        fv5140 = fv5141.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5140.blank?

                        fv5139 = fv5141.css("input[type='hidden']").to_h do |fv5142|
                          [fv5142["name"], fv5142["value"]]
                        end.except("authenticity_token")
                        [fv5141["action"], fv5140,
                         fv5139,]
                      end
                    end
                  fv5138.post(
                    fv5137,
                    params: fv5136.merge(authenticity_token: fv5135),
                    headers: fv5134,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        providers = inertia_props.fetch("social_providers")

        assert_equal [auth_app_social_google_session_path(ri: "jp")],
                     providers.select { |provider| provider.fetch("key") == "google" }
                       .map { |provider| provider.fetch("action") }
        assert_equal [auth_app_social_apple_session_path(ri: "jp")],
                     providers.select { |provider| provider.fetch("key") == "apple" }
                       .map { |provider| provider.fetch("action") }
        # The provider forms are native document POSTs, each carrying the global authenticity token
        # the ERB form embedded.
        assert_equal 1,
                     providers.count { |provider|
                       provider.fetch("key") == "google" && provider.fetch("authenticity_token").present?
                     }
      end

      test "apple button carries a permitted call to action on the custom button element" do
        begin
          fv5133 = { ri: "jp" }
          begin
            fv5132 = auth_app_sign_in_path
            fv5131 = login_challenge
            fv5130 = :entry_ref
            fv5129 = fv5133
            fv5128 = { "Host" => @host }
            fv5127 = false
            fv5126 = nil
            fv5125 = nil
            begin
              fv5071 = self
              fv5079 = fv5132
              fv5123 = fv5131
              fv5124 = fv5130
              fv5088 = fv5129
              fv5081 = fv5128
              fv5111 = fv5127
              fv5110 = fv5126
              fv5084 = fv5125
              fv5078 = fv5088.merge(fv5124 => fv5123)
              fv5071.get(
                fv5079,
                params: fv5078, headers: fv5081,
              )
              fv5117 =
                begin
                  fv5122 = fv5071.response.body
                  fv5121 = true
                  fv5120 = Nokogiri::HTML(fv5122).at_css("form")
                  if fv5120.nil? && fv5121
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5120

                    fv5119 = fv5120.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5119.blank?

                    fv5118 = fv5120.css("input[type='hidden']").to_h do |fv5075|
                      [fv5075["name"], fv5075["value"]]
                    end.except("authenticity_token")
                    [fv5120["action"], fv5119,
                     fv5118,]
                  end
                end
              if fv5117

                fv5116, fv5114, fv5115 = fv5117

                fv5071.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5071.post(
                  fv5116, params: fv5115.merge(authenticity_token: fv5114),
                          headers: fv5081,
                )
                fv5113 = fv5071.response.location
                if fv5113.present?

                  fv5109 = URI.parse(fv5113)
                  fv5108 = fv5109.host
                  fv5083 =
                    begin
                      fv5112 = fv5108
                      {
                        ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                      }.fetch(fv5112)
                    end
                  fv5082 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                    surface: fv5083, reference: fv5109.path.split("/").fetch(-2),
                  )

                  if fv5111
                    fv5090 = fv5110 || fv5071
                    fv5090.host!(fv5108)
                    fv5090.https!
                    fv5090.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                      "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                    fv5107 = fv5109.request_uri
                    fv5098 = fv5081.merge(
                      "Host" => fv5108,
                      "Origin" => "https://#{fv5108}",
                      "Sec-Fetch-Site" => "same-origin",
                    )
                    fv5090.get(
                      fv5107,
                      headers: fv5098,
                    )
                    fv5101, fv5099, fv5100 =
                      begin
                        fv5106 = fv5090.response.body
                        fv5105 = false
                        fv5104 = Nokogiri::HTML(fv5106).at_css("form")
                        if fv5104.nil? && fv5105
                          nil
                        else
                          raise RuntimeError,
                                "Auth continuation form is missing" unless fv5104

                          fv5103 = fv5104.at_css("input[name='authenticity_token']")&.[]("value")
                          raise RuntimeError,
                                "Auth continuation is missing its CSRF token" if fv5103.blank?

                          fv5102 = fv5104.css("input[type='hidden']").to_h do |fv5075|
                            [fv5075["name"], fv5075["value"]]
                          end.except("authenticity_token")
                          [fv5104["action"], fv5103,
                           fv5102,]
                        end
                      end
                    fv5090.post(
                      fv5101,
                      params: fv5100.merge(authenticity_token: fv5099),
                      headers: fv5098,
                    )
                    begin
                      fv5091 = fv5090
                      fv5093 = "session"
                      fv5092 = fv5091.response.cookies[fv5093]
                      if fv5092.nil?
                        fv5097 = fv5091.response.headers["Set-Cookie"] || fv5091.response.headers["set-cookie"]
                        fv5096 =
                          if fv5097.is_a?(String) && fv5097.start_with?("[")
                            JSON.parse(fv5097)
                          else
                            Array(fv5097)
                          end
                        fv5094 =
                          fv5096.flat_map { |fv5095|
                            fv5095.to_s.split("\n")
                          }.find do |fv5095|
                            fv5095.split(
                              ";",
                              2,
                            ).first.to_s.start_with?("#{fv5093}=")
                          end
                        if fv5094

                          _, fv5092 = fv5094.split(";", 2).first.to_s.split(
                            "=", 2,
                          )
                          fv5092 = Rack::Utils.unescape(fv5092.to_s)
                        end
                      end

                      unless fv5092.nil?
                        fv5091.cookies.delete(fv5093)
                        # Rack::Test's []= uses its default host. The current request may target a
                        # different surface, so install the cookie against the browser's active host.
                        fv5091.cookies.merge(
                          "#{fv5093}=#{Rack::Utils.escape(fv5092)}",
                          URI.parse("https://#{fv5091.host}/"),
                        )
                      end
                    end
                    fv5089 = fv5090.response.location
                    raise RuntimeError,
                          "Base confirmation did not return to Auth" if fv5089.blank?

                    fv5086 = URI.parse(fv5089)
                    if fv5088[:ri].present?
                      fv5087 = Rack::Utils.parse_nested_query(fv5086.query.to_s)
                      fv5087["ri"] ||= fv5088[:ri].to_s
                      fv5086.query = URI.encode_www_form(fv5087)
                    end
                    fv5071.host!(fv5086.host)
                    fv5071.https!
                    fv5085 = fv5086.request_uri
                    fv5067 = fv5081.merge("Host" => fv5086.host)
                    fv5071.get(
                      fv5085,
                      headers: fv5067,
                    )
                  else
                    fv5082.confirm_base!(
                      base_token: fv5084,
                      browser_digest: AuthAdmissionBinding.browser_digest(
                        surface: fv5083,
                        entry_ref: fv5082.entry_ref,
                        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                      ),
                    )
                    fv5080 = fv5071.host
                    fv5071.host!(fv5080)
                    fv5071.https!
                    fv5067 = fv5081.merge("Host" => fv5080)
                    fv5071.get(
                      fv5079,
                      params: fv5078, headers: fv5067,
                    )
                  end
                  fv5070, fv5068, fv5069 =
                    begin
                      fv5077 = fv5071.response.body
                      fv5076 = false
                      fv5074 = Nokogiri::HTML(fv5077).at_css("form")
                      if fv5074.nil? && fv5076
                        nil
                      else
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5074

                        fv5073 = fv5074.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5073.blank?

                        fv5072 = fv5074.css("input[type='hidden']").to_h do |fv5075|
                          [fv5075["name"], fv5075["value"]]
                        end.except("authenticity_token")
                        [fv5074["action"], fv5073,
                         fv5072,]
                      end
                    end
                  fv5071.post(
                    fv5070,
                    params: fv5069.merge(authenticity_token: fv5068),
                    headers: fv5067,
                  )
                end
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        assert_response :success
        apple = inertia_props.fetch("social_providers").find { |provider| provider.fetch("key") == "apple" }

        assert_equal auth_app_social_apple_session_path(ri: "jp"), apple.fetch("action")
        assert_includes ["Sign in with Apple", "Sign up with Apple", "Continue with Apple", "Appleで続行"],
                        apple.fetch("label")
      end

      test "apple button renders the official logo artwork for both appearances" do
        begin
          fv5066 = { ri: "jp" }
          begin
            fv5065 = auth_app_sign_in_path
            fv5064 = login_challenge
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
                  fv5049, params: fv5048.merge(authenticity_token: fv5047),
                          headers: fv5014,
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
                        ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                        ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                        ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
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
        apple = inertia_props.fetch("social_providers").find { |provider| provider.fetch("key") == "apple" }

        assert_equal(
          {
            "white" => "/images/social/apple_logo_white.svg",
            "black" => "/images/social/apple_logo_black.svg",
            "width" => 28,
            "height" => 40,
          },
          apple.fetch("logos"),
        )
      end

      test "rejects direct entry when logged in" do
        user = clients(:one)

        get auth_app_sign_in_url(ri: "jp"), headers: as_user_headers(user, host: @host)

        assert_response :forbidden
        assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
      end

      test "logged in entry with login challenge does not resume authorization" do
        user = clients(:one)
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "sign_in",
            params: authorize_params,
          )
        headers = as_user_headers(user, host: @host)
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference

        get auth_app_sign_in_path(ri: "jp", transaction_ref: reference), headers: headers

        assert_response :forbidden
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
        transaction = issuance.transaction.reload

        assert_equal "pending", transaction.status
        assert_nil transaction.actor_ref
        assert_nil transaction.session_ref
        assert_nil session[:oidc_authorization_login_challenge]
      end

      private

      # core-app-jp is a first-party RP, so Base issues its parent with the neutral authentication
      # intent; a fixed sign_in intent is not reachable for a registered client.
      def login_challenge(intent: "authentication")
        transaction = OidcAuthorizationTransactionCoordinator.issue!(
          surface: "app",
          intent: intent,
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
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        }
      end
    end
  end
end

class Auth::App::AuthInsControllerTest
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
end

# DAMP auth header helpers for this test class.
class Auth::App::AuthInsControllerTest
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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
