# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAdmissionBindingTest < ActiveSupport::TestCase
  fixtures :client_tokens

  test "confirmation references require UUID version four at adjacent representable versions in every realm" do
    %w(app com org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      auth_session, = binding.class.auth_admission_session_class.issue!
      ["00000000-0000-3000-8000-000000000001", "00000000-0000-5000-8000-000000000001"].each do |reference|
        assert_raises(AuthAdmissionBinding::InvalidTransition, "#{surface}: UUID version adjacent to four") do
          binding.attach_auth_session!(auth_session:, confirmation_ref: reference)
        end
        assert_equal [nil, nil], [binding.reload.auth_ceremony_session_id, binding.confirmation_ref]
      end
      reference = "00000000-0000-4000-8000-000000000001"
      binding.attach_auth_session!(auth_session:, confirmation_ref: reference)

      assert_equal [auth_session.id, reference], [binding.reload.auth_ceremony_session_id, binding.confirmation_ref]
    end
  end

  test "every realm database rejects invalid parent and partial admission proof writes" do
    %w(app com org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      auth_session, = binding.class.auth_admission_session_class.issue!
      invalid_writes = [
        [{ authorization_transaction_id: nil }, "one_parent"],
        [{ step_up_ceremony_transaction_id: binding.authorization_transaction_id }, "one_parent"],
        [{ purpose: "step_up_handoff", entry_intent: "not_applicable" }, "parent_purpose"],
        # D-60: the retired Local purposes have no parent that accepts them.
        [{ purpose: "local_sign_in" }, "entry_intent"],
        [{ purpose: "local_sign_up" }, "entry_intent"],
        [{ confirmation_ref: SecureRandom.uuid }, "auth_proof_pair"],
        [{ auth_ceremony_session_id: auth_session.id }, "auth_proof_pair"],
        [{ base_confirmed_at: binding.class.database_now }, "confirmation_requires_auth"],
        [{ redeemed_at: binding.class.database_now }, "redemption_pair"],
        [{ admitted_auth_ceremony_session_id: auth_session.id }, "redemption_pair"],
      ]
      invalid_writes.each do |attributes, constraint|
        error =
          assert_raises(ActiveRecord::StatementInvalid, "#{surface}: #{constraint}") do
            binding.class.transaction(requires_new: true) do
              # Deliberately bypass model validation through public persistence to check actual DB invariants.
              binding.update_columns(attributes)
            end
          end

        # The purpose/intent CHECK also rejects retired purposes before the parent CHECK.
        expected =
          if constraint == "entry_intent"
            "admission_binding_entry_intent"
          else
            "admission_bindings_#{constraint}"
          end

        assert_includes error.message, expected
        assert_equal [nil, nil, nil, nil],
                     [binding.reload.auth_ceremony_session_id, binding.confirmation_ref,
                      binding.base_confirmed_at, binding.redeemed_at,]
      end

      %i(entry_ref purpose base_browser_digest expires_at).each do |fact|
        changed =
          case fact
          when :entry_ref then SecureRandom.uuid
          when :purpose then "invitation_handoff"
          when :base_browser_digest then "b" * 64
          when :expires_at then binding.expires_at + 1.second
          end
        assert_raises(AuthAdmissionBinding::InvalidTransition, "#{surface}: immutable #{fact}") do
          binding.update!(fact => changed)
        end
        binding.reload
      end

      duplicate = binding.attributes.except("id").merge("entry_ref" => SecureRandom.uuid)
      assert_raises(ActiveRecord::RecordNotUnique, "#{surface}: one live binding per parent") do
        binding.class.transaction(requires_new: true) { binding.class.create!(duplicate) }
      end
      assert_equal issuance.transaction.id, binding.reload.authorization_transaction_id
    end
  end

  test "each realm binding expiry uses a strict deadline at the nearest database microsecond" do
    %w(app com org).each do |surface|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      deadline = binding.expires_at
      microsecond = Rational(1, 1_000_000)

      assert binding.live?(now: deadline - microsecond), "#{surface}: immediately below expiry"
      assert_not binding.expired?(now: deadline - microsecond), surface
      assert_not binding.live?(now: deadline), surface
      assert binding.expired?(now: deadline), "#{surface}: exactly at expiry"
      assert_not binding.live?(now: deadline + microsecond), surface
      assert binding.expired?(now: deadline + microsecond), "#{surface}: immediately above expiry"
      assert_equal deadline, binding.reload.expires_at
      assert_nil binding.retired_at
      assert_nil binding.redeemed_at
    end
  end

  test "each realm database refuses redemption without a Base confirmation" do
    [
      ["app", ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ].each do |surface, binding_model, session_model|
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = binding_model.find_by!(entry_ref: issuance.reference)
      auth_session, = session_model.issue!
      binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
      binding.assign_attributes(
        redeemed_at: binding_model.database_now, admitted_auth_ceremony_session_id: auth_session.id,
      )

      assert_not_predicate binding, :valid?, "model validation also requires Base confirmation"
      binding.reload
      assert_raises(ActiveRecord::StatementInvalid, surface) do
        binding_model.transaction(requires_new: true) do
          # This direct public persistence write deliberately bypasses model validation to exercise the CHECK.
          binding.update_columns(
            redeemed_at: binding_model.database_now,
            admitted_auth_ceremony_session_id: auth_session.id,
          )
        end
      end

      assert_nil binding.reload.redeemed_at
      assert_nil binding.admitted_auth_ceremony_session_id
      assert_nil binding.base_confirmed_at
    end
  end

  test "binding transitions reject caller-supplied decision clocks" do
    binding =
      begin
        fv5021 =
          begin
            fv5024 = SecureRandom.uuid
            fv5023 = ClientOidcAuthorizationTransaction.database_now
            ClientOidcAuthorizationTransaction.create_transaction!(
              surface: "app",
              intent: "sign_in",
              client_id: "test-client",
              redirect_uri: "https://client.example.test/callback",
              response_type: "code",
              scope: "openid",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              login_challenge: fv5024,
              login_challenge_expires_at: fv5023 + 10.minutes,
              expires_at: fv5023 + 10.minutes,
              now: fv5023,
            )
          end
        fv5022 = {}
        fv5020 = fv5022.except
        ClientAuthAdmissionBinding.create!(
          begin
            {
              entry_ref: SecureRandom.uuid,
              purpose: "authentication_handoff",
              entry_intent: "sign_in",
              curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
              base_browser_digest: "a" * 64,
              expires_at: 10.minutes.from_now,
              created_at: Time.current,
              updated_at: Time.current,
            }
          end.merge(authorization_transaction_id: fv5021.id).merge(fv5020),
        )
      end
    auth_session, = ClientAuthCeremonySession.issue!
    assert_raises(ArgumentError) do
      binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid, now: 1.day.ago)
    end
    assert_raises(ArgumentError) do
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest, now: 1.day.ago)
    end
    assert_raises(ArgumentError) do
      binding.redeem!(auth_session: auth_session, admitted_auth_session: auth_session, now: 1.day.ago)
    end
    assert_raises(ArgumentError) { binding.retire!(now: 1.day.ago) }
    assert_not_predicate binding.reload, :attached?
    assert_not_predicate binding, :confirmed?
    assert_not_predicate binding, :redeemed?
    assert_not_predicate binding, :retired?
  end

  test "distinct pending parents may attach the same active Auth continuity in every realm" do
    [
      ["app", ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ].each do |surface, binding_model, session_model|
      browser_nonce = SecureRandom.urlsafe_base64(32)
      first = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: browser_nonce, base_token: nil,
      )
      second = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: browser_nonce, base_token: nil,
      )
      first_binding = binding_model.find_by!(entry_ref: first.reference)
      second_binding = binding_model.find_by!(entry_ref: second.reference)
      auth_session, = session_model.issue!
      first_binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
      second_binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)

      assert_not_equal first.transaction.id, second.transaction.id
      assert_not_equal first_binding.entry_ref, second_binding.entry_ref
      assert_equal auth_session.id, first_binding.reload.auth_ceremony_session_id
      assert_equal auth_session.id, second_binding.reload.auth_ceremony_session_id
      assert_nil first_binding.base_confirmed_at
      assert_nil second_binding.base_confirmed_at
      assert_nil first_binding.redeemed_at
      assert_nil second_binding.redeemed_at
      assert_not_predicate auth_session.reload, :admitted?
    end
  end

  test "rejects zero or multiple admission parents and partial proof pairs" do
    attrs =
      begin
        {
          entry_ref: SecureRandom.uuid,
          purpose: "authentication_handoff",
          entry_intent: "sign_in",
          curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
          base_browser_digest: "a" * 64,
          expires_at: 10.minutes.from_now,
          created_at: Time.current,
          updated_at: Time.current,
        }
      end

    assert_not ClientAuthAdmissionBinding.new(attrs).valid?

    multiple = ClientAuthAdmissionBinding.new(
      attrs.merge(
        authorization_transaction_id: 1,
        step_up_ceremony_transaction_id: 1,
      ),
    )

    assert_not multiple.valid?
    assert_includes multiple.errors[:base], "exactly one admission parent is required"

    partial = ClientAuthAdmissionBinding.new(attrs.merge(auth_ceremony_session_id: 1))

    assert_not partial.valid?
    assert_includes partial.errors[:base], "Auth session and confirmation reference must be supplied together"
  end

  test "attaches, confirms and redeems once without reopening terminal facts" do
    parent =
      begin
        fv5019 = SecureRandom.uuid
        fv5018 = ClientOidcAuthorizationTransaction.database_now
        ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app",
          intent: "sign_in",
          client_id: "test-client",
          redirect_uri: "https://client.example.test/callback",
          response_type: "code",
          scope: "openid",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          login_challenge: fv5019,
          login_challenge_expires_at: fv5018 + 10.minutes,
          expires_at: fv5018 + 10.minutes,
          now: fv5018,
        )
      end
    entry_ref = SecureRandom.uuid
    digest = AuthAdmissionBinding.browser_digest(
      surface: "app", entry_ref:, nonce: "base-browser-nonce",
    )
    binding =
      begin
        fv5016 = parent
        fv5017 = {
          entry_ref:,
          base_token_id: client_tokens(:one).id,
          base_browser_digest: digest,
        }
        fv5015 = fv5017.except
        ClientAuthAdmissionBinding.create!(
          begin
            {
              entry_ref: SecureRandom.uuid,
              purpose: "authentication_handoff",
              entry_intent: "sign_in",
              curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
              base_browser_digest: "a" * 64,
              expires_at: 10.minutes.from_now,
              created_at: Time.current,
              updated_at: Time.current,
            }
          end.merge(authorization_transaction_id: fv5016.id).merge(fv5015),
        )
      end
    auth_session, raw_sid = ClientAuthCeremonySession.issue!

    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: client_tokens(:one), browser_digest: digest)

    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: parent.transaction_id,
    )
    binding.redeem!(auth_session:, admitted_auth_session: admitted)

    binding.reload

    assert_predicate binding, :redeemed?
    assert_predicate binding, :confirmed?
    assert_equal admitted.id, binding.admitted_auth_ceremony_session_id
    assert_raises(AuthAdmissionBinding::InvalidTransition) { binding.retire! }
    assert_nothing_raised do
      binding.redeem!(auth_session:, admitted_auth_session: admitted)
    end
  end

  test "rejects changes to immutable identity and proof facts" do
    binding =
      begin
        fv5011 =
          begin
            fv5014 = SecureRandom.uuid
            fv5013 = ClientOidcAuthorizationTransaction.database_now
            ClientOidcAuthorizationTransaction.create_transaction!(
              surface: "app",
              intent: "sign_in",
              client_id: "test-client",
              redirect_uri: "https://client.example.test/callback",
              response_type: "code",
              scope: "openid",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              login_challenge: fv5014,
              login_challenge_expires_at: fv5013 + 10.minutes,
              expires_at: fv5013 + 10.minutes,
              now: fv5013,
            )
          end
        fv5012 = {}
        fv5010 = fv5012.except
        ClientAuthAdmissionBinding.create!(
          begin
            {
              entry_ref: SecureRandom.uuid,
              purpose: "authentication_handoff",
              entry_intent: "sign_in",
              curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
              base_browser_digest: "a" * 64,
              expires_at: 10.minutes.from_now,
              created_at: Time.current,
              updated_at: Time.current,
            }
          end.merge(authorization_transaction_id: fv5011.id).merge(fv5010),
        )
      end

    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(purpose: "invitation_handoff")
    end
    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(base_browser_digest: "b" * 64)
    end
    assert_raises(AuthAdmissionBinding::InvalidTransition) do
      binding.update!(expires_at: 30.minutes.from_now)
    end
  end

  test "same parent has one live binding, and expiry is retired explicitly" do
    parent =
      begin
        fv5009 = SecureRandom.uuid
        fv5008 = ClientOidcAuthorizationTransaction.database_now
        ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app",
          intent: "sign_in",
          client_id: "test-client",
          redirect_uri: "https://client.example.test/callback",
          response_type: "code",
          scope: "openid",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          login_challenge: fv5009,
          login_challenge_expires_at: fv5008 + 10.minutes,
          expires_at: fv5008 + 10.minutes,
          now: fv5008,
        )
      end
    first =
      begin
        fv5006 = parent
        fv5007 = {}
        fv5005 = fv5007.except
        ClientAuthAdmissionBinding.create!(
          begin
            {
              entry_ref: SecureRandom.uuid,
              purpose: "authentication_handoff",
              entry_intent: "sign_in",
              curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
              base_browser_digest: "a" * 64,
              expires_at: 10.minutes.from_now,
              created_at: Time.current,
              updated_at: Time.current,
            }
          end.merge(authorization_transaction_id: fv5006.id).merge(fv5005),
        )
      end
    second = ClientAuthAdmissionBinding.new(
      begin
        {
          entry_ref: SecureRandom.uuid,
          purpose: "authentication_handoff",
          entry_intent: "sign_in",
          curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
          base_browser_digest: "a" * 64,
          expires_at: 10.minutes.from_now,
          created_at: Time.current,
          updated_at: Time.current,
        }
      end.merge(authorization_transaction_id: parent.id),
    )

    assert_raises(ActiveRecord::RecordNotUnique) { second.save!(validate: true) }

    expired =
      begin
        fv5001 =
          begin
            fv5004 = "expired-#{SecureRandom.uuid}"
            fv5003 = ClientOidcAuthorizationTransaction.database_now
            ClientOidcAuthorizationTransaction.create_transaction!(
              surface: "app",
              intent: "sign_in",
              client_id: "test-client",
              redirect_uri: "https://client.example.test/callback",
              response_type: "code",
              scope: "openid",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              login_challenge: fv5004,
              login_challenge_expires_at: fv5003 + 10.minutes,
              expires_at: fv5003 + 10.minutes,
              now: fv5003,
            )
          end
        fv5002 = { expires_at: 1.second.ago }
        fv5000 = fv5002.except
        ClientAuthAdmissionBinding.create!(
          begin
            {
              entry_ref: SecureRandom.uuid,
              purpose: "authentication_handoff",
              entry_intent: "sign_in",
              curfew_at: ClientAuthAdmissionBinding.database_now + 30.minutes,
              base_browser_digest: "a" * 64,
              expires_at: 10.minutes.from_now,
              created_at: Time.current,
              updated_at: Time.current,
            }
          end.merge(authorization_transaction_id: fv5001.id).merge(fv5000),
        )
      end

    assert_not expired.live?
    expired.retire!

    assert_predicate expired.reload, :retired?
    assert_not expired.redeemed?
    assert_equal first.id, first.reload.id
  end

  private
end
