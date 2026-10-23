# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyCookie
  extend ActiveSupport::Concern

  COOKIE_BASENAME = "withdrawal_ceremony"

  private

  def withdrawal_ceremony_cookie_name
    AuthenticationCookieName.with_host_prefix(COOKIE_BASENAME, production: JitSessionCookieConfig.force_secure?)
  end

  def withdrawal_ceremony_cookie_options
    CoreCookieOptions.for(
      request: request, same_site: :strict, path: "/",
      expires: WithdrawalCeremonyRecordable::TTL.from_now,
    )
  end

  def withdrawal_ceremony_cookie_deletion_options
    CoreCookieOptions.for(
      request: request, same_site: :strict, path: "/",
    ).except(:expires, :httponly)
  end

  def write_withdrawal_ceremony_cookie!(ceremony)
    cookies[withdrawal_ceremony_cookie_name] = withdrawal_ceremony_cookie_options.merge(
      value: "#{ceremony.public_id}:#{ceremony.plaintext_token}",
    )
  end

  def read_withdrawal_ceremony_cookie
    value = cookies[withdrawal_ceremony_cookie_name].to_s
    public_id, token = value.split(":", 2)
    return [nil, nil] if public_id.blank? || token.blank?

    [public_id, token]
  end

  def clear_withdrawal_ceremony_cookie!
    cookies.delete(withdrawal_ceremony_cookie_name, withdrawal_ceremony_cookie_deletion_options)
  end
end
