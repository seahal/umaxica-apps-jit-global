# typed: false
# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    module Sign
      class OutsControllerTest < ActionDispatch::IntegrationTest
        HOST = ENV.fetch("PUBLIC_PALM_SERVICE_URL")

        setup do
          host! HOST
        end

        test "GET sign-out shows the shared confirmation without mutating sessions" do
          before = [ClientToken.count, ClientRpSession.count, AcmeLogoutTransaction.count]

          get edit_palm_app_sign_out_url(ri: "jp")

          assert_response :success
          assert_equal "palm/app/sign/outs/edit", inertia_component
          assert_equal I18n.t("sign.shared.sign_out.title"), inertia_props.fetch("heading")
          assert_equal before, [ClientToken.count, ClientRpSession.count, AcmeLogoutTransaction.count]
        end

        test "POST sign-out without Palm RP credentials is refused before transaction creation" do
          with_forgery_protection do
            get edit_palm_app_sign_out_url(ri: "jp")
            csrf_token = css_select('meta[name="csrf-token"]').first["content"]
            before = AcmeLogoutTransaction.count

            post palm_app_sign_out_url(ri: "jp"), headers: {
              "Origin" => "http://#{HOST}",
              "Sec-Fetch-Site" => "same-origin",
              "X-CSRF-Token" => csrf_token,
            }

            assert_response :unauthorized
            assert_equal before, AcmeLogoutTransaction.count
          end
        end

        private

        def with_forgery_protection
          ActionController::Base.allow_forgery_protection = true
          yield
        ensure
          ActionController::Base.allow_forgery_protection =
            Rails.configuration.action_controller.allow_forgery_protection
        end
      end
    end
  end
end
