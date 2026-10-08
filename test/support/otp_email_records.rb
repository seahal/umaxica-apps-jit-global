# typed: false
# frozen_string_literal: true

# Builds the persisted email records the OTP delivery path takes as its `record:`.
#
# The records must be persisted rather than instantiated, because the Noticed
# delivery path serializes the recipient through GlobalID. A non-persisted record
# would fail at enqueue time in a way the legacy mailer path never exercised.
module OtpEmailRecords
  def create_otp_email_record(surface, address:)
    case surface.to_sym
    when :app then create_client_email(address: address)
    when :com then create_visitor_email(address: address)
    when :org then create_operator_email(address: address)
    else raise ArgumentError, "unsupported otp email surface: #{surface}"
    end
  end

  private

  def create_client_email(address:)
    ClientEmail.create!(
      user_id: clients(:one).id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def create_visitor_email(address:)
    VisitorEmail.create!(
      visitor_id: visitors(:reserved_visitor).id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def create_operator_email(address:)
    OperatorEmail.create!(
      staff: operators(:one),
      address: address,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end
end
