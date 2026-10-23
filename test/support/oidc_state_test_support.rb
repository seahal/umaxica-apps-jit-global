# frozen_string_literal: true

# Reads the claims of an RP `state` JWS issued during a test (D-149). The pending entry in the RP
# session is keyed by its `jti`; the return target is its `target_link_uri` claim.
module OidcStateTestSupport
  module_function

  def claims(state)
    JWT.decode(state.to_s, nil, false).first
  end

  def jti(state) = claims(state).fetch("jti")

  def target_link_uri(state) = claims(state)["target_link_uri"]
end
