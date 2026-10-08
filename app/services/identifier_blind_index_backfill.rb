# typed: false
# frozen_string_literal: true

class IdentifierBlindIndexBackfill
  Result = Data.define(
    :user_emails_updated,
    :user_telephones_updated,
    :staff_emails_updated,
    :staff_telephones_updated,
    :visitor_emails_updated,
    :visitor_telephones_updated,
  )

  public

  def call
    Result.new(
      user_emails_updated: backfill_emails(ClientEmail),
      user_telephones_updated: backfill_telephones(ClientTelephone),
      staff_emails_updated: backfill_emails(OperatorEmail),
      staff_telephones_updated: backfill_telephones(OperatorTelephone),
      visitor_emails_updated: backfill_emails(VisitorEmail),
      visitor_telephones_updated: backfill_telephones(VisitorTelephone),
    )
  end

  private

  def backfill_emails(model)
    updated = 0
    model.find_each(batch_size: 1000) do |record|
      digest = IdentifierBlindIndex.bidx_for_email(record.address, realm: model.identifier_hmac_realm)
      raise ArgumentError, "malformed persisted email identifier" if digest.blank?
      next if record.address_digest == digest

      record.address_digest = digest
      record.save!(validate: false)
      updated += 1
    end
    updated
  end

  def backfill_telephones(model)
    updated = 0
    model.find_each(batch_size: 1000) do |record|
      digest = IdentifierBlindIndex.bidx_for_telephone(record.number, realm: model.identifier_hmac_realm)
      raise ArgumentError, "malformed persisted telephone identifier" if digest.blank?
      next if record.number_digest == digest

      record.number_digest = digest
      record.save!(validate: false)
      updated += 1
    end
    updated
  end
end
