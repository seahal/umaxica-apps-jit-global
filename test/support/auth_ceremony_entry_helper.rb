# frozen_string_literal: true

# Exercises the browser-facing Base -> Auth admission transport through its public HTTP contract:
# the GET carries only a non-secret reference, and the same-origin POST redeems it with Rails CSRF.
module AuthCeremonyEntryHelper
  CEREMONY_SESSION = {
    "app" => ClientAuthCeremonySession,
    "com" => VisitorAuthCeremonySession,
    "org" => OperatorAuthCeremonySession,
  }.freeze

  # `base_token` is the Base root token the admission was issued for; a Step-Up admission is bound
  # to one, while a local sign-in admission has none.
  def redeem_auth_ceremony_entry!(path, reference:, reference_param: :entry_ref, params: {}, headers: {},
                                  confirm_via_http: false, base_browser: nil, base_token: nil)
    redeem_auth_ceremony_exchange!(
      self, path,
      reference:, reference_param:, params:, headers:, confirm_via_http:, base_browser:, base_token:,
    )
  end

  # Starts the same local sign-in admission that Base's neutral sign-in page
  # issues, then redeems it through Auth's browser-facing continuation. The
  # flow locator is installed before the redemption so the subsequent
  # authentication request resumes the admitted flow rather than a fixture
  # row that the test installed without browser continuity.
  def ensure_local_sign_in_admission!(surface:, path:, params: {}, headers: {})
    ensure_local_sign_in_admission_for!(
      self, surface:, path:, params:, headers:,
    )
  end

  def ensure_local_sign_in_admission_for!(browser, surface:, path:, params: {}, headers: {})
    normalized_surface = surface.to_s
    ceremony_class = CEREMONY_SESSION.fetch(normalized_surface)
    raw_sid = browser.cookies["__Host-auth_sid"].presence || browser.cookies["auth_sid"].presence
    if raw_sid.present?
      record = ceremony_class.find_active_by_raw_sid(raw_sid)
      return if record&.admitted? && record.admission_purpose == "local_sign_in"
    end

    auth_host =
      case normalized_surface
      when "app"
        ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      when "com"
        ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
      when "org"
        ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      else
        raise ArgumentError, "unsupported local sign-in surface"
      end

    auth_headers = headers.merge(
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    )
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: normalized_surface, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: normalized_surface, reference: issuance.reference,
    )
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(
      binding, base_token: nil, base_browser_nonce: "test-browser-nonce",
    )
    browser.host!(auth_host)
    browser.https!
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    browser.cookies.delete("auth_sid")
    browser.cookies.delete("__Host-auth_sid")
    browser.cookies.merge( # rubocop:disable Lint/Void
      "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{auth_host}/"),
    )
    browser.get(path, params: params.merge(entry_ref: issuance.reference), headers: auth_headers)
    action, token, hidden = continuation_form!(browser.response.body)
    browser.post(action, params: hidden.merge(authenticity_token: token), headers: auth_headers)

    assert_equal 303, browser.response.status
  end

  def redeem_auth_ceremony_session!(browser, path, reference:, reference_param: :entry_ref, params: {},
                                    headers: {}, confirm_via_http: false, base_browser: nil)
    redeem_auth_ceremony_exchange!(
      browser, path, reference:, reference_param:, params:, headers:, confirm_via_http:, base_browser:,
    )
  end

  # Rack::Test exposes multi-valued Set-Cookie headers as an encoded array in this application.
  # Install the browser session cookie explicitly when a cross-host Base request rotates it so
  # subsequent requests use the same Rails session a real browser would have received.
  def sync_response_cookie!(browser, name)
    value = browser.response.cookies[name]
    if value.nil?
      raw = browser.response.headers["Set-Cookie"] || browser.response.headers["set-cookie"]
      lines =
        if raw.is_a?(String) && raw.start_with?("[")
          JSON.parse(raw)
        else
          Array(raw)
        end
      line =
        lines.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
          entry.split(";", 2).first.to_s.start_with?("#{name}=")
        end
      return unless line

      _cookie_name, value = line.split(";", 2).first.to_s.split("=", 2)
      value = Rack::Utils.unescape(value.to_s)
    end

    browser.cookies.delete(name)
    # Rack::Test's []= uses its default host. The current request may target a
    # different surface, so install the cookie against the browser's active host.
    browser.cookies.merge( # rubocop:disable Lint/Void
      "#{name}=#{Rack::Utils.escape(value)}",
      URI.parse("https://#{browser.host}/"),
    )
  end

  private

  def redeem_auth_ceremony_exchange!(browser, path, reference:, reference_param:, params:, headers:,
                                     confirm_via_http: false, base_browser: nil, base_token: nil)
    request_params = params.merge(reference_param => reference)
    browser.get(path, params: request_params, headers: headers)
    form = continuation_form!(browser.response.body, allow_missing: true)
    return unless form

    action, token, hidden = form

    browser.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||= "test-browser-nonce"
    browser.post(action, params: hidden.merge(authenticity_token: token), headers: headers)
    binding_location = browser.response.location
    return if binding_location.blank?

    binding_uri = URI.parse(binding_location)
    binding_host = binding_uri.host
    binding_surface = admission_surface_for_host(binding_host)
    binding = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
      surface: binding_surface, reference: binding_uri.path.split("/").fetch(-2),
    )

    if confirm_via_http
      confirmation_browser = base_browser || browser
      confirmation_browser.host!(binding_host)
      confirmation_browser.https!
      confirmation_browser.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||= "test-browser-nonce"
      confirmation_path = binding_uri.request_uri
      base_headers = headers.merge(
        "Host" => binding_host,
        "Origin" => "https://#{binding_host}",
        "Sec-Fetch-Site" => "same-origin",
      )
      confirmation_browser.get(confirmation_path, headers: base_headers)
      confirmation_action, confirmation_token, confirmation_hidden = continuation_form!(confirmation_browser.response.body)
      confirmation_browser.post(
        confirmation_action,
        params: confirmation_hidden.merge(authenticity_token: confirmation_token), headers: base_headers,
      )
      sync_response_cookie!(confirmation_browser, "session")
      auth_location = confirmation_browser.response.location
      raise RuntimeError, "Base confirmation did not return to Auth" if auth_location.blank?

      auth_uri = URI.parse(auth_location)
      if params[:ri].present?
        query = Rack::Utils.parse_nested_query(auth_uri.query.to_s)
        query["ri"] ||= params[:ri].to_s
        auth_uri.query = URI.encode_www_form(query)
      end
      browser.host!(auth_uri.host)
      browser.https!
      final_path = auth_uri.request_uri
      auth_headers = headers.merge("Host" => auth_uri.host)
      browser.get(final_path, headers: auth_headers)
    else
      binding.confirm_base!(
        base_token: base_token,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface: binding_surface, entry_ref: binding.entry_ref, nonce: "test-browser-nonce",
        ),
      )
      auth_host = browser.host
      browser.host!(auth_host)
      browser.https!
      auth_headers = headers.merge("Host" => auth_host)
      browser.get(path, params: request_params, headers: auth_headers)
    end
    final_action, final_token, final_hidden = continuation_form!(browser.response.body)
    browser.post(final_action, params: final_hidden.merge(authenticity_token: final_token), headers: auth_headers)
  end

  def admission_surface_for_host(host)
    {
      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
    }.fetch(host)
  end

  def continuation_form!(body, allow_missing: false)
    form = Nokogiri::HTML(body).at_css("form")
    return if form.nil? && allow_missing
    raise RuntimeError, "auth ceremony continuation did not render a form" unless form

    token = form.at_css("input[name='authenticity_token']")&.[]("value")
    raise RuntimeError, "auth ceremony continuation did not render a Rails authenticity token" if token.blank?

    hidden = form.css("input[type='hidden']").to_h do |input|
      [input["name"], input["value"]]
    end.except("authenticity_token")
    [form["action"], token, hidden]
  end
end
