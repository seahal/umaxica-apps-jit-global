# typed: false
# frozen_string_literal: true

module PreferenceDbscRegistrationEndpoint
  extend ActiveSupport::Concern
  include DbscRequestLogging
  include DbscCanonicalUrl

  public

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

  def current_preference_record
    preference, = load_preference_record_from_refresh_token!(create_if_missing: false)
    preference
  end

  # Canonical (context-param-free) form of the subclass-provided dbsc_url. Used as the
  # DBSC proof audience and the advertised refresh URL so registration and refresh agree
  # byte-for-byte regardless of per-request context params. See DbscCanonicalUrl.
  def dbsc_endpoint_url
    @dbsc_endpoint_url ||= dbsc_canonical_url(dbsc_url)
  end

  def handle_registration
    result = DbscRegistrationService.call(
      record: current_preference_record,
      proof: DbscHeaderParser.string_value(dbsc_response_header),
      expected_audience: dbsc_endpoint_url,
    )

    if result[:ok]
      preference = result[:record]
      set_preference_dbsc_cookie!(
        result[:session_id],
        expires_at: preference_dbsc_cookie_expires_at(preference),
      )
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
            name: PreferenceCookieName.dbsc,
            attributes: dbsc_cookie_attributes_string,
          },
        ],
      }, status: :created
      Rails.logger.info(
        JitLogEvent.format("dbsc.registration.succeeded", request_path: request.path),
      )
    else
      render json: { error: "DBSC registration failed", error_code: result[:error_code] },
             status: :unprocessable_content
    end
  end

  def handle_bound_cookie_refresh
    preference = current_preference_record
    return head :unauthorized if preference.blank?

    session_id = DbscHeaderParser.string_value(dbsc_session_id_header)
    return head :bad_request if session_id.blank?

    proof = dbsc_response_header
    return head :forbidden unless preference.dbsc_session_id.present? &&
      session_id == preference.dbsc_session_id

    if proof.blank?
      challenge = issue_preference_dbsc_challenge_for!(preference)
      challenge_value = DbscHeaderSerializer.challenge(challenge: challenge, session_id: preference.dbsc_session_id)
      response.set_header(
        PreferenceIoKeys::Headers::DBSC_CHALLENGE,
        challenge_value,
      )
      response.set_header(
        PreferenceIoKeys::Headers::DBSC_SECURE_CHALLENGE,
        challenge_value,
      )
      Rails.logger.info(
        JitLogEvent.format("dbsc.challenge.issued", request_path: request.path),
      )
      return head :forbidden
    end

    result = DbscVerificationService.call(
      record: preference, session_id: session_id, proof: DbscHeaderParser.string_value(proof),
      expected_audience: dbsc_endpoint_url,
    )
    return render json: { error: "DBSC verification failed", error_code: result[:error_code] },
                  status: :unprocessable_content unless result[:ok]

    preference.update!(dbsc_challenge: nil, dbsc_challenge_issued_at: nil)
    set_preference_dbsc_cookie!(
      preference.dbsc_session_id,
      expires_at: preference_dbsc_cookie_expires_at(preference),
    )
    head :no_content
  end

  def dbsc_cookie_attributes_string
    # Must match the attributes the server actually sets in set_preference_dbsc_cookie!
    # (preference_cookie_options => SameSite=Strict). The DBSC-bound cookie only travels on the
    # same-origin refresh request, so Strict is correct and keeps the browser-maintained cookie
    # aligned with the actually-set cookie.
    [
      "Path=/",
      ("Secure" if Rails.env.production?),
      "HttpOnly",
      "SameSite=Strict",
    ].compact.join("; ")
  end

  def dbsc_session_id_header
    request.headers["Sec-Secure-Session-Id"].presence ||
      request.headers[PreferenceIoKeys::Headers::DBSC_SECURE_SESSION_ID].presence ||
      request.headers[PreferenceIoKeys::Headers::DBSC_SESSION_ID].presence
  end

  def dbsc_response_header
    request.headers[PreferenceIoKeys::Headers::DBSC_SECURE_RESPONSE].presence ||
      request.headers[PreferenceIoKeys::Headers::DBSC_RESPONSE].presence ||
      request.headers["Sec-Secure-Session-Response"].presence
  end

  # Subclasses must implement:
  #   def dbsc_url = <route helper returning full URL>
end
