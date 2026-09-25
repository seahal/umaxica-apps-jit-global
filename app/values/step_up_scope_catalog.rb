# typed: false
# frozen_string_literal: true

module StepUpScopeCatalog
  APP = {
    "social_link" => %r{\A/settings/(?:google|apple)(?:/edit)?(?:\z|[?#])},
    "social_unlink" => %r{\A/settings/(?:google|apple)(?:/edit)?(?:\z|[?#])},
    "session_revoke_all" => %r{\A(?:/sign/settings/sessions|/settings/sessions|/sessions|/identity/sessions)},
    "withdrawal" => %r{\A(?:/settings/withdrawal|/identity/withdrawal)},
    "settings_email" => %r{\A(?:/settings/emails|/identity/emails)},
    "settings_telephone" => %r{\A(?:/settings/telephones|/identity/telephones)},
    "settings_passkey" => %r{\A/settings/passkeys},
    "settings_mfa" => %r{\A/settings/mfa/challenge},
    "settings_secret_credential" => %r{\A/settings/(?:secrets|secret_credentials)},
    "settings_birthdate" => %r{\A(?:/settings/birthdate|/identity/birthdate)(?:\z|[?#])},
    "settings_totp" => %r{\A/settings/totps},
    "avatar_transfer_request" => %r{\A/avatar_ownership_transfers(?:\z|[?#])},
    "avatar_transfer_accept" => %r{\A/avatar_ownership_transfers/[^/?#]+/accept(?:\z|[?#])},
    "avatar_transfer_cancel" => %r{\A/avatar_ownership_transfers/[^/?#]+/cancel(?:\z|[?#])},
  }.freeze

  COM = APP.merge(
    "settings_secret_credential" => %r{\A(?:/settings/(?:secrets|secret_credentials)|/identity/secrets)},
  ).except(
    "settings_totp", "social_link", "avatar_transfer_request", "avatar_transfer_accept", "avatar_transfer_cancel",
  ).freeze

  ORG = {
    # Org links/unlinks only Google (no Apple). Link gating is enforced by
    # SocialAuth via SOCIAL_LINK_SCOPE; org must therefore offer a
    # "social_link" scope or operator Google linking can never satisfy step-up.
    "social_link" => %r{\A/settings/google(?:\z|[?#])},
    "social_unlink" => %r{\A/?(?:social/|settings/google(?:\z|[?#]))},
    "session_revoke_all" => %r{
      \A(?:/sign/settings/sessions|/settings/sessions|/sessions|/identity/sessions|
         /support/(?:clients|visitors|operators)/\d+/sessions/(?:purge|emergency_revoke))
    }x,
    "withdrawal" => %r{\A(?:/settings/withdrawal|/identity/withdrawal)},
    "settings_email" => %r{\A(?:/settings/emails|/identity/emails)},
    "settings_telephone" => %r{\A(?:/settings/telephones|/identity/telephones)},
    "settings_passkey" => %r{\A/settings/passkeys},
    "settings_mfa" => %r{\A/settings/mfa/challenge},
    "settings_secret_credential" => %r{\A(?:/settings/(?:secrets|secret_credentials)|/identity/secrets)},
    "settings_birthdate" => %r{\A(?:/settings/birthdate|/identity/birthdate)(?:\z|[?#])},
    "operator_lifecycle" => %r{\A(?:/settings/operator_lifecycle_requests|/identity/withdrawal(?:\z|[?#]))},
    "avatar_transfer_request" => %r{\A/avatar_ownership_transfers(?:\z|[?#])},
    "avatar_transfer_accept" => %r{\A/avatar_ownership_transfers/[^/?#]+/accept(?:\z|[?#])},
    "avatar_transfer_cancel" => %r{\A/avatar_ownership_transfers/[^/?#]+/cancel(?:\z|[?#])},
  }.freeze
end
