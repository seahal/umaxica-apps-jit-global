# typed: false
# frozen_string_literal: true

require "base64"
require "digest"
require "securerandom"

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY = AcmeLogoutTransactionable::BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY
  BROWSER_RP_LOGOUT_PROOF_KEY = "proof"
  BROWSER_RP_LOGOUT_CLIENT_ID_KEY = "client_id"
  BROWSER_RP_LOGOUT_SESSION_REF_KEY = "session_ref"
  BROWSER_RP_LOGOUT_PARENT_SESSION_REF_KEY = "parent_session_ref"
  BROWSER_RP_LOGOUT_EXPIRES_AT_KEY = "expires_at"
  BROWSER_RP_ORIGIN_STEPS = [
    AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED,
    AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED,
    AcmeLogoutTransaction::STEP_FINALIZED,
  ].freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
    ensure_fqdn_gate_first!
    helper_method :browser_rp_logout_flow?, :browser_rp_logout_intent_proof_for
  end

  public

  def browser_rp_logout_flow?
    true
  end

  def authenticate_oidc_rp_session!
    resolved = resolve_oidc_rp_logout_credentials
    unless resolved
      render plain: "Authentication required", status: :unauthorized
      return
    end

    @oidc_rp_logout_session, @oidc_rp_logout_resource, @oidc_rp_logout_access_payload = resolved
    @current_resource = @oidc_rp_logout_resource
    @current_session_public_id = @oidc_rp_logout_session.public_id
  end

  private

  # A completed authority phase deliberately revokes the parent Browser Session before the
  # initiating RP returns to its own origin. The origin therefore sees a stale RP credential while
  # it is still required to finish its local cleanup. The live logout challenge is the authority
  # for that continuation; it must not turn an ordinary stale credential into an authenticated
  # request.
  def browser_rp_invalid_credentials_are_ignored?
    return true if browser_rp_logout_transaction_for_origin

    super
  end

  def launch_oidc_rp_logout!(client_id:, issuer_resource_type: nil, token_issuer: nil, session_authority: :rp_session)
    _ = [issuer_resource_type, token_issuer, session_authority]
    completion_region = rp_logout_region
    session_record = oidc_rp_logout_session
    resource_type = oidc_rp_logout_resource_type
    existing_transaction = reusable_browser_rp_logout_transaction(
      session_record: session_record,
      client_id: client_id,
      resource_type: resource_type,
    )
    return redirect_to_browser_rp_logout_authority(existing_transaction, client_id:, region: completion_region) if
      existing_transaction

    origin_intent_proof = SecureRandom.random_bytes(32)
    transaction_result = issue_browser_rp_logout_transaction(
      client_id:,
      completion_region:,
      session_record:,
      resource_type:,
      origin_intent_proof:,
    )
    return render_oidc_rp_logout_unavailable unless transaction_result.success?

    transaction = transaction_result.transaction
    store_browser_rp_logout_intent_proof!(transaction, origin_intent_proof)
    log_browser_rp_logout_issued!(transaction)
    redirect_to_browser_rp_logout_authority(transaction, client_id:, region: completion_region)
  rescue RpSession::IssuanceRejected => e
    Rails.logger.warn(
      "auth.sign_out.browser_rp_binding_rejected " \
      "error_class=#{e.class.name} result=unavailable",
    )
    render_oidc_rp_logout_unavailable
  end

  def continue_browser_rp_logout!
    transaction = browser_rp_logout_transaction_for_origin
    return head(:not_found) unless transaction

    @logout_transaction = transaction
    return render_browser_rp_logout_continuation! if request.get? || request.head?

    complete_browser_rp_logout_at_origin!(transaction)
  end

  def render_browser_rp_logout_continuation!
    render "auth/shared/sign_outs/edit", status: :ok
  end

  def browser_rp_logout_authority_url(transaction, client_id:, region:)
    client = OidcClientRegistry.find!(client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    uri = URI.parse(OidcIssuer.end_session_endpoint(resource_type))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["logout_challenge"] = transaction.logout_challenge
    query["ri"] = region if region.present?
    uri.query = query.to_query
    uri.to_s
  rescue URI::InvalidURIError
    raise OidcRpLogoutError, "logout authority endpoint is invalid"
  end

  def redirect_to_browser_rp_logout_authority(transaction, client_id:, region:)
    redirect_to(
      browser_rp_logout_authority_url(transaction, client_id:, region:),
      allow_other_host: true,
      status: :see_other,
    )
  end

  def issue_browser_rp_logout_transaction(client_id:, completion_region:, session_record:, resource_type:,
                                          origin_intent_proof:)
    binding = AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
      session_record:,
      resource_type:,
      origin_intent_digest: Digest::SHA256.digest(origin_intent_proof),
    )
    options = {
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      origin_surface: logout_origin_surface,
      initiating_client_id: client_id,
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: logout_origin_surface,
        ri: completion_region,
        surface: logout_surface_name,
      ),
      actor_ref: oidc_rp_logout_resource.try(:public_id),
      session_ref: session_record.public_id,
      callback_state: nil,
      surface: logout_surface_name,
      **binding,
    }
    options[:ri] = completion_region if logout_surface_name == "app"
    AcmeLogoutTransactionCoordinator.issue!(**options)
  end

  def log_browser_rp_logout_issued!(transaction)
    log_sign_out_event(
      "auth.sign_out.transaction.issued",
      transaction:,
      user_confirmation_required: true,
      auto_handoff: false,
      cleanup_performed: false,
      result: "issued",
    )
  end

  def complete_browser_rp_logout_at_origin!(transaction)
    current_transaction = transaction
    if current_transaction.expected_step != AcmeLogoutTransaction::STEP_FINALIZED &&
        !browser_rp_logout_intent_proof_valid?(current_transaction)
      Rails.logger.warn("auth.sign_out.browser_rp_intent_proof_rejected result=unavailable")
      return render_oidc_rp_logout_unavailable
    end

    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED
      proof_entry = browser_rp_logout_intent_entry_for(current_transaction)
      prepare_browser_rp_sign_out_notice!(current_transaction)
      clear_oidc_rp_logout_cookies!
      reset_session_and_clear_inertia_history!
      restore_browser_rp_logout_intent_proof!(current_transaction, proof_entry)
      issue_sign_out_notice! if session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY].blank?
      current_transaction = advance_browser_rp_logout!(
        current_transaction,
        AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED,
      )
    end

    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED
      issue_sign_out_notice! unless sign_out_notice_issued?
      revoke_browser_rp_origin_session!(current_transaction)
      current_transaction = advance_browser_rp_logout!(
        current_transaction,
        AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED,
      )
    end

    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_FINALIZED
      result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: current_transaction.logout_challenge)
      return render_oidc_rp_logout_unavailable unless result.success?

      current_transaction = result.transaction
      delete_browser_rp_logout_intent_proof!(current_transaction)
    end

    redirect_to(current_transaction.completion_url, allow_other_host: true, status: :see_other)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RpSession::IssuanceRejected,
         Umaxica::Valkey::Error => e
    Rails.logger.warn(
      "auth.sign_out.browser_rp_origin_failed " \
      "error_class=#{e.class.name} " \
      "error_fields=#{e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.attribute_names.join(",") : "none"} " \
      "result=unavailable",
    )
    render_oidc_rp_logout_unavailable
  end

  def complete_oidc_rp_logout!
    return head(:not_found) if sign_out_active_context_present?

    notice_id = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    return head(:not_found) unless notice_id.is_a?(String) && notice_id.present?

    completion_state = Valkey::AuthState::SignOutNoticeStore.new.read(raw_id: notice_id)
    return head(:not_found) unless completion_state
    return head(:not_found) unless completion_state["face"].to_s == logout_surface_name.to_s

    expected_state = completion_state["state"].to_s
    provided_state = params[:state].to_s
    return head(:not_found) if expected_state.present? && provided_state.blank?
    return head(:not_found) if expected_state.blank? && provided_state.present?
    return head(:not_found) unless expected_state.blank? || expected_state.length == provided_state.length
    return head(:not_found) if expected_state.present? && !ActiveSupport::SecurityUtils.secure_compare(
      expected_state,
      provided_state,
    )

    @sign_out_notice = consume_sign_out_notice
    return head(:not_found) unless @sign_out_notice

    render_oidc_rp_logout_completion
  end

  class OidcRpLogoutError < StandardError; end

  private

  def browser_rp_logout_transaction_for_origin
    challenge = params[:logout_challenge].to_s
    return if challenge.blank?

    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)
    return unless transaction.browser_rp_workflow?
    return unless transaction.origin_surface == logout_origin_surface
    return unless transaction.initiating_client_id == oidc_client_id
    return unless BROWSER_RP_ORIGIN_STEPS.include?(transaction.expected_step)
    return if transaction.expired? && !transaction.finalized?

    transaction
  rescue ActiveRecord::RecordNotFound, ArgumentError
    nil
  end

  def browser_rp_logout_intent_proof_for(transaction)
    browser_rp_logout_intent_entry_for(transaction)&.fetch(BROWSER_RP_LOGOUT_PROOF_KEY, nil).to_s.presence
  end

  def store_browser_rp_logout_intent_proof!(transaction, raw_proof)
    proofs = session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    proofs = {} unless proofs.is_a?(Hash)
    proofs[transaction.logout_challenge.to_s] = {
      BROWSER_RP_LOGOUT_PROOF_KEY => Base64.strict_encode64(raw_proof),
      BROWSER_RP_LOGOUT_CLIENT_ID_KEY => transaction.initiating_client_id,
      BROWSER_RP_LOGOUT_SESSION_REF_KEY => transaction.session_ref,
      BROWSER_RP_LOGOUT_PARENT_SESSION_REF_KEY => transaction.parent_session_ref,
      BROWSER_RP_LOGOUT_EXPIRES_AT_KEY => transaction.expires_at.iso8601(6),
    }
    session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY] = proofs
  end

  def restore_browser_rp_logout_intent_proof!(transaction, proof_entry)
    return unless proof_entry.is_a?(Hash)

    proofs = session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    proofs = {} unless proofs.is_a?(Hash)
    proofs[transaction.logout_challenge.to_s] = proof_entry
    session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY] = proofs
  end

  def delete_browser_rp_logout_intent_proof!(transaction)
    proofs = session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    return unless proofs.is_a?(Hash)

    proofs.delete(transaction.logout_challenge.to_s)
    session.delete(BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY) if proofs.empty?
  end

  def browser_rp_logout_intent_proof_valid?(transaction)
    return false unless transaction.browser_rp_binding_v1?

    proof_entry = browser_rp_logout_intent_entry_for(transaction)
    entry_matches = browser_rp_logout_intent_entry_matches?(proof_entry, transaction)
    return false unless entry_matches

    encoded_proof = proof_entry.fetch(BROWSER_RP_LOGOUT_PROOF_KEY).to_s.presence
    provided_proof = params[:logout_intent_proof].to_s.presence
    return false if encoded_proof.blank? || provided_proof.blank?
    return false unless encoded_proof.bytesize == provided_proof.bytesize
    return false unless ActiveSupport::SecurityUtils.secure_compare(encoded_proof, provided_proof)

    raw_proof = Base64.strict_decode64(provided_proof)
    return false unless raw_proof.bytesize == 32

    expected_digest = transaction.origin_intent_digest.to_s.b
    actual_digest = Digest::SHA256.digest(raw_proof)
    return false unless expected_digest.bytesize == actual_digest.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected_digest, actual_digest)
  rescue ArgumentError, TypeError
    false
  end

  def browser_rp_logout_intent_entry_for(transaction)
    return unless transaction

    proofs = session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    return unless proofs.is_a?(Hash)

    entry = proofs[transaction.logout_challenge.to_s] || proofs[transaction.logout_challenge.to_sym]
    return unless entry.is_a?(Hash)

    entry.stringify_keys
  end

  def browser_rp_logout_intent_entry_matches?(entry, transaction)
    return false unless entry.is_a?(Hash)
    return false unless entry[BROWSER_RP_LOGOUT_CLIENT_ID_KEY].to_s == transaction.initiating_client_id.to_s
    return false unless entry[BROWSER_RP_LOGOUT_SESSION_REF_KEY].to_s == transaction.session_ref.to_s
    return false unless entry[BROWSER_RP_LOGOUT_PARENT_SESSION_REF_KEY].to_s == transaction.parent_session_ref.to_s

    expires_at = Time.zone.iso8601(entry.fetch(BROWSER_RP_LOGOUT_EXPIRES_AT_KEY).to_s)
    expires_at > Time.current
  rescue ArgumentError, KeyError, TypeError
    false
  end

  def reusable_browser_rp_logout_transaction(session_record:, client_id:, resource_type:)
    proofs = session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    return unless proofs.is_a?(Hash)

    parent_session_ref = session_record.parent_device_session&.public_id
    return if parent_session_ref.blank?

    changed = false
    reusable = nil
    proofs.keys.each do |challenge|
      candidate = reusable_browser_rp_logout_candidate(
        challenge,
        proofs[challenge],
        session_record:,
        client_id:,
        resource_type:,
        parent_session_ref:,
      )
      if candidate == :stale
        proofs.delete(challenge)
        changed = true
      elsif candidate
        reusable = candidate
        break
      end
    end

    session[BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY] = proofs if changed
    reusable
  rescue ActiveRecord::RecordNotFound, ArgumentError, TypeError
    nil
  end

  def reusable_browser_rp_logout_candidate(challenge, raw_entry, session_record:, client_id:, resource_type:,
                                           parent_session_ref:)
    return :stale unless raw_entry.is_a?(Hash)

    entry = raw_entry.stringify_keys
    return unless browser_rp_logout_intent_entry_metadata_matches?(
      entry, client_id:, session_record:,
             parent_session_ref:,
    )

    transaction =
      AppTicketRecord.connected_to(role: :writing) do
        AcmeLogoutTransaction.find_by(public_id: challenge.to_s)
      end
    return :stale unless browser_rp_logout_transaction_reusable?(
      transaction,
      client_id:,
      resource_type:,
      parent_session_ref:,
    )

    transaction
  end

  def browser_rp_logout_transaction_reusable?(transaction, client_id:, resource_type:, parent_session_ref:)
    transaction&.browser_rp_workflow? && transaction.browser_rp_binding_v1? &&
      transaction.origin_surface == logout_origin_surface &&
      transaction.initiating_client_id == client_id.to_s &&
      transaction.realm == browser_rp_logout_realm_for(resource_type) &&
      transaction.parent_session_ref == parent_session_ref &&
      !transaction.finalized? && !transaction.failed? && !transaction.expired?
  end

  def browser_rp_logout_intent_entry_metadata_matches?(entry, client_id:, session_record:, parent_session_ref:)
    entry[BROWSER_RP_LOGOUT_CLIENT_ID_KEY].to_s == client_id.to_s &&
      entry[BROWSER_RP_LOGOUT_SESSION_REF_KEY].to_s == session_record.public_id.to_s &&
      entry[BROWSER_RP_LOGOUT_PARENT_SESSION_REF_KEY].to_s == parent_session_ref.to_s &&
      browser_rp_logout_entry_unexpired?(entry)
  end

  def browser_rp_logout_entry_unexpired?(entry)
    Time.zone.iso8601(entry.fetch(BROWSER_RP_LOGOUT_EXPIRES_AT_KEY).to_s) > Time.current
  rescue ArgumentError, KeyError, TypeError
    false
  end

  def browser_rp_logout_realm_for(resource_type)
    { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(resource_type.to_s)
  end

  def advance_browser_rp_logout!(transaction, step)
    result = AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: step,
    )
    raise RpSession::IssuanceRejected, result.error_description unless result.success?

    result.transaction
  end

  def browser_rp_logout_session_for(transaction)
    client = OidcClientRegistry.find!(transaction.initiating_client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    case resource_type
    when "client"
      AppTicketRecord.connected_to(role: :writing) do
        ClientRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    when "visitor"
      ComTicketRecord.connected_to(role: :writing) do
        VisitorRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    when "operator"
      OrgTicketRecord.connected_to(role: :writing) do
        OperatorRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    else
      raise ArgumentError, "unsupported Browser RP logout resource type"
    end
  end

  def revoke_browser_rp_origin_session!(transaction)
    session_record = browser_rp_logout_session_for(transaction)
    return true unless session_record

    result = RpSessionRevoker.call(scope: :rp_session, record: session_record, status: "success")
    raise RpSession::IssuanceRejected, "RP Session revoke failed" unless result.success?

    true
  end

  def prepare_browser_rp_sign_out_notice!(transaction)
    @sign_out_access_expires_at = browser_rp_logout_access_expires_at
    @sign_out_actor_ref = transaction.actor_ref
    @sign_out_session_public_id = transaction.session_ref
    @sign_out_state = transaction.callback_state
  end

  def browser_rp_logout_access_expires_at
    value = @oidc_rp_logout_access_payload&.dig("exp")
    value.present? ? Time.zone.at(Integer(value)) : nil
  rescue ArgumentError, TypeError
    nil
  end

  def sign_out_notice_issued?
    session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY].is_a?(String)
  end

  def resolve_oidc_rp_logout_credentials
    resource_type = oidc_rp_logout_resource_type
    access_plain, refresh_plain = oidc_rp_logout_cookie_values
    return if access_plain.blank? && refresh_plain.blank?

    access_payload = decode_oidc_rp_logout_access(access_plain, resource_type)
    access_session = find_oidc_rp_logout_access_session(access_payload, resource_type)
    refresh_session = find_oidc_rp_logout_session_from_refresh(
      refresh_plain,
      client_id: oidc_client_id,
      resource_type: resource_type,
    ) if refresh_plain.present?
    return unless valid_oidc_rp_logout_credential_set?(
      access_plain,
      access_payload,
      access_session,
      refresh_session,
      resource_type,
      refresh_present: refresh_plain.present?,
    )

    session_record = access_session || refresh_session
    return unless oidc_rp_logout_session_current?(session_record)

    resource = oidc_rp_logout_resource_for(session_record)
    return unless resource&.active?
    return if access_payload && OidcSubject.for(resource, resource_type: resource_type) !=
      AuthorizationTokenClaims.subject(access_payload).to_s

    [session_record, resource, access_payload]
  rescue ArgumentError, ActiveRecord::RecordNotFound, URI::InvalidURIError
    nil
  end

  def oidc_rp_logout_cookie_values
    [
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence,
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.presence,
    ]
  end

  def decode_oidc_rp_logout_access(access_plain, resource_type)
    return if access_plain.blank?

    OidcRpBrowserCredentialContract.decode_access_token(
      token: access_plain,
      host: request.host,
      resource_type: resource_type,
      client_id: oidc_client_id,
      allow_expired: true,
    )
  end

  def find_oidc_rp_logout_access_session(access_payload, resource_type)
    return if access_payload.blank?

    find_oidc_rp_logout_session(
      public_id: AuthorizationTokenClaims.session_id(access_payload),
      client_id: oidc_client_id,
      resource_type: resource_type,
    )
  end

  def valid_oidc_rp_logout_credential_set?(
    access_plain,
    access_payload,
    access_session,
    refresh_session,
    resource_type,
    refresh_present:
  )
    return false if access_plain.present? && access_payload.blank?
    return false if access_payload && !valid_oidc_rp_logout_access?(access_payload, access_session, resource_type)
    return false if refresh_session.blank? && access_session.blank? && refresh_present
    return false if access_session && refresh_session && access_session.public_id != refresh_session.public_id

    true
  end

  def oidc_rp_logout_resource_type
    OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(oidc_client_id))
  end

  def oidc_rp_logout_session_class_for(resource_type)
    case resource_type.to_s
    when "operator" then OperatorRpSession
    when "visitor" then VisitorRpSession
    when "client" then ClientRpSession
    else raise ArgumentError, "unsupported RP Session resource type"
    end
  end

  def oidc_rp_logout_session_relation_for(resource_type)
    case resource_type.to_s
    when "operator" then OperatorRpSession.includes(operator_device_session: :staff)
    when "visitor" then VisitorRpSession.includes(visitor_device_session: :visitor)
    when "client" then ClientRpSession.includes(client_device_session: :user)
    else raise ArgumentError, "unsupported RP Session resource type"
    end
  end

  def oidc_rp_logout_connection_for(resource_type)
    case resource_type.to_s
    when "operator" then OrgTicketRecord
    when "visitor" then ComTicketRecord
    else AppTicketRecord
    end
  end

  def find_oidc_rp_logout_session(public_id:, client_id:, resource_type:)
    return if public_id.blank?

    oidc_rp_logout_connection_for(resource_type).connected_to(role: :writing) do
      oidc_rp_logout_session_relation_for(resource_type).find_by(
        public_id: public_id,
        oidc_client_id: client_id,
      )
    end
  end

  def find_oidc_rp_logout_session_from_refresh(refresh_plain, client_id:, resource_type:)
    parsed = oidc_rp_logout_session_class_for(resource_type).parse_refresh_token(refresh_plain)
    return if parsed.blank?

    public_id, verifier = parsed
    session_record = find_oidc_rp_logout_session(
      public_id: public_id,
      client_id: client_id,
      resource_type: resource_type,
    )
    return unless session_record&.authenticate_refresh_token(verifier)

    session_record
  end

  def valid_oidc_rp_logout_access?(payload, session_record, resource_type)
    return false unless session_record
    return false if session_record.oidc_jti.blank?

    expected_jti = session_record.oidc_jti.to_s
    actual_jti = AuthorizationTokenClaims.jti(payload).to_s
    return false unless expected_jti.bytesize == actual_jti.bytesize
    return false unless ActiveSupport::SecurityUtils.secure_compare(expected_jti, actual_jti)

    OidcSubject.for(oidc_rp_logout_resource_for(session_record), resource_type: resource_type).to_s ==
      AuthorizationTokenClaims.subject(payload).to_s
  rescue ArgumentError
    false
  end

  def oidc_rp_logout_session_current?(session_record)
    return false unless session_record
    return false if session_record.revoked?

    session_record.parent_token_active?
  end

  def oidc_rp_logout_resource_for(session_record)
    case session_record
    when OperatorRpSession then session_record.staff
    when VisitorRpSession then session_record.visitor
    else session_record.user
    end
  end

  def oidc_rp_logout_session
    @oidc_rp_logout_session || raise(OidcRpLogoutError, "RP Session was not authenticated")
  end

  def oidc_rp_logout_resource
    @oidc_rp_logout_resource || raise(OidcRpLogoutError, "RP resource was not authenticated")
  end

  def clear_oidc_rp_logout_cookies!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
  end

  def render_oidc_rp_logout_unavailable
    return render_oidc_rp_logout_completion unless logout_surface_name == "app"

    render "auth/shared/sign_outs/unavailable", status: :unprocessable_content
  end

  def render_oidc_rp_logout_completion
    render "auth/shared/sign_outs/complete", status: :ok
  end

  def rp_logout_region
    RequestContextContract.normalize_region(params[:ri])
  end

  def normalize_rp_logout_region!
    return unless logout_surface_name == "app"

    params[:ri] = rp_logout_region
  end

  def logout_origin_surface
    origin_surface = controller_path.split("/").first
    (origin_surface == "auth") ? "sign" : origin_surface
  end

  def logout_surface_name
    controller_path.split("/").second
  end
end
