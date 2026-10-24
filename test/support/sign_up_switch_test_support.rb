# frozen_string_literal: true

# D-72: a Sign In admission no longer opens Sign Up pages. A browser reaches Sign Up the way
# a person does: from the admitted first Sign In page it posts Switch, Base commits the continuation,
# and the browser is admitted again for Sign Up on the same parent.
module SignUpSwitchTestSupport
  BASE_HOST_ENV = {
    "app" => "PUBLIC_BASE_SERVICE_URL", "com" => "PUBLIC_BASE_CORPORATE_URL",
  }.freeze
  AUTH_HOST_ENV = { "app" => "PUBLIC_AUTH_SERVICE_URL", "com" => "PUBLIC_AUTH_CORPORATE_URL" }.freeze

  # base_browser: the session that holds the Base cookies when the test keeps Base and Auth in
  # separate sessions; Base hops of the continuation go through it. A caller that keeps a
  # separate Visa browser may expose it as @visa_browser.
  def switch_browser_to_sign_up!(browser, surface: "app", base_browser: nil)
    auth_host = ENV.fetch(AUTH_HOST_ENV.fetch(surface))
    browser.host!(auth_host)
    browser.https!
    browser.get("/sign/in", params: { ri: "jp" })
    # An admission that is already for Sign Up has no Sign In page to switch from.
    return browser.response unless browser.response.status == 200 && browser.response.media_type == "text/html"

    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')&.[]("content")
    browser.post(
      "/sign/switch", params: { to: "sign_up", ri: "jp", authenticity_token: csrf }.compact,
                      headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    unless browser.response.status == 303
      flunk("Switch to Sign Up was refused: HTTP #{browser.response.status}")
    end

    drive_browser_through_continuations!(browser, base_browser:, visa_browser: @visa_browser, surface:)
  end

  # Follows redirects (unwrapping Jump) and the same-origin continuation/confirmation/exit forms that
  # Auth and Base render, until an ordinary page is reached.
  def drive_browser_through_continuations!(browser, base_browser: nil, visa_browser: nil, surface: "app")
    visa_browser ||= @visa_browser
    base_hosts = sign_up_switch_base_hosts(surface, base_browser, visa_browser)
    visa_host = CommonRedirect.normalize_host(visa_host_for_test_surface(surface))

    current = browser
    20.times do
      if current.response.redirect?
        current = follow_sign_up_redirect!(
          current, browser:, base_browser:, base_hosts:, visa_browser:, visa_host:,
        )
        next
      end
      unless current.response.media_type == "text/html"
        flunk(
          "Sign Up switch reached #{current.host}#{current.request.path} HTTP " \
          "#{current.response.status} #{current.response.media_type}: " \
          "#{current.response.body.to_s[0, 300]}",
        )
      end
      form = current.response.parsed_body.at_css(
        "form[id$='continuation-form'], form[id$='confirmation-form'], form#oidc-authorization-exit-form, " \
        "form#oidc-authorization-handoff-form, form#oidc-authorization-result-form",
      )
      return current.response unless form

      current = submit_sign_up_continuation!(
        current, form, browser:, base_browser:, base_hosts:, visa_browser:, visa_host:,
      )
    end

    flunk("Sign Up switch did not settle on a page")
  end

  def sign_up_switch_base_hosts(surface, base_browser, visa_browser)
    return [] unless base_browser

    hosts = [ENV.fetch(BASE_HOST_ENV.fetch(surface.to_s))]
    hosts << visa_host_for_test_surface(surface) unless visa_browser
    hosts.map { |host| CommonRedirect.normalize_host(host) }.uniq
  end

  def follow_sign_up_redirect!(current, browser:, base_browser:, base_hosts:, visa_browser:, visa_host:)
    target = URI.parse(jump_rt_url_from_location_for_test(current.response.location))
    receiver =
      if base_browser && base_hosts.include?(target.host)
        base_browser
      elsif visa_browser && target.host == visa_host
        visa_browser
      else
        browser
      end
    receiver.host!(target.host)
    receiver.https!
    navigational_path = target.path.start_with?("/oidc/") || target.path.start_with?("/sign/oidc/") ||
      target.path.start_with?("/ceremony_bindings/")
    headers = navigational_path ? sign_up_navigation_headers : {}
    receiver.get(target.request_uri, headers: headers)
    receiver
  end

  def submit_sign_up_continuation!(current, form, browser:, base_browser:, base_hosts:, visa_browser:, visa_host:)
    action = URI.join("https://#{current.host}", form["action"])
    sender =
      if base_browser && base_hosts.include?(action.host)
        base_browser
      elsif visa_browser && action.host == visa_host
        visa_browser
      else
        browser
      end
    sender.host!(action.host)
    sender.https!
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }.compact
    sender.post(
      action.request_uri, params: fields,
                          headers: { "Origin" => "https://#{action.host}", "Sec-Fetch-Site" => "same-origin" },
    )
    sender
  end

  def sign_up_navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include SignUpSwitchTestSupport }
