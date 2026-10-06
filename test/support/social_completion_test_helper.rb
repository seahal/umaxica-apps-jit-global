# frozen_string_literal: true

# Exercises the receiver-host GET and same-origin POST used by D-81 social
# completions. The helper intentionally follows only the configured Base
# completion path and never treats a redirect reference as authorization.
module SocialCompletionTestHelper
  private

  def follow_social_completion_redirect_if_present!
    return false unless response.redirect?

    completion = URI.parse(response.location.to_s)
    return false unless completion.path == "/social/authentication/completion"

    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(base_host)
    https!
    request_headers = {
      "Host" => base_host,
      "Origin" => "https://#{base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }
    get completion.request_uri, headers: request_headers

    form = response.parsed_body.at_css("form")
    raise StandardError, "social completion continuation form missing" unless form

    params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post form["action"], params: params, headers: request_headers
    true
  end
end
