# frozen_string_literal: true

require "test_helper"

class SignUpAdmissionOwnershipTest < ActionDispatch::IntegrationTest
  [
    [:app, "client", ClientSignUpFlow, ClientAuthAdmissionBinding, ClientAuthCeremonySession, ClientToken],
    [:com, "visitor", VisitorSignUpFlow, VisitorAuthAdmissionBinding, VisitorAuthCeremonySession, VisitorToken],
  ].each do |surface, realm, flow_class, binding_class, ceremony_class, token_class|
    %i(foreign_hint foreign_url wrong_nonce).each do |attack|
      test "#{surface} #{attack} refuses the request without changing either admitted registration" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = (surface == :app) ? ENV.fetch("PUBLIC_AUTH_SERVICE_URL") : ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        contexts =
          2.times.map do
            client_id = "core-#{surface}-jp"
            parent = OidcAuthorizationTransactionCoordinator.issue!(
              surface: surface, intent: "authentication",
              params: {
                client_id: client_id,
                redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
                response_type: "code",
                scope: "openid profile",
                prompt: "create",
                state: SecureRandom.hex(16),
                nonce: SecureRandom.hex(16),
                code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
                code_challenge_method: "S256",
              },
            ).transaction
            issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
              transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
            )
            binding = binding_class.find_by!(entry_ref: issuance.reference)
            attached, raw_sid = ceremony_class.issue!
            binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
            binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
            ceremony, admitted_sid = ceremony_class.rotate_and_admit!(
              admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
              authorization_transaction_ref: parent.transaction_id,
            )
            binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
            nonce = SecureRandom.hex(32)
            now = flow_class.database_now
            flow = flow_class.create!(
              auth_admission_binding: binding, step: "contact", entry_method: "email",
              status_id: flow_class.status_id_for("CONTACT_PENDING"),
              issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce(nonce),
            )
            { binding: binding, ceremony: ceremony, parent: parent, flow: flow, sid: admitted_sid, nonce: nonce }
          end
        own, foreign = contexts
        hint = (attack == :foreign_hint) ? foreign : own
        nonce = (attack == :wrong_nonce) ? "unrelated-browser" : hint.fetch(:nonce)
        target = (attack == :foreign_url) ? foreign : own
        continuity = {
          "session_id" => SecureRandom.hex(16),
          "_csrf_token" => SecureRandom.urlsafe_base64(32),
          SignUpCycleLocator::SESSION_KEYS.fetch(surface).to_s => {
            "public_id" => hint.fetch(:flow).public_id, "nonce" => nonce,
          },
        }
        # Retain a real encrypted Rails UI cookie while the Auth SID proves this Admission.
        cookie_request = ActionDispatch::TestRequest.create
        jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
        session_key = Rails.application.config.session_options.fetch(:key)
        jar.encrypted[session_key] = { value: continuity }
        sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        browser = open_session
        browser.host!(host)
        browser.https!
        _auth_cookie = browser.cookies.merge(
          "#{sid_key}=#{Rack::Utils.escape(own.fetch(:sid))}", URI.parse("https://#{host}/"),
        )
        before =
          contexts.map do |context|
            context.values_at(:binding, :ceremony, :parent, :flow).map { |row| row.reload.attributes }
          end
        tokens = token_class.count
        %i(get post patch delete).each do |verb|
          # Each request presents the same stale cookie, independently of a prior refusal's cleanup.
          _session_cookie = browser.cookies.merge(
            "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{host}/"),
          )
          fields = { ri: "jp", fb: SignFlowBindingCodec.encode(flow: target.fetch(:flow), surface: surface) }
          headers = {
            "Sec-Fetch-Site" => "same-origin",
            "Origin" => "https://#{host}",
            "X-CSRF-Token" => continuity.fetch("_csrf_token"),
          }
          case verb
          when :get then browser.get("/sign/up/check/email/otp", params: fields, headers: headers)
          when :post then browser.post("/sign/up/check/email/otp", params: fields, headers: headers)
          when :patch then browser.patch("/sign/up/check/email/otp", params: fields, headers: headers)
          when :delete then browser.delete("/sign/up/check/email/otp", params: fields, headers: headers)
          end

          assert browser.request.cookies.key?(session_key), "the browser sends its retained Rails cookie"
          incoming_jar = ActionDispatch::Cookies::CookieJar.build(browser.request, browser.request.cookies)

          assert incoming_jar.encrypted[session_key]&.key?(SignUpCycleLocator::SESSION_KEYS.fetch(surface).to_s),
                 "the retained Rails cookie decodes its UI hint"
          assert_equal hint.fetch(:flow).public_id,
                       incoming_jar.encrypted[session_key].dig(
                         SignUpCycleLocator::SESSION_KEYS.fetch(surface).to_s,
                         "public_id",
                       )
          assert_equal (attack == :foreign_url) ? 409 : 400, browser.response.status, "#{verb} ownership refusal"
          assert_includes browser.response.headers.fetch("Cache-Control"), "no-store"
          assert_nil browser.response.headers["Location"]
          assert_equal tokens, token_class.count
          assert_equal before, contexts.map { |context|
            context.values_at(:binding, :ceremony, :parent, :flow).map { |row|
              row.reload.attributes
            }
          }
        end
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end
end
