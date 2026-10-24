# typed: false
# frozen_string_literal: true

# Base issues and Auth/Base consume purpose-specific opaque admission/result
# codes. Raw codes never persist; Valkey OpaqueAdmissionStore keys by digest.
require "digest"

class BaseAuthAdmissionCoordinator < ApplicationService
  CLIENT_BINDING_PROOF_PARAMS = %w(
    auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
    base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
    step_up_ceremony_transaction_id parent_kind purpose browser_nonce
  ).freeze

  # `code` is the internal refusal taxonomy for logs; responses stay generic.
  class Denied < StandardError
    attr_reader :code, :context

    public

    def initialize(message = nil, code: "unclassified", context: {})
      unless IdentityStepUpCeremonyContract::REFUSAL_CODES.include?(code)
        raise ArgumentError, "unknown refusal code: #{code.inspect}"
      end

      super(message)
      @code = code
      @context = context.to_h.stringify_keys.freeze
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

  CANCELLATION_PURPOSE = "cancellation_handoff"
  SWITCH_HANDOFF_VERSION = 1
  CONTINUATION_TTL = 10.seconds
  SWITCH_HANDOFF_TTL = CONTINUATION_TTL
  SWITCH_TARGETS = %w(sign_in sign_up).freeze
  CANCELLATION_HANDOFF_VERSION = 1

  CEREMONY_SESSION = {
    "app" => ClientAuthCeremonySession,
    "com" => VisitorAuthCeremonySession,
    "org" => OperatorAuthCeremonySession,
  }.freeze

  STEP_UP_TRANSACTION = {
    "app" => ClientStepUpCeremonyTransaction,
    "com" => VisitorStepUpCeremonyTransaction,
    "org" => OperatorStepUpCeremonyTransaction,
  }.freeze

  ADMISSION_BINDING = {
    "app" => ClientAuthAdmissionBinding,
    "com" => VisitorAuthAdmissionBinding,
    "org" => OperatorAuthAdmissionBinding,
  }.freeze

  Issuance = Data.define(:transaction, :code, :reference)
  TerminalOutcome = Data.define(:transaction)
  CancellationIssuance = Data.define(:transaction, :reference, :handoff)

  class << self
    public

    def issue_handoff!(transaction:, base_browser_nonce:, base_token:, restart_of: nil,
                       store: default_store)
      purpose = handoff_purpose_for(transaction.intent)
      binding, code = issue_binding_and_transport!(
        transaction: transaction, purpose: purpose, base_browser_nonce: base_browser_nonce,
        base_token: base_token, restart_of:, store: store,
      )
      Issuance.new(transaction: transaction, code: code, reference: binding.entry_ref)
    end

    # D06 Switch: a fresh admission for a parent whose earlier admissions were all redeemed by
    # ceremonies that have since been cancelled. Any redeemed admission whose ceremony is still
    # live keeps the ordinary refusal, so a Switch can never run beside an active ceremony.
    def issue_switch_admission!(transaction:, base_browser_nonce:, base_token:, target:, store: default_store)
      raise Denied.new("switch target is invalid", code: "invalid_admission") unless SWITCH_TARGETS.include?(target)

      purpose = handoff_purpose_for(transaction.intent)
      binding, code = issue_binding_and_transport!(
        transaction: transaction, purpose: purpose, base_browser_nonce: base_browser_nonce,
        base_token: base_token, restart_of: nil, store: store, after_ended_ceremonies: true, entry_intent: target,
      )
      Issuance.new(transaction: transaction, code: code, reference: binding.entry_ref)
    end

    def validate_result_browser_binding!(transaction:, surface:, base_browser_nonce:, base_token:, cancellation: false)
      unless transaction.surface == surface.to_s && base_browser_nonce.is_a?(String) && base_browser_nonce.present?
        raise Denied.new("result browser binding is missing", code: "return_binding_mismatch")
      end

      binding = admission_binding_model(surface).where.not(redeemed_at: nil)
        .find_by!(binding_parent_attributes(transaction))
      expected = AuthAdmissionBinding.browser_digest(surface:, entry_ref: binding.entry_ref, nonce: base_browser_nonce)
      unless binding.redeemed? && ActiveSupport::SecurityUtils.secure_compare(binding.base_browser_digest, expected) &&
          result_root_context_matches?(binding, transaction, base_token)
        raise Denied.new("result browser binding mismatch", code: "return_binding_mismatch")
      end
      # WU-06 (A06-2): a result issued before the curfew is not accepted at or after it.
      if !cancellation && binding.purpose == "authentication_handoff" && !AdmissionCurfewValue.for(binding).within?
        raise Denied.new("sign-in path curfew has passed", code: "expired_admission")
      end

      binding
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("result browser binding is unavailable", code: "return_binding_mismatch")
    end

    def validate_social_result_browser_binding!(reference:, surface:, provider:, base_browser_nonce:, base_token:)
      binding = find_admission_binding!(surface:, reference:)
      unless binding.redeemed? && !binding.retired? && !binding.expired? &&
          binding.purpose == "authentication_handoff" &&
          base_browser_nonce.is_a?(String) && base_browser_nonce.present?
        raise Denied.new("social result admission is unavailable", code: "return_binding_mismatch")
      end

      ensure_binding_browser_matches!(binding, surface:, nonce: base_browser_nonce)
      ensure_binding_token_matches!(binding, base_token)
      validate_admission_parent!(binding)
      validate_admission_root!(binding)
      ceremony = admitted_ceremony_session(binding)
      unless ceremony&.active? && ceremony.admitted? && ceremony.authentication_evidence_recorded? &&
          ceremony.authentication_method == provider.to_s
        raise Denied.new("social authentication evidence is unavailable", code: "return_binding_mismatch")
      end

      binding
    rescue ActiveRecord::RecordNotFound, ArgumentError
      raise Denied.new("social result admission is unavailable", code: "return_binding_mismatch")
    end

    def validate_completed_social_signup_browser_binding!(commit:, surface:, base_browser_nonce:, base_token:,
                                                          allow_incomplete: false)
      binding = find_admission_binding!(surface:, reference: commit.result["session_ref"])
      unless binding.redeemed? && !binding.retired? && !binding.expired? &&
          binding.purpose == "authentication_handoff"
        raise Denied.new("social receipt admission is unavailable", code: "return_binding_mismatch")
      end

      ensure_binding_browser_matches!(binding, surface:, nonce: base_browser_nonce)
      ceremony = admitted_ceremony_session(binding)
      unless ceremony && (ceremony.completed? || (allow_incomplete && ceremony.active?)) &&
          !ceremony.cancelled? && !ceremony.revoked_at &&
          ceremony.authentication_method == commit.identity.provider && ceremony.authentication_evidence_recorded?
        raise Denied.new("social receipt evidence is unavailable", code: "return_binding_mismatch")
      end

      validate_completed_social_parent!(binding, commit, base_token, allow_incomplete:)
      binding
    rescue ActiveRecord::RecordNotFound, ArgumentError
      raise Denied.new("social receipt browser binding is unavailable", code: "return_binding_mismatch")
    end

    def validate_registration_restart_browser!(binding:, surface:, base_browser_nonce:, base_token:, scope:, method:)
      unless binding.is_a?(admission_binding_model(surface)) && !binding.retired? &&
          binding.parent_kind == :step_up_ceremony_transaction && binding.purpose == "credential_registration_handoff"
        raise Denied.new("registration restart is unavailable", code: "invalid_admission")
      end

      transaction = admission_parent_record(binding)
      unless transaction.purpose == "credential_registration" && transaction.required_scope == scope &&
          transaction.allowed_methods_array == [method.to_s]
        raise Denied.new("registration restart intent mismatch", code: "invalid_admission")
      end

      ensure_binding_browser_matches!(binding, surface:, nonce: base_browser_nonce)
      ensure_binding_token_matches!(binding, base_token)
      validate_admission_parent!(binding)
      validate_admission_root!(binding)
      binding
    end

    def validate_admission_continuation!(binding:, surface:, expected_intent:)
      unless binding.is_a?(admission_binding_model(surface)) && binding.live? &&
          admission_reference_purposes(expected_intent).include?(binding.purpose)
        raise Denied.new("admission continuation is unavailable", code: "invalid_admission")
      end

      # The parent and root are the authority for this decision, so they are read from the
      # writer: a replica that has not caught up would refuse a sound admission.
      admission_binding_model(surface).connection_owner.connected_to(role: :writing) do
        validate_admission_parent!(binding)
        validate_admission_root!(binding)
        validate_entry_parent_intent!(binding, expected_intent)
      end
      binding
    end

    def consume_entry_reference!(reference:, surface:, expected_intent:, binding:, raw_auth_sid:, store: default_store)
      allowed_purposes = admission_reference_purposes(expected_intent)
      validate_entry_binding!(
        reference: reference, surface: surface, allowed_purposes: allowed_purposes,
        binding: binding, raw_auth_sid: raw_auth_sid,
      )
      validate_entry_parent_intent!(binding, expected_intent)
      result = store.consume_reference!(
        reference: reference,
        purposes: allowed_purposes,
        expected: binding_expectations(surface: surface, subject_ref: binding_parent_reference(binding)),
      )
      raise Denied.new("entry admission missing", code: "invalid_admission") if result.missing?
      raise Denied.new("entry admission replay", code: "admission_replay") if result.replay?
      raise Denied.new("entry admission binding mismatch", code: "invalid_admission") if result.binding_mismatch?
      raise Denied.new("entry admission rejected", code: "invalid_admission") unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      validate_entry_payload_binding!(payload: payload, binding: binding, expected_intent: expected_intent)
      validate_entry_binding!(
        reference: reference, surface: surface, allowed_purposes: allowed_purposes,
        binding: binding, raw_auth_sid: raw_auth_sid,
      )
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
        ttl: OidcAuthorizationTransactionable::RESULT_TTL,
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

    def issue_cancellation!(transaction:, ceremony_session_ref: nil, store: default_store)
      now = transaction.class.database_now
      unless %w(pending verified canceled).include?(transaction.status) && !transaction.expired?(now: now)
        raise Denied.new("cancellation is unavailable", code: "transaction_unavailable")
      end

      remaining = [transaction.expires_at - now, CONTINUATION_TTL].min
      remaining = 1.second if remaining <= 0
      reference = nil
      handoff = nil
      transaction.class.connection_owner.connected_to(role: :writing) do
        transaction.class.connection_owner.transaction do
          transaction.with_lock do
            if transaction.cancellation_handoff_ref.present? || transaction.cancellation_handoff_ciphertext.present?
              reference, handoff = reuse_cancellation_handoff!(
                transaction: transaction, store: store, ceremony_session_ref: ceremony_session_ref,
                ttl: remaining, now: now,
              )
            else
              raw_code = SecureRandom.urlsafe_base64(
                Valkey::AuthState::OpaqueAdmissionStore::CODE_BYTES,
                padding: false,
              )
              reference = SecureRandom.uuid
              handoff = encrypt_cancellation_handoff(
                surface: transaction.surface, transaction_ref: transaction.transaction_id,
                reference: reference, raw_code: raw_code, expires_at: transaction.expires_at,
              )
              transaction.prepare_cancellation_handoff!(reference:, ciphertext: handoff)
              store.issue!(
                purpose: CANCELLATION_PURPOSE,
                actor_type: SURFACE_ACTOR.fetch(transaction.surface), surface: transaction.surface,
                subject_ref: transaction.transaction_id, ceremony_session_ref: ceremony_session_ref,
                reference: reference, raw_code: raw_code, ttl: remaining, now: now,
              )
            end
          end
        end
      end

      CancellationIssuance.new(transaction: transaction, reference: reference, handoff: handoff)
    rescue ActiveRecord::RecordNotUnique
      raise Denied.new("cancellation handoff is already bound", code: "transaction_conflict")
    end

    def read_cancellation_handoff!(handoff:, surface:, transaction_ref:, store: default_store)
      transaction, payload = validate_cancellation_handoff!(handoff:, surface:, transaction_ref:)
      consume_cancellation_handoff!(transaction:, payload:, handoff:, surface:, transaction_ref:, store:)
    end

    # D09 parent-authorization Cancel. The handoff is the same encrypted, single-use shape as the
    # Step-Up cancellation; it is accepted only when it equals the ciphertext stored on the loaded
    # authorization transaction, so a Step-Up handoff can never cancel a parent or the reverse.
    def read_authorization_cancellation_handoff!(handoff:, surface:, transaction_ref:, store: default_store)
      transaction, payload = validate_authorization_cancellation_handoff!(handoff:, surface:, transaction_ref:)
      consume_cancellation_handoff!(transaction:, payload:, handoff:, surface:, transaction_ref:, store:)
    end

    # D06 Switch. Auth ends its first-page ceremony and hands Base a short-lived encrypted request
    # naming the same parent and the other flow. Base proves the ceremony really ended for that
    # parent before it issues a fresh admission; the parent itself is never consumed or re-intended.
    def validate_switch_request!(transaction:, target:)
      validate_switch_target!(transaction:, target:)
    end

    def issue_switch_handoff!(transaction:, ceremony_session:, target:)
      validate_switch_target!(transaction:, target:)
      unless ceremony_session.cancelled? && ceremony_session.authorization_transaction_ref == transaction.transaction_id
        raise Denied.new("switch ceremony is not ended for this parent", code: "invalid_admission")
      end

      switch_handoff_encryptor.encrypt_and_sign(
        JSON.generate(
          "version" => SWITCH_HANDOFF_VERSION, "surface" => transaction.surface,
          "transaction_ref" => transaction.transaction_id, "ceremony_session_id" => ceremony_session.id,
          "target" => target, "expires_at" => (transaction.class.database_now + SWITCH_HANDOFF_TTL).iso8601,
        ),
      )
    end

    def read_switch_handoff!(handoff:, surface:)
      raise Denied.new("switch handoff is invalid", code: "invalid_admission") unless handoff.is_a?(String) &&
        handoff.present?

      payload = JSON.parse(switch_handoff_encryptor.decrypt_and_verify(handoff))
      unless payload.is_a?(Hash) && payload.fetch("version") == SWITCH_HANDOFF_VERSION &&
          payload.fetch("surface") == surface.to_s && Time.zone.iso8601(payload.fetch("expires_at")) > Time.current
        raise Denied.new("switch handoff is invalid", code: "invalid_admission")
      end

      transaction = authorization_transaction_for_exit(surface:, transaction_ref: payload.fetch("transaction_ref"))
      target = payload.fetch("target")
      validate_switch_target!(transaction:, target:)
      ceremony =
        ceremony_session_class(surface).connection_owner.connected_to(role: :writing) do
          ceremony_session_class(surface).find(payload.fetch("ceremony_session_id"))
        end
      unless ceremony.cancelled? && ceremony.authorization_transaction_ref == transaction.transaction_id
        raise Denied.new("switch ceremony is not ended for this parent", code: "invalid_admission")
      end

      [transaction, target]
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature,
           JSON::ParserError, KeyError, TypeError, ArgumentError, ActiveRecord::RecordNotFound
      raise Denied.new("switch handoff is invalid", code: "invalid_admission")
    end

    def validate_authorization_cancellation_handoff!(handoff:, surface:, transaction_ref:)
      payload = decrypt_bound_cancellation_payload!(handoff:, surface:, transaction_ref:)
      transaction = authorization_transaction_for_exit(surface:, transaction_ref:)
      verify_stored_cancellation_handoff!(transaction:, reference: payload.fetch("reference"), handoff:)
      [transaction, payload]
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature,
           JSON::ParserError, KeyError, TypeError, ArgumentError
      raise Denied.new("cancellation handoff is invalid", code: "invalid_admission")
    end

    def consume_cancellation_handoff!(transaction:, payload:, handoff:, surface:, transaction_ref:, store:)
      reference = payload.fetch("reference")

      # A canceled transaction is the durable replay barrier. Once its handoff has been
      # accepted, the short-lived Valkey pointer may have expired; the encrypted handoff still
      # converges on the same idempotent cancellation without requiring a fresh code.
      if transaction.status == "canceled"
        unless transaction.cancellation_handoff_digest == cancellation_handoff_digest(handoff)
          raise Denied.new("cancellation handoff digest mismatch", code: "return_binding_mismatch")
        end

        return transaction
      end

      result = store.consume_reference!(
        reference: reference, purposes: [CANCELLATION_PURPOSE],
        expected: { "surface" => surface.to_s, "subject_ref" => transaction_ref.to_s },
        tombstone_ttl: [transaction.expires_at - transaction.class.database_now, 1.second].max,
      )
      unless result.success? || result.replay? || result.missing?
        raise Denied.new("cancellation handoff is unavailable", code: "invalid_admission")
      end

      transaction
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature,
           JSON::ParserError, KeyError, TypeError
      raise Denied.new("cancellation handoff is invalid", code: "invalid_admission")
    end

    def validate_cancellation_handoff!(handoff:, surface:, transaction_ref:)
      payload = decrypt_bound_cancellation_payload!(handoff:, surface:, transaction_ref:)
      transaction = step_up_transaction_for(surface:, transaction_ref:)
      verify_stored_cancellation_handoff!(transaction:, reference: payload.fetch("reference"), handoff:)
      [transaction, payload]
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature,
           JSON::ParserError, KeyError, TypeError, ArgumentError
      raise Denied.new("cancellation handoff is invalid", code: "invalid_admission")
    end

    def encrypt_cancellation_handoff(surface:, transaction_ref:, reference:, raw_code:, expires_at:)
      encryptor = cancellation_handoff_encryptor
      encryptor.encrypt_and_sign(
        JSON.generate(
          "version" => CANCELLATION_HANDOFF_VERSION, "surface" => surface.to_s,
          "transaction_ref" => transaction_ref.to_s, "reference" => reference.to_s,
          "raw_code" => raw_code, "expires_at" => expires_at.iso8601,
        ),
      )
    end

    def cancellation_handoff_digest(handoff)
      raise ArgumentError, "cancellation handoff is blank" unless handoff.is_a?(String) && handoff.present?

      Digest::SHA256.hexdigest("cancellation-handoff:#{handoff}")
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
      unless raw_code.is_a?(String) && raw_code.present? && transaction_ref.is_a?(String) && transaction_ref.present?
        raise Denied.new("admission binding mismatch", code: "invalid_admission")
      end

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

    def read_result_reference!(reference:, surface:, transaction_ref:, expected_intent:, store: default_store)
      unless reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN) &&
          transaction_ref.is_a?(String) && transaction_ref.present?
        raise Denied.new("admission binding mismatch", code: "invalid_admission")
      end

      purpose = result_purpose_for(expected_intent)
      payload = store.read_reference!(reference:, purposes: [purpose])
      raise Denied.new("admission missing", code: "invalid_admission") if payload.blank?

      validate_payload!(payload, surface: surface)
      raise Denied.new("admission purpose mismatch", code: "invalid_admission") unless
        payload.fetch("purpose") == purpose
      raise Denied.new("admission binding mismatch", code: "invalid_admission") unless
        payload.fetch("subject_ref") == transaction_ref.to_s

      transaction = result_transaction!(
        surface: surface, transaction_ref: transaction_ref, expected_intent: expected_intent,
      )
      generation = Integer(payload.fetch("result_generation").to_s, 10)
      raise Denied.new("admission binding mismatch", code: "invalid_admission") unless
        transaction.result_delivery_matches?(result_digest: transaction.result_digest, result_generation: generation)

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

    def client_supplied_binding_proof?(parameters)
      CLIENT_BINDING_PROOF_PARAMS.any? { |key| parameters.key?(key) || parameters.key?(key.to_sym) }
    end

    def with_admission_binding_lock!(binding, &)
      token = admission_base_token_record(binding)
      if token
        actor = admission_root_actor(token)
        actor.class.connection_class_for_self.connected_to(role: :writing) do
          actor.with_lock do
            raise Denied.new("Base actor is unavailable", code: "authorization_denied") unless actor.login_allowed?

            with_admission_ticket_locks!(binding, token, &)
          end
        end
      else
        with_admission_ticket_locks!(binding, nil, &)
      end
    end

    def admission_binding_model(surface)
      ADMISSION_BINDING.fetch(surface.to_s)
    rescue KeyError
      raise Denied.new("unsupported admission surface", code: "malformed_request")
    end

    def find_admission_binding!(surface:, reference:)
      raise Denied.new("admission reference is invalid", code: "invalid_admission") unless
        reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

      admission_binding_model(surface).connection_owner.connected_to(role: :writing) do
        admission_binding_model(surface).find_by!(entry_ref: reference)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission binding missing", code: "invalid_admission")
    end

    def find_admission_binding_by_confirmation!(surface:, reference:)
      raise Denied.new("confirmation reference is invalid", code: "invalid_admission") unless
        reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

      admission_binding_model(surface).connection_owner.connected_to(role: :writing) do
        admission_binding_model(surface).find_by!(confirmation_ref: reference)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission binding missing", code: "invalid_admission")
    end

    def handoff_purpose_for(intent)
      HANDOFF_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported admission intent" }
    end

    def result_purpose_for(intent)
      RESULT_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported admission intent" }
    end

    private

    def admitted_ceremony_session(binding)
      case binding
      when ClientAuthAdmissionBinding
        ClientAuthCeremonySession.find_by(id: binding.admitted_auth_ceremony_session_id)
      when VisitorAuthAdmissionBinding
        VisitorAuthCeremonySession.find_by(id: binding.admitted_auth_ceremony_session_id)
      when OperatorAuthAdmissionBinding
        OperatorAuthCeremonySession.find_by(id: binding.admitted_auth_ceremony_session_id)
      else
        raise Denied.new("Auth continuation is unavailable", code: "invalid_admission")
      end
    end

    private :handoff_purpose_for, :result_purpose_for

    def reuse_cancellation_handoff!(transaction:, store:, ceremony_session_ref:, ttl:, now:)
      reference = transaction.cancellation_handoff_ref
      handoff = transaction.cancellation_handoff_ciphertext
      unless reference.present? && handoff.present?
        raise Denied.new("cancellation handoff is incomplete", code: "transaction_conflict")
      end

      payload = decrypt_cancellation_handoff(handoff)
      unless payload.fetch("reference") == reference && payload.fetch("transaction_ref") == transaction.transaction_id
        raise Denied.new("cancellation handoff is inconsistent", code: "transaction_conflict")
      end

      unless transaction.status == "canceled"
        ensure_cancellation_transport!(
          store: store, reference: reference, transaction: transaction, raw_code: payload.fetch("raw_code"),
          ceremony_session_ref: ceremony_session_ref, ttl: ttl, now: now,
        )
      end
      [reference, handoff]
    end

    def issue_binding_and_transport!(transaction:, purpose:, base_browser_nonce:, base_token:,
                                     restart_of:, store:, after_ended_ceremonies: false, entry_intent: nil)
      model = admission_binding_model(transaction.surface)
      model.connection_owner.connected_to(role: :writing) do
        model.transaction do
          locked_transaction = transaction.class.lock.find(transaction.id)
          binding = create_or_reuse_binding!(
            transaction: locked_transaction, surface: locked_transaction.surface, purpose: purpose,
            base_browser_nonce: base_browser_nonce,
            base_token: base_token, restart_of:, now: model.database_now, after_ended_ceremonies:, entry_intent:,
          )
          code = issue_transport!(
            transaction: locked_transaction, surface: locked_transaction.surface, purpose: purpose,
            binding: binding, base_token: base_token, store: store,
          )
          [binding, code]
        end
      end
    end

    def create_or_reuse_binding!(transaction:, surface:, purpose:, base_browser_nonce:, base_token:,
                                 restart_of:, now:, after_ended_ceremonies: false, entry_intent: nil)
      model = admission_binding_model(surface)
      parent_attributes = binding_parent_attributes(transaction)
      validate_base_token!(transaction: transaction, surface: surface, base_token: base_token)
      resolved_intent = admission_entry_intent(transaction:, purpose:, entry_intent:)

      retire_restart_binding!(
        model:, transaction:, surface:, purpose:, base_browser_nonce:, base_token:, restart_of:,
      ) if restart_of.present?

      existing = model.lock.find_by(parent_attributes.merge(purpose: purpose, retired_at: nil, redeemed_at: nil))
      if existing
        unless existing.entry_intent == resolved_intent
          raise Denied.new("live admission opens another flow", code: "invalid_admission")
        end

        ensure_binding_token_matches!(existing, base_token)
        ensure_binding_browser_matches!(existing, surface: surface, nonce: base_browser_nonce)
        return existing unless existing.expired?(now: now)

        raise Denied.new("admission expired; explicit restart is required", code: "expired_admission")
      end

      redeemed = model.where(parent_attributes.merge(purpose: purpose)).where.not(redeemed_at: nil).to_a
      if redeemed.any? &&
          !(after_ended_ceremonies && redeemed.all? { |binding| admitted_ceremony_session(binding)&.cancelled? })
        raise Denied.new("admission redeemed; explicit cancel-and-start is required", code: "invalid_admission")
      end

      curfew_at = admission_curfew_at(redeemed:, now:, after_ended_ceremonies:)

      entry_ref = SecureRandom.uuid
      expiry = [transaction_expiry(transaction), now + admission_transport_ttl(purpose)].compact.min
      digest = AuthAdmissionBinding.browser_digest(
        surface: surface, entry_ref: entry_ref, nonce: base_browser_nonce,
      )
      binding = model.create!(
        parent_attributes.merge(
          entry_ref: entry_ref,
          purpose: purpose,
          base_token_id: base_token&.id,
          base_browser_digest: digest,
          entry_intent: resolved_intent,
          curfew_at: curfew_at,
          expires_at: expiry,
          created_at: now,
          updated_at: now,
        ),
      )
      cover_sign_in_path_curfew!(transaction, curfew_at) if purpose == "authentication_handoff"
      binding
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    # WU-06 / REQ-CURFEW: the OIDC transaction and its login challenge never end the Sign-in path before
    # the attempt's curfew, so the post-curfew exit still finds its redirect_uri. The curfew itself is
    # enforced separately (AdmissionCurfewValue); this only removes the earlier end.
    def cover_sign_in_path_curfew!(transaction, curfew_at)
      attributes = {
        expires_at: [transaction.expires_at, curfew_at].max,
        login_challenge_expires_at: [transaction.login_challenge_expires_at, curfew_at].max,
      }
      transaction.update!(attributes) if attributes.any? { |name, value| transaction.public_send(name) != value }
    end

    def admission_entry_intent(transaction:, purpose:, entry_intent:)
      case purpose
      when *AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction)
        AuthEntryIntentResolver.call(prompt: transaction.oidc_prompt, entry_intent: entry_intent)
      when *AuthAdmissionBinding::PARENT_PURPOSES.fetch(:step_up_ceremony_transaction)
        "not_applicable"
      else
        raise Denied.new("unsupported admission purpose", code: "invalid_admission")
      end
    end

    def admission_curfew_at(redeemed:, now:, after_ended_ceremonies:)
      return now + AuthAdmissionBinding::CURFEW_DURATION unless after_ended_ceremonies
      raise Denied.new("switch admission has no original binding", code: "invalid_admission") if redeemed.empty?

      deadlines = redeemed.map(&:curfew_at)
      deadlines.uniq!
      raise AuthAdmissionBinding::InvalidTransition, "switch bindings disagree on curfew" unless deadlines.one?

      deadlines.fetch(0)
    end

    def retire_restart_binding!(model:, transaction:, surface:, purpose:, base_browser_nonce:, base_token:,
                                restart_of:)
      validate_admission_reference!(restart_of, label: "restart reference")
      binding = model.lock.find_by!(entry_ref: restart_of)
      unless binding_parent_matches?(binding, transaction) &&
          binding.purpose == purpose && !binding.redeemed? && !binding.retired?
        raise Denied.new("admission restart is unavailable", code: "invalid_admission")
      end

      expected_digest = AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: binding.entry_ref, nonce: base_browser_nonce,
      )
      unless binding.base_browser_digest == expected_digest && binding.base_token_id == base_token&.id
        raise Denied.new("admission restart browser binding mismatch", code: "session_binding_mismatch")
      end

      binding.retire!
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission restart binding missing", code: "invalid_admission")
    end

    def validate_admission_reference!(reference, label:)
      return if reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

      raise Denied.new("#{label} is invalid", code: "invalid_admission")
    end

    def binding_parent_matches?(binding, transaction)
      case transaction
      when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
           OperatorOidcAuthorizationTransaction
        binding.authorization_transaction_id == transaction.id
      when ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction,
           OperatorStepUpCeremonyTransaction
        binding.step_up_ceremony_transaction_id == transaction.id
      else
        false
      end
    end

    def ensure_cancellation_transport!(store:, reference:, transaction:, raw_code:, ceremony_session_ref:, ttl:, now:)
      store.restore_reference!(
        reference: reference, purpose: CANCELLATION_PURPOSE,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface), surface: transaction.surface,
        subject_ref: transaction.transaction_id, ceremony_session_ref: ceremony_session_ref,
        raw_code: raw_code, ttl: ttl, now: now,
      )
    end

    def issue_transport!(transaction:, surface:, purpose:, binding:, base_token:, store:)
      arguments = {
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(surface.to_s),
        surface: surface.to_s,
        subject_ref: transaction_subject_reference(transaction),
        base_session_ref: base_token&.public_id,
        reference: binding.entry_ref,
      }
      store.issue!(**arguments, ttl: admission_transport_ttl(purpose))
    rescue Umaxica::Valkey::OperationError => e
      raise unless e.message == "admission code key collision"

      store.reissue_reference!(
        **arguments.except(:reference).merge(
          reference: binding.entry_ref, ttl: admission_transport_ttl(purpose),
        ),
      )
    end

    def admission_transport_ttl(purpose)
      return CONTINUATION_TTL if AuthAdmissionBinding::PARENT_PURPOSES.values.flatten.include?(purpose.to_s)

      Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL
    end

    def cancellation_handoff_encryptor
      key = Rails.application.key_generator.generate_key(
        "base-auth-cancellation-handoff", ActiveSupport::MessageEncryptor.key_len,
      )
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def decrypt_cancellation_handoff(handoff)
      raw = cancellation_handoff_encryptor.decrypt_and_verify(handoff)
      payload = JSON.parse(raw)
      raise TypeError unless payload.is_a?(Hash) && payload.fetch("version") == CANCELLATION_HANDOFF_VERSION

      expires_at = Time.zone.iso8601(payload.fetch("expires_at"))
      raise ArgumentError if expires_at <= Time.current

      payload
    end

    # Only a pending App/Com parent with the neutral `authentication` intent can switch: a fixed
    # sign_in or sign_up intent would need an intent change, which D06 forbids. prompt=login keeps
    # Sign In.
    def validate_switch_target!(transaction:, target:)
      decision_time = transaction.class.database_now
      pending = transaction.status == OidcAuthorizationTransactionable::STATUS_PENDING
      # Org has no public Sign Up (D06), so an Org parent never switches.
      neutral = transaction.intent == "authentication" && transaction.surface != "org"
      login_only = target == "sign_up" && transaction.oidc_prompt == "login"
      unless SWITCH_TARGETS.include?(target) && pending && !transaction.expired?(now: decision_time) && neutral &&
          !login_only
        raise Denied.new("switch is unavailable", code: "invalid_admission")
      end
    end

    def switch_handoff_encryptor
      key = Rails.application.key_generator.generate_key("base-auth-switch-handoff", ActiveSupport::MessageEncryptor.key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def decrypt_bound_cancellation_payload!(handoff:, surface:, transaction_ref:)
      unless handoff.is_a?(String) && handoff.present? && transaction_ref.is_a?(String) && transaction_ref.present?
        raise Denied.new("cancellation handoff is invalid", code: "invalid_admission")
      end

      payload = decrypt_cancellation_handoff(handoff)
      unless payload.fetch("surface") == surface.to_s && payload.fetch("transaction_ref") == transaction_ref.to_s
        raise Denied.new("cancellation handoff binding mismatch", code: "return_binding_mismatch")
      end

      reference = payload.fetch("reference")
      unless reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)
        raise Denied.new("cancellation reference is invalid", code: "invalid_admission")
      end

      payload
    end

    def verify_stored_cancellation_handoff!(transaction:, reference:, handoff:)
      expected_reference = transaction.cancellation_handoff_ref
      return if expected_reference.present? && expected_reference == reference &&
        transaction.cancellation_handoff_ciphertext.present? &&
        ActiveSupport::SecurityUtils.secure_compare(transaction.cancellation_handoff_ciphertext, handoff)

      raise Denied.new("cancellation handoff binding mismatch", code: "return_binding_mismatch")
    end

    def authorization_transaction_for_exit(surface:, transaction_ref:)
      model = OidcAuthorizationTransactionCoordinator.model_for(surface)
      model.connection_owner.connected_to(role: :writing) do
        model.find_by!(transaction_id: transaction_ref, surface: surface.to_s)
      end
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise Denied.new("cancellation transaction missing", code: "invalid_admission")
    end

    def step_up_transaction_for(surface:, transaction_ref:)
      model = STEP_UP_TRANSACTION.fetch(surface.to_s)
      model.connection_owner.connected_to(role: :writing) do
        model.find_by!(transaction_id: transaction_ref, surface: surface.to_s)
      end
    rescue KeyError, ActiveRecord::RecordNotFound
      raise Denied.new("cancellation transaction missing", code: "invalid_admission")
    end

    def binding_parent_attributes(transaction)
      case transaction
      when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
           OperatorOidcAuthorizationTransaction
        { authorization_transaction_id: transaction.id }
      when ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction,
           OperatorStepUpCeremonyTransaction
        { step_up_ceremony_transaction_id: transaction.id }
      else
        raise Denied.new("unsupported admission parent", code: "malformed_request")
      end
    end

    def transaction_subject_reference(transaction)
      case transaction
      when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
           OperatorOidcAuthorizationTransaction, ClientStepUpCeremonyTransaction,
           VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction
        transaction.transaction_id
      else
        raise Denied.new("unsupported admission parent", code: "malformed_request")
      end
    end

    def transaction_expiry(transaction)
      case transaction
      when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
           OperatorOidcAuthorizationTransaction
        [transaction.expires_at, transaction.login_challenge_expires_at].compact.min
      when ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction,
           OperatorStepUpCeremonyTransaction
        transaction.expires_at
      else
        raise Denied.new("unsupported admission parent", code: "malformed_request")
      end
    end

    def validate_base_token!(transaction:, surface:, base_token:)
      expected_class = {
        "app" => ClientToken,
        "com" => VisitorToken,
        "org" => OperatorToken,
      }.fetch(surface.to_s)
      allowed_without_token =
        case transaction
        when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
             OperatorOidcAuthorizationTransaction
          true
        else
          false
        end
      return if base_token.nil? && allowed_without_token
      return if base_token.is_a?(expected_class)

      raise Denied.new("Base token binding is invalid", code: "session_binding_mismatch")
    end

    def validate_completed_social_parent!(binding, commit, token, allow_incomplete: false)
      parent = admission_parent_record(binding)
      valid =
        if binding.parent_kind == :authorization_transaction
          completed_social_authorization_parent_valid?(binding, commit, token, parent, allow_incomplete:)
        else
          completed_social_sign_in_parent_valid?(binding, commit, token, parent, allow_incomplete:)
        end
      return if valid

      raise Denied.new("social receipt parent is unavailable", code: "return_binding_mismatch")
    end

    def completed_social_authorization_parent_valid?(binding, commit, token, parent, allow_incomplete:)
      return false unless parent

      pending_resume = allow_incomplete && parent.status == OidcAuthorizationTransactionable::STATUS_PENDING &&
        parent.actor_ref.nil? && binding.base_token_id == token&.id
      established = (parent.authenticated? || parent.consumed?) &&
        parent.actor_ref == commit.user.public_id && result_root_context_matches?(binding, parent, token)
      now = parent.class.database_now
      (pending_resume || established) && !parent.expired?(now:) && !parent.login_challenge_expired?(now:)
    end

    def completed_social_sign_in_parent_valid?(binding, commit, token, parent, allow_incomplete:)
      return false unless parent

      pending_resume = allow_incomplete && binding.base_token_id == token&.id &&
        completed_social_sign_in_parent_pending?(binding, commit, parent)
      completed = parent.sign_in_completed? && parent.principal_id == commit.user.id &&
        token&.id == parent.token_id && token.active_status?(token.class.database_now)
      (pending_resume || completed) && !parent.expired?(parent.class.database_now)
    end

    def completed_social_sign_in_parent_pending?(binding, commit, parent)
      return true if parent.sign_in_primary_pending? && parent.principal_id.nil?

      ceremony = admitted_ceremony_session(binding)
      (parent.sign_in_primary_pending? || parent.sign_in_session_issuance_pending?) &&
        parent.principal_id == commit.user.id && parent.authentication_method == ceremony.authentication_method &&
        parent.authentication_event_at == ceremony.authentication_event_at
    end

    def ensure_binding_token_matches!(binding, base_token)
      return if binding.base_token_id == base_token&.id

      raise Denied.new("Base token binding is invalid", code: "session_binding_mismatch")
    end

    def ensure_binding_browser_matches!(binding, surface:, nonce:)
      digest = AuthAdmissionBinding.browser_digest(surface: surface, entry_ref: binding.entry_ref, nonce: nonce)
      return if ActiveSupport::SecurityUtils.secure_compare(binding.base_browser_digest, digest)

      raise Denied.new("Base browser binding is invalid", code: "session_binding_mismatch")
    end

    def validate_entry_binding!(reference:, surface:, allowed_purposes:, binding:, raw_auth_sid:)
      model = admission_binding_model(surface)
      unless reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN) &&
          binding.is_a?(model) && binding.entry_ref == reference && binding.live? &&
          binding.confirmed? && binding.attached?
        raise Denied.new("admission binding is unavailable", code: "invalid_admission")
      end

      unless allowed_purposes.include?(binding.purpose)
        raise Denied.new("admission purpose mismatch", code: "invalid_admission")
      end

      validate_admission_parent!(binding)
      validate_admission_root!(binding)

      unless raw_auth_sid.is_a?(String) && raw_auth_sid.present?
        raise Denied.new("Auth ceremony session is missing", code: "session_binding_mismatch")
      end

      auth_session = model.auth_admission_session_class.find_active_by_raw_sid(raw_auth_sid)
      unless auth_session && auth_session.id == binding.auth_ceremony_session_id
        raise Denied.new("Auth ceremony session does not match binding", code: "session_binding_mismatch")
      end

      auth_session
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise Denied.new("Auth ceremony session is invalid", code: "session_binding_mismatch")
    end

    # A parent that cannot be loaded is an unavailable admission, not a server error: the refusal
    # must stay the generic one whatever state the reference is in.
    def validate_admission_parent!(binding)
      parent = admission_parent_record(binding)
      now = parent&.class&.database_now
      available =
        case binding.parent_kind
        when :authorization_transaction
          parent.present? && parent.status == "pending" && !parent.expired?(now:) &&
          !parent.login_challenge_expired?(now:)
        when :step_up_ceremony_transaction
          parent.present? && %w(pending verified).include?(parent.status) && !parent.expired?(now:)
        else
          false
        end
      raise Denied.new("admission parent is unavailable", code: "invalid_admission") unless available
    end

    def admission_parent_record(binding)
      case binding
      when ClientAuthAdmissionBinding
        admission_parent_record_for_surface(
          binding.parent_kind,
          authorization_transaction_id: binding.authorization_transaction_id,
          step_up_ceremony_transaction_id: binding.step_up_ceremony_transaction_id,
          authorization_transaction_class: ClientOidcAuthorizationTransaction,
          step_up_ceremony_transaction_class: ClientStepUpCeremonyTransaction,
        )
      when VisitorAuthAdmissionBinding
        admission_parent_record_for_surface(
          binding.parent_kind,
          authorization_transaction_id: binding.authorization_transaction_id,
          step_up_ceremony_transaction_id: binding.step_up_ceremony_transaction_id,
          authorization_transaction_class: VisitorOidcAuthorizationTransaction,
          step_up_ceremony_transaction_class: VisitorStepUpCeremonyTransaction,
        )
      when OperatorAuthAdmissionBinding
        admission_parent_record_for_surface(
          binding.parent_kind,
          authorization_transaction_id: binding.authorization_transaction_id,
          step_up_ceremony_transaction_id: binding.step_up_ceremony_transaction_id,
          authorization_transaction_class: OperatorOidcAuthorizationTransaction,
          step_up_ceremony_transaction_class: OperatorStepUpCeremonyTransaction,
        )
      else
        raise Denied.new("admission binding is invalid", code: "invalid_admission")
      end
    end

    def admission_parent_record_for_surface(
      parent_kind,
      authorization_transaction_id:,
      step_up_ceremony_transaction_id:,
      authorization_transaction_class:,
      step_up_ceremony_transaction_class:
    )
      case parent_kind
      when :authorization_transaction
        authorization_transaction_class.find_by(id: authorization_transaction_id)
      when :step_up_ceremony_transaction
        step_up_ceremony_transaction_class.find_by(id: step_up_ceremony_transaction_id)
      else
        raise Denied.new("admission parent is invalid", code: "invalid_admission")
      end
    end

    def admission_base_token_record(binding)
      return if binding.base_token_id.nil?

      case binding
      when ClientAuthAdmissionBinding, VisitorAuthAdmissionBinding, OperatorAuthAdmissionBinding
        binding.association(:base_token).tap { |owner| owner.reset_scope }.scope.take
      else raise Denied.new("admission binding is invalid", code: "invalid_admission")
      end
    end

    def admission_device_session_record(token)
      return if token.device_session_id.nil?

      case token
      when ClientToken then ClientDeviceSession.find_by(id: token.device_session_id)
      when VisitorToken then VisitorDeviceSession.find_by(id: token.device_session_id)
      when OperatorToken then OperatorDeviceSession.find_by(id: token.device_session_id)
      else raise Denied.new("Base token is invalid", code: "session_binding_mismatch")
      end
    end

    def validate_admission_root!(binding)
      return if binding.base_token_id.nil?

      token = admission_base_token_record(binding)
      raise Denied.new("Base session is unavailable", code: "session_expired") unless token

      device = admission_device_session_record(token)
      raise Denied.new("Base device session is unavailable", code: "session_expired") unless device

      validate_step_up_root_context!(binding, token) if binding.parent_kind == :step_up_ceremony_transaction
      return if token.active_status?(token.class.database_now) && device.usable? &&
        device.current_refresh_token_id == token.id && admission_root_actor(token).login_allowed?

      raise Denied.new("Base session is unavailable", code: "session_expired")
    end

    def result_root_context_matches?(binding, transaction, token)
      return true if binding.base_token_id == token&.id
      return false unless token && transaction.consumed?

      case transaction
      when ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction, OperatorOidcAuthorizationTransaction
        transaction.base_finalized_at.present? && transaction.browser_session_ref == token.public_id &&
          transaction.actor_ref == admission_root_actor(token).public_id
      when ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction
        transaction.purpose == "reauthentication" && binding.base_token_id.present? &&
          admission_base_token_record(binding)&.device_session_id == token.device_session_id &&
          transaction.actor_ref == admission_root_actor(token).public_id
      else
        false
      end
    end

    def validate_step_up_root_context!(binding, token)
      transaction = admission_parent_record(binding)
      return if transaction.actor_ref == admission_root_actor(token).public_id &&
        transaction.session_ref == token.public_id && transaction.token_binding == token.public_id &&
        transaction.require_session_binding

      raise Denied.new("step-up Base context mismatch", code: "session_binding_mismatch")
    end

    def admission_root_actor(token)
      case token
      when ClientToken then token.association(:user).tap { |owner| owner.reset_scope }.scope.take
      when VisitorToken then token.association(:visitor).tap { |owner| owner.reset_scope }.scope.take
      when OperatorToken then token.association(:staff).tap { |owner| owner.reset_scope }.scope.take
      else raise Denied.new("Base token is invalid", code: "session_binding_mismatch")
      end
    end

    def with_admission_ticket_locks!(binding, token, &)
      binding.class.connection_owner.connected_to(role: :writing) do
        binding.class.transaction do
          if token
            device_session = admission_device_session_record(token)
            raise Denied.new("Base device session is missing", code: "session_expired") unless device_session

            device_session.with_lock do
              token.with_lock { with_admission_parent_lock!(binding, &) }
            end
          else
            with_admission_parent_lock!(binding, &)
          end
        end
      end
    end

    def with_admission_parent_lock!(binding)
      parent = admission_parent_record(binding)
      raise Denied.new("admission parent is missing", code: "invalid_admission") unless parent

      parent.with_lock do
        binding.with_lock do
          ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact
          ids.uniq!
          binding.class.auth_admission_session_class.where(id: ids).order(:id).lock.load
          validate_admission_parent!(binding) unless binding.redeemed?
          validate_admission_root!(binding)
          yield binding
        end
      end
    end

    def validate_entry_parent_intent!(binding, expected_intent)
      parent = admission_parent_record(binding)
      actual =
        case binding.parent_kind
        when :authorization_transaction
          if binding.purpose == "authentication_handoff"
            AuthEntryIntentResolver.call(prompt: parent.oidc_prompt, entry_intent: binding.entry_intent)
          else
            parent.intent
          end
        when :step_up_ceremony_transaction then parent.purpose
        else raise Denied.new("admission parent missing", code: "invalid_admission")
        end
      return if actual == expected_intent.to_s

      raise Denied.new("admission parent intent mismatch", code: "invalid_admission")
    end

    def validate_entry_payload_binding!(payload:, binding:, expected_intent:)
      expected_purpose = handoff_purpose_for(expected_intent)
      unless payload.fetch("purpose") == expected_purpose && payload.fetch("reference") == binding.entry_ref
        raise Denied.new("admission binding mismatch", code: "invalid_admission")
      end
      unless payload.fetch("subject_ref") == binding_parent_reference(binding)
        raise Denied.new("admission parent mismatch", code: "invalid_admission")
      end
    rescue KeyError
      raise Denied.new("admission binding mismatch", code: "invalid_admission")
    end

    def binding_parent_reference(binding)
      case binding.parent_kind
      when :authorization_transaction, :step_up_ceremony_transaction
        admission_parent_record(binding).transaction_id
      else
        raise Denied.new("admission parent missing", code: "invalid_admission")
      end
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
      [handoff_purpose_for(intent)]
    end

    def default_store
      Valkey::AuthState::OpaqueAdmissionStore.new
    end
  end
end
