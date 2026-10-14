# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseStepUpIntentAuthorityTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :operator_tokens, :operator_passkeys

  setup do
    https!
  end

  %w(app com org).each do |surface|
    test "#{surface} ordinary verification conflicts with a pending bootstrap purpose without replacing it" do
      actor_id = SecureRandom.random_number(1 << 60) + 1_000_000_000
      actor, token, transaction_class, host, headers =
        case surface
        when "app"
          actor = Client.create!(id: actor_id, status_id: ClientStatus::ACTIVE)
          token = ClientToken.create!(user: actor, root_login_established_at: ClientToken.database_now)
          host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          [actor, token, ClientStepUpCeremonyTransaction, host, begin
            fx0_host = host
            fx0_token = token
            fx0_user = actor
            begin
              f0_cookie_pairs =
                begin
                  f0_host = fx0_host
                  f0_token = fx0_token
                  f0_client = OidcClientRegistry.find!("base-app-ww")
                  f0_key = [f0_client.client_id, f0_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if @base_browser_rp_credentials[f0_key] ||
                      (f0_token.currently_usable? &&
                        !(f0_token.device_session_id && ClientRpSession.exists?(
                          device_session_id: f0_token.device_session_id,
                          oidc_client_id: f0_client.client_id,
                          revoked_at: nil,
                        )))
                    unless @base_browser_rp_credentials[f0_key]
                      f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                      f0_now = Time.current
                      f0_session = ClientRpSession.create!(
                        client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                        refresh_token_expires_at: f0_now + 10.minutes,
                      )
                      f0_access = AuthenticationTokenService.encode(
                        fx0_user,
                        host: f0_host,
                        resource_type: "client",
                        session_public_id: f0_token.public_id,
                        base_session_public_id: f0_token.public_id,
                        oidc_sid: f0_session.public_id,
                        oidc_jti: f0_session.oidc_jti,
                        expires_at: f0_now + 10.minutes,
                        scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(f0_client),
                        audiences: [f0_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                        subject: OidcSubject.for(
                          fx0_user,
                          resource_type: "client",
                        ),
                        client_id: f0_client.client_id,
                      )
                      @base_browser_rp_credentials[f0_key] = [f0_access, f0_session.issue_refresh_token!]
                    end
                    f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                    [
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                    ]
                  else
                    []
                  end
                end
              cookies.merge(f0_cookie_pairs, URI.parse("https://#{f0_host}/"))
            end
            bearer_headers(
              jwt_access_token_for(
                fx0_user,
                host: fx0_host,
                session_public_id: fx0_token.public_id,
                resource_type: "client",
              ),
              host: fx0_host,
            )
          end,]
        when "com"
          actor = Visitor.create!(id: actor_id, status_id: VisitorStatus::ACTIVE)
          token = VisitorToken.create!(visitor: actor, root_login_established_at: VisitorToken.database_now)
          host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
          [actor, token, VisitorStepUpCeremonyTransaction, host, begin
            fx1_host = host
            fx1_token = token
            fx1_visitor = actor
            begin
              f1_cookie_pairs =
                begin
                  f1_host = fx1_host
                  f1_token = fx1_token
                  f1_client = OidcClientRegistry.find!("base-com-ww")
                  f1_key = [f1_client.client_id, f1_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if @base_browser_rp_credentials[f1_key] ||
                      (f1_token.currently_usable? &&
                        !(f1_token.device_session_id && VisitorRpSession.exists?(
                          device_session_id: f1_token.device_session_id,
                          oidc_client_id: f1_client.client_id,
                          revoked_at: nil,
                        )))
                    unless @base_browser_rp_credentials[f1_key]
                      f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                      f1_now = Time.current
                      f1_session = VisitorRpSession.create!(
                        visitor_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                        refresh_token_expires_at: f1_now + 10.minutes,
                      )
                      f1_access = AuthenticationTokenService.encode(
                        fx1_visitor,
                        host: f1_host,
                        resource_type: "visitor",
                        session_public_id: f1_token.public_id,
                        base_session_public_id: f1_token.public_id,
                        oidc_sid: f1_session.public_id,
                        oidc_jti: f1_session.oidc_jti,
                        expires_at: f1_now + 10.minutes,
                        scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(f1_client),
                        audiences: [f1_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                        subject: OidcSubject.for(
                          fx1_visitor,
                          resource_type: "visitor",
                        ),
                        client_id: f1_client.client_id,
                      )
                      @base_browser_rp_credentials[f1_key] = [f1_access, f1_session.issue_refresh_token!]
                    end
                    f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                    [
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                    ]
                  else
                    []
                  end
                end
              cookies.merge(f1_cookie_pairs, URI.parse("https://#{f1_host}/"))
            end
            bearer_headers(
              jwt_access_token_for(
                fx1_visitor,
                host: fx1_host,
                session_public_id: fx1_token.public_id,
                resource_type: "visitor",
              ),
              host: fx1_host,
            )
          end,]
        when "org"
          actor = Operator.create!(id: actor_id)
          token = OperatorToken.create!(staff: actor, root_login_established_at: OperatorToken.database_now)
          host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
          [actor, token, OperatorStepUpCeremonyTransaction, host, begin
            fx2_host = host
            fx2_token = token
            fx2_operator = actor
            begin
              f2_cookie_pairs =
                begin
                  f2_host = fx2_host
                  f2_token = fx2_token
                  f2_client = OidcClientRegistry.find!("base-org-ww")
                  f2_key = [f2_client.client_id, f2_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if @base_browser_rp_credentials[f2_key] ||
                      (f2_token.currently_usable? &&
                        !(f2_token.device_session_id && OperatorRpSession.exists?(
                          device_session_id: f2_token.device_session_id,
                          oidc_client_id: f2_client.client_id,
                          revoked_at: nil,
                        )))
                    unless @base_browser_rp_credentials[f2_key]
                      f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                      f2_now = Time.current
                      f2_session = OperatorRpSession.create!(
                        operator_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                        refresh_token_expires_at: f2_now + 10.minutes,
                      )
                      f2_access = AuthenticationTokenService.encode(
                        fx2_operator,
                        host: f2_host,
                        resource_type: "operator",
                        session_public_id: f2_token.public_id,
                        base_session_public_id: f2_token.public_id,
                        oidc_sid: f2_session.public_id,
                        oidc_jti: f2_session.oidc_jti,
                        expires_at: f2_now + 10.minutes,
                        scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(f2_client),
                        audiences: [f2_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                        subject: OidcSubject.for(
                          fx2_operator,
                          resource_type: "operator",
                        ),
                        client_id: f2_client.client_id,
                      )
                      @base_browser_rp_credentials[f2_key] = [f2_access, f2_session.issue_refresh_token!]
                    end
                    f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                    [
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                    ]
                  else
                    []
                  end
                end
              cookies.merge(f2_cookie_pairs, URI.parse("https://#{f2_host}/"))
            end
            bearer_headers(
              jwt_access_token_for(
                fx2_operator,
                host: fx2_host,
                session_public_id: fx2_token.public_id,
                resource_type: "operator",
              ),
              host: fx2_host,
            )
          end,]
        end
      target = public_send("base_#{surface}_identity_passkeys_path", ri: "jp")
      pt = signed_step_up_pt_for(target, surface:, session_nonce: token.public_id)
      post public_send("base_#{surface}_verification_setup_url", ri: "jp", host:),
           params: { scope: "settings_passkey", pt:, registration_method: "passkey" }, headers: headers

      assert_response :see_other
      original = transaction_class.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)

      assert_equal ["pending", "bootstrap"], [original.status, original.purpose]
      different_target = public_send("base_#{surface}_identity_emails_path", ri: "jp")
      different_pt = signed_step_up_pt_for(different_target, surface:, session_nonce: token.public_id)
      post public_send("base_#{surface}_verification_setup_url", ri: "jp", host:),
           params: { scope: "settings_email", pt: different_pt, registration_method: "passkey" }, headers: headers

      assert_response :conflict
      assert_equal ["pending", "settings_passkey", target, 1],
                   [original.reload.status, original.required_scope, original.return_to,
                    transaction_class.where(actor_ref: actor.public_id).count,]
      # Concurrent registration makes ordinary verification eligible without completing this bootstrap.
      case surface
      when "app"
        actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
      when "com"
        actor.visitor_emails.create!(
          address: "purpose-#{SecureRandom.hex(8)}@example.com",
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).finalize_binding!
      when "org"
        actor.operator_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
      end
      post public_send("base_#{surface}_verification_url", ri: "jp", host:),
           params: { scope: "settings_passkey", pt: }, headers: headers

      assert_response :conflict
      assert_equal ["pending", "bootstrap", target, nil, 1],
                   [original.reload.status, original.purpose, original.return_to,
                    token.reload.last_step_up_at, transaction_class.where(actor_ref: actor.public_id).count,]
    end

    test "#{surface} a changed return target conflicts and protected continue retains the original intent" do
      actor_class, token_class, transaction_class, host_key, passkeys = {
        "app" => [Client, ClientToken, ClientStepUpCeremonyTransaction, "PUBLIC_BASE_SERVICE_URL", :client_passkeys],
        "com" => [Visitor, VisitorToken, VisitorStepUpCeremonyTransaction,
                  "PUBLIC_BASE_CORPORATE_URL", :visitor_passkeys,],
        "org" => [Operator, OperatorToken, OperatorStepUpCeremonyTransaction,
                  "PUBLIC_BASE_STAFF_URL", :operator_passkeys,],
      }.fetch(surface)
      # Independent writer tests can leave credential rows outside fixture transactions.
      actor = actor_class.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000)
      if surface == "com"
        VisitorEmail.create!(
          visitor: actor, address: "conflict-#{SecureRandom.hex(8)}@example.com",
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).finalize_binding!
      end
      actor.public_send(passkeys).create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
      owner_key = { "app" => :user, "com" => :visitor, "org" => :staff }.fetch(surface)
      token = token_class.create!(owner_key => actor)
      host = ENV.fetch(host_key)
      headers =
        case surface
        when "app" then begin
          fx3_host = host
          fx3_token = token
          fx3_user = actor
          begin
            f3_cookie_pairs =
              begin
                f3_host = fx3_host
                f3_token = fx3_token
                f3_client = OidcClientRegistry.find!("base-app-ww")
                f3_key = [f3_client.client_id, f3_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f3_key] ||
                    (f3_token.currently_usable? &&
                      !(f3_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f3_token.device_session_id,
                        oidc_client_id: f3_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f3_key]
                    f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                    f3_now = Time.current
                    f3_session = ClientRpSession.create!(
                      client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                      refresh_token_expires_at: f3_now + 10.minutes,
                    )
                    f3_access = AuthenticationTokenService.encode(
                      fx3_user, host: f3_host, resource_type: "client",
                                session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                                oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                subject: OidcSubject.for(
                                  fx3_user,
                                  resource_type: "client",
                                ), client_id: f3_client.client_id,
                    )
                    @base_browser_rp_credentials[f3_key] =
                      [f3_access, f3_session.issue_refresh_token!]
                  end
                  f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f3_cookie_pairs, URI.parse("https://#{f3_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx3_user,
              host: fx3_host,
              session_public_id: fx3_token.public_id,
              resource_type: "client",
            ),
            host: fx3_host,
          )
        end
        when "com" then begin
          fx4_host = host
          fx4_token = token
          fx4_visitor = actor
          begin
            f4_cookie_pairs =
              begin
                f4_host = fx4_host
                f4_token = fx4_token
                f4_client = OidcClientRegistry.find!("base-com-ww")
                f4_key = [f4_client.client_id, f4_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f4_key] ||
                    (f4_token.currently_usable? &&
                      !(f4_token.device_session_id && VisitorRpSession.exists?(
                        device_session_id: f4_token.device_session_id,
                        oidc_client_id: f4_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f4_key]
                    f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
                    f4_now = Time.current
                    f4_session = VisitorRpSession.create!(
                      visitor_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                      refresh_token_expires_at: f4_now + 10.minutes,
                    )
                    f4_access = AuthenticationTokenService.encode(
                      fx4_visitor,
                      host: f4_host,
                      resource_type: "visitor",
                      session_public_id: f4_token.public_id,
                      base_session_public_id: f4_token.public_id,
                      oidc_sid: f4_session.public_id,
                      oidc_jti: f4_session.oidc_jti,
                      expires_at: f4_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f4_client),
                      audiences: [f4_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                      subject: OidcSubject.for(
                        fx4_visitor,
                        resource_type: "visitor",
                      ),
                      client_id: f4_client.client_id,
                    )
                    @base_browser_rp_credentials[f4_key] =
                      [f4_access, f4_session.issue_refresh_token!]
                  end
                  f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f4_cookie_pairs, URI.parse("https://#{f4_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx4_visitor,
              host: fx4_host,
              session_public_id: fx4_token.public_id,
              resource_type: "visitor",
            ),
            host: fx4_host,
          )
        end
        when "org" then begin
          fx5_host = host
          fx5_token = token
          fx5_operator = actor
          begin
            f5_cookie_pairs =
              begin
                f5_host = fx5_host
                f5_token = fx5_token
                f5_client = OidcClientRegistry.find!("base-org-ww")
                f5_key = [f5_client.client_id, f5_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f5_key] ||
                    (f5_token.currently_usable? &&
                      !(f5_token.device_session_id && OperatorRpSession.exists?(
                        device_session_id: f5_token.device_session_id,
                        oidc_client_id: f5_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f5_key]
                    f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
                    f5_now = Time.current
                    f5_session = OperatorRpSession.create!(
                      operator_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                      refresh_token_expires_at: f5_now + 10.minutes,
                    )
                    f5_access = AuthenticationTokenService.encode(
                      fx5_operator,
                      host: f5_host,
                      resource_type: "operator",
                      session_public_id: f5_token.public_id,
                      base_session_public_id: f5_token.public_id,
                      oidc_sid: f5_session.public_id,
                      oidc_jti: f5_session.oidc_jti,
                      expires_at: f5_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f5_client),
                      audiences: [f5_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                      subject: OidcSubject.for(
                        fx5_operator,
                        resource_type: "operator",
                      ),
                      client_id: f5_client.client_id,
                    )
                    @base_browser_rp_credentials[f5_key] =
                      [f5_access, f5_session.issue_refresh_token!]
                  end
                  f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f5_cookie_pairs, URI.parse("https://#{f5_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx5_operator,
              host: fx5_host,
              session_public_id: fx5_token.public_id,
              resource_type: "operator",
            ),
            host: fx5_host,
          )
        end
        end
      endpoint = public_send("base_#{surface}_verification_url", ri: "jp", host:)
      original_target = public_send("base_#{surface}_identity_passkeys_path", ri: "jp")
      original_pt = signed_step_up_pt_for(original_target, surface:, session_nonce: token.public_id)
      post endpoint, params: { scope: "settings_passkey", pt: original_pt }, headers: headers

      assert_response :see_other
      original = transaction_class.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)
      changed_pt = signed_step_up_pt_for("#{original_target}?intent=second", surface:, session_nonce: token.public_id)
      post endpoint, params: { scope: "settings_passkey", pt: changed_pt }, headers: headers

      assert_response :conflict
      assert_equal ["pending", original_target, 1],
                   [original.reload.status, original.return_to,
                    transaction_class.where(actor_ref: actor.public_id).count,]
      csrf = response.parsed_body.css("form").first.at_css('input[name="authenticity_token"]')["value"]
      with_forgery_protection do
        post endpoint,
             params: { scope: "settings_passkey",
                       pt: changed_pt,
                       conflict_action: "continue",
                       authenticity_token: csrf, },
             headers: headers.merge("Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-site")
      end

      assert_response :see_other
      assert_equal ["pending", original_target, nil, 1],
                   [original.reload.status, original.return_to, token.reload.last_step_up_at,
                    transaction_class.where(actor_ref: actor.public_id).count,]

      email_target = public_send("base_#{surface}_identity_emails_path", ri: "jp")
      email_pt = signed_step_up_pt_for(email_target, surface:, session_nonce: token.public_id)
      post endpoint, params: { scope: "settings_email", pt: email_pt }, headers: headers

      assert_response :conflict
      assert_equal ["pending", "settings_passkey", original_target],
                   [original.reload.status, original.required_scope, original.return_to]
      csrf = response.parsed_body.css("form").last.at_css('input[name="authenticity_token"]')["value"]
      with_forgery_protection do
        post endpoint,
             params: { scope: "settings_email",
                       pt: email_pt,
                       conflict_action: "cancel_and_start",
                       authenticity_token: csrf, },
             headers: headers.merge("Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-site")
      end

      assert_response :see_other
      replacement = transaction_class.find_by!(actor_ref: actor.public_id, status: "pending")

      assert_equal ["canceled", "settings_email", email_target, nil, 2],
                   [original.reload.status, replacement.required_scope, replacement.return_to,
                    token.reload.last_step_up_at, transaction_class.where(actor_ref: actor.public_id).count,]
    end
  end

  test "app conflict forms preserve validated scope and return proof through protected choices" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    token = ClientToken.create!(user: actor)
    headers =
      begin
        fx6_host = host
        fx6_token = token
        fx6_user = actor
        begin
          f6_cookie_pairs =
            begin
              f6_host = fx6_host
              f6_token = fx6_token
              f6_client = OidcClientRegistry.find!("base-app-ww")
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f6_key] ||
                  (f6_token.currently_usable? &&
                    !(f6_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f6_token.device_session_id,
                      oidc_client_id: f6_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f6_key]
                  f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
                  f6_now = Time.current
                  f6_session = ClientRpSession.create!(
                    client_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                    refresh_token_expires_at: f6_now + 10.minutes,
                  )
                  f6_access = AuthenticationTokenService.encode(
                    fx6_user, host: f6_host, resource_type: "client",
                              session_public_id: f6_token.public_id, base_session_public_id: f6_token.public_id,
                              oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                              expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                              subject: OidcSubject.for(
                                fx6_user,
                                resource_type: "client",
                              ), client_id: f6_client.client_id,
                  )
                  @base_browser_rp_credentials[f6_key] =
                    [f6_access, f6_session.issue_refresh_token!]
                end
                f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f6_cookie_pairs, URI.parse("https://#{f6_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx6_user,
            host: fx6_host,
            session_public_id: fx6_token.public_id,
            resource_type: "client",
          ),
          host: fx6_host,
        )
      end
    original_pt = signed_step_up_pt_for(
      base_app_identity_passkeys_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:),
         params: { scope: "settings_passkey", pt: original_pt }, headers: headers
    original = ClientStepUpCeremonyTransaction.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:), params: { scope: "settings_email", pt: }, headers: headers

    assert_response :conflict
    forms = response.parsed_body.css("form")

    assert_equal [["settings_email", pt], ["settings_email", pt]], forms.map { |form|
      [form.at_css('input[name="scope"]')&.[]("value"), form.at_css('input[name="pt"]')&.[]("value")]
    }
    csrf = forms.last.at_css('input[name="authenticity_token"]')["value"]
    with_forgery_protection do
      post base_app_verification_url(ri: "jp", host:),
           params: { scope: "settings_email", pt:, conflict_action: "cancel_and_start" },
           headers: headers.merge("Sec-Fetch-Site" => "cross-site")

      assert_equal [422, "pending", 1],
                   [response.status, original.reload.status,
                    ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count,]
      post base_app_verification_url(ri: "jp", host:),
           params: { scope: "settings_email", pt:, conflict_action: "cancel_and_start", authenticity_token: csrf },
           headers: headers.merge("Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-site")
    end

    assert_response :see_other
    replacement = ClientStepUpCeremonyTransaction.find_by!(actor_ref: actor.public_id, status: "pending")

    assert_equal ["canceled", "settings_email", base_app_identity_emails_path(ri: "jp"), nil],
                 [original.reload.status, replacement.required_scope, replacement.return_to,
                  token.reload.last_step_up_at,]
  end

  test "app conflict continue explicitly restarts an expired binding without extending its parent deadline" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    token = ClientToken.create!(user: actor)
    headers =
      begin
        fx7_host = host
        fx7_token = token
        fx7_user = actor
        begin
          f7_cookie_pairs =
            begin
              f7_host = fx7_host
              f7_token = fx7_token
              f7_client = OidcClientRegistry.find!("base-app-ww")
              f7_key = [f7_client.client_id, f7_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f7_key] ||
                  (f7_token.currently_usable? &&
                    !(f7_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f7_token.device_session_id,
                      oidc_client_id: f7_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f7_key]
                  f7_token.rotate_refresh_token! unless f7_token.device_session_record.current_refresh_token_id
                  f7_now = Time.current
                  f7_session = ClientRpSession.create!(
                    client_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                    refresh_token_expires_at: f7_now + 10.minutes,
                  )
                  f7_access = AuthenticationTokenService.encode(
                    fx7_user, host: f7_host, resource_type: "client",
                              session_public_id: f7_token.public_id, base_session_public_id: f7_token.public_id,
                              oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                              expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                              subject: OidcSubject.for(
                                fx7_user,
                                resource_type: "client",
                              ), client_id: f7_client.client_id,
                  )
                  @base_browser_rp_credentials[f7_key] =
                    [f7_access, f7_session.issue_refresh_token!]
                end
                f7_access, f7_refresh = @base_browser_rp_credentials.fetch(f7_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f7_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f7_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f7_cookie_pairs, URI.parse("https://#{f7_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx7_user,
            host: fx7_host,
            session_public_id: fx7_token.public_id,
            resource_type: "client",
          ),
          host: fx7_host,
        )
      end
    original_pt = signed_step_up_pt_for(
      base_app_identity_passkeys_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:),
         params: { scope: "settings_passkey", pt: original_pt }, headers: headers
    original = ClientStepUpCeremonyTransaction.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: original.id)
    deadline = original.expires_at
    binding.update_columns(expires_at: binding.class.database_now - Rational(1, 1_000_000))
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:), params: { scope: "settings_email", pt: }, headers: headers

    assert_response :conflict
    form = response.parsed_body.css("form").first

    assert_equal binding.entry_ref, form.at_css('input[name="restart_of"]')&.[]("value")
    csrf = form.at_css('input[name="authenticity_token"]')["value"]
    with_forgery_protection do
      post base_app_verification_url(ri: "jp", host:),
           params: { scope: "settings_email",
                     pt:,
                     conflict_action: "continue",
                     restart_of: binding.entry_ref,
                     authenticity_token: csrf, },
           headers: headers.merge("Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-site")
    end

    assert_response :see_other
    replacement = ClientAuthAdmissionBinding.find_by!(entry_ref: redirect_query.fetch("entry_ref"))

    assert_equal [original.id, deadline, "pending", "settings_passkey", true, nil],
                 [replacement.step_up_ceremony_transaction_id, original.reload.expires_at, original.status,
                  original.required_scope, binding.reload.retired?, token.reload.last_step_up_at,]
  end

  test "app conflict continue returns to admitted Auth without allocating another admission" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    token = ClientToken.create!(user: actor)
    headers =
      begin
        fx8_host = host
        fx8_token = token
        fx8_user = actor
        begin
          f8_cookie_pairs =
            begin
              f8_host = fx8_host
              f8_token = fx8_token
              f8_client = OidcClientRegistry.find!("base-app-ww")
              f8_key = [f8_client.client_id, f8_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f8_key] ||
                  (f8_token.currently_usable? &&
                    !(f8_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f8_token.device_session_id,
                      oidc_client_id: f8_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f8_key]
                  f8_token.rotate_refresh_token! unless f8_token.device_session_record.current_refresh_token_id
                  f8_now = Time.current
                  f8_session = ClientRpSession.create!(
                    client_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                    refresh_token_expires_at: f8_now + 10.minutes,
                  )
                  f8_access = AuthenticationTokenService.encode(
                    fx8_user, host: f8_host, resource_type: "client",
                              session_public_id: f8_token.public_id, base_session_public_id: f8_token.public_id,
                              oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                              expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                              subject: OidcSubject.for(
                                fx8_user,
                                resource_type: "client",
                              ), client_id: f8_client.client_id,
                  )
                  @base_browser_rp_credentials[f8_key] =
                    [f8_access, f8_session.issue_refresh_token!]
                end
                f8_access, f8_refresh = @base_browser_rp_credentials.fetch(f8_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f8_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f8_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f8_cookie_pairs, URI.parse("https://#{f8_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx8_user,
            host: fx8_host,
            session_public_id: fx8_token.public_id,
            resource_type: "client",
          ),
          host: fx8_host,
        )
      end
    original_pt = signed_step_up_pt_for(
      base_app_identity_passkeys_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:),
         params: { scope: "settings_passkey", pt: original_pt }, headers: headers
    original = ClientStepUpCeremonyTransaction.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: original.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: original.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id,
    )
    post base_app_verification_url(ri: "jp", host:), params: { scope: "settings_email", pt: }, headers: headers

    assert_response :conflict
    csrf = response.parsed_body.css("form").first.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference ["ClientAuthAdmissionBinding.count", "ClientAuthCeremonySession.count"] do
      with_forgery_protection do
        post base_app_verification_url(ri: "jp", host:),
             params: { scope: "settings_email", pt:, conflict_action: "continue", authenticity_token: csrf },
             headers: headers.merge("Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-site")
      end
    end

    assert_response :see_other
    jump_uri = URI.parse(response.location)
    jump_token = Rack::Utils.parse_nested_query(jump_uri.query).fetch("rt")
    destination, = JWT.decode(
      jump_token,
      JumpRtKeyring.private_key(JumpRtSurface.namespace_for_controller("Base::App::VerificationController")),
      true, algorithms: ["ES384"],
    )

    assert_equal auth_app_verification_url(ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"),
                 destination.fetch("url")
    assert_equal ["pending", true, nil],
                 [original.reload.status, admitted.reload.active?(now: admitted.class.database_now),
                  token.reload.last_step_up_at,]
  end

  test "app Base verification GET displays a nonconsuming start and POST issues opaque admission" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-intent-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      http_headers_45 =
        begin
          fx9_host = host
          fx9_token = token
          fx9_user = user
          begin
            f9_cookie_pairs =
              begin
                f9_host = fx9_host
                f9_token = fx9_token
                f9_client = OidcClientRegistry.find!("base-app-ww")
                f9_key = [f9_client.client_id, f9_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f9_key] ||
                    (f9_token.currently_usable? &&
                      !(f9_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f9_token.device_session_id,
                        oidc_client_id: f9_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f9_key]
                    f9_token.rotate_refresh_token! unless f9_token.device_session_record.current_refresh_token_id
                    f9_now = Time.current
                    f9_session = ClientRpSession.create!(
                      client_token: f9_token, oidc_client_id: f9_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f9_now,
                      refresh_token_expires_at: f9_now + 10.minutes,
                    )
                    f9_access = AuthenticationTokenService.encode(
                      fx9_user,
                      host: f9_host,
                      resource_type: "client",
                      session_public_id: f9_token.public_id,
                      base_session_public_id: f9_token.public_id,
                      oidc_sid: f9_session.public_id,
                      oidc_jti: f9_session.oidc_jti,
                      expires_at: f9_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f9_client),
                      audiences: [f9_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f9_client),
                      subject: OidcSubject.for(
                        fx9_user,
                        resource_type: "client",
                      ),
                      client_id: f9_client.client_id,
                    )
                    @base_browser_rp_credentials[f9_key] =
                      [f9_access, f9_session.issue_refresh_token!]
                  end
                  f9_access, f9_refresh = @base_browser_rp_credentials.fetch(f9_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f9_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f9_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f9_cookie_pairs, URI.parse("https://#{f9_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx9_user,
              host: fx9_host,
              session_public_id: fx9_token.public_id,
              resource_type: "client",
            ),
            host: fx9_host,
          )
        end
      get base_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: http_headers_45
    end
    assert_response :success, response.body
    assert_equal "base/app/verifications/show", inertia_component
    form = inertia_props.fetch("form")

    assert_equal "settings_email", form.fetch("scope")
    assert_equal pt, form.fetch("pt")
    assert_equal base_app_verification_path(ri: "jp"), form.fetch("action")

    assert_difference -> { ClientStepUpCeremonyTransaction.count }, 1 do
      http_headers_44 =
        begin
          fx10_host = host
          fx10_token = token
          fx10_user = user
          begin
            f10_cookie_pairs =
              begin
                f10_host = fx10_host
                f10_token = fx10_token
                f10_client = OidcClientRegistry.find!("base-app-ww")
                f10_key = [f10_client.client_id, f10_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f10_key] ||
                    (f10_token.currently_usable? &&
                      !(f10_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f10_token.device_session_id,
                        oidc_client_id: f10_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f10_key]
                    f10_token.rotate_refresh_token! unless f10_token.device_session_record.current_refresh_token_id
                    f10_now = Time.current
                    f10_session = ClientRpSession.create!(
                      client_token: f10_token, oidc_client_id: f10_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f10_now,
                      refresh_token_expires_at: f10_now + 10.minutes,
                    )
                    f10_access = AuthenticationTokenService.encode(
                      fx10_user,
                      host: f10_host,
                      resource_type: "client",
                      session_public_id: f10_token.public_id,
                      base_session_public_id: f10_token.public_id,
                      oidc_sid: f10_session.public_id,
                      oidc_jti: f10_session.oidc_jti,
                      expires_at: f10_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f10_client),
                      audiences: [f10_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f10_client),
                      subject: OidcSubject.for(
                        fx10_user,
                        resource_type: "client",
                      ),
                      client_id: f10_client.client_id,
                    )
                    @base_browser_rp_credentials[f10_key] =
                      [f10_access, f10_session.issue_refresh_token!]
                  end
                  f10_access, f10_refresh = @base_browser_rp_credentials.fetch(f10_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f10_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f10_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f10_cookie_pairs, URI.parse("https://#{f10_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx10_user,
              host: fx10_host,
              session_public_id: fx10_token.public_id,
              resource_type: "client",
            ),
            host: fx10_host,
          )
        end
      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: form.fetch("scope"), pt: form.fetch("pt") },
           headers: http_headers_44
    end
    assert_response :see_other
    query = redirect_query

    assert_predicate query["entry_ref"], :present?
    assert_nil query["step_up_ceremony_grant"]
    assert_nil query["scope"]
    assert_nil query["pt"]
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: query.fetch("entry_ref"))
    http_headers_43 =
      begin
        fx11_host = host
        fx11_token = token
        fx11_user = user
        begin
          f11_cookie_pairs =
            begin
              f11_host = fx11_host
              f11_token = fx11_token
              f11_client = OidcClientRegistry.find!("base-app-ww")
              f11_key = [f11_client.client_id, f11_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f11_key] ||
                  (f11_token.currently_usable? &&
                    !(f11_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f11_token.device_session_id,
                      oidc_client_id: f11_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f11_key]
                  f11_token.rotate_refresh_token! unless f11_token.device_session_record.current_refresh_token_id
                  f11_now = Time.current
                  f11_session = ClientRpSession.create!(
                    client_token: f11_token, oidc_client_id: f11_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f11_now,
                    refresh_token_expires_at: f11_now + 10.minutes,
                  )
                  f11_access = AuthenticationTokenService.encode(
                    fx11_user,
                    host: f11_host,
                    resource_type: "client",
                    session_public_id: f11_token.public_id,
                    base_session_public_id: f11_token.public_id,
                    oidc_sid: f11_session.public_id,
                    oidc_jti: f11_session.oidc_jti,
                    expires_at: f11_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f11_client),
                    audiences: [f11_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f11_client),
                    subject: OidcSubject.for(
                      fx11_user,
                      resource_type: "client",
                    ),
                    client_id: f11_client.client_id,
                  )
                  @base_browser_rp_credentials[f11_key] = [f11_access, f11_session.issue_refresh_token!]
                end
                f11_access, f11_refresh = @base_browser_rp_credentials.fetch(f11_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f11_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f11_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f11_cookie_pairs, URI.parse("https://#{f11_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx11_user,
            host: fx11_host,
            session_public_id: fx11_token.public_id,
            resource_type: "client",
          ),
          host: fx11_host,
        )
      end
    get base_app_verification_url(scope: "settings_email", pt:, ri: "jp", host:),
        params: { restart_of: binding.entry_ref }, headers: http_headers_43

    assert_equal [200, binding.entry_ref, "settings_email", pt, nil],
                 [response.status, response.parsed_body.at_css('input[name="restart_of"]')&.[]("value"),
                  response.parsed_body.at_css('input[name="scope"]')&.[]("value"),
                  response.parsed_body.at_css('input[name="pt"]')&.[]("value"), token.reload.last_step_up_at,]
    foreign = open_session
    foreign.host!(host)
    foreign.https!
    [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::REFRESH_COOKIE].each do |name|
      foreign.cookies.merge("#{name}=#{Rack::Utils.escape(cookies[name])}", URI.parse("https://#{host}/"))
    end
    foreign.get(
      base_app_verification_url(scope: "settings_email", pt:, ri: "jp", host:),
      params: { restart_of: binding.entry_ref },
    )

    assert_equal [400, nil, I18n.t("errors.messages.invalid_request"), nil, nil],
                 [foreign.response.status, foreign.response.location, foreign.response.body,
                  binding.reload.retired_at, binding.redeemed_at,]
    _auth_session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: session.fetch("auth_admission_browser_nonce"),
          ),
        )
        [admission_session, admission_raw_sid]
      end
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: query.fetch("entry_ref"), surface: "app", expected_intent: "step_up",
      binding:, raw_auth_sid: raw_sid,
    )
    transaction = ClientStepUpCeremonyTransaction.find_by!(transaction_id: payload.fetch("subject_ref"))

    assert_equal transaction.transaction_id,
                 begin
                   fv5068 = transaction.transaction_id
                   BaseStepUpMarkerAdapter.new.read(
                     locator: session.fetch(:base_step_up_marker_locator),
                     transaction_ref: fv5068,
                   )
                 end.fetch("transaction_ref")
    assert_equal user.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "settings_email", transaction.required_scope
    assert_equal StepUpRequirement::NO_AAL, transaction.required_aal
    assert_nil token.reload.last_step_up_at
  end

  test "app base completion consumes the opaque result and commits freshness for the admitted session" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-completion-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_42 =
      begin
        fx12_host = host
        fx12_token = token
        fx12_user = user
        begin
          f12_cookie_pairs =
            begin
              f12_host = fx12_host
              f12_token = fx12_token
              f12_client = OidcClientRegistry.find!("base-app-ww")
              f12_key = [f12_client.client_id, f12_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f12_key] ||
                  (f12_token.currently_usable? &&
                    !(f12_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f12_token.device_session_id,
                      oidc_client_id: f12_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f12_key]
                  f12_token.rotate_refresh_token! unless f12_token.device_session_record.current_refresh_token_id
                  f12_now = Time.current
                  f12_session = ClientRpSession.create!(
                    client_token: f12_token, oidc_client_id: f12_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f12_now,
                    refresh_token_expires_at: f12_now + 10.minutes,
                  )
                  f12_access = AuthenticationTokenService.encode(
                    fx12_user,
                    host: f12_host,
                    resource_type: "client",
                    session_public_id: f12_token.public_id,
                    base_session_public_id: f12_token.public_id,
                    oidc_sid: f12_session.public_id,
                    oidc_jti: f12_session.oidc_jti,
                    expires_at: f12_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f12_client),
                    audiences: [f12_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f12_client),
                    subject: OidcSubject.for(
                      fx12_user,
                      resource_type: "client",
                    ),
                    client_id: f12_client.client_id,
                  )
                  @base_browser_rp_credentials[f12_key] = [f12_access, f12_session.issue_refresh_token!]
                end
                f12_access, f12_refresh = @base_browser_rp_credentials.fetch(f12_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f12_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f12_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f12_cookie_pairs, URI.parse("https://#{f12_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx12_user,
            host: fx12_host,
            session_public_id: fx12_token.public_id,
            resource_type: "client",
          ),
          host: fx12_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_42

    assert_response :see_other
    transaction =
      begin
        fv5067 = ClientStepUpCeremonyTransaction
        fv5066 = user
        fv5065 = token
        fv5067.where(
          actor_ref: fv5066.public_id,
          session_ref: fv5065.public_id,
        ).order(id: :desc).first!
      end
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now,
      verified_credential_ref: begin
        fv5064 = user
        fv5064.client_totp_credentials.find_by!(
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        ).public_id
      end,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    foreign = open_session
    foreign.host!(host)
    foreign.https!
    [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::REFRESH_COOKIE].each do |name|
      foreign.cookies.merge("#{name}=#{Rack::Utils.escape(cookies[name])}", URI.parse("https://#{host}/"))
    end
    foreign.get(
      base_app_verification_completion_url(ri: "jp", host:),
      params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
    )

    assert_equal [400, nil, "verified", nil],
                 [foreign.response.status, foreign.response.location, transaction.reload.status,
                  token.reload.last_step_up_at,]
    http_headers_41 =
      begin
        fx13_host = host
        fx13_token = token
        fx13_user = user
        begin
          f13_cookie_pairs =
            begin
              f13_host = fx13_host
              f13_token = fx13_token
              f13_client = OidcClientRegistry.find!("base-app-ww")
              f13_key = [f13_client.client_id, f13_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f13_key] ||
                  (f13_token.currently_usable? &&
                    !(f13_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f13_token.device_session_id,
                      oidc_client_id: f13_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f13_key]
                  f13_token.rotate_refresh_token! unless f13_token.device_session_record.current_refresh_token_id
                  f13_now = Time.current
                  f13_session = ClientRpSession.create!(
                    client_token: f13_token, oidc_client_id: f13_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f13_now,
                    refresh_token_expires_at: f13_now + 10.minutes,
                  )
                  f13_access = AuthenticationTokenService.encode(
                    fx13_user,
                    host: f13_host,
                    resource_type: "client",
                    session_public_id: f13_token.public_id,
                    base_session_public_id: f13_token.public_id,
                    oidc_sid: f13_session.public_id,
                    oidc_jti: f13_session.oidc_jti,
                    expires_at: f13_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f13_client),
                    audiences: [f13_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f13_client),
                    subject: OidcSubject.for(
                      fx13_user,
                      resource_type: "client",
                    ),
                    client_id: f13_client.client_id,
                  )
                  @base_browser_rp_credentials[f13_key] =
                    [f13_access, f13_session.issue_refresh_token!]
                end
                f13_access, f13_refresh = @base_browser_rp_credentials.fetch(f13_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f13_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f13_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f13_cookie_pairs, URI.parse("https://#{f13_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx13_user,
            host: fx13_host,
            session_public_id: fx13_token.public_id,
            resource_type: "client",
          ),
          host: fx13_host,
        )
      end
    get base_app_verification_completion_url(ri: "jp", host:),
        params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
        headers: http_headers_41

    assert_response :success
    assert_equal ["verified", nil], [transaction.reload.status, token.reload.last_step_up_at]

    http_headers_40 =
      begin
        fx14_host = host
        fx14_token = token
        fx14_user = user
        begin
          f14_cookie_pairs =
            begin
              f14_host = fx14_host
              f14_token = fx14_token
              f14_client = OidcClientRegistry.find!("base-app-ww")
              f14_key = [f14_client.client_id, f14_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f14_key] ||
                  (f14_token.currently_usable? &&
                    !(f14_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f14_token.device_session_id,
                      oidc_client_id: f14_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f14_key]
                  f14_token.rotate_refresh_token! unless f14_token.device_session_record.current_refresh_token_id
                  f14_now = Time.current
                  f14_session = ClientRpSession.create!(
                    client_token: f14_token, oidc_client_id: f14_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f14_now,
                    refresh_token_expires_at: f14_now + 10.minutes,
                  )
                  f14_access = AuthenticationTokenService.encode(
                    fx14_user,
                    host: f14_host,
                    resource_type: "client",
                    session_public_id: f14_token.public_id,
                    base_session_public_id: f14_token.public_id,
                    oidc_sid: f14_session.public_id,
                    oidc_jti: f14_session.oidc_jti,
                    expires_at: f14_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f14_client),
                    audiences: [f14_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f14_client),
                    subject: OidcSubject.for(
                      fx14_user,
                      resource_type: "client",
                    ),
                    client_id: f14_client.client_id,
                  )
                  @base_browser_rp_credentials[f14_key] =
                    [f14_access, f14_session.issue_refresh_token!]
                end
                f14_access, f14_refresh = @base_browser_rp_credentials.fetch(f14_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f14_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f14_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f14_cookie_pairs, URI.parse("https://#{f14_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx14_user,
            host: fx14_host,
            session_public_id: fx14_token.public_id,
            resource_type: "client",
          ),
          host: fx14_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_40

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "consumed", transaction.reload.status
    token.reload

    assert_equal transaction.verified_at, token.last_step_up_at
    assert_equal "settings_email", token.last_step_up_scope
    assert_equal "totp", token.last_step_up_method
    assert_equal "aal1", token.last_step_up_aal
    assert_predicate ceremony.reload, :completed?
  end

  test "app base completion route is post only" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    recognized_get = Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :get)

    assert_equal "base/app/verification/completions", recognized_get[:controller]
    assert_equal "show", recognized_get[:action]

    recognized = Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :post)

    assert_equal "base/app/verification/completions", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "app base completion rejects missing csrf token when forgery protection is enabled" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    user.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    pt = signed_step_up_pt_for(base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)
    http_headers_39 =
      begin
        fx15_host = host
        fx15_token = token
        fx15_user = user
        begin
          f15_cookie_pairs =
            begin
              f15_host = fx15_host
              f15_token = fx15_token
              f15_client = OidcClientRegistry.find!("base-app-ww")
              f15_key = [f15_client.client_id, f15_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f15_key] ||
                  (f15_token.currently_usable? &&
                    !(f15_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f15_token.device_session_id,
                      oidc_client_id: f15_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f15_key]
                  f15_token.rotate_refresh_token! unless f15_token.device_session_record.current_refresh_token_id
                  f15_now = Time.current
                  f15_session = ClientRpSession.create!(
                    client_token: f15_token,
                    oidc_client_id: f15_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: f15_now,
                    refresh_token_expires_at: f15_now + 10.minutes,
                  )
                  f15_access = AuthenticationTokenService.encode(
                    fx15_user,
                    host: f15_host,
                    resource_type: "client",
                    session_public_id: f15_token.public_id,
                    base_session_public_id: f15_token.public_id,
                    oidc_sid: f15_session.public_id,
                    oidc_jti: f15_session.oidc_jti,
                    expires_at: f15_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f15_client),
                    audiences: [f15_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f15_client),
                    subject: OidcSubject.for(
                      fx15_user,
                      resource_type: "client",
                    ),
                    client_id: f15_client.client_id,
                  )
                  @base_browser_rp_credentials[f15_key] =
                    [f15_access, f15_session.issue_refresh_token!]
                end
                f15_access, f15_refresh = @base_browser_rp_credentials.fetch(f15_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f15_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f15_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(
            f15_cookie_pairs,
            URI.parse("https://#{f15_host}/"),
          )
        end
        bearer_headers(
          jwt_access_token_for(
            fx15_user,
            host: fx15_host,
            session_public_id: fx15_token.public_id,
            resource_type: "client",
          ),
          host: fx15_host,
        )
      end
    post base_app_verification_url(ri: "jp", host:), params: { scope: "settings_email", pt: },
                                                     headers: http_headers_39
    transaction = ClientStepUpCeremonyTransaction.find_by!(
      actor_ref: user.public_id, session_ref: token.public_id,
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: "test-passkey",
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)

    with_forgery_protection do
      # The request is explicitly cross-site and has no CSRF token; refuse it before consuming
      # the Step-Up result.
      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: begin
             fx16_host = host
             fx16_token = token
             fx16_user = user
             begin
               f16_cookie_pairs =
                 begin
                   f16_host = fx16_host
                   f16_token = fx16_token
                   f16_client = OidcClientRegistry.find!("base-app-ww")
                   f16_key = [f16_client.client_id, f16_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if @base_browser_rp_credentials[f16_key] ||
                       (f16_token.currently_usable? &&
                         !(f16_token.device_session_id && ClientRpSession.exists?(
                           device_session_id: f16_token.device_session_id,
                           oidc_client_id: f16_client.client_id,
                           revoked_at: nil,
                         )))
                     unless @base_browser_rp_credentials[f16_key]
                       f16_token.rotate_refresh_token! unless f16_token.device_session_record.current_refresh_token_id
                       f16_now = Time.current
                       f16_session = ClientRpSession.create!(
                         client_token: f16_token, oidc_client_id: f16_client.client_id, oidc_scope: "openid profile",
                         oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f16_now,
                         refresh_token_expires_at: f16_now + 10.minutes,
                       )
                       f16_access = AuthenticationTokenService.encode(
                         fx16_user,
                         host: f16_host,
                         resource_type: "client",
                         session_public_id: f16_token.public_id,
                         base_session_public_id: f16_token.public_id,
                         oidc_sid: f16_session.public_id,
                         oidc_jti: f16_session.oidc_jti,
                         expires_at: f16_now + 10.minutes,
                         scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(f16_client),
                         audiences: [f16_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f16_client),
                         subject: OidcSubject.for(
                           fx16_user,
                           resource_type: "client",
                         ),
                         client_id: f16_client.client_id,
                       )
                       @base_browser_rp_credentials[f16_key] =
                         [f16_access, f16_session.issue_refresh_token!]
                     end
                     f16_access, f16_refresh = @base_browser_rp_credentials.fetch(f16_key)
                     [
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f16_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f16_refresh)}",
                     ]
                   else
                     []
                   end
                 end
               cookies.merge(f16_cookie_pairs, URI.parse("https://#{f16_host}/"))
             end
             bearer_headers(
               jwt_access_token_for(
                 fx16_user,
                 host: fx16_host,
                 session_public_id: fx16_token.public_id,
                 resource_type: "client",
               ),
               host: fx16_host,
             )
           end.merge("Sec-Fetch-Site" => "cross-site")
    end

    assert_response :unprocessable_content
    assert_nil token.reload.last_step_up_at
    assert_not_predicate transaction.reload, :consumed?
  end

  test "app base completion refuses an invalid stored return target before consuming the result" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-unsafe-return-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_38 =
      begin
        fx17_host = host
        fx17_token = token
        fx17_user = user
        begin
          f17_cookie_pairs =
            begin
              f17_host = fx17_host
              f17_token = fx17_token
              f17_client = OidcClientRegistry.find!("base-app-ww")
              f17_key = [f17_client.client_id, f17_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f17_key] ||
                  (f17_token.currently_usable? &&
                    !(f17_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f17_token.device_session_id,
                      oidc_client_id: f17_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f17_key]
                  f17_token.rotate_refresh_token! unless f17_token.device_session_record.current_refresh_token_id
                  f17_now = Time.current
                  f17_session = ClientRpSession.create!(
                    client_token: f17_token, oidc_client_id: f17_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f17_now,
                    refresh_token_expires_at: f17_now + 10.minutes,
                  )
                  f17_access = AuthenticationTokenService.encode(
                    fx17_user,
                    host: f17_host,
                    resource_type: "client",
                    session_public_id: f17_token.public_id,
                    base_session_public_id: f17_token.public_id,
                    oidc_sid: f17_session.public_id,
                    oidc_jti: f17_session.oidc_jti,
                    expires_at: f17_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f17_client),
                    audiences: [f17_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f17_client),
                    subject: OidcSubject.for(
                      fx17_user,
                      resource_type: "client",
                    ),
                    client_id: f17_client.client_id,
                  )
                  @base_browser_rp_credentials[f17_key] = [f17_access, f17_session.issue_refresh_token!]
                end
                f17_access, f17_refresh = @base_browser_rp_credentials.fetch(f17_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f17_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f17_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f17_cookie_pairs, URI.parse("https://#{f17_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx17_user,
            host: fx17_host,
            session_public_id: fx17_token.public_id,
            resource_type: "client",
          ),
          host: fx17_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_38

    assert_response :see_other
    transaction =
      begin
        fv5063 = ClientStepUpCeremonyTransaction
        fv5062 = user
        fv5061 = token
        fv5063.where(
          actor_ref: fv5062.public_id,
          session_ref: fv5061.public_id,
        ).order(id: :desc).first!
      end
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now,
      verified_credential_ref: begin
        fv5060 = user
        fv5060.client_totp_credentials.find_by!(
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        ).public_id
      end,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )
    # Written past the model on purpose: the issuer never stores such a target. Partitions: another
    # host, a protocol-relative host, a path outside the scope, an empty value and a path carrying a
    # control character. A NUL is not reachable: the column cannot store one.
    [
      "https://evil.example/steal", "//evil.example/steal", "/dashboard", "", "/identity/emails\n/x",
    ].each do |stored_target|
      transaction.update_columns(return_to: stored_target)

      http_headers_37 =
        begin
          fx18_host = host
          fx18_token = token
          fx18_user = user
          begin
            f18_cookie_pairs =
              begin
                f18_host = fx18_host
                f18_token = fx18_token
                f18_client = OidcClientRegistry.find!("base-app-ww")
                f18_key = [f18_client.client_id, f18_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f18_key] ||
                    (f18_token.currently_usable? &&
                      !(f18_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f18_token.device_session_id,
                        oidc_client_id: f18_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f18_key]
                    f18_token.rotate_refresh_token! unless f18_token.device_session_record.current_refresh_token_id
                    f18_now = Time.current
                    f18_session = ClientRpSession.create!(
                      client_token: f18_token, oidc_client_id: f18_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f18_now,
                      refresh_token_expires_at: f18_now + 10.minutes,
                    )
                    f18_access = AuthenticationTokenService.encode(
                      fx18_user,
                      host: f18_host,
                      resource_type: "client",
                      session_public_id: f18_token.public_id,
                      base_session_public_id: f18_token.public_id,
                      oidc_sid: f18_session.public_id,
                      oidc_jti: f18_session.oidc_jti,
                      expires_at: f18_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f18_client),
                      audiences: [f18_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f18_client),
                      subject: OidcSubject.for(
                        fx18_user,
                        resource_type: "client",
                      ),
                      client_id: f18_client.client_id,
                    )
                    @base_browser_rp_credentials[f18_key] =
                      [f18_access, f18_session.issue_refresh_token!]
                  end
                  f18_access, f18_refresh = @base_browser_rp_credentials.fetch(f18_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f18_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f18_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f18_cookie_pairs, URI.parse("https://#{f18_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx18_user,
              host: fx18_host,
              session_public_id: fx18_token.public_id,
              resource_type: "client",
            ),
            host: fx18_host,
          )
        end
      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: http_headers_37

      assert_response :bad_request, stored_target.inspect
      assert_nil response.headers["Location"], stored_target.inspect
      assert_equal "verified", transaction.reload.status, stored_target.inspect
      assert_nil transaction.consumed_at, stored_target.inspect
      assert_nil token.reload.last_step_up_at, stored_target.inspect
      assert_not ceremony.reload.completed?, stored_target.inspect
    end

    # The result was never consumed, so the original target still completes the ceremony.
    transaction.update_columns(return_to: return_to)
    http_headers_36 =
      begin
        fx19_host = host
        fx19_token = token
        fx19_user = user
        begin
          f19_cookie_pairs =
            begin
              f19_host = fx19_host
              f19_token = fx19_token
              f19_client = OidcClientRegistry.find!("base-app-ww")
              f19_key = [f19_client.client_id, f19_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f19_key] ||
                  (f19_token.currently_usable? &&
                    !(f19_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f19_token.device_session_id,
                      oidc_client_id: f19_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f19_key]
                  f19_token.rotate_refresh_token! unless f19_token.device_session_record.current_refresh_token_id
                  f19_now = Time.current
                  f19_session = ClientRpSession.create!(
                    client_token: f19_token, oidc_client_id: f19_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f19_now,
                    refresh_token_expires_at: f19_now + 10.minutes,
                  )
                  f19_access = AuthenticationTokenService.encode(
                    fx19_user,
                    host: f19_host,
                    resource_type: "client",
                    session_public_id: f19_token.public_id,
                    base_session_public_id: f19_token.public_id,
                    oidc_sid: f19_session.public_id,
                    oidc_jti: f19_session.oidc_jti,
                    expires_at: f19_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f19_client),
                    audiences: [f19_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f19_client),
                    subject: OidcSubject.for(
                      fx19_user,
                      resource_type: "client",
                    ),
                    client_id: f19_client.client_id,
                  )
                  @base_browser_rp_credentials[f19_key] =
                    [f19_access, f19_session.issue_refresh_token!]
                end
                f19_access, f19_refresh = @base_browser_rp_credentials.fetch(f19_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f19_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f19_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f19_cookie_pairs, URI.parse("https://#{f19_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx19_user,
            host: fx19_host,
            session_public_id: fx19_token.public_id,
            resource_type: "client",
          ),
          host: fx19_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_36

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "consumed", transaction.reload.status
  end

  test "sign completion transport posts result body only to fixed base endpoint" do
    source = Rails.root.join("app/views/auth/shared/oidc_authorization_handoff.html.erb").read

    assert_includes source, 'id="oidc-authorization-handoff-form"'
    assert_includes source, 'method="post"'
    assert_includes source, "hidden_field_tag :authenticity_token, form_authenticity_token"
    assert_not_includes source, "return_to"
    assert_not_includes source, "result"
  end

  test "base completion controllers do not skip forgery protection" do
    [
      "app/controllers/base/app/verifications_controller.rb",
      "app/controllers/base/com/verifications_controller.rb",
      "app/controllers/base/org/verifications_controller.rb",
      "app/controllers/concerns/base_step_up_completion.rb",
    ].each do |path|
      assert_not_includes Rails.root.join(path).read, "skip_forgery_protection"
    end
  end

  test "app base completion retried with the same result keeps the original freshness event" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-retry-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_35 =
      begin
        fx20_host = host
        fx20_token = token
        fx20_user = user
        begin
          f20_cookie_pairs =
            begin
              f20_host = fx20_host
              f20_token = fx20_token
              f20_client = OidcClientRegistry.find!("base-app-ww")
              f20_key = [f20_client.client_id, f20_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f20_key] ||
                  (f20_token.currently_usable? &&
                    !(f20_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f20_token.device_session_id,
                      oidc_client_id: f20_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f20_key]
                  f20_token.rotate_refresh_token! unless f20_token.device_session_record.current_refresh_token_id
                  f20_now = Time.current
                  f20_session = ClientRpSession.create!(
                    client_token: f20_token, oidc_client_id: f20_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f20_now,
                    refresh_token_expires_at: f20_now + 10.minutes,
                  )
                  f20_access = AuthenticationTokenService.encode(
                    fx20_user,
                    host: f20_host,
                    resource_type: "client",
                    session_public_id: f20_token.public_id,
                    base_session_public_id: f20_token.public_id,
                    oidc_sid: f20_session.public_id,
                    oidc_jti: f20_session.oidc_jti,
                    expires_at: f20_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f20_client),
                    audiences: [f20_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f20_client),
                    subject: OidcSubject.for(
                      fx20_user,
                      resource_type: "client",
                    ),
                    client_id: f20_client.client_id,
                  )
                  @base_browser_rp_credentials[f20_key] = [f20_access, f20_session.issue_refresh_token!]
                end
                f20_access, f20_refresh = @base_browser_rp_credentials.fetch(f20_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f20_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f20_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f20_cookie_pairs, URI.parse("https://#{f20_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx20_user,
            host: fx20_host,
            session_public_id: fx20_token.public_id,
            resource_type: "client",
          ),
          host: fx20_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_35

    assert_response :see_other
    transaction =
      begin
        fv5059 = ClientStepUpCeremonyTransaction
        fv5058 = user
        fv5057 = token
        fv5059.where(
          actor_ref: fv5058.public_id,
          session_ref: fv5057.public_id,
        ).order(id: :desc).first!
      end
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now,
      verified_credential_ref: begin
        fv5056 = user
        fv5056.client_totp_credentials.find_by!(
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        ).public_id
      end,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    2.times do
      http_headers_34 =
        begin
          fx21_host = host
          fx21_token = token
          fx21_user = user
          begin
            f21_cookie_pairs =
              begin
                f21_host = fx21_host
                f21_token = fx21_token
                f21_client = OidcClientRegistry.find!("base-app-ww")
                f21_key = [f21_client.client_id, f21_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f21_key] ||
                    (f21_token.currently_usable? &&
                      !(f21_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f21_token.device_session_id,
                        oidc_client_id: f21_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f21_key]
                    f21_token.rotate_refresh_token! unless f21_token.device_session_record.current_refresh_token_id
                    f21_now = Time.current
                    f21_session = ClientRpSession.create!(
                      client_token: f21_token, oidc_client_id: f21_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f21_now,
                      refresh_token_expires_at: f21_now + 10.minutes,
                    )
                    f21_access = AuthenticationTokenService.encode(
                      fx21_user,
                      host: f21_host,
                      resource_type: "client",
                      session_public_id: f21_token.public_id,
                      base_session_public_id: f21_token.public_id,
                      oidc_sid: f21_session.public_id,
                      oidc_jti: f21_session.oidc_jti,
                      expires_at: f21_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f21_client),
                      audiences: [f21_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f21_client),
                      subject: OidcSubject.for(
                        fx21_user,
                        resource_type: "client",
                      ),
                      client_id: f21_client.client_id,
                    )
                    @base_browser_rp_credentials[f21_key] =
                      [f21_access, f21_session.issue_refresh_token!]
                  end
                  f21_access, f21_refresh = @base_browser_rp_credentials.fetch(f21_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f21_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f21_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f21_cookie_pairs, URI.parse("https://#{f21_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx21_user,
              host: fx21_host,
              session_public_id: fx21_token.public_id,
              resource_type: "client",
            ),
            host: fx21_host,
          )
        end
      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: http_headers_34

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri
      assert_equal transaction.reload.verified_at, token.reload.last_step_up_at
      assert_equal "consumed", transaction.status
    end
  end

  test "app base verification returns to the protected page without a new ceremony while freshness is valid" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-fresh-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_33 =
      begin
        fx22_host = host
        fx22_token = token
        fx22_user = user
        begin
          f22_cookie_pairs =
            begin
              f22_host = fx22_host
              f22_token = fx22_token
              f22_client = OidcClientRegistry.find!("base-app-ww")
              f22_key = [f22_client.client_id, f22_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f22_key] ||
                  (f22_token.currently_usable? &&
                    !(f22_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f22_token.device_session_id,
                      oidc_client_id: f22_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f22_key]
                  f22_token.rotate_refresh_token! unless f22_token.device_session_record.current_refresh_token_id
                  f22_now = Time.current
                  f22_session = ClientRpSession.create!(
                    client_token: f22_token, oidc_client_id: f22_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f22_now,
                    refresh_token_expires_at: f22_now + 10.minutes,
                  )
                  f22_access = AuthenticationTokenService.encode(
                    fx22_user,
                    host: f22_host,
                    resource_type: "client",
                    session_public_id: f22_token.public_id,
                    base_session_public_id: f22_token.public_id,
                    oidc_sid: f22_session.public_id,
                    oidc_jti: f22_session.oidc_jti,
                    expires_at: f22_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f22_client),
                    audiences: [f22_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f22_client),
                    subject: OidcSubject.for(
                      fx22_user,
                      resource_type: "client",
                    ),
                    client_id: f22_client.client_id,
                  )
                  @base_browser_rp_credentials[f22_key] = [f22_access, f22_session.issue_refresh_token!]
                end
                f22_access, f22_refresh = @base_browser_rp_credentials.fetch(f22_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f22_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f22_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f22_cookie_pairs, URI.parse("https://#{f22_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx22_user,
            host: fx22_host,
            session_public_id: fx22_token.public_id,
            resource_type: "client",
          ),
          host: fx22_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_33
    transaction =
      begin
        fv5055 = ClientStepUpCeremonyTransaction
        fv5054 = user
        fv5053 = token
        fv5055.where(
          actor_ref: fv5054.public_id,
          session_ref: fv5053.public_id,
        ).order(id: :desc).first!
      end
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now,
      verified_credential_ref: begin
        fv5052 = user
        fv5052.client_totp_credentials.find_by!(
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        ).public_id
      end,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    http_headers_32 =
      begin
        fx23_host = host
        fx23_token = token
        fx23_user = user
        begin
          f23_cookie_pairs =
            begin
              f23_host = fx23_host
              f23_token = fx23_token
              f23_client = OidcClientRegistry.find!("base-app-ww")
              f23_key = [f23_client.client_id, f23_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f23_key] ||
                  (f23_token.currently_usable? &&
                    !(f23_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f23_token.device_session_id,
                      oidc_client_id: f23_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f23_key]
                  f23_token.rotate_refresh_token! unless f23_token.device_session_record.current_refresh_token_id
                  f23_now = Time.current
                  f23_session = ClientRpSession.create!(
                    client_token: f23_token, oidc_client_id: f23_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f23_now,
                    refresh_token_expires_at: f23_now + 10.minutes,
                  )
                  f23_access = AuthenticationTokenService.encode(
                    fx23_user,
                    host: f23_host,
                    resource_type: "client",
                    session_public_id: f23_token.public_id,
                    base_session_public_id: f23_token.public_id,
                    oidc_sid: f23_session.public_id,
                    oidc_jti: f23_session.oidc_jti,
                    expires_at: f23_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f23_client),
                    audiences: [f23_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f23_client),
                    subject: OidcSubject.for(
                      fx23_user,
                      resource_type: "client",
                    ),
                    client_id: f23_client.client_id,
                  )
                  @base_browser_rp_credentials[f23_key] =
                    [f23_access, f23_session.issue_refresh_token!]
                end
                f23_access, f23_refresh = @base_browser_rp_credentials.fetch(f23_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f23_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f23_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f23_cookie_pairs, URI.parse("https://#{f23_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx23_user,
            host: fx23_host,
            session_public_id: fx23_token.public_id,
            resource_type: "client",
          ),
          host: fx23_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_32

    assert_response :see_other

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      http_headers_31 =
        begin
          fx24_host = host
          fx24_token = token
          fx24_user = user
          begin
            f24_cookie_pairs =
              begin
                f24_host = fx24_host
                f24_token = fx24_token
                f24_client = OidcClientRegistry.find!("base-app-ww")
                f24_key = [f24_client.client_id, f24_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f24_key] ||
                    (f24_token.currently_usable? &&
                      !(f24_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f24_token.device_session_id,
                        oidc_client_id: f24_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f24_key]
                    f24_token.rotate_refresh_token! unless f24_token.device_session_record.current_refresh_token_id
                    f24_now = Time.current
                    f24_session = ClientRpSession.create!(
                      client_token: f24_token, oidc_client_id: f24_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f24_now,
                      refresh_token_expires_at: f24_now + 10.minutes,
                    )
                    f24_access = AuthenticationTokenService.encode(
                      fx24_user,
                      host: f24_host,
                      resource_type: "client",
                      session_public_id: f24_token.public_id,
                      base_session_public_id: f24_token.public_id,
                      oidc_sid: f24_session.public_id,
                      oidc_jti: f24_session.oidc_jti,
                      expires_at: f24_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f24_client),
                      audiences: [f24_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f24_client),
                      subject: OidcSubject.for(
                        fx24_user,
                        resource_type: "client",
                      ),
                      client_id: f24_client.client_id,
                    )
                    @base_browser_rp_credentials[f24_key] =
                      [f24_access, f24_session.issue_refresh_token!]
                  end
                  f24_access, f24_refresh = @base_browser_rp_credentials.fetch(f24_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f24_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f24_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f24_cookie_pairs, URI.parse("https://#{f24_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx24_user,
              host: fx24_host,
              session_public_id: fx24_token.public_id,
              resource_type: "client",
            ),
            host: fx24_host,
          )
        end
      get base_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: http_headers_31

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri

      http_headers_30 =
        begin
          fx25_host = host
          fx25_token = token
          fx25_user = user
          begin
            f25_cookie_pairs =
              begin
                f25_host = fx25_host
                f25_token = fx25_token
                f25_client = OidcClientRegistry.find!("base-app-ww")
                f25_key = [f25_client.client_id, f25_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f25_key] ||
                    (f25_token.currently_usable? &&
                      !(f25_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f25_token.device_session_id,
                        oidc_client_id: f25_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f25_key]
                    f25_token.rotate_refresh_token! unless f25_token.device_session_record.current_refresh_token_id
                    f25_now = Time.current
                    f25_session = ClientRpSession.create!(
                      client_token: f25_token, oidc_client_id: f25_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f25_now,
                      refresh_token_expires_at: f25_now + 10.minutes,
                    )
                    f25_access = AuthenticationTokenService.encode(
                      fx25_user,
                      host: f25_host,
                      resource_type: "client",
                      session_public_id: f25_token.public_id,
                      base_session_public_id: f25_token.public_id,
                      oidc_sid: f25_session.public_id,
                      oidc_jti: f25_session.oidc_jti,
                      expires_at: f25_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f25_client),
                      audiences: [f25_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f25_client),
                      subject: OidcSubject.for(
                        fx25_user,
                        resource_type: "client",
                      ),
                      client_id: f25_client.client_id,
                    )
                    @base_browser_rp_credentials[f25_key] = [f25_access, f25_session.issue_refresh_token!]
                  end
                  f25_access, f25_refresh = @base_browser_rp_credentials.fetch(f25_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f25_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f25_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f25_cookie_pairs, URI.parse("https://#{f25_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx25_user,
              host: fx25_host,
              session_public_id: fx25_token.public_id,
              resource_type: "client",
            ),
            host: fx25_host,
          )
        end
      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: "settings_email", pt: pt }, headers: http_headers_30

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri
    end
  end

  test "app base completion refuses a result that was not issued for the transaction" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-foreign-result-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_29 =
      begin
        fx26_host = host
        fx26_token = token
        fx26_user = user
        begin
          f26_cookie_pairs =
            begin
              f26_host = fx26_host
              f26_token = fx26_token
              f26_client = OidcClientRegistry.find!("base-app-ww")
              f26_key = [f26_client.client_id, f26_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f26_key] ||
                  (f26_token.currently_usable? &&
                    !(f26_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f26_token.device_session_id,
                      oidc_client_id: f26_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f26_key]
                  f26_token.rotate_refresh_token! unless f26_token.device_session_record.current_refresh_token_id
                  f26_now = Time.current
                  f26_session = ClientRpSession.create!(
                    client_token: f26_token, oidc_client_id: f26_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f26_now,
                    refresh_token_expires_at: f26_now + 10.minutes,
                  )
                  f26_access = AuthenticationTokenService.encode(
                    fx26_user,
                    host: f26_host,
                    resource_type: "client",
                    session_public_id: f26_token.public_id,
                    base_session_public_id: f26_token.public_id,
                    oidc_sid: f26_session.public_id,
                    oidc_jti: f26_session.oidc_jti,
                    expires_at: f26_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f26_client),
                    audiences: [f26_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f26_client),
                    subject: OidcSubject.for(
                      fx26_user,
                      resource_type: "client",
                    ),
                    client_id: f26_client.client_id,
                  )
                  @base_browser_rp_credentials[f26_key] = [f26_access, f26_session.issue_refresh_token!]
                end
                f26_access, f26_refresh = @base_browser_rp_credentials.fetch(f26_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f26_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f26_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f26_cookie_pairs, URI.parse("https://#{f26_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx26_user,
            host: fx26_host,
            session_public_id: fx26_token.public_id,
            resource_type: "client",
          ),
          host: fx26_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_29

    assert_response :see_other
    transaction =
      begin
        fv5051 = ClientStepUpCeremonyTransaction
        fv5050 = user
        fv5049 = token
        fv5051.where(
          actor_ref: fv5050.public_id,
          session_ref: fv5049.public_id,
        ).order(id: :desc).first!
      end
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now,
      verified_credential_ref: begin
        fv5048 = user
        fv5048.client_totp_credentials.find_by!(
          user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        ).public_id
      end,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    http_headers_28 =
      begin
        fx27_host = host
        fx27_token = token
        fx27_user = user
        begin
          f27_cookie_pairs =
            begin
              f27_host = fx27_host
              f27_token = fx27_token
              f27_client = OidcClientRegistry.find!("base-app-ww")
              f27_key = [f27_client.client_id, f27_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f27_key] ||
                  (f27_token.currently_usable? &&
                    !(f27_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f27_token.device_session_id,
                      oidc_client_id: f27_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f27_key]
                  f27_token.rotate_refresh_token! unless f27_token.device_session_record.current_refresh_token_id
                  f27_now = Time.current
                  f27_session = ClientRpSession.create!(
                    client_token: f27_token, oidc_client_id: f27_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f27_now,
                    refresh_token_expires_at: f27_now + 10.minutes,
                  )
                  f27_access = AuthenticationTokenService.encode(
                    fx27_user,
                    host: f27_host,
                    resource_type: "client",
                    session_public_id: f27_token.public_id,
                    base_session_public_id: f27_token.public_id,
                    oidc_sid: f27_session.public_id,
                    oidc_jti: f27_session.oidc_jti,
                    expires_at: f27_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f27_client),
                    audiences: [f27_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f27_client),
                    subject: OidcSubject.for(
                      fx27_user,
                      resource_type: "client",
                    ),
                    client_id: f27_client.client_id,
                  )
                  @base_browser_rp_credentials[f27_key] =
                    [f27_access, f27_session.issue_refresh_token!]
                end
                f27_access, f27_refresh = @base_browser_rp_credentials.fetch(f27_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f27_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f27_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f27_cookie_pairs, URI.parse("https://#{f27_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx27_user,
            host: fx27_host,
            session_public_id: fx27_token.public_id,
            resource_type: "client",
          ),
          host: fx27_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: "#{result.reference}x" },
         headers: http_headers_28

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil token.reload.last_step_up_at
    assert_equal "verified", transaction.reload.status
  end

  test "app base cancellation closes the pending transaction and blocks a later completion" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_27 =
      begin
        fx28_host = host
        fx28_token = token
        fx28_user = user
        begin
          f28_cookie_pairs =
            begin
              f28_host = fx28_host
              f28_token = fx28_token
              f28_client = OidcClientRegistry.find!("base-app-ww")
              f28_key = [f28_client.client_id, f28_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f28_key] ||
                  (f28_token.currently_usable? &&
                    !(f28_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f28_token.device_session_id,
                      oidc_client_id: f28_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f28_key]
                  f28_token.rotate_refresh_token! unless f28_token.device_session_record.current_refresh_token_id
                  f28_now = Time.current
                  f28_session = ClientRpSession.create!(
                    client_token: f28_token, oidc_client_id: f28_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f28_now,
                    refresh_token_expires_at: f28_now + 10.minutes,
                  )
                  f28_access = AuthenticationTokenService.encode(
                    fx28_user,
                    host: f28_host,
                    resource_type: "client",
                    session_public_id: f28_token.public_id,
                    base_session_public_id: f28_token.public_id,
                    oidc_sid: f28_session.public_id,
                    oidc_jti: f28_session.oidc_jti,
                    expires_at: f28_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f28_client),
                    audiences: [f28_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f28_client),
                    subject: OidcSubject.for(
                      fx28_user,
                      resource_type: "client",
                    ),
                    client_id: f28_client.client_id,
                  )
                  @base_browser_rp_credentials[f28_key] = [f28_access, f28_session.issue_refresh_token!]
                end
                f28_access, f28_refresh = @base_browser_rp_credentials.fetch(f28_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f28_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f28_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f28_cookie_pairs, URI.parse("https://#{f28_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx28_user,
            host: fx28_host,
            session_public_id: fx28_token.public_id,
            resource_type: "client",
          ),
          host: fx28_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_27

    assert_response :see_other
    transaction =
      begin
        fv5047 = ClientStepUpCeremonyTransaction
        fv5046 = user
        fv5045 = token
        fv5047.where(
          actor_ref: fv5046.public_id,
          session_ref: fv5045.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5043 = transaction
        fv5044 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5043)
        {

          cancellation_ref: fv5044.reference,
          transaction_ref: fv5043.transaction_id,
        }
      end

    http_headers_26 =
      begin
        fx29_host = host
        fx29_token = token
        fx29_user = user
        begin
          f29_cookie_pairs =
            begin
              f29_host = fx29_host
              f29_token = fx29_token
              f29_client = OidcClientRegistry.find!("base-app-ww")
              f29_key = [f29_client.client_id, f29_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f29_key] ||
                  (f29_token.currently_usable? &&
                    !(f29_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f29_token.device_session_id,
                      oidc_client_id: f29_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f29_key]
                  f29_token.rotate_refresh_token! unless f29_token.device_session_record.current_refresh_token_id
                  f29_now = Time.current
                  f29_session = ClientRpSession.create!(
                    client_token: f29_token, oidc_client_id: f29_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f29_now,
                    refresh_token_expires_at: f29_now + 10.minutes,
                  )
                  f29_access = AuthenticationTokenService.encode(
                    fx29_user,
                    host: f29_host,
                    resource_type: "client",
                    session_public_id: f29_token.public_id,
                    base_session_public_id: f29_token.public_id,
                    oidc_sid: f29_session.public_id,
                    oidc_jti: f29_session.oidc_jti,
                    expires_at: f29_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f29_client),
                    audiences: [f29_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f29_client),
                    subject: OidcSubject.for(
                      fx29_user,
                      resource_type: "client",
                    ),
                    client_id: f29_client.client_id,
                  )
                  @base_browser_rp_credentials[f29_key] =
                    [f29_access, f29_session.issue_refresh_token!]
                end
                f29_access, f29_refresh = @base_browser_rp_credentials.fetch(f29_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f29_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f29_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f29_cookie_pairs, URI.parse("https://#{f29_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx29_user,
            host: fx29_host,
            session_public_id: fx29_token.public_id,
            resource_type: "client",
          ),
          host: fx29_host,
        )
      end
    post base_app_verification_cancellation_url(ri: "jp", host: host),
         headers: http_headers_26,
         params: cancellation.merge(scope: "settings_email", return_to: return_to)

    assert_response :see_other
    assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_predicate transaction.reload, :canceled?
    assert_not_nil transaction.canceled_at
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at

    http_headers_25 =
      begin
        fx30_host = host
        fx30_token = token
        fx30_user = user
        begin
          f30_cookie_pairs =
            begin
              f30_host = fx30_host
              f30_token = fx30_token
              f30_client = OidcClientRegistry.find!("base-app-ww")
              f30_key = [f30_client.client_id, f30_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f30_key] ||
                  (f30_token.currently_usable? &&
                    !(f30_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f30_token.device_session_id,
                      oidc_client_id: f30_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f30_key]
                  f30_token.rotate_refresh_token! unless f30_token.device_session_record.current_refresh_token_id
                  f30_now = Time.current
                  f30_session = ClientRpSession.create!(
                    client_token: f30_token, oidc_client_id: f30_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f30_now,
                    refresh_token_expires_at: f30_now + 10.minutes,
                  )
                  f30_access = AuthenticationTokenService.encode(
                    fx30_user,
                    host: f30_host,
                    resource_type: "client",
                    session_public_id: f30_token.public_id,
                    base_session_public_id: f30_token.public_id,
                    oidc_sid: f30_session.public_id,
                    oidc_jti: f30_session.oidc_jti,
                    expires_at: f30_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f30_client),
                    audiences: [f30_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f30_client),
                    subject: OidcSubject.for(
                      fx30_user,
                      resource_type: "client",
                    ),
                    client_id: f30_client.client_id,
                  )
                  @base_browser_rp_credentials[f30_key] =
                    [f30_access, f30_session.issue_refresh_token!]
                end
                f30_access, f30_refresh = @base_browser_rp_credentials.fetch(f30_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f30_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f30_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f30_cookie_pairs, URI.parse("https://#{f30_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx30_user,
            host: fx30_host,
            session_public_id: fx30_token.public_id,
            resource_type: "client",
          ),
          host: fx30_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: "opaque-result" },
         headers: http_headers_25

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_predicate transaction.reload, :canceled?
  end

  test "app base cancellation repeated with the same handoff is idempotent" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-twice-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    http_headers_24 =
      begin
        fx31_host = host
        fx31_token = token
        fx31_user = user
        begin
          f31_cookie_pairs =
            begin
              f31_host = fx31_host
              f31_token = fx31_token
              f31_client = OidcClientRegistry.find!("base-app-ww")
              f31_key = [f31_client.client_id, f31_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f31_key] ||
                  (f31_token.currently_usable? &&
                    !(f31_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f31_token.device_session_id,
                      oidc_client_id: f31_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f31_key]
                  f31_token.rotate_refresh_token! unless f31_token.device_session_record.current_refresh_token_id
                  f31_now = Time.current
                  f31_session = ClientRpSession.create!(
                    client_token: f31_token, oidc_client_id: f31_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f31_now,
                    refresh_token_expires_at: f31_now + 10.minutes,
                  )
                  f31_access = AuthenticationTokenService.encode(
                    fx31_user,
                    host: f31_host,
                    resource_type: "client",
                    session_public_id: f31_token.public_id,
                    base_session_public_id: f31_token.public_id,
                    oidc_sid: f31_session.public_id,
                    oidc_jti: f31_session.oidc_jti,
                    expires_at: f31_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f31_client),
                    audiences: [f31_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f31_client),
                    subject: OidcSubject.for(
                      fx31_user,
                      resource_type: "client",
                    ),
                    client_id: f31_client.client_id,
                  )
                  @base_browser_rp_credentials[f31_key] = [f31_access, f31_session.issue_refresh_token!]
                end
                f31_access, f31_refresh = @base_browser_rp_credentials.fetch(f31_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f31_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f31_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f31_cookie_pairs, URI.parse("https://#{f31_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx31_user,
            host: fx31_host,
            session_public_id: fx31_token.public_id,
            resource_type: "client",
          ),
          host: fx31_host,
        )
      end
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_24

    assert_response :see_other
    transaction =
      begin
        fv5042 = ClientStepUpCeremonyTransaction
        fv5041 = user
        fv5040 = token
        fv5042.where(
          actor_ref: fv5041.public_id,
          session_ref: fv5040.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5038 = transaction
        fv5039 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5038)
        {

          cancellation_ref: fv5039.reference,
          transaction_ref: fv5038.transaction_id,
        }
      end

    http_headers_23 =
      begin
        fx32_host = host
        fx32_token = token
        fx32_user = user
        begin
          f32_cookie_pairs =
            begin
              f32_host = fx32_host
              f32_token = fx32_token
              f32_client = OidcClientRegistry.find!("base-app-ww")
              f32_key = [f32_client.client_id, f32_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f32_key] ||
                  (f32_token.currently_usable? &&
                    !(f32_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f32_token.device_session_id,
                      oidc_client_id: f32_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f32_key]
                  f32_token.rotate_refresh_token! unless f32_token.device_session_record.current_refresh_token_id
                  f32_now = Time.current
                  f32_session = ClientRpSession.create!(
                    client_token: f32_token, oidc_client_id: f32_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f32_now,
                    refresh_token_expires_at: f32_now + 10.minutes,
                  )
                  f32_access = AuthenticationTokenService.encode(
                    fx32_user,
                    host: f32_host,
                    resource_type: "client",
                    session_public_id: f32_token.public_id,
                    base_session_public_id: f32_token.public_id,
                    oidc_sid: f32_session.public_id,
                    oidc_jti: f32_session.oidc_jti,
                    expires_at: f32_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f32_client),
                    audiences: [f32_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f32_client),
                    subject: OidcSubject.for(
                      fx32_user,
                      resource_type: "client",
                    ),
                    client_id: f32_client.client_id,
                  )
                  @base_browser_rp_credentials[f32_key] = [f32_access, f32_session.issue_refresh_token!]
                end
                f32_access, f32_refresh = @base_browser_rp_credentials.fetch(f32_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f32_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f32_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f32_cookie_pairs, URI.parse("https://#{f32_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx32_user,
            host: fx32_host,
            session_public_id: fx32_token.public_id,
            resource_type: "client",
          ),
          host: fx32_host,
        )
      end
    post base_app_verification_cancellation_url(ri: "jp", host: host),
         params: cancellation, headers: http_headers_23

    assert_response :see_other
    canceled_at = transaction.reload.canceled_at

    http_headers_22 =
      begin
        fx33_host = host
        fx33_token = token
        fx33_user = user
        begin
          f33_cookie_pairs =
            begin
              f33_host = fx33_host
              f33_token = fx33_token
              f33_client = OidcClientRegistry.find!("base-app-ww")
              f33_key = [f33_client.client_id, f33_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f33_key] ||
                  (f33_token.currently_usable? &&
                    !(f33_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f33_token.device_session_id,
                      oidc_client_id: f33_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f33_key]
                  f33_token.rotate_refresh_token! unless f33_token.device_session_record.current_refresh_token_id
                  f33_now = Time.current
                  f33_session = ClientRpSession.create!(
                    client_token: f33_token, oidc_client_id: f33_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f33_now,
                    refresh_token_expires_at: f33_now + 10.minutes,
                  )
                  f33_access = AuthenticationTokenService.encode(
                    fx33_user,
                    host: f33_host,
                    resource_type: "client",
                    session_public_id: f33_token.public_id,
                    base_session_public_id: f33_token.public_id,
                    oidc_sid: f33_session.public_id,
                    oidc_jti: f33_session.oidc_jti,
                    expires_at: f33_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f33_client),
                    audiences: [f33_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f33_client),
                    subject: OidcSubject.for(
                      fx33_user,
                      resource_type: "client",
                    ),
                    client_id: f33_client.client_id,
                  )
                  @base_browser_rp_credentials[f33_key] = [f33_access, f33_session.issue_refresh_token!]
                end
                f33_access, f33_refresh = @base_browser_rp_credentials.fetch(f33_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f33_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f33_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f33_cookie_pairs, URI.parse("https://#{f33_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx33_user,
            host: fx33_host,
            session_public_id: fx33_token.public_id,
            resource_type: "client",
          ),
          host: fx33_host,
        )
      end
    post base_app_verification_cancellation_url(ri: "jp", host: host),
         params: cancellation, headers: http_headers_22

    assert_response :see_other
    assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal canceled_at, transaction.reload.canceled_at
    assert_predicate transaction, :canceled?
  end

  test "app base cancellation without any started ceremony is refused" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      http_headers_21 =
        begin
          fx34_host = host
          fx34_token = token
          fx34_user = user
          begin
            f34_cookie_pairs =
              begin
                f34_host = fx34_host
                f34_token = fx34_token
                f34_client = OidcClientRegistry.find!("base-app-ww")
                f34_key = [f34_client.client_id, f34_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f34_key] ||
                    (f34_token.currently_usable? &&
                      !(f34_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f34_token.device_session_id,
                        oidc_client_id: f34_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f34_key]
                    f34_token.rotate_refresh_token! unless f34_token.device_session_record.current_refresh_token_id
                    f34_now = Time.current
                    f34_session = ClientRpSession.create!(
                      client_token: f34_token, oidc_client_id: f34_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f34_now,
                      refresh_token_expires_at: f34_now + 10.minutes,
                    )
                    f34_access = AuthenticationTokenService.encode(
                      fx34_user,
                      host: f34_host,
                      resource_type: "client",
                      session_public_id: f34_token.public_id,
                      base_session_public_id: f34_token.public_id,
                      oidc_sid: f34_session.public_id,
                      oidc_jti: f34_session.oidc_jti,
                      expires_at: f34_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f34_client),
                      audiences: [f34_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f34_client),
                      subject: OidcSubject.for(
                        fx34_user,
                        resource_type: "client",
                      ),
                      client_id: f34_client.client_id,
                    )
                    @base_browser_rp_credentials[f34_key] =
                      [f34_access, f34_session.issue_refresh_token!]
                  end
                  f34_access, f34_refresh = @base_browser_rp_credentials.fetch(f34_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f34_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f34_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f34_cookie_pairs, URI.parse("https://#{f34_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx34_user,
              host: fx34_host,
              session_public_id: fx34_token.public_id,
              resource_type: "client",
            ),
            host: fx34_host,
          )
        end
      post base_app_verification_cancellation_url(ri: "jp", host: host),
           headers: http_headers_21
    end

    assert_response :bad_request
    assert_nil response.headers["Location"]
  end

  # The cancellation destination is Base's own entry point, resolved on the server. The posted
  # return_to (which Auth used to fill with the success continuation) is not an authority, whatever
  # it contains.
  test "app base cancellation ignores every posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-dest-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: session_nonce_for(token),
    )
    [
      base_app_identity_emails_path(ri: "jp"),
      "https://evil.example/steal",
      "//evil.example/steal",
      "/%2F%2Fevil.example",
      "/identity\x00/emails",
      "/\\evil.example",
      "",
    ].each do |return_to|
      http_headers_20 =
        begin
          fx35_host = host
          fx35_token = token
          fx35_user = user
          begin
            f35_cookie_pairs =
              begin
                f35_host = fx35_host
                f35_token = fx35_token
                f35_client = OidcClientRegistry.find!("base-app-ww")
                f35_key = [f35_client.client_id, f35_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f35_key] ||
                    (f35_token.currently_usable? &&
                      !(f35_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f35_token.device_session_id,
                        oidc_client_id: f35_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f35_key]
                    f35_token.rotate_refresh_token! unless f35_token.device_session_record.current_refresh_token_id
                    f35_now = Time.current
                    f35_session = ClientRpSession.create!(
                      client_token: f35_token, oidc_client_id: f35_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f35_now,
                      refresh_token_expires_at: f35_now + 10.minutes,
                    )
                    f35_access = AuthenticationTokenService.encode(
                      fx35_user,
                      host: f35_host,
                      resource_type: "client",
                      session_public_id: f35_token.public_id,
                      base_session_public_id: f35_token.public_id,
                      oidc_sid: f35_session.public_id,
                      oidc_jti: f35_session.oidc_jti,
                      expires_at: f35_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f35_client),
                      audiences: [f35_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f35_client),
                      subject: OidcSubject.for(
                        fx35_user,
                        resource_type: "client",
                      ),
                      client_id: f35_client.client_id,
                    )
                    @base_browser_rp_credentials[f35_key] = [f35_access, f35_session.issue_refresh_token!]
                  end
                  f35_access, f35_refresh = @base_browser_rp_credentials.fetch(f35_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f35_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f35_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f35_cookie_pairs, URI.parse("https://#{f35_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx35_user,
              host: fx35_host,
              session_public_id: fx35_token.public_id,
              resource_type: "client",
            ),
            host: fx35_host,
          )
        end
      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: "settings_email", pt: pt }, headers: http_headers_20

      assert_response :see_other
      transaction =
        begin
          fv5037 = ClientStepUpCeremonyTransaction
          fv5036 = user
          fv5035 = token
          fv5037.where(
            actor_ref: fv5036.public_id,
            session_ref: fv5035.public_id,
          ).order(id: :desc).first!
        end
      cancellation =
        begin
          fv5033 = transaction
          fv5034 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5033)
          {

            cancellation_ref: fv5034.reference,
            transaction_ref: fv5033.transaction_id,
          }
        end

      post base_app_verification_cancellation_url(ri: "jp", host: host),
           headers: begin
             fx36_host = host
             fx36_token = token
             fx36_user = user
             begin
               f36_cookie_pairs =
                 begin
                   f36_host = fx36_host
                   f36_token = fx36_token
                   f36_client = OidcClientRegistry.find!("base-app-ww")
                   f36_key = [f36_client.client_id, f36_token.public_id]
                   @base_browser_rp_credentials ||= {}
                   if @base_browser_rp_credentials[f36_key] ||
                       (f36_token.currently_usable? &&
                         !(f36_token.device_session_id && ClientRpSession.exists?(
                           device_session_id: f36_token.device_session_id,
                           oidc_client_id: f36_client.client_id,
                           revoked_at: nil,
                         )))
                     unless @base_browser_rp_credentials[f36_key]
                       f36_token.rotate_refresh_token! unless f36_token.device_session_record.current_refresh_token_id
                       f36_now = Time.current
                       f36_session = ClientRpSession.create!(
                         client_token: f36_token, oidc_client_id: f36_client.client_id, oidc_scope: "openid profile",
                         oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f36_now,
                         refresh_token_expires_at: f36_now + 10.minutes,
                       )
                       f36_access = AuthenticationTokenService.encode(
                         fx36_user,
                         host: f36_host,
                         resource_type: "client",
                         session_public_id: f36_token.public_id,
                         base_session_public_id: f36_token.public_id,
                         oidc_sid: f36_session.public_id,
                         oidc_jti: f36_session.oidc_jti,
                         expires_at: f36_now + 10.minutes,
                         scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(f36_client),
                         audiences: [f36_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f36_client),
                         subject: OidcSubject.for(
                           fx36_user,
                           resource_type: "client",
                         ),
                         client_id: f36_client.client_id,
                       )
                       @base_browser_rp_credentials[f36_key] =
                         [f36_access, f36_session.issue_refresh_token!]
                     end
                     f36_access, f36_refresh = @base_browser_rp_credentials.fetch(f36_key)
                     [
                       "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f36_access)}",
                       "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f36_refresh)}",
                     ]
                   else
                     []
                   end
                 end
               cookies.merge(f36_cookie_pairs, URI.parse("https://#{f36_host}/"))
             end
             bearer_headers(
               jwt_access_token_for(
                 fx36_user,
                 host: fx36_host,
                 session_public_id: fx36_token.public_id,
                 resource_type: "client",
               ),
               host: fx36_host,
             )
           end.merge("Referer" => "https://#{host}/identity/emails"),
           params: cancellation.merge(scope: "settings_email", return_to: return_to)

      assert_response :see_other
      assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri, return_to
      assert_equal host, URI.parse(response.location).host
    end
  end

  test "app base completion rejects wrong session result" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    other_token = create_client_token!(user)
    user.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: other_token.public_id,
    )
    http_headers_19 =
      begin
        fx37_host = host
        fx37_token = other_token
        fx37_user = user
        begin
          f37_cookie_pairs =
            begin
              f37_host = fx37_host
              f37_token = fx37_token
              f37_client = OidcClientRegistry.find!("base-app-ww")
              f37_key = [f37_client.client_id, f37_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f37_key] ||
                  (f37_token.currently_usable? &&
                    !(f37_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f37_token.device_session_id,
                      oidc_client_id: f37_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f37_key]
                  f37_token.rotate_refresh_token! unless f37_token.device_session_record.current_refresh_token_id
                  f37_now = Time.current
                  f37_session = ClientRpSession.create!(
                    client_token: f37_token,
                    oidc_client_id: f37_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: f37_now,
                    refresh_token_expires_at: f37_now + 10.minutes,
                  )
                  f37_access = AuthenticationTokenService.encode(
                    fx37_user,
                    host: f37_host,
                    resource_type: "client",
                    session_public_id: f37_token.public_id,
                    base_session_public_id: f37_token.public_id,
                    oidc_sid: f37_session.public_id,
                    oidc_jti: f37_session.oidc_jti,
                    expires_at: f37_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f37_client),
                    audiences: [f37_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f37_client),
                    subject: OidcSubject.for(
                      fx37_user,
                      resource_type: "client",
                    ),
                    client_id: f37_client.client_id,
                  )
                  @base_browser_rp_credentials[f37_key] =
                    [f37_access, f37_session.issue_refresh_token!]
                end
                f37_access, f37_refresh = @base_browser_rp_credentials.fetch(f37_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f37_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f37_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(
            f37_cookie_pairs,
            URI.parse("https://#{f37_host}/"),
          )
        end
        bearer_headers(
          jwt_access_token_for(
            fx37_user,
            host: fx37_host,
            session_public_id: fx37_token.public_id,
            resource_type: "client",
          ),
          host: fx37_host,
        )
      end
    post base_app_verification_url(ri: "jp", host:), params: { scope: "settings_email", pt: },
                                                     headers: http_headers_19
    transaction = ClientStepUpCeremonyTransaction.find_by!(
      actor_ref: user.public_id, session_ref: other_token.public_id,
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: "test-passkey",
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = ClientAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: other_token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)

    http_headers_18 =
      begin
        fx38_host = host
        fx38_token = token
        fx38_user = user
        begin
          f38_cookie_pairs =
            begin
              f38_host = fx38_host
              f38_token = fx38_token
              f38_client = OidcClientRegistry.find!("base-app-ww")
              f38_key = [f38_client.client_id, f38_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f38_key] ||
                  (f38_token.currently_usable? &&
                    !(f38_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f38_token.device_session_id,
                      oidc_client_id: f38_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f38_key]
                  f38_token.rotate_refresh_token! unless f38_token.device_session_record.current_refresh_token_id
                  f38_now = Time.current
                  f38_session = ClientRpSession.create!(
                    client_token: f38_token, oidc_client_id: f38_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f38_now,
                    refresh_token_expires_at: f38_now + 10.minutes,
                  )
                  f38_access = AuthenticationTokenService.encode(
                    fx38_user,
                    host: f38_host,
                    resource_type: "client",
                    session_public_id: f38_token.public_id,
                    base_session_public_id: f38_token.public_id,
                    oidc_sid: f38_session.public_id,
                    oidc_jti: f38_session.oidc_jti,
                    expires_at: f38_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f38_client),
                    audiences: [f38_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f38_client),
                    subject: OidcSubject.for(
                      fx38_user,
                      resource_type: "client",
                    ),
                    client_id: f38_client.client_id,
                  )
                  @base_browser_rp_credentials[f38_key] =
                    [f38_access, f38_session.issue_refresh_token!]
                end
                f38_access, f38_refresh = @base_browser_rp_credentials.fetch(f38_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f38_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f38_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f38_cookie_pairs, URI.parse("https://#{f38_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx38_user,
            host: fx38_host,
            session_public_id: fx38_token.public_id,
            resource_type: "client",
          ),
          host: fx38_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_18

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_not_predicate transaction.reload, :consumed?
  end

  test "app base completion rejects a result whose payload is not a JSON object" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    http_headers_17 =
      begin
        fx39_host = host
        fx39_token = token
        fx39_user = user
        begin
          f39_cookie_pairs =
            begin
              f39_host = fx39_host
              f39_token = fx39_token
              f39_client = OidcClientRegistry.find!("base-app-ww")
              f39_key = [f39_client.client_id, f39_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f39_key] ||
                  (f39_token.currently_usable? &&
                    !(f39_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f39_token.device_session_id,
                      oidc_client_id: f39_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f39_key]
                  f39_token.rotate_refresh_token! unless f39_token.device_session_record.current_refresh_token_id
                  f39_now = Time.current
                  f39_session = ClientRpSession.create!(
                    client_token: f39_token, oidc_client_id: f39_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f39_now,
                    refresh_token_expires_at: f39_now + 10.minutes,
                  )
                  f39_access = AuthenticationTokenService.encode(
                    fx39_user,
                    host: f39_host,
                    resource_type: "client",
                    session_public_id: f39_token.public_id,
                    base_session_public_id: f39_token.public_id,
                    oidc_sid: f39_session.public_id,
                    oidc_jti: f39_session.oidc_jti,
                    expires_at: f39_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f39_client),
                    audiences: [f39_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f39_client),
                    subject: OidcSubject.for(
                      fx39_user,
                      resource_type: "client",
                    ),
                    client_id: f39_client.client_id,
                  )
                  @base_browser_rp_credentials[f39_key] =
                    [f39_access, f39_session.issue_refresh_token!]
                end
                f39_access, f39_refresh = @base_browser_rp_credentials.fetch(f39_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f39_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f39_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f39_cookie_pairs, URI.parse("https://#{f39_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx39_user,
            host: fx39_host,
            session_public_id: fx39_token.public_id,
            resource_type: "client",
          ),
          host: fx39_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: "missing", result_ref: "[1]" },
         headers: http_headers_17

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
  end

  test "app base completion rejects an unsigned result before consuming its transaction" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: base_app_identity_emails_path(ri: "jp"),
    )
    http_headers_16 =
      begin
        fx40_host = host
        fx40_token = token
        fx40_user = user
        begin
          f40_cookie_pairs =
            begin
              f40_host = fx40_host
              f40_token = fx40_token
              f40_client = OidcClientRegistry.find!("base-app-ww")
              f40_key = [f40_client.client_id, f40_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f40_key] ||
                  (f40_token.currently_usable? &&
                    !(f40_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: f40_token.device_session_id,
                      oidc_client_id: f40_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f40_key]
                  f40_token.rotate_refresh_token! unless f40_token.device_session_record.current_refresh_token_id
                  f40_now = Time.current
                  f40_session = ClientRpSession.create!(
                    client_token: f40_token, oidc_client_id: f40_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f40_now,
                    refresh_token_expires_at: f40_now + 10.minutes,
                  )
                  f40_access = AuthenticationTokenService.encode(
                    fx40_user,
                    host: f40_host,
                    resource_type: "client",
                    session_public_id: f40_token.public_id,
                    base_session_public_id: f40_token.public_id,
                    oidc_sid: f40_session.public_id,
                    oidc_jti: f40_session.oidc_jti,
                    expires_at: f40_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f40_client),
                    audiences: [f40_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f40_client),
                    subject: OidcSubject.for(
                      fx40_user,
                      resource_type: "client",
                    ),
                    client_id: f40_client.client_id,
                  )
                  @base_browser_rp_credentials[f40_key] =
                    [f40_access, f40_session.issue_refresh_token!]
                end
                f40_access, f40_refresh = @base_browser_rp_credentials.fetch(f40_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f40_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f40_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f40_cookie_pairs, URI.parse("https://#{f40_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx40_user,
            host: fx40_host,
            session_public_id: fx40_token.public_id,
            resource_type: "client",
          ),
          host: fx40_host,
        )
      end
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: issuance.transaction.transaction_id, result_ref: "forged-result" },
         headers: http_headers_16

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "app base verification intent rejects arbitrary scope" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app",
                                               session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      http_headers_15 =
        begin
          fx41_host = host
          fx41_token = token
          fx41_user = user
          begin
            f41_cookie_pairs =
              begin
                f41_host = fx41_host
                f41_token = fx41_token
                f41_client = OidcClientRegistry.find!("base-app-ww")
                f41_key = [f41_client.client_id, f41_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f41_key] ||
                    (f41_token.currently_usable? &&
                      !(f41_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f41_token.device_session_id,
                        oidc_client_id: f41_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f41_key]
                    f41_token.rotate_refresh_token! unless f41_token.device_session_record.current_refresh_token_id
                    f41_now = Time.current
                    f41_session = ClientRpSession.create!(
                      client_token: f41_token, oidc_client_id: f41_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f41_now,
                      refresh_token_expires_at: f41_now + 10.minutes,
                    )
                    f41_access = AuthenticationTokenService.encode(
                      fx41_user,
                      host: f41_host,
                      resource_type: "client",
                      session_public_id: f41_token.public_id,
                      base_session_public_id: f41_token.public_id,
                      oidc_sid: f41_session.public_id,
                      oidc_jti: f41_session.oidc_jti,
                      expires_at: f41_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f41_client),
                      audiences: [f41_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f41_client),
                      subject: OidcSubject.for(
                        fx41_user,
                        resource_type: "client",
                      ),
                      client_id: f41_client.client_id,
                    )
                    @base_browser_rp_credentials[f41_key] =
                      [f41_access, f41_session.issue_refresh_token!]
                  end
                  f41_access, f41_refresh = @base_browser_rp_credentials.fetch(f41_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f41_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f41_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f41_cookie_pairs, URI.parse("https://#{f41_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx41_user,
              host: fx41_host,
              session_public_id: fx41_token.public_id,
              resource_type: "client",
            ),
            host: fx41_host,
          )
        end
      get base_app_verification_url(scope: "admin", pt: pt, ri: "jp", host: host),
          headers: http_headers_15
    end

    assert_response :bad_request
  end

  test "app base verification intent rejects mismatched return target" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app",
                                               session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      http_headers_14 =
        begin
          fx42_host = host
          fx42_token = token
          fx42_user = user
          begin
            f42_cookie_pairs =
              begin
                f42_host = fx42_host
                f42_token = fx42_token
                f42_client = OidcClientRegistry.find!("base-app-ww")
                f42_key = [f42_client.client_id, f42_token.public_id]
                @base_browser_rp_credentials ||= {}
                if @base_browser_rp_credentials[f42_key] ||
                    (f42_token.currently_usable? &&
                      !(f42_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: f42_token.device_session_id,
                        oidc_client_id: f42_client.client_id,
                        revoked_at: nil,
                      )))
                  unless @base_browser_rp_credentials[f42_key]
                    f42_token.rotate_refresh_token! unless f42_token.device_session_record.current_refresh_token_id
                    f42_now = Time.current
                    f42_session = ClientRpSession.create!(
                      client_token: f42_token, oidc_client_id: f42_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f42_now,
                      refresh_token_expires_at: f42_now + 10.minutes,
                    )
                    f42_access = AuthenticationTokenService.encode(
                      fx42_user,
                      host: f42_host,
                      resource_type: "client",
                      session_public_id: f42_token.public_id,
                      base_session_public_id: f42_token.public_id,
                      oidc_sid: f42_session.public_id,
                      oidc_jti: f42_session.oidc_jti,
                      expires_at: f42_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f42_client),
                      audiences: [f42_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f42_client),
                      subject: OidcSubject.for(
                        fx42_user,
                        resource_type: "client",
                      ),
                      client_id: f42_client.client_id,
                    )
                    @base_browser_rp_credentials[f42_key] =
                      [f42_access, f42_session.issue_refresh_token!]
                  end
                  f42_access, f42_refresh = @base_browser_rp_credentials.fetch(f42_key)
                  [
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f42_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f42_refresh)}",
                  ]
                else
                  []
                end
              end
            cookies.merge(f42_cookie_pairs, URI.parse("https://#{f42_host}/"))
          end
          bearer_headers(
            jwt_access_token_for(
              fx42_user,
              host: fx42_host,
              session_public_id: fx42_token.public_id,
              resource_type: "client",
            ),
            host: fx42_host,
          )
        end
      get base_app_verification_url(scope: "settings_telephone", pt: pt, ri: "jp", host: host),
          headers: http_headers_14
    end

    assert_response :bad_request
  end

  test "com base cancellation ignores a posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = create_verified_visitor_with_email(
      email_address: "visitor-cancel-dest-#{SecureRandom.hex(4)}@example.com",
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    http_headers_13 =
      begin
        fx43_host = host
        fx43_token = token
        fx43_visitor = visitor
        begin
          f43_cookie_pairs =
            begin
              f43_host = fx43_host
              f43_token = fx43_token
              f43_client = OidcClientRegistry.find!("base-com-ww")
              f43_key = [f43_client.client_id, f43_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f43_key] ||
                  (f43_token.currently_usable? &&
                    !(f43_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f43_token.device_session_id,
                      oidc_client_id: f43_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f43_key]
                  f43_token.rotate_refresh_token! unless f43_token.device_session_record.current_refresh_token_id
                  f43_now = Time.current
                  f43_session = VisitorRpSession.create!(
                    visitor_token: f43_token, oidc_client_id: f43_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f43_now,
                    refresh_token_expires_at: f43_now + 10.minutes,
                  )
                  f43_access = AuthenticationTokenService.encode(
                    fx43_visitor,
                    host: f43_host,
                    resource_type: "visitor",
                    session_public_id: f43_token.public_id,
                    base_session_public_id: f43_token.public_id,
                    oidc_sid: f43_session.public_id,
                    oidc_jti: f43_session.oidc_jti,
                    expires_at: f43_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f43_client),
                    audiences: [f43_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f43_client),
                    subject: OidcSubject.for(
                      fx43_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f43_client.client_id,
                  )
                  @base_browser_rp_credentials[f43_key] = [f43_access, f43_session.issue_refresh_token!]
                end
                f43_access, f43_refresh = @base_browser_rp_credentials.fetch(f43_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f43_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f43_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f43_cookie_pairs, URI.parse("https://#{f43_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx43_visitor,
            host: fx43_host,
            session_public_id: fx43_token.public_id,
            resource_type: "visitor",
          ),
          host: fx43_host,
        )
      end
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_13

    assert_response :see_other
    transaction =
      begin
        fv5032 = VisitorStepUpCeremonyTransaction
        fv5031 = visitor
        fv5030 = token
        fv5032.where(
          actor_ref: fv5031.public_id,
          session_ref: fv5030.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5028 = transaction
        fv5029 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5028)
        {

          cancellation_ref: fv5029.reference,
          transaction_ref: fv5028.transaction_id,
        }
      end

    http_headers_12 =
      begin
        fx44_host = host
        fx44_token = token
        fx44_visitor = visitor
        begin
          f44_cookie_pairs =
            begin
              f44_host = fx44_host
              f44_token = fx44_token
              f44_client = OidcClientRegistry.find!("base-com-ww")
              f44_key = [f44_client.client_id, f44_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f44_key] ||
                  (f44_token.currently_usable? &&
                    !(f44_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f44_token.device_session_id,
                      oidc_client_id: f44_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f44_key]
                  f44_token.rotate_refresh_token! unless f44_token.device_session_record.current_refresh_token_id
                  f44_now = Time.current
                  f44_session = VisitorRpSession.create!(
                    visitor_token: f44_token, oidc_client_id: f44_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f44_now,
                    refresh_token_expires_at: f44_now + 10.minutes,
                  )
                  f44_access = AuthenticationTokenService.encode(
                    fx44_visitor,
                    host: f44_host,
                    resource_type: "visitor",
                    session_public_id: f44_token.public_id,
                    base_session_public_id: f44_token.public_id,
                    oidc_sid: f44_session.public_id,
                    oidc_jti: f44_session.oidc_jti,
                    expires_at: f44_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f44_client),
                    audiences: [f44_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f44_client),
                    subject: OidcSubject.for(
                      fx44_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f44_client.client_id,
                  )
                  @base_browser_rp_credentials[f44_key] =
                    [f44_access, f44_session.issue_refresh_token!]
                end
                f44_access, f44_refresh = @base_browser_rp_credentials.fetch(f44_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f44_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f44_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f44_cookie_pairs, URI.parse("https://#{f44_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx44_visitor,
            host: fx44_host,
            session_public_id: fx44_token.public_id,
            resource_type: "visitor",
          ),
          host: fx44_host,
        )
      end
    post base_com_verification_cancellation_url(ri: "jp", host: host),
         headers: http_headers_12,
         params: cancellation.merge(scope: "settings_email", return_to: "https://evil.example/steal")

    assert_response :see_other
    assert_equal base_com_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal host, URI.parse(response.location).host
    assert_predicate transaction.reload, :canceled?
  end

  test "com base cancellation closes the pending transaction without granting freshness" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = create_verified_visitor_with_email(email_address: "visitor-cancel-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    http_headers_11 =
      begin
        fx45_host = host
        fx45_token = token
        fx45_visitor = visitor
        begin
          f45_cookie_pairs =
            begin
              f45_host = fx45_host
              f45_token = fx45_token
              f45_client = OidcClientRegistry.find!("base-com-ww")
              f45_key = [f45_client.client_id, f45_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f45_key] ||
                  (f45_token.currently_usable? &&
                    !(f45_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f45_token.device_session_id,
                      oidc_client_id: f45_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f45_key]
                  f45_token.rotate_refresh_token! unless f45_token.device_session_record.current_refresh_token_id
                  f45_now = Time.current
                  f45_session = VisitorRpSession.create!(
                    visitor_token: f45_token, oidc_client_id: f45_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f45_now,
                    refresh_token_expires_at: f45_now + 10.minutes,
                  )
                  f45_access = AuthenticationTokenService.encode(
                    fx45_visitor,
                    host: f45_host,
                    resource_type: "visitor",
                    session_public_id: f45_token.public_id,
                    base_session_public_id: f45_token.public_id,
                    oidc_sid: f45_session.public_id,
                    oidc_jti: f45_session.oidc_jti,
                    expires_at: f45_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f45_client),
                    audiences: [f45_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f45_client),
                    subject: OidcSubject.for(
                      fx45_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f45_client.client_id,
                  )
                  @base_browser_rp_credentials[f45_key] = [f45_access, f45_session.issue_refresh_token!]
                end
                f45_access, f45_refresh = @base_browser_rp_credentials.fetch(f45_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f45_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f45_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f45_cookie_pairs, URI.parse("https://#{f45_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx45_visitor,
            host: fx45_host,
            session_public_id: fx45_token.public_id,
            resource_type: "visitor",
          ),
          host: fx45_host,
        )
      end
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_11

    assert_response :see_other
    transaction =
      begin
        fv5027 = VisitorStepUpCeremonyTransaction
        fv5026 = visitor
        fv5025 = token
        fv5027.where(
          actor_ref: fv5026.public_id,
          session_ref: fv5025.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5023 = transaction
        fv5024 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5023)
        {

          cancellation_ref: fv5024.reference,
          transaction_ref: fv5023.transaction_id,
        }
      end

    http_headers_10 =
      begin
        fx46_host = host
        fx46_token = token
        fx46_visitor = visitor
        begin
          f46_cookie_pairs =
            begin
              f46_host = fx46_host
              f46_token = fx46_token
              f46_client = OidcClientRegistry.find!("base-com-ww")
              f46_key = [f46_client.client_id, f46_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f46_key] ||
                  (f46_token.currently_usable? &&
                    !(f46_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f46_token.device_session_id,
                      oidc_client_id: f46_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f46_key]
                  f46_token.rotate_refresh_token! unless f46_token.device_session_record.current_refresh_token_id
                  f46_now = Time.current
                  f46_session = VisitorRpSession.create!(
                    visitor_token: f46_token, oidc_client_id: f46_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f46_now,
                    refresh_token_expires_at: f46_now + 10.minutes,
                  )
                  f46_access = AuthenticationTokenService.encode(
                    fx46_visitor,
                    host: f46_host,
                    resource_type: "visitor",
                    session_public_id: f46_token.public_id,
                    base_session_public_id: f46_token.public_id,
                    oidc_sid: f46_session.public_id,
                    oidc_jti: f46_session.oidc_jti,
                    expires_at: f46_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f46_client),
                    audiences: [f46_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f46_client),
                    subject: OidcSubject.for(
                      fx46_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f46_client.client_id,
                  )
                  @base_browser_rp_credentials[f46_key] = [f46_access, f46_session.issue_refresh_token!]
                end
                f46_access, f46_refresh = @base_browser_rp_credentials.fetch(f46_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f46_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f46_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f46_cookie_pairs, URI.parse("https://#{f46_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx46_visitor,
            host: fx46_host,
            session_public_id: fx46_token.public_id,
            resource_type: "visitor",
          ),
          host: fx46_host,
        )
      end
    post base_com_verification_cancellation_url(ri: "jp", host: host),
         headers: http_headers_10, params: cancellation

    assert_response :see_other
    assert_predicate transaction.reload, :canceled?
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at
  end

  test "org base cancellation ignores a posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    http_headers_9 =
      begin
        fx47_host = host
        fx47_token = token
        fx47_operator = operator
        begin
          f47_cookie_pairs =
            begin
              f47_host = fx47_host
              f47_token = fx47_token
              f47_client = OidcClientRegistry.find!("base-org-ww")
              f47_key = [f47_client.client_id, f47_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f47_key] ||
                  (f47_token.currently_usable? &&
                    !(f47_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f47_token.device_session_id,
                      oidc_client_id: f47_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f47_key]
                  f47_token.rotate_refresh_token! unless f47_token.device_session_record.current_refresh_token_id
                  f47_now = Time.current
                  f47_session = OperatorRpSession.create!(
                    operator_token: f47_token, oidc_client_id: f47_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f47_now,
                    refresh_token_expires_at: f47_now + 10.minutes,
                  )
                  f47_access = AuthenticationTokenService.encode(
                    fx47_operator,
                    host: f47_host,
                    resource_type: "operator",
                    session_public_id: f47_token.public_id,
                    base_session_public_id: f47_token.public_id,
                    oidc_sid: f47_session.public_id,
                    oidc_jti: f47_session.oidc_jti,
                    expires_at: f47_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f47_client),
                    audiences: [f47_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f47_client),
                    subject: OidcSubject.for(
                      fx47_operator,
                      resource_type: "operator",
                    ),
                    client_id: f47_client.client_id,
                  )
                  @base_browser_rp_credentials[f47_key] = [f47_access, f47_session.issue_refresh_token!]
                end
                f47_access, f47_refresh = @base_browser_rp_credentials.fetch(f47_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f47_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f47_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f47_cookie_pairs, URI.parse("https://#{f47_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx47_operator,
            host: fx47_host,
            session_public_id: fx47_token.public_id,
            resource_type: "operator",
          ),
          host: fx47_host,
        )
      end
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_9

    assert_response :see_other
    transaction =
      begin
        fv5022 = OperatorStepUpCeremonyTransaction
        fv5021 = operator
        fv5020 = token
        fv5022.where(
          actor_ref: fv5021.public_id,
          session_ref: fv5020.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5018 = transaction
        fv5019 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5018)
        {

          cancellation_ref: fv5019.reference,
          transaction_ref: fv5018.transaction_id,
        }
      end

    http_headers_8 =
      begin
        fx48_host = host
        fx48_token = token
        fx48_operator = operator
        begin
          f48_cookie_pairs =
            begin
              f48_host = fx48_host
              f48_token = fx48_token
              f48_client = OidcClientRegistry.find!("base-org-ww")
              f48_key = [f48_client.client_id, f48_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f48_key] ||
                  (f48_token.currently_usable? &&
                    !(f48_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f48_token.device_session_id,
                      oidc_client_id: f48_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f48_key]
                  f48_token.rotate_refresh_token! unless f48_token.device_session_record.current_refresh_token_id
                  f48_now = Time.current
                  f48_session = OperatorRpSession.create!(
                    operator_token: f48_token, oidc_client_id: f48_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f48_now,
                    refresh_token_expires_at: f48_now + 10.minutes,
                  )
                  f48_access = AuthenticationTokenService.encode(
                    fx48_operator,
                    host: f48_host,
                    resource_type: "operator",
                    session_public_id: f48_token.public_id,
                    base_session_public_id: f48_token.public_id,
                    oidc_sid: f48_session.public_id,
                    oidc_jti: f48_session.oidc_jti,
                    expires_at: f48_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f48_client),
                    audiences: [f48_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f48_client),
                    subject: OidcSubject.for(
                      fx48_operator,
                      resource_type: "operator",
                    ),
                    client_id: f48_client.client_id,
                  )
                  @base_browser_rp_credentials[f48_key] =
                    [f48_access, f48_session.issue_refresh_token!]
                end
                f48_access, f48_refresh = @base_browser_rp_credentials.fetch(f48_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f48_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f48_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f48_cookie_pairs, URI.parse("https://#{f48_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx48_operator,
            host: fx48_host,
            session_public_id: fx48_token.public_id,
            resource_type: "operator",
          ),
          host: fx48_host,
        )
      end
    post base_org_verification_cancellation_url(ri: "jp", host: host),
         headers: http_headers_8,
         params: cancellation.merge(scope: "settings_email", return_to: "https://evil.example/steal")

    assert_response :see_other
    assert_equal base_org_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal host, URI.parse(response.location).host
    assert_predicate transaction.reload, :canceled?
  end

  test "org base cancellation closes the pending transaction without granting freshness" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    http_headers_7 =
      begin
        fx49_host = host
        fx49_token = token
        fx49_operator = operator
        begin
          f49_cookie_pairs =
            begin
              f49_host = fx49_host
              f49_token = fx49_token
              f49_client = OidcClientRegistry.find!("base-org-ww")
              f49_key = [f49_client.client_id, f49_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f49_key] ||
                  (f49_token.currently_usable? &&
                    !(f49_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f49_token.device_session_id,
                      oidc_client_id: f49_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f49_key]
                  f49_token.rotate_refresh_token! unless f49_token.device_session_record.current_refresh_token_id
                  f49_now = Time.current
                  f49_session = OperatorRpSession.create!(
                    operator_token: f49_token, oidc_client_id: f49_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f49_now,
                    refresh_token_expires_at: f49_now + 10.minutes,
                  )
                  f49_access = AuthenticationTokenService.encode(
                    fx49_operator,
                    host: f49_host,
                    resource_type: "operator",
                    session_public_id: f49_token.public_id,
                    base_session_public_id: f49_token.public_id,
                    oidc_sid: f49_session.public_id,
                    oidc_jti: f49_session.oidc_jti,
                    expires_at: f49_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f49_client),
                    audiences: [f49_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f49_client),
                    subject: OidcSubject.for(
                      fx49_operator,
                      resource_type: "operator",
                    ),
                    client_id: f49_client.client_id,
                  )
                  @base_browser_rp_credentials[f49_key] = [f49_access, f49_session.issue_refresh_token!]
                end
                f49_access, f49_refresh = @base_browser_rp_credentials.fetch(f49_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f49_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f49_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f49_cookie_pairs, URI.parse("https://#{f49_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx49_operator,
            host: fx49_host,
            session_public_id: fx49_token.public_id,
            resource_type: "operator",
          ),
          host: fx49_host,
        )
      end
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_7

    assert_response :see_other
    transaction =
      begin
        fv5017 = OperatorStepUpCeremonyTransaction
        fv5016 = operator
        fv5015 = token
        fv5017.where(
          actor_ref: fv5016.public_id,
          session_ref: fv5015.public_id,
        ).order(id: :desc).first!
      end
    cancellation =
      begin
        fv5013 = transaction
        fv5014 = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: fv5013)
        {

          cancellation_ref: fv5014.reference,
          transaction_ref: fv5013.transaction_id,
        }
      end

    http_headers_6 =
      begin
        fx50_host = host
        fx50_token = token
        fx50_operator = operator
        begin
          f50_cookie_pairs =
            begin
              f50_host = fx50_host
              f50_token = fx50_token
              f50_client = OidcClientRegistry.find!("base-org-ww")
              f50_key = [f50_client.client_id, f50_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f50_key] ||
                  (f50_token.currently_usable? &&
                    !(f50_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f50_token.device_session_id,
                      oidc_client_id: f50_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f50_key]
                  f50_token.rotate_refresh_token! unless f50_token.device_session_record.current_refresh_token_id
                  f50_now = Time.current
                  f50_session = OperatorRpSession.create!(
                    operator_token: f50_token, oidc_client_id: f50_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f50_now,
                    refresh_token_expires_at: f50_now + 10.minutes,
                  )
                  f50_access = AuthenticationTokenService.encode(
                    fx50_operator,
                    host: f50_host,
                    resource_type: "operator",
                    session_public_id: f50_token.public_id,
                    base_session_public_id: f50_token.public_id,
                    oidc_sid: f50_session.public_id,
                    oidc_jti: f50_session.oidc_jti,
                    expires_at: f50_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f50_client),
                    audiences: [f50_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f50_client),
                    subject: OidcSubject.for(
                      fx50_operator,
                      resource_type: "operator",
                    ),
                    client_id: f50_client.client_id,
                  )
                  @base_browser_rp_credentials[f50_key] = [f50_access, f50_session.issue_refresh_token!]
                end
                f50_access, f50_refresh = @base_browser_rp_credentials.fetch(f50_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f50_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f50_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f50_cookie_pairs, URI.parse("https://#{f50_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx50_operator,
            host: fx50_host,
            session_public_id: fx50_token.public_id,
            resource_type: "operator",
          ),
          host: fx50_host,
        )
      end
    post base_org_verification_cancellation_url(ri: "jp", host: host),
         headers: http_headers_6, params: cancellation

    assert_response :see_other
    assert_predicate transaction.reload, :canceled?
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at
  end

  test "com base verification intent creates a visitor transaction bound to the session" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = create_verified_visitor_with_email(email_address: "visitor-intent-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    http_headers_5 =
      begin
        fx51_host = host
        fx51_token = token
        fx51_visitor = visitor
        begin
          f51_cookie_pairs =
            begin
              f51_host = fx51_host
              f51_token = fx51_token
              f51_client = OidcClientRegistry.find!("base-com-ww")
              f51_key = [f51_client.client_id, f51_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f51_key] ||
                  (f51_token.currently_usable? &&
                    !(f51_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f51_token.device_session_id,
                      oidc_client_id: f51_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f51_key]
                  f51_token.rotate_refresh_token! unless f51_token.device_session_record.current_refresh_token_id
                  f51_now = Time.current
                  f51_session = VisitorRpSession.create!(
                    visitor_token: f51_token, oidc_client_id: f51_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f51_now,
                    refresh_token_expires_at: f51_now + 10.minutes,
                  )
                  f51_access = AuthenticationTokenService.encode(
                    fx51_visitor,
                    host: f51_host,
                    resource_type: "visitor",
                    session_public_id: f51_token.public_id,
                    base_session_public_id: f51_token.public_id,
                    oidc_sid: f51_session.public_id,
                    oidc_jti: f51_session.oidc_jti,
                    expires_at: f51_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f51_client),
                    audiences: [f51_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f51_client),
                    subject: OidcSubject.for(
                      fx51_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f51_client.client_id,
                  )
                  @base_browser_rp_credentials[f51_key] = [f51_access, f51_session.issue_refresh_token!]
                end
                f51_access, f51_refresh = @base_browser_rp_credentials.fetch(f51_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f51_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f51_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f51_cookie_pairs, URI.parse("https://#{f51_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx51_visitor,
            host: fx51_host,
            session_public_id: fx51_token.public_id,
            resource_type: "visitor",
          ),
          host: fx51_host,
        )
      end
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_5

    assert_response :see_other
    transaction =
      begin
        fv5012 = VisitorStepUpCeremonyTransaction
        fv5011 = visitor
        fv5010 = token
        fv5012.where(
          actor_ref: fv5011.public_id,
          session_ref: fv5010.public_id,
        ).order(id: :desc).first!
      end

    assert_equal visitor.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "com", transaction.surface
    assert_equal "step_up", transaction.purpose
    assert_equal return_to, transaction.return_to
    assert_predicate redirect_query["entry_ref"], :present?
    assert_nil redirect_query["step_up_ceremony_grant"]
  end

  test "com base completion consumes the opaque result and commits freshness" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = create_verified_visitor_with_email(email_address: "visitor-completion-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    http_headers_4 =
      begin
        fx52_host = host
        fx52_token = token
        fx52_visitor = visitor
        begin
          f52_cookie_pairs =
            begin
              f52_host = fx52_host
              f52_token = fx52_token
              f52_client = OidcClientRegistry.find!("base-com-ww")
              f52_key = [f52_client.client_id, f52_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f52_key] ||
                  (f52_token.currently_usable? &&
                    !(f52_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f52_token.device_session_id,
                      oidc_client_id: f52_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f52_key]
                  f52_token.rotate_refresh_token! unless f52_token.device_session_record.current_refresh_token_id
                  f52_now = Time.current
                  f52_session = VisitorRpSession.create!(
                    visitor_token: f52_token, oidc_client_id: f52_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f52_now,
                    refresh_token_expires_at: f52_now + 10.minutes,
                  )
                  f52_access = AuthenticationTokenService.encode(
                    fx52_visitor,
                    host: f52_host,
                    resource_type: "visitor",
                    session_public_id: f52_token.public_id,
                    base_session_public_id: f52_token.public_id,
                    oidc_sid: f52_session.public_id,
                    oidc_jti: f52_session.oidc_jti,
                    expires_at: f52_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f52_client),
                    audiences: [f52_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f52_client),
                    subject: OidcSubject.for(
                      fx52_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f52_client.client_id,
                  )
                  @base_browser_rp_credentials[f52_key] = [f52_access, f52_session.issue_refresh_token!]
                end
                f52_access, f52_refresh = @base_browser_rp_credentials.fetch(f52_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f52_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f52_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f52_cookie_pairs, URI.parse("https://#{f52_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx52_visitor,
            host: fx52_host,
            session_public_id: fx52_token.public_id,
            resource_type: "visitor",
          ),
          host: fx52_host,
        )
      end
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_4

    assert_response :see_other
    transaction =
      begin
        fv5009 = VisitorStepUpCeremonyTransaction
        fv5008 = visitor
        fv5007 = token
        fv5009.where(
          actor_ref: fv5008.public_id,
          session_ref: fv5007.public_id,
        ).order(id: :desc).first!
      end
    email = visitor.visitor_emails.first
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "email_otp", aal: "none", phishing_resistant: false, user_verified: false,
      verified_at: VisitorStepUpCeremonyTransaction.database_now, verified_credential_ref: email.public_id,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = VisitorAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = VisitorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "com", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    foreign = open_session
    foreign.host!(host)
    foreign.https!
    [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::REFRESH_COOKIE].each do |name|
      foreign.cookies.merge("#{name}=#{Rack::Utils.escape(cookies[name])}", URI.parse("https://#{host}/"))
    end
    foreign.get(
      base_com_verification_completion_url(ri: "jp", host:),
      params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
    )

    assert_equal [400, nil, "verified", nil],
                 [foreign.response.status, foreign.response.location, transaction.reload.status,
                  token.reload.last_step_up_at,]

    http_headers_3 =
      begin
        fx53_host = host
        fx53_token = token
        fx53_visitor = visitor
        begin
          f53_cookie_pairs =
            begin
              f53_host = fx53_host
              f53_token = fx53_token
              f53_client = OidcClientRegistry.find!("base-com-ww")
              f53_key = [f53_client.client_id, f53_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f53_key] ||
                  (f53_token.currently_usable? &&
                    !(f53_token.device_session_id && VisitorRpSession.exists?(
                      device_session_id: f53_token.device_session_id,
                      oidc_client_id: f53_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f53_key]
                  f53_token.rotate_refresh_token! unless f53_token.device_session_record.current_refresh_token_id
                  f53_now = Time.current
                  f53_session = VisitorRpSession.create!(
                    visitor_token: f53_token, oidc_client_id: f53_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f53_now,
                    refresh_token_expires_at: f53_now + 10.minutes,
                  )
                  f53_access = AuthenticationTokenService.encode(
                    fx53_visitor,
                    host: f53_host,
                    resource_type: "visitor",
                    session_public_id: f53_token.public_id,
                    base_session_public_id: f53_token.public_id,
                    oidc_sid: f53_session.public_id,
                    oidc_jti: f53_session.oidc_jti,
                    expires_at: f53_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f53_client),
                    audiences: [f53_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f53_client),
                    subject: OidcSubject.for(
                      fx53_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f53_client.client_id,
                  )
                  @base_browser_rp_credentials[f53_key] =
                    [f53_access, f53_session.issue_refresh_token!]
                end
                f53_access, f53_refresh = @base_browser_rp_credentials.fetch(f53_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f53_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f53_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f53_cookie_pairs, URI.parse("https://#{f53_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx53_visitor,
            host: fx53_host,
            session_public_id: fx53_token.public_id,
            resource_type: "visitor",
          ),
          host: fx53_host,
        )
      end
    post base_com_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_3

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "settings_email", token.reload.last_step_up_scope
    assert_equal "consumed", transaction.reload.status
  end

  test "org base verification intent creates an operator transaction bound to the session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    http_headers_2 =
      begin
        fx54_host = host
        fx54_token = token
        fx54_operator = operator
        begin
          f54_cookie_pairs =
            begin
              f54_host = fx54_host
              f54_token = fx54_token
              f54_client = OidcClientRegistry.find!("base-org-ww")
              f54_key = [f54_client.client_id, f54_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f54_key] ||
                  (f54_token.currently_usable? &&
                    !(f54_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f54_token.device_session_id,
                      oidc_client_id: f54_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f54_key]
                  f54_token.rotate_refresh_token! unless f54_token.device_session_record.current_refresh_token_id
                  f54_now = Time.current
                  f54_session = OperatorRpSession.create!(
                    operator_token: f54_token, oidc_client_id: f54_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f54_now,
                    refresh_token_expires_at: f54_now + 10.minutes,
                  )
                  f54_access = AuthenticationTokenService.encode(
                    fx54_operator,
                    host: f54_host,
                    resource_type: "operator",
                    session_public_id: f54_token.public_id,
                    base_session_public_id: f54_token.public_id,
                    oidc_sid: f54_session.public_id,
                    oidc_jti: f54_session.oidc_jti,
                    expires_at: f54_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f54_client),
                    audiences: [f54_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f54_client),
                    subject: OidcSubject.for(
                      fx54_operator,
                      resource_type: "operator",
                    ),
                    client_id: f54_client.client_id,
                  )
                  @base_browser_rp_credentials[f54_key] = [f54_access, f54_session.issue_refresh_token!]
                end
                f54_access, f54_refresh = @base_browser_rp_credentials.fetch(f54_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f54_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f54_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f54_cookie_pairs, URI.parse("https://#{f54_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx54_operator,
            host: fx54_host,
            session_public_id: fx54_token.public_id,
            resource_type: "operator",
          ),
          host: fx54_host,
        )
      end
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_2

    assert_response :see_other
    transaction =
      begin
        fv5006 = OperatorStepUpCeremonyTransaction
        fv5005 = operator
        fv5004 = token
        fv5006.where(
          actor_ref: fv5005.public_id,
          session_ref: fv5004.public_id,
        ).order(id: :desc).first!
      end

    assert_equal operator.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "org", transaction.surface
    assert_equal "step_up", transaction.purpose
    assert_equal ["passkey"], transaction.allowed_methods_array
    assert_predicate redirect_query["entry_ref"], :present?
    assert_nil redirect_query["step_up_ceremony_grant"]
  end

  test "org base completion consumes the opaque result and commits freshness" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    http_headers_1 =
      begin
        fx55_host = host
        fx55_token = token
        fx55_operator = operator
        begin
          f55_cookie_pairs =
            begin
              f55_host = fx55_host
              f55_token = fx55_token
              f55_client = OidcClientRegistry.find!("base-org-ww")
              f55_key = [f55_client.client_id, f55_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f55_key] ||
                  (f55_token.currently_usable? &&
                    !(f55_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f55_token.device_session_id,
                      oidc_client_id: f55_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f55_key]
                  f55_token.rotate_refresh_token! unless f55_token.device_session_record.current_refresh_token_id
                  f55_now = Time.current
                  f55_session = OperatorRpSession.create!(
                    operator_token: f55_token, oidc_client_id: f55_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f55_now,
                    refresh_token_expires_at: f55_now + 10.minutes,
                  )
                  f55_access = AuthenticationTokenService.encode(
                    fx55_operator,
                    host: f55_host,
                    resource_type: "operator",
                    session_public_id: f55_token.public_id,
                    base_session_public_id: f55_token.public_id,
                    oidc_sid: f55_session.public_id,
                    oidc_jti: f55_session.oidc_jti,
                    expires_at: f55_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f55_client),
                    audiences: [f55_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f55_client),
                    subject: OidcSubject.for(
                      fx55_operator,
                      resource_type: "operator",
                    ),
                    client_id: f55_client.client_id,
                  )
                  @base_browser_rp_credentials[f55_key] = [f55_access, f55_session.issue_refresh_token!]
                end
                f55_access, f55_refresh = @base_browser_rp_credentials.fetch(f55_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f55_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f55_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f55_cookie_pairs, URI.parse("https://#{f55_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx55_operator,
            host: fx55_host,
            session_public_id: fx55_token.public_id,
            resource_type: "operator",
          ),
          host: fx55_host,
        )
      end
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: http_headers_1

    assert_response :see_other
    transaction =
      begin
        fv5003 = OperatorStepUpCeremonyTransaction
        fv5002 = operator
        fv5001 = token
        fv5003.where(
          actor_ref: fv5002.public_id,
          session_ref: fv5001.public_id,
        ).order(id: :desc).first!
      end
    passkey = operator.staff_passkeys.first
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.external_id,
    )
    # Synthetic Auth proof isolates Base finalization, but still follows every public admission transition.
    binding = OperatorAuthAdmissionBinding.find_by!(step_up_ceremony_transaction_id: transaction.id)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref, surface: "org", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    foreign = open_session
    foreign.host!(host)
    foreign.https!
    [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::REFRESH_COOKIE].each do |name|
      foreign.cookies.merge("#{name}=#{Rack::Utils.escape(cookies[name])}", URI.parse("https://#{host}/"))
    end
    foreign.get(
      base_org_verification_completion_url(ri: "jp", host:),
      params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
    )

    assert_equal [400, nil, "verified", nil],
                 [foreign.response.status, foreign.response.location, transaction.reload.status,
                  token.reload.last_step_up_at,]

    http_headers_0 =
      begin
        fx56_host = host
        fx56_token = token
        fx56_operator = operator
        begin
          f56_cookie_pairs =
            begin
              f56_host = fx56_host
              f56_token = fx56_token
              f56_client = OidcClientRegistry.find!("base-org-ww")
              f56_key = [f56_client.client_id, f56_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f56_key] ||
                  (f56_token.currently_usable? &&
                    !(f56_token.device_session_id && OperatorRpSession.exists?(
                      device_session_id: f56_token.device_session_id,
                      oidc_client_id: f56_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f56_key]
                  f56_token.rotate_refresh_token! unless f56_token.device_session_record.current_refresh_token_id
                  f56_now = Time.current
                  f56_session = OperatorRpSession.create!(
                    operator_token: f56_token, oidc_client_id: f56_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f56_now,
                    refresh_token_expires_at: f56_now + 10.minutes,
                  )
                  f56_access = AuthenticationTokenService.encode(
                    fx56_operator,
                    host: f56_host,
                    resource_type: "operator",
                    session_public_id: f56_token.public_id,
                    base_session_public_id: f56_token.public_id,
                    oidc_sid: f56_session.public_id,
                    oidc_jti: f56_session.oidc_jti,
                    expires_at: f56_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f56_client),
                    audiences: [f56_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f56_client),
                    subject: OidcSubject.for(
                      fx56_operator,
                      resource_type: "operator",
                    ),
                    client_id: f56_client.client_id,
                  )
                  @base_browser_rp_credentials[f56_key] =
                    [f56_access, f56_session.issue_refresh_token!]
                end
                f56_access, f56_refresh = @base_browser_rp_credentials.fetch(f56_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f56_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f56_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f56_cookie_pairs, URI.parse("https://#{f56_host}/"))
        end
        bearer_headers(
          jwt_access_token_for(
            fx56_operator,
            host: fx56_host,
            session_public_id: fx56_token.public_id,
            resource_type: "operator",
          ),
          host: fx56_host,
        )
      end
    post base_org_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: http_headers_0

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "settings_email", token.reload.last_step_up_scope
    assert_equal "consumed", transaction.reload.status
  end

  private

  def create_client_token!(user)
    ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
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

  def redirect_query
    uri = URI.parse(response.location)
    if uri.host == "jump.umaxica.net"
      payload, = JWT.decode(Rack::Utils.parse_nested_query(uri.query).fetch("rt"), nil, false)
      uri = URI.parse(payload.fetch("url"))
    end
    Rack::Utils.parse_query(uri.query)
  end

  def decode_grant(token, surface:)
    IdentityStepUpCeremonyGrant.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.base_issuer_id(surface),
    )
  end

  def issue_step_up_grant!(surface:, actor_ref:, session_ref:, scope:, methods:, return_to:)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      required_scope: scope,
      required_aal: StepUpRequirement::NO_AAL,
      audience: "step_up:#{surface}",
      token_binding: session_ref,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 10.minutes.from_now,
    )
  end
end

# DAMP local helper copy for former shared test support.
class BaseStepUpIntentAuthorityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  # The Base surface shares its production origin with Acme (both resolve to
  # `https://www.umaxica.<tld>`), so the issuer namespace cannot be inferred
  # from a host substring like "base". Match against the actual configured
  # Base hosts first; only fall back to substring heuristics for surfaces
  # whose test/production hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

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

  # Base's Browser-RP context binds the signed `pt` to the current root token
  # public_id, which is also the durable step-up transaction session_ref.
  def session_nonce_for(token)
    token.public_id
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
                               aal: StepUpRequirement::NO_AAL)
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
      user_headers =
        as_user_headers(user, host: host)
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

# DAMP local route helper aliases for former shared test support.
class BaseStepUpIntentAuthorityTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class BaseStepUpIntentAuthorityTest
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
    email = VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    email.finalize_binding!
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
