# typed: false
# frozen_string_literal: true

# Base issues and Auth/Base consume purpose-specific opaque admission/result
# codes. Raw codes never persist; Valkey OpaqueAdmissionStore keys by digest.
class BaseAuthAdmissionCoordinator < ApplicationService
  # `code` is the internal refusal taxonomy for logs; responses stay generic.
  class Denied < StandardError
    attr_reader :code

    public

    def initialize(message = nil, code: "unclassified")
      unless IdentityStepUpCeremonyContract::REFUSAL_CODES.include?(code)
        raise ArgumentError, "unknown refusal code: #{code.inspect}"
      end

      super(message)
      @code = code
    end
  end

  TICKET_CEREMONY_PURPOSES = %w(step_up reauthentication bootstrap credential_registration credential_change).freeze

  SURFACE_ACTOR = {
    "app" => "client",
    "com" => "visitor",
    "org" => "operator",
  }.freeze

  HANDOFF_PURPOSE = {
    "authentication" => "authentication_handoff",
    "sign_in" => "authentication_handoff",
    "sign_up" => "authentication_handoff",
    "invitation" => "invitation_handoff",
    "step_up" => "step_up_handoff",
    "reauthentication" => "reauthentication_handoff",
    "bootstrap" => "bootstrap_handoff",
    "credential_registration" => "credential_registration_handoff",
    "credential_change" => "credential_change_handoff",
  }.freeze

  RESULT_PURPOSE = {
    "authentication" => "authentication_result",
    "sign_in" => "authentication_result",
    "sign_up" => "authentication_result",
    "invitation" => "invitation_result",
    "step_up" => "step_up_result",
    "reauthentication" => "reauthentication_result",
    "bootstrap" => "bootstrap_result",
    "credential_registration" => "credential_registration_result",
    "credential_change" => "credential_change_result",
  }.freeze

  LOCAL_ENTRY_PURPOSE = {
    "sign_in" => "local_sign_in",
    "sign_up" => "local_sign_up",
  }.freeze

  CEREMONY_SESSION = {
    "app" => ClientAuthCeremonySession,
    "com" => VisitorAuthCeremonySession,
    "org" => OperatorAuthCeremonySession,
  }.freeze

  LOCAL_SIGN_IN_FLOW = {
    "app" => ClientSignInFlow,
    "com" => VisitorSignInFlow,
    "org" => OperatorSignInFlow,
  }.freeze

  STEP_UP_TRANSACTION = {
    "app" => ClientStepUpCeremonyTransaction,
    "com" => VisitorStepUpCeremonyTransaction,
    "org" => OperatorStepUpCeremonyTransaction,
  }.freeze

  Issuance = Data.define(:transaction, :code, :reference)

  class << self
    public

    def issue_handoff!(transaction:, reference: transaction.transaction_id, store: default_store)
      purpose = handoff_purpose_for(transaction.intent)
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface),
        surface: transaction.surface,
        subject_ref: transaction.transaction_id,
        reference: reference,
      )
      Issuance.new(transaction: transaction, code: code, reference: reference)
    end

    def consume_handoff!(raw_code:, surface:, expected_intent:, store: default_store)
      purpose = handoff_purpose_for(expected_intent)
      consume_code!(
        purpose: purpose,
        raw_code: raw_code,
        surface: surface,
        store: store,
      )
    end

    def issue_local_entry!(surface:, intent:, nonce_digest: nil, store: default_store)
      purpose = local_entry_purpose_for(intent)
      model = LOCAL_SIGN_IN_FLOW.fetch(surface.to_s)
      transaction =
        model.connection_class_for_self.connected_to(role: :writing) do
          now = model.database_now
          model.create!(
            step: "primary", status_id: model.status_id_for("PRIMARY_PENDING"),
            nonce_digest: nonce_digest || model.digest_nonce(SecureRandom.urlsafe_base64(32)),
            issued_at: now, expires_at: now + model.default_ttl,
          )
        end
      reference = transaction.public_id
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(surface.to_s),
        surface: surface,
        subject_ref: reference,
        reference: reference,
      )
      Issuance.new(transaction: transaction, code: code, reference: reference)
    end

    def consume_local_entry!(raw_code:, surface:, expected_intent:, store: default_store)
      purpose = local_entry_purpose_for(expected_intent)
      result = store.consume!(
        purpose: purpose,
        raw_code: raw_code,
        expected: binding_expectations(surface: surface),
      )
      raise Denied.new("local admission missing", code: "invalid_admission") if result.missing?
      raise Denied.new("local admission replay", code: "admission_replay") if result.replay?
      raise Denied.new("local admission binding mismatch", code: "invalid_admission") if result.binding_mismatch?
      raise Denied.new("local admission rejected", code: "invalid_admission") unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def consume_entry_reference!(reference:, surface:, expected_intent:, store: default_store)
      result = store.consume_reference!(
        reference: reference,
        purposes: admission_reference_purposes(expected_intent),
        expected: binding_expectations(surface: surface),
      )
      raise Denied.new("local admission missing", code: "invalid_admission") if result.missing?
      raise Denied.new("local admission replay", code: "admission_replay") if result.replay?
      raise Denied.new("local admission binding mismatch", code: "invalid_admission") if result.binding_mismatch?
      raise Denied.new("local admission rejected", code: "invalid_admission") unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def issue_result!(transaction:, ceremony_session_ref: nil, store: default_store)
      purpose = result_purpose_for(transaction.intent)
      reference = SecureRandom.uuid
      raw_code = SecureRandom.urlsafe_base64(Valkey::AuthState::OpaqueAdmissionStore::CODE_BYTES, padding: false)
      result_digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(
        purpose: purpose,
        raw_code: raw_code,
      )
      _locked_transaction, generation = transaction.prepare_result_delivery!(
        result_digest: result_digest,
        ttl: Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL,
      )
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface),
        surface: transaction.surface,
        subject_ref: transaction.transaction_id,
        reference: reference,
        ceremony_session_ref: ceremony_session_ref,
        result_generation: generation,
        raw_code: raw_code,
      )
      Issuance.new(transaction: transaction, code: code, reference: reference)
    end

    def resolve_step_up_admission!(payload:, surface:, expected_intent:)
      unless TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)
        raise Denied.new("unsupported ceremony purpose", code: "malformed_request")
      end

      validate_payload!(payload, surface: surface)
      unless payload.fetch("purpose") == handoff_purpose_for(expected_intent)
        raise Denied.new("admission purpose mismatch", code: "invalid_admission")
      end

      model = STEP_UP_TRANSACTION.fetch(surface.to_s)
      model.connection_owner.connected_to(role: :writing) do
        transaction = model.find_by!(transaction_id: payload.fetch("subject_ref"), surface: surface.to_s)
        unless transaction.purpose == expected_intent.to_s && %w(pending verified).include?(transaction.status) &&
            !transaction.expired?(now: model.database_now)
          raise Denied.new(
            "ceremony is unavailable",
            code: transaction.unavailable_refusal_code(
              expected_purposes: [expected_intent.to_s],
              now: model.database_now,
            ),
          )
        end

        transaction
      end
    rescue KeyError, ActiveRecord::RecordNotFound
      raise Denied.new("admission transaction missing", code: "invalid_admission")
    end

    def read_result!(raw_code:, surface:, transaction_ref:, expected_intent:, store: default_store)
      raise Denied.new("admission binding mismatch", code: "invalid_admission") if transaction_ref.to_s.blank?

      purpose = result_purpose_for(expected_intent)
      payload = store.read(raw_code, purpose: purpose)
      raise Denied.new("admission missing", code: "invalid_admission") if payload.blank?

      validate_payload!(payload, surface: surface)
      raise Denied.new(
        "admission purpose mismatch",
        code: "invalid_admission",
      ) unless payload.fetch("purpose") == purpose
      raise Denied.new(
        "admission binding mismatch",
        code: "invalid_admission",
      ) unless payload.fetch("subject_ref") == transaction_ref.to_s

      transaction = result_transaction!(
        surface: surface, transaction_ref: transaction_ref,
        expected_intent: expected_intent,
      )
      generation = Integer(payload.fetch("result_generation").to_s, 10)
      digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose:, raw_code: raw_code)
      raise Denied.new(
        "admission binding mismatch",
        code: "invalid_admission",
      ) unless transaction.result_delivery_matches?(
        result_digest: digest,
        result_generation: generation,
      )

      payload
    rescue KeyError, ArgumentError
      raise Denied.new("admission rejected", code: "invalid_admission")
    end

    def register_result_and_issue!(surface:, login_challenge:, actor:, session_ref:, auth_method:, acr: nil,
                                   authentication_event_at: nil, ceremony_session_ref: nil,
                                   store: default_store)
      transaction = OidcAuthorizationTransactionCoordinator.model_for(surface).find_by!(
        surface: surface,
        login_challenge: login_challenge,
      )
      if transaction.authenticated?
        raise Denied.new(
          "authentication actor mismatch",
          code: "session_binding_mismatch",
        ) unless transaction.actor_ref == actor.public_id
      else
        transaction = OidcAuthorizationTransactionCoordinator.register_result!(
          surface: surface,
          login_challenge: login_challenge,
          actor: actor,
          session_ref: session_ref,
          auth_method: auth_method,
          acr: acr,
          authentication_event_at: authentication_event_at,
        ).transaction
      end

      issue_result!(transaction: transaction, ceremony_session_ref: ceremony_session_ref, store: store)
    end

    def ceremony_session_class(surface)
      CEREMONY_SESSION.fetch(surface.to_s)
    end

    def handoff_purpose_for(intent)
      HANDOFF_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported admission intent" }
    end

    def result_purpose_for(intent)
      RESULT_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported admission intent" }
    end

    def local_entry_purpose_for(intent)
      LOCAL_ENTRY_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported local entry intent" }
    end

    def local_entry_purpose?(payload:, intent:)
      purpose = LOCAL_ENTRY_PURPOSE[intent.to_s]
      purpose.present? && payload.fetch("purpose").to_s == purpose
    end

    private

    private :handoff_purpose_for, :result_purpose_for, :local_entry_purpose_for

    def consume_code!(purpose:, raw_code:, surface:, store:)
      result = store.consume!(
        purpose: purpose,
        raw_code: raw_code,
        expected: binding_expectations(surface: surface),
      )
      raise Denied.new("admission missing", code: "invalid_admission") if result.missing?
      raise Denied.new("admission replay", code: "admission_replay") if result.replay?
      raise Denied.new("admission binding mismatch", code: "invalid_admission") if result.binding_mismatch?
      raise Denied.new("admission rejected", code: "invalid_admission") unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def result_transaction!(surface:, transaction_ref:, expected_intent:)
      if TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)
        model = STEP_UP_TRANSACTION.fetch(surface.to_s)
        model.connection_owner.connected_to(role: :writing) do
          transaction = model.find_by!(transaction_id: transaction_ref, surface: surface.to_s)
          raise Denied.new(
            "admission purpose mismatch",
            code: "invalid_admission",
          ) unless transaction.purpose == expected_intent.to_s

          transaction
        end
      else
        OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: surface, transaction_id: transaction_ref,
        )
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission transaction missing", code: "invalid_admission")
    end

    def validate_payload!(payload, surface:)
      raise Denied.new("admission rejected", code: "invalid_admission") if payload.blank?
      raise Denied.new(
        "admission surface mismatch",
        code: "invalid_admission",
      ) unless payload.fetch("surface").to_s == surface.to_s

      actor = SURFACE_ACTOR.fetch(surface.to_s)
      raise Denied.new(
        "admission actor mismatch",
        code: "invalid_admission",
      ) unless payload.fetch("actor_type").to_s == actor
    end

    def binding_expectations(surface:, subject_ref: nil)
      expected = {
        actor_type: SURFACE_ACTOR.fetch(surface.to_s),
        surface: surface.to_s,
      }
      expected[:subject_ref] = subject_ref.to_s if subject_ref.present?
      expected
    end

    def admission_reference_purposes(intent)
      purposes = [handoff_purpose_for(intent)]
      local_purpose = LOCAL_ENTRY_PURPOSE[intent.to_s]
      purposes.unshift(local_purpose) if local_purpose.present?
      purposes
    end

    def default_store
      Valkey::AuthState::OpaqueAdmissionStore.new
    end
  end
end
