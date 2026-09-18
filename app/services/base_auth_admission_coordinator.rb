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
    "sign_in" => "sign_in_handoff",
    "sign_up" => "sign_up_handoff",
    "invitation" => "sign_up_handoff",
    "step_up" => "step_up_handoff",
    "reauthentication" => "step_up_handoff",
  }.freeze

  RESULT_PURPOSE = {
    "sign_in" => "sign_in_result",
    "sign_up" => "sign_up_result",
    "invitation" => "sign_up_result",
    "step_up" => "step_up_result",
    "reauthentication" => "step_up_result",
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

  BASE_HOST_KEY = {
    "app" => :base_service,
    "com" => :base_corporate,
    "org" => :base_staff,
  }.freeze

  Issuance = Data.define(:transaction, :code, :resume_url)

  class << self
    public

    def issue_handoff!(transaction:, store: default_store)
      purpose = handoff_purpose_for(transaction.intent)
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface),
        surface: transaction.surface,
        subject_ref: transaction.transaction_id,
      )
      Issuance.new(transaction: transaction, code: code, resume_url: nil)
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
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(surface.to_s),
        surface: surface,
      )
      Issuance.new(transaction: nil, code: code, resume_url: nil)
    end

    def consume_local_entry!(raw_code:, surface:, expected_intent:, store: default_store)
      purpose = local_entry_purpose_for(expected_intent)
      result = store.consume!(purpose: purpose, raw_code: raw_code)
      raise Denied, "local admission missing" if result.missing?
      raise Denied, "local admission replay" if result.replay?
      raise Denied, "local admission rejected" unless result.success?

      payload = result.payload
      validate_payload!(payload, surface: surface)
      payload
    end

    def issue_result!(transaction:, ceremony_session_ref: nil, store: default_store)
      purpose = result_purpose_for(transaction.intent)
      code = store.issue!(
        purpose: purpose,
        actor_type: SURFACE_ACTOR.fetch(transaction.surface),
        surface: transaction.surface,
        subject_ref: transaction.transaction_id,
        base_session_ref: transaction.session_ref,
        ceremony_session_ref: ceremony_session_ref,
      )
      Issuance.new(
        transaction: transaction,
        code: code,
        resume_url: resume_url(transaction: transaction, result_code: code),
      )
    end

    def consume_result!(raw_code:, surface:, store: default_store)
      # Result purpose is recovered from the consumed payload; try each result
      # purpose for this surface's expected intents would leak retries. Callers
      # pass the raw code plus surface; we require the payload purpose to be a
      # result purpose and the surface to match.
      last_error = nil
      RESULT_PURPOSE.values.uniq.each do |purpose|
        result = store.consume!(purpose: purpose, raw_code: raw_code)
        next if result.missing?

        raise Denied, "admission replay" if result.replay?
        raise Denied, "admission rejected" unless result.success?

        payload = result.payload
        validate_payload!(payload, surface: surface)
        return payload
      rescue Denied => e
        last_error = e
        raise if e.message == "admission replay"
      end
      raise(last_error || Denied.new("admission missing"))
    end

    def register_result_and_issue_resume!(surface:, login_challenge:, actor:, session_ref:, auth_method:, acr: nil,
                                          authentication_event_at: nil, ceremony_session_ref: nil)
      issuance = OidcAuthorizationTransactionCoordinator.register_result!(
        surface: surface,
        login_challenge: login_challenge,
        actor: actor,
        session_ref: session_ref,
        auth_method: auth_method,
        acr: acr,
        authentication_event_at: authentication_event_at,
      )
      issue_result!(transaction: issuance.transaction, ceremony_session_ref: ceremony_session_ref)
    end

    def resume_url(transaction:, result_code:)
      origin = Oidc::AcmeServiceOrigin.from(
        Rails.configuration.x.boot_config.fetch(:hosts).public_send(BASE_HOST_KEY.fetch(transaction.surface)).to_s,
        default_scheme: "https",
      )
      origin.authorization_endpoint(query: { result: result_code })
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

    private

    def consume_code!(purpose:, raw_code:, surface:, store:)
      result = store.consume!(purpose: purpose, raw_code: raw_code)
      raise Denied, "admission missing" if result.missing?
      raise Denied, "admission replay" if result.replay?
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

    def default_store
      Valkey::AuthState::OpaqueAdmissionStore.new
    end
  end
end
