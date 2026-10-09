# typed: false
# frozen_string_literal: true

require "test_helper"
require "timeout"

class RecoverySecretParallelGetTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  fixtures :clients, :visitors

  test "parallel public recovery-secret GETs disclose a receipt once on com" do
    surfaces = [
      {
        name: "com",
        actor: visitors(:reserved_visitor),
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        purpose: "visitor.recovery_secret_credential",
        token_model: VisitorToken,
        owner_column: :visitor_id,
        headers: ->(actor, host) {
          begin
            rp_headers = as_visitor_headers(actor, host: host)
            rp_host = rp_headers["Host"]
            rp_route =
              begin
                Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
              rescue ActionController::RoutingError
                nil
              end
            rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(rp_family) && rp_surface == "com"
              rp_client_id =
                case rp_family
                when "base" then "base-#{rp_surface}-ww"
                when "edit" then "edit-org"
                else "#{rp_family}-#{rp_surface}"
                end
              rp_token = VisitorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rp_client = OidcClientRegistry.find!(rp_client_id)
              rp_key = [rp_client.client_id, rp_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                  !(rp_token.device_session_id && VisitorRpSession.exists?(
                    device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                  ))
                rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
                rp_now = Time.current
                rp_session = VisitorRpSession.create!(
                  visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                  refresh_token_expires_at: rp_now + 10.minutes,
                )
                rp_access = AuthenticationTokenService.encode(
                  rp_token.visitor, host: rp_host, resource_type: "visitor",
                                    session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                    oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                    expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                    issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                    subject: OidcSubject.for(
                                      rp_token.visitor,
                                      resource_type: "visitor",
                                    ), client_id: rp_client.client_id,
                )
                @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[rp_key]
                rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
                rp_cookie = [
                  rp_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
                ].join("; ")
                rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
              end
            end
            rp_headers
          end
        },
        path: ->(token) { base_com_identity_recovery_secret_path(token: token, ri: "jp") },
      },
    ]

    surfaces.each do |surface|
      actor = surface.fetch(:actor)
      host = surface.fetch(:host)
      token_model = surface.fetch(:token_model)
      owner_column = surface.fetch(:owner_column)
      original_token_ids = token_model.where(owner_column => actor.id).pluck(:id)
      original_reveal_ids = SecurityOneTimeReveal.where(
        actor_type: actor.class.name,
        actor_id: actor.id,
        purpose: surface.fetch(:purpose),
      ).pluck(:id)
      session_headers = surface.fetch(:headers).call(actor, host)
      reveal = IdentityOneTimeReveal.issue!(
        actor: actor,
        session_nonce: actor.public_id,
        value: "parallel-#{surface.fetch(:name)}-passcode",
        purpose: surface.fetch(:purpose),
      )
      path = surface.fetch(:path).call(reveal.token)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      browsers = Array.new(2) { open_session }
      threads =
        browsers.map do |browser|
          # Independent workers are required to exercise the concurrent database boundary.
          Thread.new do
            browser.host!(host)
            ready << true
            start.pop
            browser.get(path, headers: session_headers)
            page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")
            props = JSON.parse(page.text).fetch("props")
            outcomes << { status: browser.response.status, passcodes: props.fetch("passcodes") }
          end
        end

      begin
        Timeout.timeout(5) do
          2.times { ready.pop }
          2.times { start << true }
          threads.each(&:value)
        end

        responses = 2.times.map { outcomes.pop }

        assert_equal [200, 200], responses.map { |response| response.fetch(:status) }.sort,
                     "#{surface.fetch(:name)} parallel reveal requests must render successfully"
        assert_equal 1, responses.count { |response|
          response.fetch(:passcodes) == ["parallel-#{surface.fetch(:name)}-passcode"]
        },
                     "#{surface.fetch(:name)} parallel GETs may disclose the receipt once"
        assert_equal 1, responses.count { |response| response.fetch(:passcodes).empty? },
                     "#{surface.fetch(:name)} losing the consume race must disclose no passcode"
      ensure
        threads.each { |thread| thread.kill if thread.alive? }
        threads.each(&:join)
        SecurityOneTimeReveal.where(
          actor_type: actor.class.name,
          actor_id: actor.id,
          purpose: surface.fetch(:purpose),
        ).where.not(id: original_reveal_ids).delete_all
        token_model.where(owner_column => actor.id).where.not(id: original_token_ids).delete_all
      end
    end
  end
end
