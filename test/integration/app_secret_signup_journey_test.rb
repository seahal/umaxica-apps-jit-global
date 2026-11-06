# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretSignupJourneyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  SECRET_LIFETIME_VALUES = {
    "APP_SECRET_ISSUANCE_TTL_SECONDS" => "600",
    "APP_SECRET_PURGE_DELAY_SECONDS" => "86400",
    "APP_SECRET_OUTBOX_RETENTION_SECONDS" => "604800",
    "APP_SECRET_PROOF_RETENTION_SECONDS" => "2592000",
  }.freeze

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_lifetimes = ENV.to_h.slice(*SECRET_LIFETIME_VALUES.keys)
    SECRET_LIFETIME_VALUES.each { |key, value| ENV[key] = value }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    SECRET_LIFETIME_VALUES.each_key do |key|
      @previous_lifetimes.key?(key) ? ENV[key] = @previous_lifetimes.fetch(key) : ENV.delete(key)
    end
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil

    contact = ClientTelephone.find_by(public_id: @telephone_public_id) if @telephone_public_id
    contact ||= ClientTelephone.find_by(number: @telephone_number) if @telephone_number
    flow = ClientSignUpFlow.find_by(public_id: @flow_public_id) if @flow_public_id
    flow ||= ClientSignUpFlow.find_by(pending_contact_type: "telephone", pending_contact_id: contact.id) if contact
    actor_id = contact&.user_id || flow&.principal_id
    actor = Client.find_by(id: actor_id) if actor_id

    if actor
      binding_id = @auth_admission_binding_id || flow&.auth_admission_binding_id
      binding = ClientAuthAdmissionBinding.find_by(id: binding_id) if binding_id
      parent_ids = binding&.authorization_transaction_id ? [binding.authorization_transaction_id] : []
      ceremony_ids = [binding&.auth_ceremony_session_id, binding&.admitted_auth_ceremony_session_id].compact

      # Every completed sign-up case runs IdentityGraphProvisioner, which bootstraps a persona, an
      # enterprise and a root unit for the new actor, and these cases commit instead of rolling
      # back (uses_transaction). None of those tables has a fixture file, so without this the next
      # fixture load re-enables the enterprise foreign key against a row that is already gone.
      # The ids are materialized here, while the membership rows still exist, because a lazy
      # relation would re-run its subquery after they were deleted.
      identity_ids = ClientIdentity.where(source_record_id: actor.id).pluck(:id)
      persona_ids = ClientPersona.where(client_identity_id: identity_ids).pluck(:id)
      enterprise_ids =
        (PersonaMembership.where(persona_id: persona_ids).pluck(:enterprise_id) +
          EnterpriseOwnership.where(client_id: actor.id).pluck(:enterprise_id)).uniq
      unit_ids = EnterpriseUnit.where(enterprise_id: enterprise_ids).pluck(:id)
      PersonaMembership.where(persona_id: persona_ids)
        .or(PersonaMembership.where(enterprise_id: enterprise_ids)).delete_all
      PersonaAssignment.where(persona_id: persona_ids).delete_all
      ClientOidcIdentityBinding.where(client_identity_id: identity_ids).delete_all
      AvatarPersonaBinding.where(persona_id: persona_ids).delete_all
      ClientPersonaOwnership.where(client_persona_id: persona_ids).delete_all
      ClientPersonaLifecycle.where(client_persona_id: persona_ids).delete_all
      ClientPersona.where(id: persona_ids).delete_all
      ClientIdentity.where(id: identity_ids).delete_all
      EnterpriseUnitClosure.where(ancestor_id: unit_ids)
        .or(EnterpriseUnitClosure.where(descendant_id: unit_ids)).delete_all
      EnterpriseUnit.where(id: unit_ids).delete_all
      EnterpriseLifecycle.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnership.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseAdministrationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseDelegationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseViewGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnershipTransferRequest.where(enterprise_id: enterprise_ids).delete_all
      Enterprise.where(id: enterprise_ids).delete_all

      ClientTelephoneCeremonyTransaction.where(telephone_candidate_ref: contact.public_id).delete_all if contact
      ClientPasskeyCeremonyTransaction.where(actor_ref: actor.public_id).delete_all
      ClientContactAuditOutbox.where(owner_ref: actor.public_id).delete_all
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).delete_all
      ClientSecretCredential.where(client_id: actor.id).delete_all
      ClientSecretIssuance.where(client_id: actor.id).delete_all
      ClientPasskey.where(user_id: actor.id).delete_all
      ClientSignUpFlow.where(id: flow.id).delete_all if flow
      ClientAuthAdmissionBinding.where(id: binding_id).delete_all if binding_id
      ClientAuthCeremonySession.where(id: ceremony_ids).delete_all if ceremony_ids.any?
      ClientOidcAuthorizationTransaction.where(id: parent_ids).delete_all if parent_ids.any?
      ClientTelephone.where(user_id: actor.id).delete_all
      ClientAuthorityLock.where(client_id: actor.id).delete_all
      token_ids = ClientToken.where(user_id: actor.id).select(:id)
      OpAppGrant.where(client_token_id: token_ids).delete_all
      ClientDeviceSession.where(user_id: actor.id).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: actor.id).delete_all
      ClientDeviceSession.where(user_id: actor.id).delete_all
      # Registration completion receipts are durable rows keyed by the actor; they commit with
      # these cases and would otherwise block the client delete below.
      ClientRegistrationCompletion.where(client_id: actor.id).delete_all
      ClientAccount.where(user_id: actor.id).delete_all
      Client.where(id: actor.id).delete_all
    end
  end

  SIGNUP_CASES = (0..20).map { |count| [count, :completed] } +
    [[0, :canceled], [0, :expired], [0, :payload_unavailable]]
  # The telephone OTP writer refuses the caller-owned fixture transaction; exercise its request commit boundary.
  uses_transaction(
    *SIGNUP_CASES.map do |active_count, outcome|
      "test_telephone_signup_with_A=#{active_count}_saves_its_fixed_Secret_set_and_handles_#{outcome}"
    end,
  )

  SIGNUP_CASES.each do |active_count, outcome|
    test "telephone signup with A=#{active_count} saves its fixed Secret set and handles #{outcome}" do # rubocop:disable Minitest/MultipleAssertions -- Verifies each observable boundary in one signup journey.
      host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host!(base_host)
      https!
      get "/sign", params: { ri: "jp" }
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      }
      issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      target = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
      # This registration journey asks the OP for prompt=create. A neutral RP sign-in request
      # no longer authorizes entering signup merely by visiting its contact page (D-72).
      target.query = URI.encode_www_form(URI.decode_www_form(target.query) + [["prompt", "create"]])
      host!(target.host)
      https!
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      get target.request_uri

      assert_response :see_other
      auth_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_uri.host == base_host
        second_rt = Rack::Utils.parse_query(auth_uri.query).fetch("rt")
        # WU-02: the hop from the authorization step to Auth is issued by Visa.
        visa_issuer = JitSecurityJwtRegistry.surface("VISA_APP")
        second_payload, = JWT.decode(
          second_rt, JitSecurityJwtRegistry.public_key_for(visa_issuer.id, visa_issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{visa_host_for_test_base_host(base_host)}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_uri = URI.parse(second_payload.fetch("url"))
      end
      host!(auth_uri.host)
      get auth_uri.request_uri, headers: headers

      12.times do
        if response.redirect?
          location = URI.parse(response.location)
          if location.host == "jump.umaxica.net"
            jump_token = Rack::Utils.parse_query(location.query).fetch("rt")
            jump_payload, = JWT.decode(jump_token, nil, false)
            location = URI.parse(jump_payload.fetch("url"))
          end
          host!(location.host) if location.host
          get location.request_uri, headers: {
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          }
        else
          form = response.parsed_body.at_css("form[id$='continuation-form'], form[id$='confirmation-form']")
          break unless form

          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          post form["action"], params: fields, headers: {
            "Origin" => "https://#{request.host}", "Sec-Fetch-Site" => "same-origin",
          }
        end
      end

      assert_equal 200, response.status, "admission stopped before the Auth page"
      assert_equal host, request.host
      get new_auth_app_sign_up_telephone_path(ri: "jp")

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      @telephone_number = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      post auth_app_sign_up_telephone_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
        :user_telephone => { raw_number: @telephone_number, confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response" => "synthetic",
      }

      registration = session[:user_telephone_registration]
      @telephone_public_id = registration.stringify_keys.fetch("public_id") if registration
      @flow_public_id = session[:auth_app_up_sequence_id] if session[:auth_app_up_sequence_id]

      assert_response :redirect
      telephone = ClientTelephone.find_by!(public_id: @telephone_public_id)
      flow = ClientSignUpFlow.find_by!(public_id: session[:auth_app_up_sequence_id])
      @flow_public_id = flow.public_id
      @auth_admission_binding_id = flow.auth_admission_binding_id
      flow_binding = SignFlowBindingCodec.encode(flow: flow, surface: :app)
      transaction = ClientTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: telephone.public_id)
      delivery =
        (enqueued_jobs + performed_jobs).reverse.find do |entry|
          next false unless entry.fetch(:job) == Outbound::SmsDeliveryJob

          encrypted = entry.fetch(:args).fetch(0).fetch("encrypted_payload")
          OutboundSensitivePayload.decrypt_sms_delivery(encrypted).fetch(:otp_binding)[3] == transaction.transaction_id
        end
      delivery_params = OutboundSensitivePayload.decrypt_sms_delivery(
        delivery.fetch(:args).fetch(0).fetch("encrypted_payload"),
      )
      code = delivery_params.fetch(:otp_code)

      assert_equal ["app", "sign_up", flow.public_id, transaction.transaction_id,
                    transaction.otp_generation,], delivery_params.fetch(:otp_binding)
      queued_contains_code = JSON.generate(delivery.fetch(:args)).include?(code)

      assert_not queued_contains_code, "Queued SMS must not contain the plaintext signup code"
      patch auth_app_sign_up_check_telephone_otp_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf), params: {
              user_telephone: { pass_code: code },
            }

      assert_response :redirect
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

      assert_predicate transaction.reload.otp_consumed_at, :present?
      assert_nil transaction.otp_verifier
      flow.reload
      get auth_app_sign_up_guard_telephone_path(ri: "jp", fb: flow_binding)
      actor = Client.find(telephone.user_id)
      now = Client.database_now
      active_count.times do
        # Holdings are setup facts; the HTTP registration allocates its own batch.
        prior = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
          browser_session_ref: SecureRandom.base58(21), planned_count: 1, expires_at: now + 1.minute,
          presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: prior, name: "Existing", password: raw,
          confirmed_at: now,
        )
      end
      get auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding)

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      post auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
           headers: headers.merge("X-CSRF-Token" => csrf),
           as: :json

      assert_response :success
      options = response.parsed_body
      credential = WebAuthn::FakeClient.new("https://#{host}", encoding: :base64url).create(
        challenge: options.fetch("options").fetch("challenge"), user_verified: true,
      )
      patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf), params: {
              challenge_id: options.fetch("challenge_id"),
              credential: credential,
              checkpoint_version: flow.checkpoint_version,
            }, as: :json

      assert_response :created
      assert_not flow.reload.requirement_cleared?(:passkey)
      issuance = ClientSecretIssuance.find_by!(sign_up_flow_ref: flow.public_id)
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      destination = response.parsed_body.fetch("redirect_url")
      assert_no_difference(["ClientSecretIssuance.count", "ClientPasskey.count", "ClientSecretCredential.count"]) do
        patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf), params: {
                challenge_id: options.fetch("challenge_id"),
                credential: credential,
                checkpoint_version: flow.checkpoint_version,
              }, as: :json
      end
      assert_response :created
      assert_equal destination, response.parsed_body.fetch("redirect_url")
      get destination

      assert_response :success
      assert_no_difference("ClientSecretCredential.count") {
        get auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding)
      }
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      if active_count == 19
        assert_equal I18n.t("base.app.secrets.distribution_one_present"), page.fetch("props").fetch("notice")
      elsif active_count == 20
        assert_equal I18n.t("base.app.secrets.distribution_omitted"), page.fetch("props").fetch("notice")
        assert_equal "omitted", page.fetch("props").fetch("state")
        assert_nil issuance.expires_at
        assert_nil issuance.encrypted_payload
        assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_no_difference("ClientSecretCredential.count") do
          post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
               headers: headers.merge("X-CSRF-Token" => csrf)
        end
        assert_response :forbidden
        assert_nil issuance.reload.encrypted_payload
      else
        assert_nil page.fetch("props").fetch("notice")
      end
      values = []
      if outcome == :payload_unavailable
        nonce = SignUpSessionState.for(session, surface: :app).cycle_payload.stringify_keys.fetch("nonce")
        ClientSecretPresentationIssuer.prepare_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)
        issuance.reload.update!(encrypted_payload: nil)
        passkey_ids = ClientPasskey.where(user_id: actor.id).pluck(:public_id)
        assert_no_difference ["ClientSecretCredential.count", "ClientPasskey.count", "ClientToken.count"] do
          post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
               headers: headers.merge("X-CSRF-Token" => csrf)
        end

        assert_not flow.reload.requirement_cleared?(:passkey)
        assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, actor.reload.status_id
        assert_equal passkey_ids, ClientPasskey.where(user_id: actor.id).pluck(:public_id)
        assert_not_nil issuance.reload.canceled_at
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_response :gone
        assert_equal 2, ClientSecretCredential.where(issuance_id: issuance.id).where.not(discard_at: Float::INFINITY).count
        assert_equal ["payload_unavailable"], ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id,
          event_name: %w(secret.issuance_canceled secret.discarded),
        ).distinct.pluck(:reason)
        patch auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf),
              params: { checkpoint_version: flow.checkpoint_version, stored: "1" }

        assert_response :forbidden
        assert_not flow.reload.requirement_cleared?(:passkey)
        assert_nil issuance.reload.confirmed_at
        next
      end
      if expected_count.positive?
        post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
             headers: headers.merge("X-CSRF-Token" => csrf)

        assert_response :success
        assert_equal "strict-origin", response.headers["Referrer-Policy"]
        assert_equal "strict-origin", response.parsed_body.at_css('meta[name="referrer"]')["content"]
        values = response.parsed_body.css("[data-secret-value] code").map(&:text)
        cancel_form = response.parsed_body.at_css('form input[name="_method"][value="delete"]')

        assert cancel_form, "single-delivery cancellation must submit the protected DELETE endpoint"
        assert_equal expected_count, values.length
        values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
        csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      end
      confirmation = { checkpoint_version: flow.checkpoint_version }
      confirmation[:stored] = "1" if expected_count.positive?
      patch auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf),
            params: confirmation

      assert_response :see_other
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

      assert flow.reload.requirement_cleared?(:passkey)
      assert issuance.reload.confirmed_at if expected_count.positive?

      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, Client.find(telephone.user_id).status_id
      get auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding)

      assert_response :success
      completed_page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      expected_notice =
        case active_count
        when 19 then I18n.t("base.app.secrets.distribution_one_confirmed")
        when 20 then I18n.t("base.app.secrets.distribution_omitted")
        end
      if expected_notice
        assert_equal expected_notice, completed_page.fetch("props").fetch("notice")
      else
        assert_nil completed_page.fetch("props").fetch("notice")
      end
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      if outcome != :completed
        if outcome == :canceled
          delete auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding),
                 headers: headers.merge("X-CSRF-Token" => csrf)

          assert_response :see_other
          assert_predicate flow.reload, :sign_up_cancelled?
        else
          overdue_at = Client.database_now - 1.second
          flow.update_columns(
            issued_at: overdue_at - 1.second,
            expires_at: overdue_at,
          ) # Test setup: make the DB-clock deadline overdue.
          SignUpExpiryJob.perform_now

          assert_equal ClientSignUpFlowStatus::EXPIRED, flow.reload.status_id
        end

        assert_nil issuance.reload.signup_completed_at
        assert_nil issuance.encrypted_payload
        assert_operator issuance.discard_at, :<=, Client.database_now + 1.day
        values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
        assert_equal 0,
                     ClientSecretCapacityQuery.call(client: Client.find(telephone.user_id), at: Client.database_now)
                       .active_count
        reason = (outcome == :canceled) ? "flow_canceled" : "flow_expired"

        assert_equal 2, ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: reason,
        ).where.not(credential_ref: nil).count
        next
      end
      assert_no_difference("ClientToken.count") do
        patch auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf), params: {
                requirement: "birthdate",
                checkpoint_version: flow.reload.checkpoint_version,
                birthdate_year: "1990",
                birthdate_month: "01",
                birthdate_day: "15",
              }
      end
      assert_response :redirect
      assert_predicate flow.reload, :sign_up_completed?
      contact_intent = ClientContactAuditOutbox.find_by!(operation_ref: flow.public_id)

      assert_equal "finalized", contact_intent.event_name
      assert_equal "telephone", contact_intent.contact_kind
      assert_equal telephone.public_id, contact_intent.contact_ref
      assert_equal actor.public_id, contact_intent.owner_ref
      assert_nil contact_intent.actor_ref
      assert_nil contact_intent.acknowledged_at
      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, Client.find(telephone.user_id).status_id
      assert_equal active_count + expected_count, ClientSecretCapacityQuery.call(
        client: actor, at: Client.database_now,
      ).active_count
      assert issuance.reload.signup_completed_at
      assert_equal 1, ClientSecretAuditOutbox.where(
        operation_ref: issuance.origin_operation_id, event_name: "secret.signup_completed",
      ).count
      assert_no_difference("ClientSecretAuditOutbox.count") do
        ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
      end
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.update!(signup_completed_at: nil) }
      if active_count.zero?
        admission_binding = ClientAuthAdmissionBinding.find(flow.auth_admission_binding_id)
        authorization_transaction = ClientOidcAuthorizationTransaction.find(
          admission_binding.authorization_transaction_id,
        )

        assert_equal "app", authorization_transaction.surface
        assert_equal "sign_up", authorization_transaction.intent
        assert_not_predicate authorization_transaction, :base_finalized?
        cancellation = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: authorization_transaction)
        BaseAuthAdmissionCoordinator.read_authorization_cancellation_handoff!(
          handoff: cancellation.handoff, surface: "app", transaction_ref: authorization_transaction.transaction_id,
        )
        authorization_transaction.cancel!(
          cancellation_handoff_digest: BaseAuthAdmissionCoordinator.cancellation_handoff_digest(cancellation.handoff),
        )

        assert_predicate authorization_transaction.reload, :canceled?
        assert_not_predicate authorization_transaction, :base_finalized?
        assert_predicate flow.reload, :sign_up_completed?
        assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, Client.find(telephone.user_id).status_id

        issuance.reload
        completed_at = issuance.signup_completed_at
        credential_facts = ClientSecretCredential.where(issuance_id: issuance.id).order(:id)
          .pluck(:public_id, :confirmed_at, :revoked_at, :discard_at)
        audit_facts = ClientSecretAuditOutbox.where(operation_ref: issuance.origin_operation_id)
          .order(:id).pluck(:event_name, :credential_ref, :occurred_at, :item_count)

        assert_equal expected_count, credential_facts.length
        assert credential_facts.all? { |_, confirmed_at, revoked_at, discard_at|
          confirmed_at.present? && revoked_at.nil? && discard_at == Float::INFINITY
        }, "completed Secret credentials must remain active before lifecycle reconciliation"

        ClientSecretLifecycleJob.perform_now(batch_size: 500, phase: "signup")

        assert_predicate flow.reload, :sign_up_completed?
        assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, Client.find(telephone.user_id).status_id
        assert_equal completed_at, issuance.reload.signup_completed_at
        assert_equal credential_facts, ClientSecretCredential.where(issuance_id: issuance.id).order(:id)
          .pluck(:public_id, :confirmed_at, :revoked_at, :discard_at)
        assert_equal audit_facts, ClientSecretAuditOutbox.where(operation_ref: issuance.origin_operation_id)
          .order(:id).pluck(:event_name, :credential_ref, :occurred_at, :item_count)
      end
      flow.destroy!

      values.each { |value| assert ClientSecretLookupQuery.call(client: actor, secret: value) }
    end
  end
end
