# frozen_string_literal: true

# A bare PRIMARY_PENDING sign-in flow owned by an actor. Under the OIDC parent a flow exists only once
# primary authentication names its principal; model and service tests that start from that point
# create it here instead of driving an HTTP ceremony.
module SignInFlowTestFactory
  module_function

  MODELS = { "app" => ClientSignInFlow, "com" => VisitorSignInFlow, "org" => OperatorSignInFlow }.freeze

  def create!(surface:, principal_id:)
    model = MODELS.fetch(surface.to_s)
    now = model.database_now
    model.create!(
      principal_id:, state_id: model.state_id_for("PRIMARY_PENDING"),
      nonce_digest: model.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now, expires_at: now + model.default_ttl,
    )
  end
end
