# frozen_string_literal: true

require "test_helper"

class AdmissionBindingDeadlineIntentTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    test "#{surface} issuance stores an immutable OP-clock curfew and explicit authentication intent" do
      client_id, resource_type, model =
        case surface
        when "app" then ["core-app-jp", "client", ClientAuthAdmissionBinding]
        when "com" then ["core-com-jp", "visitor", VisitorAuthAdmissionBinding]
        when "org" then ["core-org-jp", "operator", OperatorAuthAdmissionBinding]
        end
      prompts = (surface == "org") ? [nil] : [nil, "create"]
      prompts.each do |prompt|
        parent = OidcAuthorizationTransactionCoordinator.issue!(
          surface: surface, intent: "authentication",
          params: {
            client_id: client_id,
            redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(resource_type).first,
            response_type: "code",
            scope: "openid profile",
            state: SecureRandom.hex(16),
            nonce: SecureRandom.hex(16),
            code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            code_challenge_method: "S256",
            prompt: prompt,
          },
        ).transaction
        before = model.database_now
        issued = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        after = model.database_now
        binding = model.find_by!(entry_ref: issued.reference)

        assert_equal((prompt == "create") ? "sign_up" : "sign_in", binding.entry_intent)
        assert_operator binding.curfew_at, :>=, before + 30.minutes
        assert_operator binding.curfew_at, :<=, after + 30.minutes
        assert_operator binding.expires_at, :<, binding.curfew_at, "Acceptance TTL remains separate until WU-06"
        %i(curfew_at entry_intent).each do |fact|
          changed =
            if fact == :curfew_at
              binding.curfew_at + 1.second
            else
              (binding.entry_intent == "sign_in") ? "sign_up" : "sign_in"
            end
          assert_raises(AuthAdmissionBinding::InvalidTransition) { binding.update!(fact => changed) }
          binding.reload
        end
      end
    end

    test "#{surface} database rejects missing deadlines and intent-purpose mismatches" do
      client_id, resource_type, model =
        case surface
        when "app" then ["core-app-jp", "client", ClientAuthAdmissionBinding]
        when "com" then ["core-com-jp", "visitor", VisitorAuthAdmissionBinding]
        when "org" then ["core-org-jp", "operator", OperatorAuthAdmissionBinding]
        end
      parent = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface, intent: "authentication",
        params: {
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(resource_type).first,
          response_type: "code",
          scope: "openid profile",
          state: SecureRandom.hex(16),
          nonce: SecureRandom.hex(16),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
        },
      ).transaction
      issued = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = model.find_by!(entry_ref: issued.reference)
      [{ curfew_at: nil }, { entry_intent: nil }, { entry_intent: "" },
       { entry_intent: "not_applicable" }, { entry_intent: "unknown" },].each do |attributes|
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { binding.update_columns(attributes) }
        end
        binding.reload
      end
    end
  end

  %w(app com).each do |surface|
    test "#{surface} Switch copies the original curfew instead of minting a later one" do
      client_id, resource_type, model =
        case surface
        when "app" then ["core-app-jp", "client", ClientAuthAdmissionBinding]
        when "com" then ["core-com-jp", "visitor", VisitorAuthAdmissionBinding]
        end
      parent = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface, intent: "authentication",
        params: {
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(resource_type).first,
          response_type: "code",
          scope: "openid profile",
          state: SecureRandom.hex(16),
          nonce: SecureRandom.hex(16),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
        },
      ).transaction
      nonce = SecureRandom.hex(32)
      # Zero original Bindings is below the supported Switch-history boundary; the loop below
      # exercises one original Binding and then multiple redeemed Bindings with one curfew.
      assert_no_difference -> { model.count } do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseAuthAdmissionCoordinator.issue_switch_admission!(
            transaction: parent, base_browser_nonce: nonce, base_token: nil, target: "sign_up",
          )
        end
      end
      issued = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: nonce,
        base_token: nil,
      )
      binding = model.find_by!(entry_ref: issued.reference)
      session_class = model.auth_admission_session_class
      original_deadline = binding.curfew_at
      %w(sign_up sign_in).each do |target|
        attached, raw_sid = session_class.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        admitted, = session_class.rotate_and_admit!(
          previous_raw_sid: raw_sid, admission_purpose: "authentication_handoff",
          authorization_transaction_ref: parent.transaction_id,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
        admitted.cancel!
        later = model.database_now + 5.minutes
        replacement =
          model.stub(:database_now, later) do
            BaseAuthAdmissionCoordinator.issue_switch_admission!(
              transaction: parent, base_browser_nonce: nonce, base_token: nil, target: target,
            )
          end
        switched = model.find_by!(entry_ref: replacement.reference)

        assert_equal target, switched.entry_intent
        assert_equal original_deadline, switched.curfew_at
        assert_operator switched.curfew_at, :<, later + 30.minutes
        binding = switched
      end
    end
  end

  test "app Switch reads the earlier ceremonies in one query however many Switches the parent has had" do
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        client_id: "core-app-jp",
        redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
        response_type: "code",
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    nonce = SecureRandom.hex(32)
    issued = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issued.reference)
    ceremony_selects = []
    # Three Switches: the last one runs with three redeemed Bindings behind it.
    %w(sign_up sign_in sign_up).each do |target|
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      admitted, = ClientAuthCeremonySession.rotate_and_admit!(
        previous_raw_sid: raw_sid, admission_purpose: "authentication_handoff",
        authorization_transaction_ref: parent.transaction_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
      admitted.cancel!
      ceremony_selects.clear
      counter =
        lambda do |*, payload|
          ceremony_selects << payload[:sql] if payload[:sql].match?(/\ASELECT .*FROM "client_auth_ceremony_sessions"/)
        end
      replacement =
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          BaseAuthAdmissionCoordinator.issue_switch_admission!(
            transaction: parent, base_browser_nonce: nonce, base_token: nil, target: target,
          )
        end
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: replacement.reference)
    end

    assert_equal 1, ceremony_selects.size, ceremony_selects.join("\n")
  end

  test "app Switch is refused while an earlier redeemed Binding's ceremony is still live" do
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        client_id: "core-app-jp",
        redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
        response_type: "code",
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    nonce = SecureRandom.hex(32)
    issued = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issued.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      previous_raw_sid: raw_sid, admission_purpose: "authentication_handoff",
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)

    assert_no_difference -> { ClientAuthAdmissionBinding.count } do
      error =
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseAuthAdmissionCoordinator.issue_switch_admission!(
            transaction: parent, base_browser_nonce: nonce, base_token: nil, target: "sign_up",
          )
        end
      assert_equal "invalid_admission", error.code
    end
    assert_not admitted.reload.cancelled?
  end

  test "re-verification stores not_applicable and rejects authentication intent on all realms" do
    [
      ["app", clients(:one), ClientToken, { user: clients(:one) }, ClientStepUpCeremonyTransaction,
       ClientAuthAdmissionBinding,],
      ["com", visitors(:reserved_visitor), VisitorToken, { visitor: visitors(:reserved_visitor) },
       VisitorStepUpCeremonyTransaction, VisitorAuthAdmissionBinding,],
      ["org", operators(:one), OperatorToken, { staff: operators(:one) }, OperatorStepUpCeremonyTransaction,
       OperatorAuthAdmissionBinding,],
    ].each do |surface, actor, token_class, owner, parent_class, binding_class|
      token = token_class.create!(**owner, authentication_epoch: actor.authentication_epoch)
      parent = parent_class.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
        required_aal: "none", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:#{surface}",
      )
      issued = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: token,
      )
      binding = binding_class.find_by!(entry_ref: issued.reference)

      assert_equal "not_applicable", binding.entry_intent
      assert_not_nil binding.curfew_at
      %w(sign_in sign_up).each do |intent|
        assert_raises(ActiveRecord::StatementInvalid) do
          binding_class.transaction(requires_new: true) { binding.update_columns(entry_intent: intent) }
        end
        binding.reload
      end
    end
  end
end
