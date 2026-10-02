# typed: false
# frozen_string_literal: true

require "test_helper"

# Expired authorization transactions are removed once their retention has passed
# (plans/active/sign-fqdn-integrated-plan.md section 5). BVA at the cutoff, now - RETENTION_PERIOD:
# one second before and exactly at the cutoff are removed, one second after is kept.
class OidcAuthorizationTransactionPurgerTest < ActiveSupport::TestCase
  SURFACES = {
    "app" => { model: ClientOidcAuthorizationTransaction, client_id: "core-app", realm: "client" },
    "com" => { model: VisitorOidcAuthorizationTransaction, client_id: "core-com", realm: "visitor" },
    "org" => { model: OperatorOidcAuthorizationTransaction, client_id: "core-org", realm: "operator" },
  }.freeze

  test "removes transactions expired at or before the retention cutoff and keeps later ones" do
    now = Time.current.change(usec: 0)
    cutoff = now - OidcAuthorizationTransactionable::RETENTION_PERIOD

    SURFACES.each do |surface, config|
      client = OidcClientRegistry.find!(config.fetch(:client_id))
      transactions =
        { before: -1.second, at: 0.seconds, after: 1.second }.to_h do |label, offset|
          issued = OidcAuthorizationTransactionCoordinator.issue!(
            surface: surface,
            intent: "sign_in",
            params: {
              response_type: "code",
              client_id: client.client_id,
              redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:realm)).first,
              code_challenge: "a" * 43,
              code_challenge_method: "S256",
              state: "state-#{label}",
              nonce: "nonce-#{label}",
              scope: "openid",
            },
          ).transaction
          issued.update_columns(expires_at: cutoff + offset)
          [label, issued]
        end

      OidcAuthorizationTransactionPurger.call(now: now)

      assert_not config.fetch(:model).exists?(transactions.fetch(:before).id), "#{surface} before cutoff"
      assert_not config.fetch(:model).exists?(transactions.fetch(:at).id), "#{surface} at cutoff"
      assert config.fetch(:model).exists?(transactions.fetch(:after).id), "#{surface} after cutoff"
    end
  end

  test "keeps a live transaction" do
    client = OidcClientRegistry.find!("core-app")
    live = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        state: "state-live",
        nonce: "nonce-live",
        scope: "openid",
      },
    ).transaction

    OidcAuthorizationTransactionPurger.call

    assert ClientOidcAuthorizationTransaction.exists?(live.id)
  end
end
