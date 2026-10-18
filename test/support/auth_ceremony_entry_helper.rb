# frozen_string_literal: true

# Exercises the browser-facing Base -> Auth admission transport through its public HTTP contract:
# the GET carries only a non-secret reference, and the same-origin POST redeems it with Rails CSRF.
module AuthCeremonyEntryHelper
  def redeem_auth_ceremony_entry!(path, reference:, reference_param: :transaction_ref, params: {}, headers: {})
    request_params = params.merge(reference_param => reference)
    get(path, params: request_params, headers: headers)

    token = response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1]
    raise RuntimeError, "auth ceremony continuation did not render a Rails authenticity token" if token.blank?

    post(
      path,
      params: request_params.merge(authenticity_token: token),
      headers: headers,
    )
  end

  def redeem_auth_ceremony_session!(browser, path, reference:, reference_param: :transaction_ref, params: {},
                                    headers: {})
    request_params = params.merge(reference_param => reference)
    browser.get(path, params: request_params, headers: headers)

    token = browser.response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1]
    raise RuntimeError, "auth ceremony continuation did not render a Rails authenticity token" if token.blank?

    browser.post(
      path,
      params: request_params.merge(authenticity_token: token),
      headers: headers,
    )
  end
end
