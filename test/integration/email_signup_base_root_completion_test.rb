# frozen_string_literal: true

require "test_helper"

# Boolean comparisons prevent retained browser and proof material from appearing in failure output.
# Each journey keeps admission, signup, and exact proof replay in the same real browser context.
# rubocop:disable Minitest/MultipleAssertions
class EmailSignupBaseRootCompletionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SignInFlowCleanup

  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    # The test lock serializes these HTTP journeys; retain pre-existing rows for scoped cleanup.
    @initial_client_ids = Client.pluck(:id)
    @initial_signup_ids = ClientSignUpFlow.pluck(:id)
    @initial_binding_ids = ClientAuthAdmissionBinding.pluck(:id)
    @initial_ceremony_ids = ClientAuthCeremonySession.pluck(:id)
    @initial_parent_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  teardown do
    # Delivery runs after real commits, so rollback fixtures cannot clean up this journey.
    owners = Client.where.not(id: @initial_client_ids).to_a
    owner_ids = owners.map(&:id)
    # Completed signup also commits the actor's bootstrap identity and collective graph.
    owners.each do |owner|
      identity_ids = ClientIdentity.where(source_record_id: owner.id).pluck(:id)
      persona_ids = ClientPersona.where(client_identity_id: identity_ids).pluck(:id)
      enterprise_ids =
        (PersonaMembership.where(persona_id: persona_ids).pluck(:enterprise_id) +
          EnterpriseOwnership.where(client_id: owner.id).pluck(:enterprise_id)).uniq
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
    end
    flows = ClientSignUpFlow.where.not(id: @initial_signup_ids).to_a
    session_refs =
      flows.map do |flow|
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      end
    ClientEmailCeremonyTransaction.where(session_ref: session_refs).delete_all
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
    ClientAuthAdmissionBinding.where.not(id: @initial_binding_ids).delete_all
    ClientAuthCeremonySession.where.not(id: @initial_ceremony_ids).delete_all
    ClientOidcAuthorizationTransaction.where.not(id: @initial_parent_ids).delete_all
    delete_client_sign_in_flows!(ClientSignInFlow.where(principal_id: owner_ids))
    token_ids = ClientToken.where(user_id: owner_ids).select(:id)
    OpAppGrant.where(client_token_id: token_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: owner_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).delete_all
    ClientContactAuditOutbox.where(owner_ref: owners.map(&:public_id)).delete_all
    ClientEmail.where(user_id: owner_ids).delete_all
    ClientAccount.where(user_id: owner_ids).delete_all
    ClientOidcConnection.where(user_id: owner_ids).delete_all
    ClientRegistrationCompletion.where(client_id: owner_ids).delete_all
    ClientAuthorityLock.where(client_id: owner_ids).delete_all
    Client.where(id: owner_ids).delete_all
  end

  %w(app).each do |surface|
    test "#{surface} email signup binds its original OIDC browser and Visa commits exactly one root" do
      previous_protection = ActionController::Base.allow_forgery_protection
      previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
      previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
      ActionController::Base.allow_forgery_protection = true
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      base_host, auth_host, issuer_name, signup_model, contact_model, actor_model, token_model, owner_key,
        contact_parameter =
        case surface
        when "app"
          [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
           "BASE_APP", ClientSignUpFlow, ClientEmail, Client, ClientToken, :user_id, :client_email,]
        end
      visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
      owner = open_session
      owner.host!(base_host)
      owner.https!
      base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => nil }
      auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => nil }
      owner.get("/sign", params: { ri: "jp" })

      assert_equal 200, owner.response.status
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(
        "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: base_headers,
      )

      assert_equal 303, owner.response.status

      issuer = JitSecurityJwtRegistry.surface(issuer_name)
      # Visa is the OP: Base's /sign POST hands off to Visa, whose authorize GET starts the
      # ceremony and Jump-hands the browser to Auth's admission entry.
      target = URI.parse(owner.response.location)
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

      # A registration journey explicitly requests create; a neutral admission no longer
      # authorizes signup merely because a later browser request visits that page (D-72).
      target.query = URI.encode_www_form(URI.decode_www_form(target.query) + [["prompt", "create"]])

      assert_equal "https", target.scheme
      assert_equal visa_host, target.host
      owner.host!(target.host)
      owner.get(target.request_uri, params: { ri: "jp" })

      assert_equal 303, owner.response.status
      # Visa signs its own Jump to the Auth admission entry.
      entry_target = URI.parse(owner.response.location)
      entry_rt = Rack::Utils.parse_query(entry_target.query).fetch("rt")
      visa_issuer = JitSecurityJwtRegistry.surface("VISA_APP")
      entry_payload, = JWT.decode(
        entry_rt, JitSecurityJwtRegistry.public_key_for(visa_issuer.id, visa_issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{visa_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      entry_target = URI.parse(entry_payload.fetch("url"))
      entry_reference = Rack::Utils.parse_query(entry_target.query).fetch("entry_ref")
      navigation_headers = {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
      }
      owner.host!(entry_target.host)
      owner.get(entry_target.request_uri, headers: navigation_headers)

      assert_equal 303, owner.response.status
      # Auth's admission entry walks sentry -> sign-up entry -> /ceremony_bindings as document
      # navigations until it hands the browser to the Visa confirmation.
      2.times do
        hop = URI.parse(owner.response.location)

        assert_equal "https", hop.scheme
        owner.host!(hop.host)
        owner.get(hop.request_uri, headers: navigation_headers)

        assert_equal 303, owner.response.status
      end
      # A GET outside a document navigation renders the non-consuming confirmation
      # representation; the browser's own navigation records base_confirmed_at and returns
      # it to Auth, where the reference is redeemed.
      confirmation = URI.parse(owner.response.location)

      assert_equal "https", confirmation.scheme
      assert_equal visa_host, confirmation.host
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: entry_reference)
      parent = authorization_transaction_for_test(binding)
      original_parent_id = parent.id
      original_binding_id = binding.id
      owner.host!(confirmation.host)
      owner.get(confirmation.request_uri)

      assert_equal 200, owner.response.status
      form = owner.response.parsed_body.at_css("form")

      assert_not_nil form, "the ceremony binding confirmation must render its form"
      assert_nil binding.reload.base_confirmed_at
      owner.get(confirmation.request_uri, headers: navigation_headers)

      assert_equal 303, owner.response.status
      assert_withheld { binding.reload.base_confirmed_at.present? }
      entry_return = URI.parse(owner.response.location)

      assert_equal "https", entry_return.scheme
      owner.host!(entry_return.host)
      owner.get(entry_return.request_uri, headers: navigation_headers)

      assert_equal 303, owner.response.status
      assert_withheld { binding.reload.redeemed? }
      auth = owner

      assert_equal 303, auth.response.status
      assert_withheld { binding.reload.redeemed? }
      ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)

      assert_withheld("Auth must retain the original OIDC parent") {
        ceremony.authorization_transaction_ref == parent.transaction_id
      }

      switch_browser_to_sign_up!(auth, surface: surface.to_s)
      auth.get("/sign/up/email/new", params: { ri: "jp" })

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.post(
        "/sign/up/email", params: {
          contact_parameter => { raw_address: "signup-root-#{surface}-#{SecureRandom.hex(8)}@example.com",
                                 confirm_policy: "1", },
          :authenticity_token => csrf,
          "cf-turnstile-response" => "test",
          :ri => "jp",
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      otp_uri = URI.parse(auth.response.location)
      locator = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
      decoded = SignFlowBindingCodec.decode(locator)
      signup = signup_model.find_by!(public_id: decoded.flow_public_id)
      contact = contact_model.find(signup.pending_contact_id)
      actor = actor_model.find(contact[owner_key])

      assert_equal 0, token_model.where(owner_key => actor.id).count
      transaction_model = ClientEmailCeremonyTransaction
      transaction = transaction_model.find_by!(email_candidate_ref: contact.public_id)
      delivery =
        (enqueued_jobs + performed_jobs).reverse.find do |entry|
          next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

          notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
          notification.fetch(:params).fetch(:sign_up_email_transaction_ref) == transaction.transaction_id
        end
      notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
      delivery_params = notification.fetch(:params)
      code = OutboundSensitivePayload.decrypt_email_otp(delivery_params.fetch(:encrypted_hotp_token))

      assert_withheld("Delivery must name the original signup") {
        delivery_params.fetch(:sign_up_flow_ref) == signup.public_id
      }
      assert_withheld("Delivery must name the current typed ceremony generation") {
        delivery_params.fetch(:sign_up_email_otp_generation) == transaction.otp_generation
      }
      queued_contains_code = JSON.generate(delivery.fetch(:args)).include?(code)

      assert_not queued_contains_code, "Queued delivery must not contain plaintext code"
      auth.get(otp_uri.request_uri)

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.patch(
        otp_uri.request_uri, params: {
          :user_email => { pass_code: code }, :authenticity_token => csrf, "cf-turnstile-response" => "test",
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      assert_withheld("The actual browser must consume its typed Email proof") {
        transaction.reload.otp_consumed_at.present?
      }
      active_verifier_cleared = transaction.otp_verifier.nil?

      assert active_verifier_cleared, "Fresh consumption must remove the active verifier"
      birthdate_uri = URI.parse(auth.response.location)

      signup.reload
      checkpoint_binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(birthdate_uri.query).fetch("fb"))

      assert_equal decoded.flow_public_id, checkpoint_binding.flow_public_id
      assert_equal signup.step, checkpoint_binding.phase
      assert_equal signup.checkpoint_version, checkpoint_binding.generation
      assert_equal signup.expires_at.to_i, checkpoint_binding.expires_at
      assert_not_equal decoded.phase, checkpoint_binding.phase
      auth.get(birthdate_uri.request_uri)

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.patch(
        birthdate_uri.request_uri, params: {
          requirement: "birthdate",
          birthdate: "2000-01-01",
          checkpoint_version: signup.reload.checkpoint_version,
          authenticity_token: csrf,
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      assert_withheld { signup.reload.sign_up_completed? }
      assert_withheld { contact.reload.binding_effective? }
      assert_equal 0, token_model.where(owner_key => actor.id).count
      auth.get(URI.parse(auth.response.location).request_uri)

      assert_equal 302, auth.response.status
      handoff_uri = URI.parse(auth.response.location)

      assert_equal "/sign/oidc/handoff", handoff_uri.path
      auth.get(handoff_uri.request_uri)

      assert_equal 400, auth.response.status
      assert_nil parent.reload.base_finalized_at
      auth.get(handoff_uri.request_uri, headers: navigation_headers)

      assert_equal 303, auth.response.status
      completion = URI.parse(auth.response.location)

      assert_equal "https", completion.scheme
      assert_equal visa_host, completion.host
      assert_equal "/oidc/result", completion.path
      submission = Rack::Utils.parse_query(completion.query)

      assert_withheld("Result must name the original OIDC parent") {
        submission.fetch("transaction_ref") == parent.transaction_id
      }
      assert_withheld("Result must bind the original Contact owner") { parent.reload.actor_ref == actor.public_id }
      assert_equal "email_otp", parent.auth_method
      before_parent = parent.reload.attributes
      before_contact = contact.reload.attributes
      foreign = open_session
      foreign.host!(visa_host)
      foreign.https!
      foreign.get(completion.request_uri, headers: navigation_headers)

      assert_equal 400, foreign.response.status
      assert_withheld("Another browser must not consume the owner's proof") {
        before_parent == parent.reload.attributes
      }
      assert_equal 0, token_model.where(owner_key => actor.id).count

      owner.host!(visa_host)
      owner.get(completion.request_uri, headers: navigation_headers)

      assert_equal 200, owner.response.status
      assert_withheld("Visa GET must not finalize the parent") { before_parent == parent.reload.attributes }
      assert_equal 0, token_model.where(owner_key => actor.id).count
      form = owner.response.parsed_body.at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      visa_headers = { "Origin" => "https://#{visa_host}", "Sec-Fetch-Site" => "same-origin" }
      owner.post(form["action"], params: fields.except("authenticity_token"), headers: visa_headers)

      assert_equal 422, owner.response.status
      assert_withheld("CSRF refusal must preserve the OIDC parent") { before_parent == parent.reload.attributes }
      assert_equal 0, token_model.where(owner_key => actor.id).count
      foreign.post(form["action"], params: fields, headers: visa_headers)

      assert_equal 422, foreign.response.status
      assert_withheld { before_parent == parent.reload.attributes }
      owner.post(form["action"], params: fields, headers: visa_headers)

      assert_equal 303, owner.response.status
      assert_withheld { parent.reload.base_finalized_at.present? }
      root = token_model.where(owner_key => actor.id).sole

      assert_equal root.public_id, parent.browser_session_ref
      assert_equal original_parent_id, parent.id
      assert_equal original_binding_id, binding.reload.id
      assert_equal original_parent_id, binding.authorization_transaction_id
      assert_withheld("Completion must preserve the finalized Contact") { before_contact == contact.reload.attributes }
      finalized_parent = parent.attributes
      owner.get(completion.request_uri, headers: navigation_headers)

      assert_equal 400, owner.response.status
      owner.post(form["action"], params: fields, headers: visa_headers)

      assert_equal 422, owner.response.status
      assert_equal 1, token_model.where(owner_key => actor.id).count
      assert_withheld("Replay must preserve the committed parent and Root") {
        parent.reload.attributes == finalized_parent &&
          token_model.find_by!(public_id: parent.browser_session_ref).id == root.id
      }
    ensure
      ActionController::Base.allow_forgery_protection = previous_protection
      TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
      TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    end
  end
end
# rubocop:enable Minitest/MultipleAssertions
