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
  [
    ["app", "visa.umaxica.app", "core-app-jp", "client", ClientOidcAuthorizationTransaction,
     ClientAuthAdmissionBinding,],
    ["com", "visa.umaxica.com", "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction,
     VisitorAuthAdmissionBinding,],
    ["org", "visa.umaxica.org", "core-org-jp", "operator", OperatorOidcAuthorizationTransaction,
     OperatorAuthAdmissionBinding,],
  ].each do |surface, host, client_id, realm, transaction_class, binding_class|
    test "#{surface} authorization handles coordinator failures without creating admissions" do
      host! host
      https!
      parameters = {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: "state-sensitive-sentinel",
        nonce: "nonce-sensitive-sentinel",
        code: "code-sensitive-sentinel",
        ri: "jp",
      }
      [BaseAuthAdmissionCoordinator::Denied, Umaxica::Valkey::Unavailable,
       Umaxica::Valkey::OperationError, ActiveRecord::RecordNotFound,].each do |error_class|
        logged_errors = []
        logged_info = []
        failure = ->(**) { raise error_class, "PrivateModel id=123456 sensitive-token-sentinel" }
        capture_error = ->(*messages) { logged_errors.concat(messages.grep(String)) }
        capture_info = ->(*messages) { logged_info.concat(messages.grep(String)) }
        before = [transaction_class.count, binding_class.count]
        Rails.logger.stub(:error, capture_error) do
          Rails.logger.stub(:info, capture_info) do
            OidcAuthorizationTransactionCoordinator.stub(:issue_with_handoff!, failure) do
              get "/oauth/authorize", params: parameters,
                                      headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
            end
          end
        end

        assert_equal before, [transaction_class.count, binding_class.count], error_class.name
        assert_nil response.location
        if [Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError].include?(error_class)
          assert_response :service_unavailable
          assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
          events = logged_errors.grep(/oidc\.authorize\.backend_failure/)

          assert_equal 1, events.length
          event = JSON.parse(events.first).fetch("data")

          assert_equal surface, event.fetch("surface")
          assert_equal error_class.name, event.fetch("error_class")
          %w(state-sensitive-sentinel nonce-sensitive-sentinel code-sensitive-sentinel
             sensitive-token-sentinel).each do |secret|
            assert_not_includes events.first, secret
          end
        else
          assert_response :bad_request
          assert_equal "invalid_request", response.parsed_body.fetch("error")
          assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
          assert_not_includes response.body, "PrivateModel"
          assert_not_includes response.body, "123456"
          if error_class == ActiveRecord::RecordNotFound
            events = logged_info.grep(/oidc\.authorize\.invalid_request/)

            assert_equal 1, events.length
            assert_equal error_class.name, JSON.parse(events.first).fetch("data").fetch("error_class")
          end
        end
      end
    end
  end
end
