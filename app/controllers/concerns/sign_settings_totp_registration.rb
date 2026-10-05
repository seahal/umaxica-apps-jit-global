# frozen_string_literal: true

# Registration controllers explicitly discard obsolete CookieStore enrollment on POST.
# These values cannot participate in the admitted server-side registration path.
module SignSettingsTotpRegistration
  private

  def discard_legacy_totp_enrollment!
    session.delete(:totp_enrollment)
    session.delete(:totp_ceremony)
    session.delete(:private_key)
  end
end
