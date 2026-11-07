# typed: false
# frozen_string_literal: true

# Widens the response's form-action to the registered relying-party origins of one realm.
#
# A Visa page whose form answers with a redirect through Jump to a relying party (the authorization
# continuation, the logout confirmation) needs every hop of that redirect allowed: browsers apply
# form-action to the redirect chain, and the global policy names only the first-party gateway
# hosts. Without the RP origin the browser stops on the submitting page after the server has
# already acted, and a second submission then fails. The including controller calls
# `allow_registered_rp_form_targets!` explicitly on the one page that needs it; no other response
# is widened.
#
# Requires nothing from the includer beyond an ActionController request.
module RegisteredRpFormTargets
  extend ActiveSupport::Concern

  private

  # @param realm [String] "client" or "operator", as in OidcClientRegistry's redirect_uris_by_realm
  # @param uri_kind [Symbol] :callback for authorization redirect_uris, :post_logout for
  #   post_logout_redirect_uris
  def allow_registered_rp_form_targets!(realm:, uri_kind:)
    sources = request.content_security_policy.directives.fetch("form-action") +
      registered_rp_origins(realm:, uri_kind:)
    sources.uniq!
    policy = request.content_security_policy.clone
    policy.form_action(*sources)
    request.content_security_policy = policy
  end

  def registered_rp_origins(realm:, uri_kind:)
    origins =
      OidcClientRegistry.client_ids.flat_map do |client_id|
        client = OidcClientRegistry.find!(client_id)
        uris =
          case uri_kind
          when :callback then client.redirect_uris_by_realm.fetch(realm, [])
          when :post_logout
            client.redirect_uris_by_realm.key?(realm) ? client.post_logout_redirect_uris : []
          else raise ArgumentError, "unsupported registered RP URI kind: #{uri_kind.inspect}"
          end
        uris.map { |uri| registered_rp_origin(uri) }
      end
    origins.uniq!
    origins
  end

  def registered_rp_origin(uri)
    parsed = URI.parse(uri)
    port = (parsed.port == parsed.default_port) ? "" : ":#{parsed.port}"
    "#{parsed.scheme}://#{parsed.host}#{port}"
  end
end
