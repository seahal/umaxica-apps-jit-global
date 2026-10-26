# frozen_string_literal: true

# Exercises the browser-facing Base -> Auth admission transport through its current GET entry and
# confirmation contract.
module AuthCeremonyEntryHelper
  # Design D (D-100): an authorization-transaction entry GET relays automatically to
  # /ceremony_bindings, which attaches the Auth session and hands the browser to the Base
  # confirmation receiver. The Base confirmation is applied directly here to isolate the Auth
  # leaf; the Base receiver has its own HTTP tests. The final GET redeems and redirects to the
  # clean ceremony URL.
  def admit_auth_ceremony_entry!(path, reference:, params: {}, browser: self, base_token: nil, browser_digest: nil)
    binding = attach_auth_ceremony_entry!(path, reference:, params:, browser:)
    binding.confirm_base!(base_token:, browser_digest: browser_digest || binding.base_browser_digest)
    browser.get(path, params: params.merge(entry_ref: reference))
    raise RuntimeError, "auth entry did not redeem the admission (HTTP #{browser.response.status})" unless
      browser.response.status == 303

    browser.response
  end

  def attach_auth_ceremony_entry!(path, reference:, params: {}, browser: self)
    browser.get(path, params: params.merge(entry_ref: reference))
    raise RuntimeError, "auth entry did not relay to ceremony_bindings (HTTP #{browser.response.status})" unless
      browser.response.status == 303 && URI.parse(browser.response.location).path == "/ceremony_bindings"

    browser.get(browser.response.location)
    raise RuntimeError, "ceremony binding did not hand off to Base (HTTP #{browser.response.status})" unless
      browser.response.status == 303

    binding = [ClientAuthAdmissionBinding, VisitorAuthAdmissionBinding, OperatorAuthAdmissionBinding]
      .lazy.filter_map { |model| model.find_by(entry_ref: reference) }.first
    raise RuntimeError, "admission binding is missing" unless binding

    binding
  end
end
