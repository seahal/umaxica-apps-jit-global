# typed: false
# frozen_string_literal: true

# Base issues and Auth/Base consume purpose-specific opaque admission/result
# codes. Raw codes never persist; Valkey OpaqueAdmissionStore keys by digest.
require "digest"

class BaseAuthAdmissionCoordinator < ApplicationService
  ADMISSION_REFERENCE_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.freeze

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
  CANCELLATION_HANDOFF_VERSION = 1

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

  ADMISSION_BINDING = {
    "app" => ClientAuthAdmissionBinding,
    "com" => VisitorAuthAdmissionBinding,
    "org" => OperatorAuthAdmissionBinding,
  }.freeze

  Issuance = Data.define(:transaction, :code, :reference)
  CancellationIssuance = Data.define(:transaction, :reference, :handoff)

  class << self
    public

    def issue_handoff!(transaction:, base_browser_nonce:, base_token:, reference: nil, restart_of: nil,
                       store: default_store)
      purpose = handoff_purpose_for(transaction.intent)
      binding, code = issue_binding_and_transport!(
        transaction: transaction, purpose: purpose, base_browser_nonce: base_browser_nonce,
        base_token: base_token, requested_reference: reference, restart_of:, store: store,
      )
      Issuance.new(transaction: transaction, code: code, reference: binding.entry_ref)
    end

    def issue_local_entry!(surface:, intent:, base_browser_nonce:, base_token:, nonce_digest: nil,
                           restart_of: nil, store: default_store)
      purpose = local_entry_purpose_for(intent)
      model = LOCAL_SIGN_IN_FLOW.fetch(surface.to_s)
      binding, transaction, code =
        model.connection_class_for_self.connected_to(role: :writing) do
        model.transaction do
          now = model.database_now
          created =
            if restart_of.present?
              restart_local_flow!(model:, surface: surface.to_s, purpose:, restart_of:, now:)
            else
              model.create!(
                state_id: model.state_id_for("PRIMARY_PENDING"),
                nonce_digest: nonce_digest || model.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: now, expires_at: now + model.default_ttl,
              )
            end
          binding = create_or_reuse_binding!(
            transaction: created, surface: surface.to_s, purpose: purpose, base_browser_nonce: base_browser_nonce,
            base_token: base_token, requested_reference: nil, restart_of:, now: now,
          )
          issued_code = issue_transport!(
            transaction: created, surface: surface.to_s, purpose: purpose, binding: binding,
            base_token: base_token, store: store,
          )
          [binding, created, issued_code]
        end
      end
      Issuance.new(transaction: transaction, code: code, reference: binding.entry_ref)
    end

    def consume_entry_reference!(reference:, surface:, expected_intent:, binding:, raw_auth_sid:, store: default_store)
      validate_entry_binding!(
        reference: reference, surface: surface, expected_intent: expected_intent,
        binding: binding, raw_auth_sid: raw_auth_sid,
      )
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
      validate_entry_payload_binding!(payload: payload, binding: binding, expected_intent: expected_intent)
      validate_entry_binding!(
        reference: reference, surface: surface, expected_intent: expected_intent,
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

    def issue_cancellation!(transaction:, ceremony_session_ref: nil, store: default_store)
      now = transaction.class.database_now
      unless %w(pending verified canceled).include?(transaction.status) && !transaction.expired?(now: now)
        raise Denied.new("cancellation is unavailable", code: "transaction_unavailable")
      end

      remaining = [transaction.expires_at - now, 1.second].max
      reference = nil
      handoff = nil
      transaction.class.connection_owner.connected_to(role: :writing) do
        transaction.class.connection_owner.transaction do
          transaction.with_lock do
            if transaction.cancellation_handoff_ref.present? || transaction.cancellation_handoff_ciphertext.present?
              unless transaction.cancellation_handoff_ref.present? && transaction.cancellation_handoff_ciphertext.present?
                raise Denied.new("cancellation handoff is incomplete", code: "transaction_conflict")
              end

              reference = transaction.cancellation_handoff_ref
              handoff = transaction.cancellation_handoff_ciphertext
              payload = decrypt_cancellation_handoff(handoff)
              unless payload.fetch("reference") == reference && payload.fetch("transaction_ref") == transaction.transaction_id
                raise Denied.new("cancellation handoff is inconsistent", code: "transaction_conflict")
              end

              ensure_cancellation_transport!(
                store: store, reference: reference, transaction: transaction, raw_code: payload.fetch("raw_code"),
                ceremony_session_ref: ceremony_session_ref, ttl: remaining, now: now,
              ) unless transaction.status == "canceled"
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
      unless handoff.is_a?(String) && handoff.present? && transaction_ref.is_a?(String) && transaction_ref.present?
        raise Denied.new("cancellation handoff is invalid", code: "invalid_admission")
      end

      payload = decrypt_cancellation_handoff(handoff)
      unless payload.fetch("surface") == surface.to_s && payload.fetch("transaction_ref") == transaction_ref.to_s
        raise Denied.new("cancellation handoff binding mismatch", code: "return_binding_mismatch")
      end

      reference = payload.fetch("reference")
      unless reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN)
        raise Denied.new("cancellation reference is invalid", code: "invalid_admission")
      end

      transaction = step_up_transaction_for(surface:, transaction_ref:)
      expected_reference = transaction.cancellation_handoff_ref
      unless expected_reference.present? && expected_reference == reference &&
          transaction.cancellation_handoff_ciphertext.present? &&
          ActiveSupport::SecurityUtils.secure_compare(transaction.cancellation_handoff_ciphertext, handoff)
        raise Denied.new("cancellation handoff binding mismatch", code: "return_binding_mismatch")
      end

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
      unless reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN) &&
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

    def admission_binding_model(surface)
      ADMISSION_BINDING.fetch(surface.to_s)
    rescue KeyError
      raise Denied.new("unsupported admission surface", code: "malformed_request")
    end

    def find_admission_binding!(surface:, reference:)
      raise Denied.new("admission reference is invalid", code: "invalid_admission") unless
        reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN)

      admission_binding_model(surface).connection_owner.connected_to(role: :writing) do
        admission_binding_model(surface).find_by!(entry_ref: reference)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission binding missing", code: "invalid_admission")
    end

    def find_admission_binding_by_confirmation!(surface:, reference:)
      raise Denied.new("confirmation reference is invalid", code: "invalid_admission") unless
        reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN)

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

    def local_entry_purpose_for(intent)
      LOCAL_ENTRY_PURPOSE.fetch(intent.to_s) { raise ArgumentError, "unsupported local entry intent" }
    end

    def local_entry_purpose?(payload:, intent:)
      purpose = LOCAL_ENTRY_PURPOSE[intent.to_s]
      purpose.present? && payload.fetch("purpose").to_s == purpose
    end

    private

    private :handoff_purpose_for, :result_purpose_for, :local_entry_purpose_for

    def issue_binding_and_transport!(transaction:, purpose:, base_browser_nonce:, base_token:,
                                     requested_reference:, restart_of:, store:)
      model = admission_binding_model(transaction.surface)
      model.connection_owner.connected_to(role: :writing) do
        model.transaction do
          locked_transaction = transaction.class.lock.find(transaction.id)
          binding = create_or_reuse_binding!(
            transaction: locked_transaction, surface: locked_transaction.surface, purpose: purpose,
            base_browser_nonce: base_browser_nonce,
            base_token: base_token, requested_reference: requested_reference, restart_of:, now: model.database_now,
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
                                 requested_reference:, restart_of:, now:)
      model = admission_binding_model(surface)
      parent_attributes = binding_parent_attributes(transaction)
      validate_base_token!(transaction: transaction, surface: surface, base_token: base_token)

      retire_restart_binding!(
        model:, transaction:, surface:, purpose:, base_browser_nonce:, base_token:, restart_of:, now:,
      ) if restart_of.present?

      existing = model.lock.find_by(parent_attributes.merge(purpose: purpose, retired_at: nil, redeemed_at: nil))
      if existing
        if existing.expired?(now: now)
          existing.retire!(now: now)
        else
          ensure_binding_token_matches!(existing, base_token)
          return existing
        end
      end

      entry_ref = SecureRandom.uuid
      expiry = [transaction_expiry(transaction), now + Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL].compact.min
      digest = AuthAdmissionBinding.browser_digest(
        surface: surface, entry_ref: entry_ref, nonce: base_browser_nonce,
      )
      model.create!(
        parent_attributes.merge(
          entry_ref: entry_ref,
          purpose: purpose,
          base_token_id: base_token&.id,
          base_browser_digest: digest,
          expires_at: expiry,
          created_at: now,
          updated_at: now,
        ),
      )
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def restart_local_flow!(model:, surface:, purpose:, restart_of:, now:)
      validate_admission_reference!(restart_of, label: "restart reference")
      binding_model = admission_binding_model(surface)
      binding = binding_model.find_by!(entry_ref: restart_of)
      raise Denied.new("local restart parent mismatch", code: "invalid_admission") if
        binding.sign_in_flow_id.blank?

      flow = model.lock.find(binding.sign_in_flow_id)
      unless binding.purpose == purpose && flow.sign_in_primary_pending? && !flow.expired?(now) && flow.principal_id.nil?
        raise Denied.new("local restart is unavailable", code: "invalid_admission")
      end

      flow
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("local restart binding missing", code: "invalid_admission")
    end

    def retire_restart_binding!(model:, transaction:, surface:, purpose:, base_browser_nonce:, base_token:,
                                restart_of:, now:)
      validate_admission_reference!(restart_of, label: "restart reference")
      binding = model.lock.find_by!(entry_ref: restart_of)
      unless binding_parent_matches?(binding, transaction) &&
          binding.purpose == purpose && !binding.redeemed? && !binding.retired? && binding.live?(now: now)
        raise Denied.new("admission restart is unavailable", code: "invalid_admission")
      end

      expected_digest = AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: binding.entry_ref, nonce: base_browser_nonce,
      )
      unless binding.base_browser_digest == expected_digest && binding.base_token_id == base_token&.id
        raise Denied.new("admission restart browser binding mismatch", code: "session_binding_mismatch")
      end

      binding.retire!(now: now)
    rescue ActiveRecord::RecordNotFound
      raise Denied.new("admission restart binding missing", code: "invalid_admission")
    end

    def validate_admission_reference!(reference, label:)
      return if reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN)

      raise Denied.new("#{label} is invalid", code: "invalid_admission")
    end

    def binding_parent_matches?(binding, transaction)
      case transaction
      when ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow
        binding.sign_in_flow_id == transaction.id
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
      store.issue!(**arguments)
    rescue Umaxica::Valkey::OperationError => e
      raise unless e.message == "admission code key collision" && store.respond_to?(:reissue_reference!)

      store.reissue_reference!(**arguments.except(:reference).merge(reference: binding.entry_ref))
    end

    def cancellation_handoff_encryptor
      key = Rails.application.key_generator.generate_key(
        "base-auth-cancellation-handoff", ActiveSupport::MessageEncryptor.key_len,
      )
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end

    def decrypt_cancellation_handoff(handoff)
      raw = cancellation_handoff_encryptor.decrypt_and_verify(handoff)
      payload = JSON.parse(raw)
      raise TypeError unless payload.is_a?(Hash) && payload.fetch("version") == CANCELLATION_HANDOFF_VERSION

      expires_at = Time.zone.iso8601(payload.fetch("expires_at"))
      raise ArgumentError if expires_at <= Time.current

      payload
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
      when ClientSignInFlow
        { sign_in_flow_id: transaction.id }
      when VisitorSignInFlow
        { sign_in_flow_id: transaction.id }
      when OperatorSignInFlow
        { sign_in_flow_id: transaction.id }
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
      when ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow
        transaction.public_id
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
      when ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow,
           ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction,
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
        when ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow,
             ClientOidcAuthorizationTransaction, VisitorOidcAuthorizationTransaction,
             OperatorOidcAuthorizationTransaction
          true
        else
          false
        end
      return if base_token.nil? && allowed_without_token
      return if base_token.is_a?(expected_class)

      raise Denied.new("Base token binding is invalid", code: "session_binding_mismatch")
    end

    def ensure_binding_token_matches!(binding, base_token)
      return if binding.base_token_id == base_token&.id

      raise Denied.new("Base token binding is invalid", code: "session_binding_mismatch")
    end

    def validate_entry_binding!(reference:, surface:, expected_intent:, binding:, raw_auth_sid:)
      model = admission_binding_model(surface)
      unless reference.is_a?(String) && reference.match?(ADMISSION_REFERENCE_PATTERN) &&
          binding.is_a?(model) && binding.entry_ref == reference && binding.live? &&
          binding.confirmed? && binding.attached?
        raise Denied.new("admission binding is unavailable", code: "invalid_admission")
      end

      unless raw_auth_sid.is_a?(String) && raw_auth_sid.present?
        raise Denied.new("Auth ceremony session is missing", code: "session_binding_mismatch")
      end

      auth_session = model.auth_admission_session_class.find_active_by_raw_sid(raw_auth_sid)
      unless auth_session && auth_session.id == binding.auth_ceremony_session_id && !auth_session.admitted?
        raise Denied.new("Auth ceremony session does not match binding", code: "session_binding_mismatch")
      end

      return auth_session if expected_intent.to_s.blank?

      auth_session
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise Denied.new("Auth ceremony session is invalid", code: "session_binding_mismatch")
    end

    def validate_entry_payload_binding!(payload:, binding:, expected_intent:)
      expected_purpose =
        if local_entry_purpose?(payload: { "purpose" => binding.purpose }, intent: expected_intent)
          local_entry_purpose_for(expected_intent)
        else
          handoff_purpose_for(expected_intent)
        end
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
      when :sign_in_flow
        binding.sign_in_flow.public_id
      when :authorization_transaction
        binding.authorization_transaction.transaction_id
      when :step_up_ceremony_transaction
        binding.step_up_ceremony_transaction.transaction_id
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
