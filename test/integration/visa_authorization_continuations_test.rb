# frozen_string_literal: true

require "test_helper"

class VisaAuthorizationContinuationsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "every Visa continuation refuses missing browser navigation and malformed references" do
    {
      "visa.umaxica.app" => %w(result cancellation switch),
      "visa.umaxica.com" => %w(result cancellation switch),
      "visa.umaxica.org" => %w(result cancellation),
    }.each do |host, continuations|
      host! host
      continuations.each do |continuation|
        get "/oidc/#{continuation}"

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal "invalid continuation request", response.parsed_body.fetch("error_description")
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
        assert_equal "no-referrer", response.headers["Referrer-Policy"]

        get "/oidc/#{continuation}", headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal "invalid continuation request", response.parsed_body.fetch("error_description")

        get "/oidc/#{continuation}", headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "iframe",
        }

        assert_response :bad_request
        assert_equal "invalid continuation request", response.parsed_body.fetch("error_description")

        head "/oidc/#{continuation}", headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }

        assert_response :bad_request
        assert_empty response.body
      end
    end
  end

  test "authorization bases deny access and expose no endpoint actions" do
    [Visa::App::AuthorizationBaseController, Visa::Com::AuthorizationBaseController,
     Visa::Org::AuthorizationBaseController,].each do |controller|
      assert_equal :deny_all, controller.authentication_mode_for(:show)
      assert_equal :deny_all, controller.authentication_mode_for(:create)
      assert_empty controller.action_methods
    end
  end

  test "every continuation preserves the parameter byte limit below at and above its boundary" do
    {
      "visa.umaxica.app" => %w(result cancellation switch),
      "visa.umaxica.com" => %w(result cancellation switch),
      "visa.umaxica.org" => %w(result cancellation),
    }.each do |host, continuations|
      host! host
      continuations.each do |continuation|
        [2047, 2048, 2049].each do |length|
          get "/oidc/#{continuation}", params: { result_ref: "a" * length }, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
          }

          assert_response :bad_request
          expected = (length > 2048) ? "authorization request is too large" : "invalid continuation request"

          assert_equal expected, response.parsed_body.fetch("error_description")
        end
      end
    end
  end

  test "each realm preserves the total query byte limit below at and above its boundary" do
    %w(visa.umaxica.app visa.umaxica.com visa.umaxica.org).each do |host|
      host! host
      [8191, 8192, 8193].each do |length|
        query = URI.encode_www_form(a: "a" * 2048, b: "b" * 2048, c: "c" * 2048, d: "d" * (length - 6155))

        assert_equal length, query.bytesize

        get "/oidc/result?#{query}", headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }

        assert_response :bad_request
        expected = (length > 8192) ? "authorization request is too large" : "invalid continuation request"

        assert_equal expected, response.parsed_body.fetch("error_description")
      end
    end
  end

  test "continuation endpoints expose only show while authorization endpoints retain create" do
    [Visa::App::Oidc::ResultsController, Visa::App::Oidc::CancellationsController,
     Visa::App::Oidc::SwitchesController, Visa::Com::Oidc::ResultsController,
     Visa::Com::Oidc::CancellationsController, Visa::Com::Oidc::SwitchesController,
     Visa::Org::Oidc::ResultsController, Visa::Org::Oidc::CancellationsController,].each do |controller|
      assert_equal Set["show"], controller.action_methods
      assert_equal :open, controller.authentication_mode_for(:show)
    end
    [Visa::App::Oauth::AuthorizationsController, Visa::Com::Oauth::AuthorizationsController,
     Visa::Org::Oauth::AuthorizationsController,].each do |controller|
      assert_equal Set["show", "create"], controller.action_methods
      assert_equal :open, controller.authentication_mode_for(:show)
      assert_equal :open, controller.authentication_mode_for(:create)
    end
  end
end
