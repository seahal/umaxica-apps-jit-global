# typed: false
# frozen_string_literal: true

class IdentifierEncryptionReencrypt
  Result = Data.define(
    :user_emails_reencrypted,
    :user_telephones_reencrypted,
    :staff_emails_reencrypted,
    :staff_telephones_reencrypted,
    :visitor_emails_reencrypted,
    :visitor_telephones_reencrypted,
  )

  MODELS = [
    ClientEmail,
    ClientTelephone,
    OperatorEmail,
    OperatorTelephone,
    VisitorEmail,
    VisitorTelephone,
  ].freeze

  public

  def initialize(models: MODELS)
    unless models.is_a?(Array) && models.any? && models.uniq == models && (models - MODELS).empty?
      raise ArgumentError, "unsupported identifier encryption targets"
    end

    @models = models.dup.freeze
  end

  def call
    counts = Hash.new(0)

    work =
      lambda do
        @models.each do |model|
          counts[model.name] = reencrypt_records(model)
        end
      end

    if defined?(Prosopite)
      Prosopite.pause(&work)
    else
      work.call
    end

    Result.new(
      user_emails_reencrypted: counts["ClientEmail"],
      user_telephones_reencrypted: counts["ClientTelephone"],
      staff_emails_reencrypted: counts["OperatorEmail"],
      staff_telephones_reencrypted: counts["OperatorTelephone"],
      visitor_emails_reencrypted: counts["VisitorEmail"],
      visitor_telephones_reencrypted: counts["VisitorTelephone"],
    )
  end

  private

  def reencrypt_records(model)
    updated = 0
    model.unscoped.in_batches(of: 1000) do |relation|
      relation.each do |record|
        model.encrypted_attributes.each do |attr_name|
          value = record.public_send(attr_name)
          record.public_send("#{attr_name}_will_change!")
          record.public_send("#{attr_name}=", value)
        end

        record.save!
        updated += 1
      end
    end
    updated
  end
end
