# typed: false
# frozen_string_literal: true

# Base issues and Auth/Base consume purpose-specific opaque admission/result
# codes. Raw codes never persist; Valkey OpaqueAdmissionStore keys by digest.
class BaseAuthAdmissionCoordinator < ApplicationService
  class Denied < StandardError; end

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
  }.freeze

  RESULT_PURPOSE = {
    "authentication" => "authentication_result",
    "sign_in" => "authentication_result",
    "sign_up" => "authentication_result",
    "invitation" => "invitation_result",
    "step_up" => "step_up_result",
    "reauthentication" => "reauthentication_result",
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

  Issuance = Data.define(:transaction, :code, :reference)

  class << self
    public

    def issue_handoff!(transaction:, store: default_store)
      purpose = handoff_purpose_for(transaction.intent)
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface),
        surface: transaction.surface,
        subject_ref: transaction.transaction_id,
        reference: transaction.transaction_id,
      )
      Issuance.new(transaction: transaction, code: code, reference: transaction.transaction_id)
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

    def issue_local_entry!(surface:, intent:, store: default_store)
      purpose = local_entry_purpose_for(intent)
      reference = SecureRandom.uuid
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(surface.to_s),
        surface: surface,
        subject_ref: reference,
        reference: reference,
      )
      Issuance.new(transaction: nil, code: code, reference: reference)
    end

    def consume_local_entry!(raw_code:, surface:, expected_intent:, store: default_store)
      purpose = local_entry_purpose_for(expected_intent)
      result = store.consume!(
        purpose: purpose,
        raw_code: raw_code,
        expected: binding_expectations(surface: surface),
      )
      raise Denied, "local admission missing" if result.missing?
      raise Denied, "local admission replay" if result.replay?
      raise Denied, "local admission binding mismatch" if result.binding_mismatch?
      raise Denied, "local admission rejected" unless result.success?

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
      raise Denied, "local admission missing" if result.missing?
      raise Denied, "local admission replay" if result.replay?
      raise Denied, "local admission binding mismatch" if result.binding_mismatch?
      raise Denied, "local admission rejected" unless result.success?

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

    def read_result!(raw_code:, surface:, transaction_ref:, expected_intent:, store: default_store)
      raise Denied, "admission binding mismatch" if transaction_ref.to_s.blank?

      purpose = result_purpose_for(expected_intent)
      payload = store.read(raw_code, purpose: purpose)
      raise Denied, "admission missing" if payload.blank?

      validate_payload!(payload, surface: surface)
      raise Denied, "admission purpose mismatch" unless payload.fetch("purpose") == purpose
      raise Denied, "admission binding mismatch" unless payload.fetch("subject_ref") == transaction_ref.to_s

      transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
        surface: surface,
        transaction_id: transaction_ref,
      )
      generation = Integer(payload.fetch("result_generation").to_s, 10)
      digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose:, raw_code: raw_code)
      raise Denied, "admission binding mismatch" unless transaction.result_delivery_matches?(
        result_digest: digest,
        result_generation: generation,
      )

      payload
    rescue KeyError, ArgumentError
      raise Denied, "admission rejected"
    end

    def consume_result!(raw_code:, surface:, transaction_ref:, expected_intent:, store: default_store)
      raise Denied, "admission binding mismatch" if transaction_ref.to_s.blank?

      purpose = result_purpose_for(expected_intent)
      result = store.consume!(
        purpose: purpose,
        raw_code: raw_code,
        expected: binding_expectations(surface: surface, subject_ref: transaction_ref),
      )
      raise Denied, "admission missing" if result.missing?
      raise Denied, "admission replay" if result.replay?
      raise Denied, "admission binding mismatch" if result.binding_mismatch?
      raise Denied, "admission rejected" unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def register_result_and_issue!(surface:, login_challenge:, actor:, session_ref:, auth_method:, acr: nil,
                                   authentication_event_at: nil, ceremony_session_ref: nil,
                                   store: default_store)
      transaction = OidcAuthorizationTransactionCoordinator.model_for(surface).find_by!(
        surface: surface,
        login_challenge: login_challenge,
      )
      if transaction.authenticated?
        raise Denied, "authentication actor mismatch" unless transaction.actor_ref == actor.public_id
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
      payload.fetch("purpose").to_s == local_entry_purpose_for(intent)
    end

    private

    private :handoff_purpose_for, :result_purpose_for, :local_entry_purpose_for

    def consume_code!(purpose:, raw_code:, surface:, store:)
      result = store.consume!(
        purpose: purpose,
        raw_code: raw_code,
        expected: binding_expectations(surface: surface),
      )
      raise Denied, "admission missing" if result.missing?
      raise Denied, "admission replay" if result.replay?
      raise Denied, "admission binding mismatch" if result.binding_mismatch?
      raise Denied, "admission rejected" unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def validate_payload!(payload, surface:)
      raise Denied, "admission rejected" if payload.blank?
      raise Denied, "admission surface mismatch" unless payload.fetch("surface").to_s == surface.to_s

      actor = SURFACE_ACTOR.fetch(surface.to_s)
      raise Denied, "admission actor mismatch" unless payload.fetch("actor_type").to_s == actor
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
