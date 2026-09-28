# typed: false
# frozen_string_literal: true

module SignDbscRegistrationEndpoint
  extend ActiveSupport::Concern
  include DbscRequestLogging
  include DbscCanonicalUrl

  def create
    log_dbsc_request_observability!
    response.set_header("Cache-Control", "no-store")

    if dbsc_session_id_header.present?
      handle_bound_cookie_refresh
    else
      handle_registration
    end
  end

  private

  def load_current_resource
    return nil if extract_access_token(AuthenticationBase::ACCESS_COOKIE_KEY).blank?

    super
  end

  def dbsc_token_record
    token_from_refresh_cookie || current_session
  end

  def token_from_refresh_cookie
    refresh_plain = cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s
    refresh_public_id, = token_class.parse_refresh_token(refresh_plain)
    find_refresh_token_record(refresh_public_id)
  end

  def handle_registration
    result = DbscRegistrationService.call(
      record: dbsc_token_record,
      proof: dbsc_response_header,
      expected_audience: dbsc_endpoint_url,
    )

    if result[:ok]
      token_record = result[:record]
      set_dbsc_cookie!(result[:session_id], expires_at: dbsc_cookie_expires_at_for(token_record))
      render json: {
        session_identifier: result[:session_id],
        refresh_url: dbsc_endpoint_url,
        scope: {
          origin: request.base_url,
          include_site: false,
        },
        credentials: [
          {
            type: "cookie",
            name: AuthenticationBase::DBSC_COOKIE_KEY,
            attributes: dbsc_cookie_attributes_string,
          },
        ],
      }, status: :created
      Rails.logger.info(
        "[dbsc] registration success path=#{dbsc_endpoint_url} session_id=#{result[:session_id].to_s[0, 24]}",
      )
    else
      render json: { error: "DBSC registration failed", error_code: result[:error_code] },
             status: :unprocessable_content
    end
  end

  def handle_bound_cookie_refresh
    token_record = dbsc_token_record
    return head :unauthorized if token_record.blank?

    session_id = dbsc_session_id_header
    proof = dbsc_response_header
    parsed_session_id = DbscHeaderParser.string_value(session_id)

    if proof.blank?
      challenge = issue_dbsc_challenge_for!(token_record)
      challenge_value = %("#{challenge}";id="#{parsed_session_id}")
      response.set_header(AuthIoKeys::Headers::DBSC_CHALLENGE, challenge_value)
      response.set_header(AuthIoKeys::Headers::SECURE_DBSC_CHALLENGE, challenge_value)
      Rails.logger.info(
        "[dbsc] challenge issued path=#{dbsc_endpoint_url} session_id=#{parsed_session_id.to_s[0, 24]}",
      )
      return head :forbidden
    end

    result = DbscVerificationService.call(
      record: token_record, session_id: session_id, proof: proof,
      expected_audience: dbsc_endpoint_url,
    )
    return render json: { error: "DBSC verification failed", error_code: result[:error_code] },
                  status: :unprocessable_content unless result[:ok]

    token_record.update!(dbsc_challenge: nil, dbsc_challenge_issued_at: nil)
    set_dbsc_cookie!(token_record.dbsc_session_id, expires_at: dbsc_cookie_expires_at_for(token_record))
    head :no_content
  end

  def dbsc_cookie_attributes_string
    # Must match the attributes the server actually sets in set_dbsc_cookie! (auth_cookie_options
    # => SameSite=Strict). The DBSC-bound cookie is host-only and only travels on the same-origin
    # refresh request, so Strict is correct and keeps the browser-maintained cookie aligned with
    # the ADR (auth/DBSC cookies are Strict).
    [
      "Path=/",
      ("Secure" if Rails.env.production?),
      "HttpOnly",
      "SameSite=Strict",
    ].compact.join("; ")
  end

  # Canonical (context-param-free) form of the subclass-provided dbsc_url. Used as the
  # DBSC proof audience and the advertised refresh URL so registration and refresh agree
  # byte-for-byte regardless of per-request context params. See DbscCanonicalUrl.
  def dbsc_endpoint_url
    @dbsc_endpoint_url ||= dbsc_canonical_url(dbsc_url)
  end

  def dbsc_session_id_header
    request.headers[AuthIoKeys::Headers::SECURE_DBSC_SESSION_ID].presence ||
      request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID].presence ||
      request.headers["Sec-Secure-Session-Id"].presence
  end

  def dbsc_response_header
    request.headers[AuthIoKeys::Headers::SECURE_DBSC_RESPONSE].presence ||
      request.headers[AuthIoKeys::Headers::DBSC_RESPONSE].presence ||
      request.headers["Sec-Secure-Session-Response"].presence
  end

  # Subclasses must implement:
  #   def dbsc_url = <route helper returning full URL>
end
