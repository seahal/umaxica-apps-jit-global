# frozen_string_literal: true

# Drives the public Base RP to Visa OP to Auth admission navigation used by browser-facing tests.
# Visa's authorization GET creates the Auth admission and redirects to the Auth Sentry; it does not
# render an authorization form. Keeping that transport in one helper prevents tests from coupling to
# the retired Base/OP form sequence.
module OidcAuthAdmissionTestHelper
  BASE_HOST_ENV = {
    "app" => "PUBLIC_BASE_SERVICE_URL",
    "com" => "PUBLIC_BASE_CORPORATE_URL",
    "org" => "PUBLIC_BASE_STAFF_URL",
  }.freeze

  AUTH_HOST_ENV = {
    "app" => "PUBLIC_AUTH_SERVICE_URL",
    "com" => "PUBLIC_AUTH_CORPORATE_URL",
    "org" => "PUBLIC_AUTH_STAFF_URL",
  }.freeze

  def bootstrap_auth_sign_in_admission!(surface: "app", region: "jp", target_link_uri: "/dashboard")
    base_host = ENV.fetch(BASE_HOST_ENV.fetch(surface.to_s))
    auth_host = ENV.fetch(AUTH_HOST_ENV.fetch(surface.to_s))
    visa_host = visa_host_for_test_base_host(base_host)

    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    issue_base_admission!(base_host:, region:, target_link_uri:)
    current_browser = follow_admission_redirects!(
      base_host:, visa_host:, auth_host:, browser: @base_browser,
    )

    raise RuntimeError, "Auth admission did not reach the Auth browser" unless current_browser.equal?(self)
    raise RuntimeError, "Auth admission did not render the Auth entry" unless response.successful?

    host!(auth_host)
    https!
    self
  end

  private

  def issue_base_admission!(base_host:, region:, target_link_uri:)
    @base_browser.get(
      "/sign",
      params: { ri: region, target_link_uri: target_link_uri },
      headers: navigation_headers(site: "same-origin"),
    )
    form = response_form(@base_browser)
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"],
      params: fields,
      headers: {
        "Origin" => "https://#{base_host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )
  end

  def follow_admission_redirects!(base_host:, visa_host:, auth_host:, browser:)
    current_browser = browser
    current_host = base_host
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      target = URI.parse(jump_rt_url_from_location_for_test(target.to_s)) if target.host == jump_host
      current_browser, current_host = navigate_admission_target(
        target:, base_host:, visa_host:, auth_host:,
      )
    end

    current_browser
  end

  def navigate_admission_target(target:, base_host:, visa_host:, auth_host:)
    case target.host
    when base_host, visa_host
      @base_browser.host!(target.host)
      @base_browser.https!
      @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))
      [@base_browser, target.host]
    when auth_host
      host!(auth_host)
      https!
      get(target.request_uri, headers: navigation_headers(site: "cross-site"))
      [self, auth_host]
    else
      raise RuntimeError, "Unexpected Auth admission host: #{target.host.inspect}"
    end
  end

  def response_form(browser)
    form = browser.response.parsed_body.at_css("form")
    return form if form

    raise RuntimeError, "browser admission form is missing (HTTP #{browser.response.status})"
  end

  def navigation_headers(site:)
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end
end
