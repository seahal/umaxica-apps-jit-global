# typed: false
# frozen_string_literal: true

module StepUpScopeCatalog
  APP = {
    "social_link" => %r{\A/settings/(?:google|apple)(?:/edit)?(?:\z|[?#])},
    "social_unlink" => %r{\A/settings/(?:google|apple)(?:/edit)?(?:\z|[?#])},
    "session_revoke_all" =>
      %r{\A(?:/sign/settings/sessions|/settings/sessions|/sessions|/identity/sessions)(?:\z|[/?#])},
    "withdrawal" => %r{\A(?:/settings/withdrawal|/identity/withdrawal)(?:\z|[/?#])},
    "settings_email" => %r{\A(?:/settings/emails|/identity/emails)(?:\z|[/?#])},
    "settings_telephone" => %r{\A(?:/settings/telephones|/identity/telephones)(?:\z|[/?#])},
    "settings_passkey" => %r{\A/identity/passkeys(?:\z|[/?#])},
    "settings_mfa" => %r{\A/identity/mfa/challenge(?:\z|[?#])},
    "settings_secret_credential" => %r{\A/secrets(?:\z|[/?#])},
    "settings_birthdate" => %r{\A(?:/settings/birthdate|/identity/birthdate)(?:\z|[?#])},
    "settings_totp" => %r{\A/identity/totps(?:\z|[/?#])},
    "avatar_transfer_request" => %r{\A/avatar_ownership_transfers(?:\z|[?#])},
    "avatar_transfer_accept" => %r{\A/avatar_ownership_transfers/[^/?#]+/accept(?:\z|[?#])},
    "avatar_transfer_cancel" => %r{\A/avatar_ownership_transfers/[^/?#]+/cancel(?:\z|[?#])},
  }.freeze

  COM = APP.merge(
    "settings_secret_credential" => %r{\A(?:/settings/(?:secrets|secret_credentials)|/identity/secrets)(?:\z|[/?#])},
  ).except(
    "settings_totp", "social_link", "social_unlink", "avatar_transfer_request", "avatar_transfer_accept",
    "avatar_transfer_cancel",
  ).freeze

  ORG = {
    "session_revoke_all" =>
      %r{\A(?:/sign/settings/sessions|/settings/sessions|/sessions|/identity/sessions)(?:\z|[/?#])},
    "withdrawal" => %r{\A(?:/settings/withdrawal|/identity/withdrawal)(?:\z|[/?#])},
    "settings_email" => %r{\A(?:/settings/emails|/identity/emails)(?:\z|[/?#])},
    "settings_telephone" => %r{\A(?:/settings/telephones|/identity/telephones)(?:\z|[/?#])},
    "settings_passkey" => %r{\A/identity/passkeys(?:\z|[/?#])},
    "settings_mfa" => %r{\A/identity/mfa/challenge(?:\z|[?#])},
    "settings_secret_credential" => %r{\A(?:/settings/(?:secrets|secret_credentials)|/identity/secrets)(?:\z|[/?#])},
    "settings_birthdate" => %r{\A(?:/settings/birthdate|/identity/birthdate)(?:\z|[?#])},
    "operator_lifecycle" => %r{\A(?:/settings/operator_lifecycle_requests(?:\z|[/?#])|/identity/withdrawal(?:\z|[?#]))},
    "avatar_transfer_request" => %r{\A/avatar_ownership_transfers(?:\z|[?#])},
    "avatar_transfer_accept" => %r{\A/avatar_ownership_transfers/[^/?#]+/accept(?:\z|[?#])},
    "avatar_transfer_cancel" => %r{\A/avatar_ownership_transfers/[^/?#]+/cancel(?:\z|[?#])},
    # adr/operator-capability-authorization.md: administrative scopes. Each is reachable only from
    # its own confirmation page, and every one of those pages authorizes the operator's capability
    # before it asks for Step-Up, so cataloguing a scope opens nothing to an ungranted operator. The
    # org enforcement realm is deliberately absent.
    "support_session_revoke" => %r{\A/support/(?:clients|visitors)/[0-9A-Za-z_-]{1,64}/revocations/new(?:\z|[?#])},
    "enforcement_case_apply" => %r{\A/support/(?:app|com)/enforcement_cases/new(?:\z|[?#])},
    "enforcement_case_approve" =>
      %r{\A/support/(?:app|com)/enforcement_cases/[0-9A-Za-z_-]{1,64}/approval/new(?:\z|[?#])},
    "enforcement_case_release" =>
      %r{\A/support/(?:app|com)/enforcement_cases/[0-9A-Za-z_-]{1,64}/release/new(?:\z|[?#])},
    "enforcement_case_review_appeal" =>
      %r{\A/support/(?:app|com)/enforcement_cases/[0-9A-Za-z_-]{1,64}/appeal_review/new(?:\z|[?#])},
    "operator_capability" => %r{\A/iam/grants/(?:new|[0-9A-Za-z_-]{1,64}/revocation/new)(?:\z|[?#])},
  }.freeze
end
