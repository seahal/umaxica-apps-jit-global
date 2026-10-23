# frozen_string_literal: true

# D-72 / WU-24b: a Sign In admission no longer opens Sign Up pages. A browser reaches Sign Up the way
# a person does: from the admitted first Sign In page it posts Switch, Base commits the continuation,
# and the browser is admitted again for Sign Up on the same parent.
module SignUpSwitchTestSupport
  AUTH_HOST_ENV = { "app" => "PUBLIC_AUTH_SERVICE_URL", "com" => "PUBLIC_AUTH_CORPORATE_URL" }.freeze

  # base_browser: the session that holds the Base cookies when the test keeps Base and Auth in
  # separate sessions; Base hops of the continuation go through it.
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

    drive_browser_through_continuations!(browser, base_browser:)
  end

  # Follows redirects (unwrapping Jump) and the same-origin continuation/confirmation/exit forms that
  # Auth and Base render, until an ordinary page is reached.
  def drive_browser_through_continuations!(browser, base_browser: nil)
    current = browser
    20.times do
      if current.response.redirect?
        target = URI.parse(jump_rt_url_from_location_for_test(current.response.location))
        current = (base_browser && base_browser.host == target.host) ? base_browser : browser
        current.host!(target.host)
        current.get(target.request_uri)
        next
      end
      unless current.response.media_type == "text/html"
        flunk("Sign Up switch reached HTTP #{current.response.status} #{current.response.media_type}")
      end
      form = current.response.parsed_body.at_css(
        "form[id$='continuation-form'], form[id$='confirmation-form'], form#oidc-authorization-exit-form",
      )
      return current.response unless form

      action = URI.join("https://#{current.host}", form["action"])
      sender = (base_browser && base_browser.host == action.host) ? base_browser : browser
      sender.host!(action.host)
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }.compact
      sender.post(
        action.request_uri, params: fields,
                            headers: { "Origin" => "https://#{action.host}", "Sec-Fetch-Site" => "same-origin" },
      )
      current = sender
    end

    flunk("Sign Up switch did not settle on a page")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include SignUpSwitchTestSupport }
