# frozen_string_literal: true

require "test_helper"

class VisaAuthorizationStartBoundaryTest < ActionDispatch::IntegrationTest
  test "Visa authorization HEAD cannot allocate an authentication transaction" do
    [
      ["visa.umaxica.app", "core-app-jp", "client", ClientOidcAuthorizationTransaction],
      ["visa.umaxica.com", "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction],
      ["visa.umaxica.org", "core-org-jp", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |host, client_id, realm, model|
      host! host
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: "head-boundary",
        nonce: "head-boundary",
        ri: "jp",
      }
      assert_no_difference -> { model.count } do
        head "/oauth/authorize", params: parameters, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }
      end

      assert_response :bad_request
      assert_empty response.body
      assert_nil response.location
    end
  end

  test "Visa authorization GET rejects continuation parameters before allocating a transaction" do
    [
      ["visa.umaxica.app", "core-app-jp", "client", ClientOidcAuthorizationTransaction],
      ["visa.umaxica.com", "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction],
      ["visa.umaxica.org", "core-org-jp", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |host, client_id, realm, model|
      host! host
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: "start-boundary",
        nonce: "start-boundary",
        ri: "jp",
      }
      %w(result result_ref transaction_ref cancellation_ref switch_handoff).each do |name|
        [nil, "", "opaque-reference", { nested: "reference" }].each do |value|
          assert_no_difference -> { model.count } do
            get "/oauth/authorize", params: parameters.merge(name => value)
          end

          assert_response :bad_request
          assert_equal "invalid_request", response.parsed_body.fetch("error")
          assert_nil response.location
        end
      end
    end
  end

  test "Visa authorization POST rejects blank continuation fields as well as populated ones" do
    [
      ["visa.umaxica.app", "core-app-jp", "client", ClientOidcAuthorizationTransaction],
      ["visa.umaxica.com", "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction],
      ["visa.umaxica.org", "core-org-jp", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |host, client_id, realm, model|
      host! host
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: "start-boundary",
        nonce: "start-boundary",
        ri: "jp",
        ceremony_action: "start",
      }
      %w(result result_ref transaction_ref cancellation_ref switch_handoff).each do |name|
        [nil, "", "opaque-reference"].each do |value|
          assert_no_difference -> { model.count } do
            post "/oauth/authorize", params: parameters.merge(name => value)
          end

          assert_response :bad_request
          assert_equal "invalid_request", response.parsed_body.fetch("error")
          assert_nil response.location
        end
      end
    end
  end
end
