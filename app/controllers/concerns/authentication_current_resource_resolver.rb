# typed: false
# frozen_string_literal: true

class AuthenticationCurrentResourceResolver
  Result =
    Struct.new(
      :resource,
      :session_public_id,
      :token_public_id,
      :payload,
      :failure_reason,
      keyword_init: true,
    ) do
      def success?
        resource.present?
      end
    end

  def initialize(access_token:, request_host:, resource_type:, resource_class:, token_class:,
                 authorization_scheme: nil, dpop_proof: nil, request_method: nil, request_uri: nil,
                 jwt_issuer_id: nil)
    @access_token = access_token
    @request_host = request_host
    @resource_type = resource_type
    @resource_class = resource_class
    @token_class = token_class
    @authorization_scheme = authorization_scheme
    @dpop_proof = dpop_proof
    @request_method = request_method
    @request_uri = request_uri
    @jwt_issuer_id = jwt_issuer_id
  end

  def call
    return failure(:blank_access_token) if @access_token.blank?

    payload = AuthenticationToken.decode(
      @access_token,
      host: @request_host,
      resource_type: @resource_type,
      jwt_issuer_id: @jwt_issuer_id,
    )
    if payload.blank?
      sid = AuthenticationToken.extract_session_id_allow_expired(
        @access_token,
        host: @request_host,
        resource_type: @resource_type,
        jwt_issuer_id: @jwt_issuer_id,
      )
      return failure(:token_decode_failed, session_public_id: sid) if sid.present?

      return failure(:token_decode_failed)
    end
    return failure(:dpop_verification_failed, payload: payload) unless dpop_valid?(payload)

    unless AuthenticationToken.resource_type_scope_matches?(payload, @resource_type)
      return failure(:actor_mismatch, payload: payload)
    end

    sid = AuthenticationToken.extract_session_id(payload)
    return failure(:missing_session_id, payload: payload) if sid.blank?

    token_record = token_record_for_session_identifier(sid)
    return failure(:token_session_not_found, payload: payload) unless token_record
    return failure(:dpop_binding_mismatch, payload: payload) unless token_dpop_binding_current?(token_record, payload)
    return failure(:token_jti_mismatch, payload: payload) unless token_jti_current?(token_record, payload)

    resolve_and_build_result!(token_record, payload, sid)
  end

  private

  # A session is idle-expired when its last activity (last_used_at, falling back
  # to created_at for a session that has not been touched yet) is older than the
  # surface idle window. A record with no usable timestamp is not treated as
  # expired, leaving the absolute-lifetime checks to govern it.
  def session_idle_expired?(token_record)
    reference = session_activity_reference(token_record)
    return false if reference.blank?

    reference < Time.current - SecurityTokenLifetimes.idle_ttl_for(@resource_type)
  end

  # Throttled per-request activity write: refresh last_used_at only when it is
  # missing or older than the throttle window, so authenticated requests do not
  # write to the session row on every hit. update_columns keeps this off the
  # validation/callback path; the write uses the primary (writing) connection.
  def touch_session_activity!(token_record)
    return unless token_record.respond_to?(:has_attribute?) && token_record.has_attribute?(:last_used_at)

    now = Time.current
    last = token_record.last_used_at
    return if last.present? && (now - last) < SecurityTokenLifetimes::ACTIVITY_TOUCH_THROTTLE

    token_connection_owner.connected_to(role: :writing) do
      token_record.update_columns(last_used_at: now) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def session_activity_reference(token_record)
    token_record_attribute(token_record, :last_used_at).presence ||
      (token_record.respond_to?(:created_at) ? token_record.created_at : nil)
  end

  def dpop_valid?(payload)
    token_jkt = payload.dig("cnf", "jkt")
    scheme = @authorization_scheme.to_s
    scheme_dpop = scheme.casecmp?("DPoP")

    return true if token_jkt.blank? && !scheme_dpop && @dpop_proof.blank?
    return false unless scheme_dpop
    return false if token_jkt.blank?

    result = DpopRequestVerifier.new(
      access_token_payload: payload,
      proof_jwt: @dpop_proof,
      request_method: @request_method,
      request_uri: @request_uri,
      access_token: @access_token,
      resource_type: @resource_type,
    ).call

    result.valid?
  end

  def token_record_for_session_identifier(session_identifier)
    check_logic =
      lambda do
        base_scope =
          if @token_class.respond_to?(:currently_usable_at)
            @token_class.currently_usable_at
          else
            @token_class.where(nil)
          end
        usable_tokens = base_scope.includes(:device_session)
        device_session = token_column?("device_session_id") ? device_session_for(session_identifier) : nil
        if device_session
          token = usable_tokens.where(device_session_id: device_session.id).order(created_at: :desc).first
          return token if token
        end
        scope = usable_tokens.where(public_id: session_identifier)
        if token_column?("oidc_sid") && uuid_identifier?(session_identifier)
          scope = scope.or(usable_tokens.where(oidc_sid: session_identifier))
        end
        scope.first
      end

    # Use the primary database for revocation-sensitive checks so a recently
    # revoked session cannot slip through replica lag.
    operation = lambda { token_connection_owner.connected_to(role: :writing, &check_logic) }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def current_session_public_id(token_record, session_identifier)
    token_record&.try(:device_session)&.public_id.presence || token_record&.public_id.presence || session_identifier
  end

  def token_record_public_id(token_record)
    token_record&.public_id.presence
  end

  def token_jti_current?(token_record, payload)
    oidc_jti = token_record_attribute(token_record, :oidc_jti)
    return true if oidc_jti.blank?

    payload_jti = AuthenticationToken.extract_jti(payload)
    ActiveSupport::SecurityUtils.secure_compare(oidc_jti.to_s, payload_jti.to_s)
  end

  def token_dpop_binding_current?(token_record, payload)
    record_jkt = (token_record_attribute(token_record, :dpop_jkt).presence ||
      token_record&.try(:device_session)&.dpop_jkt).to_s
    payload_jkt = payload.dig("cnf", "jkt").to_s
    return true if record_jkt.blank? && payload_jkt.blank?
    return false if record_jkt.blank? || payload_jkt.blank?

    ActiveSupport::SecurityUtils.secure_compare(record_jkt, payload_jkt)
  end

  def token_record_attribute(token_record, attribute)
    return unless token_record&.respond_to?(:has_attribute?) && token_record.has_attribute?(attribute)

    token_record.public_send(attribute)
  end

  def token_column?(column_name)
    return false unless @token_class.respond_to?(:column_names)

    @token_class.column_names.include?(column_name)
  end

  def device_session_for(public_id)
    klass = device_session_class
    return unless klass && public_id.present?

    klass.active.find_by(public_id: public_id)
  end

  def device_session_class
    case @resource_type.to_s
    when "client" then ::ClientDeviceSession
    when "operator" then ::OperatorDeviceSession
    when "visitor" then ::VisitorDeviceSession
    end
  end

  def uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def token_connection_owner
    klass = @token_class
    return OrgTicketRecord unless klass.respond_to?(:connection_class?)

    klass = klass.superclass until klass.connection_class?
    klass
  end

  def resolve_and_build_result!(token_record, payload, sid)
    if session_idle_expired?(token_record)
      return resource_failure(:idle_timeout, payload, token_record, sid, include_token: false)
    end

    resource = find_resource_from_payload(payload)
    return resource_failure(:resource_not_found, payload, token_record, sid) if resource.blank?
    if withdrawal_required?(resource)
      return resource_failure(:withdrawal_required, payload, token_record, sid)
    end
    if administratively_locked?(resource)
      return resource_failure(:administrative_access_locked, payload, token_record, sid)
    end
    if token_stale_for_administrative_lock?(resource, payload)
      return resource_failure(:administrative_access_token_stale, payload, token_record, sid)
    end

    touch_session_activity!(token_record)

    Result.new(
      resource: resource,
      session_public_id: current_session_public_id(token_record, sid),
      token_public_id: token_record_public_id(token_record),
      payload: payload,
      failure_reason: nil,
    )
  end

  def find_resource_from_payload(payload)
    ActiveRecord::Base.connected_to(role: :writing) do
      subject = AuthenticationToken.extract_subject(payload)
      next unless subject.is_a?(String)
      next unless subject.match?(/\A\d+\z/)

      @resource_class.find_by(id: Integer(subject, 10))
    end
  end

  def resource_failure(reason, payload, token_record, sid, include_token: true)
    failure(
      reason,
      payload: payload,
      session_public_id: current_session_public_id(token_record, sid),
      token_public_id: include_token ? token_record_public_id(token_record) : nil,
    )
  end

  def failure(reason, payload: nil, session_public_id: nil, token_public_id: nil)
    Result.new(
      resource: nil,
      session_public_id: session_public_id,
      token_public_id: token_public_id,
      payload: payload,
      failure_reason: reason,
    )
  end

  def administratively_locked?(resource)
    self.class.administratively_locked?(resource)
  end

  def token_stale_for_administrative_lock?(resource, payload)
    resource.respond_to?(:access_token_stale_for_administrative_lock?) &&
      resource.access_token_stale_for_administrative_lock?(payload)
  end

  def withdrawal_required?(resource)
    return false unless %w(client visitor).include?(@resource_type.to_s)
    return true if resource.respond_to?(:suspended?) && resource.suspended?
    return true if resource.respond_to?(:terminated?) && resource.terminated?
    return true if resource.respond_to?(:withdrawn?) && resource.withdrawn?

    resource.respond_to?(:deactivated?) && resource.deactivated?
  end

  class << self
    def administratively_locked?(resource)
      resource.respond_to?(:admin_locked?) && resource.admin_locked?
    end
  end
end
