# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class AppSecretRootLoginConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_security_modes client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  setup do
    @client_sign_in_flow_id_before_test = ClientSignInFlow.maximum(:id) || 0
    @client_auth_ceremony_session_id_before_test = ClientAuthCeremonySession.maximum(:id) || 0
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_purge_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    ClientIdentityState.ensure_defaults!
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = @previous_purge_delay
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  %i(completion cancellation expiration).each do |outcome|
    test "Base Secret results racing #{outcome} cannot establish a second or terminal root login" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      identifier = "root-secret-#{SecureRandom.hex(4)}@example.com"
      actor.client_emails.create!(
        address: identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
      ).finalize_binding!
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      now = ClientToken.database_now
      token.update!(authentication_event_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      step_up_grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
      )
      step_up_grant.issue_refresh_token!(now:)
      step_up_evidence = StepUpEvidenceValue.new(
        acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: step_up_grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: step_up_grant.oidc_jti,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
        step_up_evidence: step_up_evidence,
      )
      ClientSecretPresentationIssuer.prepare!(
        actor_context: context, token: token, issuance: issuance, step_up_evidence: step_up_evidence,
      )
      raw = ClientSecretPresentationIssuer.call!(
        actor_context: context, token: token, issuance: issuance, step_up_evidence: step_up_evidence,
      ).first
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance, step_up_evidence: step_up_evidence,
      )
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base = open_session
      base.host!(base_host)
      base.https!
      target =
        begin
          fv5069 = base
          fv5065 = base_host
          fv5069.get("/sign", params: { ri: "jp" })
          fv5075 = Nokogiri::HTML(fv5069.response.body).at_css('input[name="authenticity_token"]')["value"]
          fv5069.post(
            "/sign", params: { ri: "jp", authenticity_token: fv5075 }, headers: {
              "Origin" => "https://#{fv5065}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          fv5066 = JitSecurityJwtRegistry.surface("BASE_APP")
          fv5071 = URI.parse(fv5069.response.location)
          # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
          unless fv5071.host == fv5065
            fv5073 = Rack::Utils.parse_query(fv5071.query).fetch("rt")
            fv5072, = JWT.decode(
              fv5073, JitSecurityJwtRegistry.public_key_for(
                fv5066.id,
                fv5066.current_kid,
              ), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5065}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            fv5071 = URI.parse(fv5072.fetch("url"))
          end
          fv5069.host!(fv5071.host)
          fv5069.https!
          # The Visa OP authorize endpoint relays an unauthenticated browser to the Auth
          # sign-in entry through a Visa-signed Jump rt; it never renders the ceremony-start
          # form.
          fv5069.get(
            fv5071.request_uri,
            headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
          )
          fv5068 = URI.parse(fv5069.response.location)
          fv5067 = Rack::Utils.parse_query(fv5068.query).fetch("rt")
          fv_visa_surface = JitSecurityJwtRegistry.surface("VISA_APP")
          fv5064, = JWT.decode(
            fv5067, JitSecurityJwtRegistry.public_key_for(
              fv_visa_surface.id,
              fv_visa_surface.current_kid,
            ), true,
            algorithms: ["ES384"],
            verify_iss: true, iss: "https://#{ENV.fetch("PUBLIC_VISA_SERVICE_URL")}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          URI.parse(fv5064.fetch("url"))
        end
      entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
      admission = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      transaction = ClientOidcAuthorizationTransaction.find(admission.authorization_transaction_id)
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      auth_headers = {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      }
      navigation_headers = {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
      }
      begin
        fv5063 = auth
        fv5062 = target.path
        fv5061 = entry_ref
        fv5060 = :entry_ref
        fv5059 = { ri: "jp" }
        fv5058 = auth_headers
        fv5057 = true
        fv5056 = base
        begin
          fv5004 = fv5063
          fv5011 = fv5062
          fv5054 = fv5061
          fv5055 = fv5060
          fv5020 = fv5059
          fv5013 = fv5058
          fv5042 = fv5057
          fv5041 = fv5056
          fv5016 = nil
          fv5010 = fv5020.merge(fv5055 => fv5054)
          # Design D keeps the entry GET as a relay: the sentry hands the browser to the
          # sign-in entry, /sign/in relays it to /ceremony_bindings, and the attachment
          # hands the browser to the Visa confirmation receiver. No hop renders a form.
          fv5004.get(fv5011, params: fv5010, headers: fv5013.merge(navigation_headers))
          fv5044 = nil
          3.times do
            raise RuntimeError, "Auth admission stopped before a redirect" unless fv5004.response.redirect?

            fv5017 = URI.parse(fv5004.response.location)
            if fv5017.host == auth_host
              fv5004.get(fv5017.request_uri, headers: fv5013.merge(navigation_headers))
            else
              fv5044 = fv5004.response.location
              break
            end
          end
          raise RuntimeError, "Auth admission did not reach the confirmation receiver" if fv5044.blank?

          fv5040 = URI.parse(fv5044)
          fv5039 = fv5040.host
          fv5015 =
            begin
              fv5043 = fv5039
              {
                ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
              }.fetch(fv5043)
            end
          fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
            surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
          )

          if fv5042
            fv5022 = fv5041 || fv5004
            fv5022.host!(fv5039)
            fv5022.https!
            fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5038 = fv5040.request_uri
            fv5029 = fv5013.merge(
              "Host" => fv5039,
              "Origin" => "https://#{fv5039}",
              "Sec-Fetch-Site" => "same-origin",
            )
            # The Visa confirmation receiver is GET-only: a top-level navigation GET
            # confirms the binding and hands the browser back to Auth.
            fv5022.get(fv5038, headers: fv5029.merge(navigation_headers))
            fv5021 = fv5022.response.location
            raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

            fv5018 = URI.parse(fv5021)
            if fv5020[:ri].present?
              fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
              fv5019["ri"] ||= fv5020[:ri].to_s
              fv5018.query = URI.encode_www_form(fv5019)
            end
            fv5004.host!(fv5018.host)
            fv5004.https!
            fv5017 = fv5018.request_uri
            fv5000 = fv5013.merge("Host" => fv5018.host)
            fv5004.get(fv5017, headers: fv5000.merge(navigation_headers))
          else
            fv5014.confirm_base!(
              base_token: fv5016,
              browser_digest: AuthAdmissionBinding.browser_digest(
                surface: fv5015,
                entry_ref: fv5014.entry_ref,
                nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
              ),
            )
            fv5012 = fv5004.host
            fv5004.host!(fv5012)
            fv5004.https!
            fv5000 = fv5013.merge("Host" => fv5012)
            fv5004.get(fv5011, params: fv5010, headers: fv5000)
          end
          raise RuntimeError, "Auth admission did not redeem the reference" unless fv5004.response.redirect?

          fv5019 = URI.parse(fv5004.response.location)
          unless fv5019.path == URI.parse(auth_app_sign_in_path(ri: "jp")).path
            raise RuntimeError, "Auth admission did not return to the sign-in entry"
          end

          fv5004.get(fv5019.request_uri, headers: fv5000.merge(navigation_headers))
          raise RuntimeError, "Auth sign-in entry did not render" unless fv5004.response.status == 200
        end
      end
      auth.get(new_auth_app_sign_in_secret_path(ri: "jp"))
      page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
      auth.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :secret => raw,
          :identifier => identifier,
          :authenticity_token => page.fetch("props").fetch("authenticity_token"),
          "cf-turnstile-response" => "synthetic",
        }, headers: auth_headers,
      )
      auth.follow_redirect!
      auth.follow_redirect! if auth.response.redirect?
      # The handoff is a Design D GET: it issues the result reference and relays the
      # browser to Visa's result resource.
      auth.get(
        auth_app_sign_oidc_handoff_path(ri: "jp"), headers: auth_headers.merge(navigation_headers),
      )

      assert_equal 303, auth.response.status
      result_uri = URI.parse(auth.response.location)
      base.host!(result_uri.host)
      base.https!
      base.get(
        result_uri.request_uri, headers: { "Host" => result_uri.host }.merge(navigation_headers),
      )
      result_form = Nokogiri::HTML(base.response.body).at_css("form#visa-authorization-continuation-form")
      result_action = result_form["action"]
      ceremony_action = result_form.at_css('input[name="ceremony_action"]')["value"]
      continuation = result_form.at_css('input[name="continuation"]')["value"]
      authenticity_token = result_form.at_css('input[name="authenticity_token"]')["value"]
      result_origin = "https://#{result_uri.host}"
      flow = ClientSignInFlow.find(transaction.reload.secret_sign_in_flow_id)
      credential = ClientSecretCredential.find_by!(issuance_id: issuance.id)
      ceremony = ClientAuthCeremonySession.find(credential.claim_ceremony_session_id)
      duplicate = open_session
      duplicate.host!(result_uri.host)
      duplicate.https!
      # Two in-flight requests from the same legitimate pre-completion browser. Clone the
      # cookies this browser sends to the continuation host: the jar is sorted by name, so
      # `to_hash` would collapse the Base and Visa sessions into whichever sorts last.
      continuation_uri = URI.parse("https://#{result_uri.host}/")
      base.cookies.for(continuation_uri).split("; ").each do |raw_cookie|
        duplicate.cookies.merge(raw_cookie, continuation_uri)
      end
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      futures = nil
      if outcome == :completion
        futures =
          [base, duplicate].map do |browser|
            Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
              # Rack completion runs after the explicit connection scope returns its lease.
              response_finished = []
              begin
                AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                  connection.execute("SET lock_timeout = '10000'")
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  browser.post(
                    result_action, params: { ceremony_action: ceremony_action,
                                             continuation: continuation,
                                             authenticity_token: authenticity_token, },
                                   headers: { "Origin" => result_origin, "Sec-Fetch-Site" => "same-origin" },
                                   env: { "rack.response_finished" => response_finished },
                  )
                  browser.response.status
                ensure
                  connection.execute("RESET lock_timeout")
                end
              ensure
                response_finished.reverse_each do |callback|
                  callback.call(browser.request.env, browser.response.status, browser.response.headers, nil)
                end
              end
            rescue StandardError => e
              ready << e
              raise
            ensure
              # Release model-clock leases before the dedicated worker exits.
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          end
        pids = Timeout.timeout(10) { [ready.pop, ready.pop] }
        pids.each { |entry| raise entry if entry.is_a?(Exception) }
        2.times { release << true }

        assert_equal 2, pids.uniq.length
      else
        # The configured two-connection pool supports one observer and one
        # blocked HTTP request. The second stale callback is sent afterward.
        actor.with_lock do
          futures = [
            Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
              # Rack completion runs after the explicit connection scope returns its lease.
              response_finished = []
              begin
                AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                  connection.execute("SET lock_timeout = '10000'")
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  base.post(
                    result_action, params: { ceremony_action: ceremony_action,
                                             continuation: continuation,
                                             authenticity_token: authenticity_token, },
                                   headers: { "Origin" => result_origin, "Sec-Fetch-Site" => "same-origin" },
                                   env: { "rack.response_finished" => response_finished },
                  )
                  base.response.status
                ensure
                  connection.execute("RESET lock_timeout")
                end
              ensure
                response_finished.reverse_each do |callback|
                  callback.call(base.request.env, base.response.status, base.response.headers, nil)
                end
              end
            rescue StandardError => e
              ready << e
              raise
            ensure
              # Release model-clock leases before the dedicated worker exits.
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end,
          ]
          pid = Timeout.timeout(10) { ready.pop }
          raise pid if pid.is_a?(Exception)

          release << true
          Timeout.timeout(10) do
            loop do
              if futures.first.complete?
                raise RuntimeError, "completion escaped the Client lock barrier"
              end

              blocked =
                Client.uncached do
                  Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
                end
              break if blocked

              Thread.pass
            end
          end

          assert_not_equal Client.lease_connection.select_value("SELECT pg_backend_pid()"), pid
          OpBaseAppRecord.transaction do
            flow.lock!
            if outcome == :cancellation
              flow.halt_sign_in!
            else
              flow.update!(expires_at: ClientSignInFlow.database_now)
              flow.expire_sign_in!
            end
          end
        end
      end
      statuses = Timeout.timeout(15) { futures.map(&:value!) }
      unless outcome == :completion
        duplicate.post(
          result_action, params: { ceremony_action: ceremony_action,
                                   continuation: continuation,
                                   authenticity_token: authenticity_token, },
                         headers: { "Origin" => result_origin, "Sec-Fetch-Site" => "same-origin" },
        )
        statuses << duplicate.response.status
      end
      expected = (outcome == :completion) ? [303, 400] : [400, 400]

      assert_equal expected, statuses.sort
      assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
      assert_equal (outcome == :completion) ? 2 : 1, ClientToken.where(user_id: actor.id).count
      receipts = ClientSecretSignInReceipt.where(credential_ref: credential.public_id)

      assert_equal (outcome == :completion) ? 1 : 0, receipts.count
      if outcome == :completion
        root = ClientToken.find_by!(id: flow.reload.token_id, user_id: actor.id)

        assert_equal root.public_id, receipts.first.root_token_ref
        assert_equal actor.public_id, receipts.first.client_ref
        assert credential.reload.consumed_at
        assert_predicate root, :currently_usable?
        assert_equal 1, [base, duplicate].count { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] }
      else
        assert_equal 400, duplicate.response.status
        assert_nil flow.reload.token_id
        assert_nil credential.reload.consumed_at
        assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.day)
        assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
        assert [base, duplicate].all? { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil? }
      end
    ensure
      2.times { release << true } if release
      futures&.each { |future| future.wait(15) }
      if actor
        # OP grants have a strict-loaded logout hint. Destroying the grant via the
        # association can raise during teardown and skip the root-token cleanup,
        # leaving ClientSignInFlow.token_id pointing at a missing token for later
        # fixture loads. Delete the owned child rows explicitly before the grant.
        token_ids = ClientToken.where(user_id: actor.id).pluck(:id)
        OpBaseAppRecord.connected_to(role: :writing) do
          stop_ids = OpAppAuthorityStopRootTarget.where(root_id: token_ids).pluck(:stop_id)
          OpAppAuthorityStopParticipant.where(stop_id: stop_ids).delete_all
          OpAppAuthorityStopEpochCutoff.where(stop_id: stop_ids).delete_all
          OpAppAuthorityStopGrantTarget.where(stop_id: stop_ids).delete_all
          OpAppAuthorityStopRootTarget.where(stop_id: stop_ids).delete_all
          OpAppAuthorityStop.where(id: stop_ids).delete_all
          grant_ids = OpAppGrant.where(client_token_id: token_ids).pluck(:id)
          OpAppGrantLogoutHint.where(grant_id: grant_ids).delete_all
          OpAppGrant.where(id: grant_ids).delete_all
        end
        ClientSecretSignInReceipt.where(client_ref: actor.public_id).find_each(&:destroy!)
        flow_ids = ClientSignInFlow.where("id > ?", @client_sign_in_flow_id_before_test).or(
          ClientSignInFlow.where(principal_id: actor.id),
        ).pluck(:id)
        flow_ids << flow.id if flow && flow_ids.exclude?(flow.id)
        unless flow_ids.empty?
          transaction_rows = ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow_ids)
          transaction_ids = transaction_rows.select(:id)
          auth_transaction_refs = transaction_rows.pluck(:transaction_id)
          ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow_ids).or(
            ClientSessionLimitResolutionTransaction.where(oidc_authorization_transaction_id: transaction_ids),
          ).find_each(&:destroy!)
          admission_rows = ClientAuthAdmissionBinding.where(authorization_transaction_id: transaction_ids)
          ceremony_ids = admission_rows.pluck(
            :auth_ceremony_session_id,
            :admitted_auth_ceremony_session_id,
          ).flatten.compact
          ClientAuthAdmissionBinding.where(id: admission_rows.select(:id)).find_each(&:destroy!)
          transaction_rows.find_each(&:destroy!)
          ceremony_ids.concat(
            ClientAuthCeremonySession.where(authorization_transaction_ref: auth_transaction_refs).pluck(:id),
          )
          ceremony_ids.concat(
            ClientAuthCeremonySession.where("id > ?", @client_auth_ceremony_session_id_before_test).pluck(:id),
          )
          ceremony_ids << ceremony.id if ceremony && ceremony_ids.exclude?(ceremony.id)
          ceremony_ids.uniq!
          loop do
            previous_digests = ClientAuthCeremonySession.where(id: ceremony_ids).pluck(:previous_sid_digest).compact
            previous_ids = ClientAuthCeremonySession.where(sid_digest: previous_digests)
              .where.not(id: ceremony_ids).pluck(:id)
            break if previous_ids.empty?

            ceremony_ids.concat(previous_ids)
            ceremony_ids.uniq!
          end
          ClientAuthCeremonySession.where(id: ceremony_ids).find_each(&:destroy!)
          ClientSignInFlow.where(id: flow_ids).find_each(&:destroy!)
        end
        Chronicle.where(subject_type: "Client", subject_id: actor.id).find_each(&:destroy!)
        ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
        ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
        ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
        ClientToken.where(user_id: actor.id).find_each(&:destroy!)
        # An Identity is physically erased only once it has lapsed and is purgeable.
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        destroy_test_client_after_cross_database_cleanup!(actor)
      end
    end
  end

  private

  # This fixture walks the complete Base-to-Auth browser handoff.
end
