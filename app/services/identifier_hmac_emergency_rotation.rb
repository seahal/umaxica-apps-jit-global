# typed: false
# frozen_string_literal: true

require "openssl"

class IdentifierHmacEmergencyRotation
  Result = Data.define(
    :user_emails_updated,
    :user_telephones_updated,
    :staff_emails_updated,
    :staff_telephones_updated,
    :visitor_emails_updated,
    :visitor_telephones_updated,
    :records_failed,
  )

  IDENTIFIER_TARGETS = [
    {
      model: ClientEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :user_emails_updated,
    },
    {
      model: ClientTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :user_telephones_updated,
    },
    {
      model: OperatorEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :staff_emails_updated,
    },
    {
      model: OperatorTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :staff_telephones_updated,
    },
    {
      model: VisitorEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :visitor_emails_updated,
    },
    {
      model: VisitorTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :visitor_telephones_updated,
    },
  ].freeze

  public

  def initialize(realm:, channel:, maintenance_connection:)
    unless (realm.is_a?(String) || realm.is_a?(Symbol)) && (channel.is_a?(String) || channel.is_a?(Symbol))
      raise ArgumentError, "unsupported identifier rotation domain"
    end

    @target =
      case [realm.to_s, channel.to_s]
      when ["app", "email"] then IDENTIFIER_TARGETS.fetch(0)
      when ["app", "telephone"] then IDENTIFIER_TARGETS.fetch(1)
      when ["org", "email"] then IDENTIFIER_TARGETS.fetch(2)
      when ["org", "telephone"] then IDENTIFIER_TARGETS.fetch(3)
      when ["com", "email"] then IDENTIFIER_TARGETS.fetch(4)
      when ["com", "telephone"] then IDENTIFIER_TARGETS.fetch(5)
      else raise ArgumentError, "unsupported identifier rotation domain"
      end
    unless maintenance_connection.is_a?(PG::Connection)
      raise ArgumentError, "identifier rotation requires an explicit PostgreSQL maintenance connection"
    end

    source_connection = @target.fetch(:model).lease_connection.raw_connection
    unless [maintenance_connection.db, maintenance_connection.host, maintenance_connection.port] ==
        [source_connection.db, source_connection.host, source_connection.port]
      raise ArgumentError, "identifier rotation maintenance database mismatch"
    end

    @maintenance_connection = maintenance_connection
    @operation_ref = SecureRandom.uuid
  end

  def call
    counts = Hash.new(0)

    result = overwrite_target(@target)
    counts[@target.fetch(:result_key)] = result.fetch(:updated)
    counts[:records_failed] = result.fetch(:failed)

    Result.new(
      user_emails_updated: counts[:user_emails_updated],
      user_telephones_updated: counts[:user_telephones_updated],
      staff_emails_updated: counts[:staff_emails_updated],
      staff_telephones_updated: counts[:staff_telephones_updated],
      visitor_emails_updated: counts[:visitor_emails_updated],
      visitor_telephones_updated: counts[:visitor_telephones_updated],
      records_failed: counts[:records_failed],
    )
  end

  private

  def overwrite_target(target)
    model = target.fetch(:model)
    unless target_columns_present?(target)
      raise ArgumentError, "identifier rotation target columns unavailable"
    end

    operation = -> { overwrite_target_records(target, model) }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def overwrite_target_records(target, model)
    updated = 0
    failed = 0

    model.unscoped.in_batches(of: 1000, load: false) do |relation|
      relation.pluck(model.primary_key).each do |record_id|
        case overwrite_record(target, record_id)
        when :updated
          updated += 1
        when :failed
          failed += 1
        when :unchanged
          next
        else
          raise ArgumentError, "unexpected identifier rotation outcome"
        end
      end
    end

    { updated: updated, failed: failed }
  end

  def target_columns_present?(target)
    model = target.fetch(:model)
    model.column_names.include?(target.fetch(:digest_column).to_s) &&
      model.column_names.include?(target.fetch(:identifier_column).to_s)
  end

  def overwrite_record(target, record_id)
    model = target.fetch(:model)
    record = model.unscoped.find(record_id)
    digest =
      case record
      when ClientEmail, VisitorEmail, OperatorEmail
        IdentifierBlindIndex.bidx_for_email(record.address, realm: model.identifier_hmac_realm)
      when ClientTelephone, VisitorTelephone, OperatorTelephone
        IdentifierBlindIndex.bidx_for_telephone(record.number, realm: model.identifier_hmac_realm)
      else
        raise ArgumentError, "unsupported identifier rotation model"
      end
    raise ArgumentError, "identifier rotation produced an empty digest" if digest.blank?

    function =
      case record
      when ClientEmail then "public.rotate_client_emails_hmac"
      when ClientTelephone then "public.rotate_client_telephones_hmac"
      when VisitorEmail then "public.rotate_visitor_emails_hmac"
      when VisitorTelephone then "public.rotate_visitor_telephones_hmac"
      when OperatorEmail then "public.rotate_operator_emails_hmac"
      when OperatorTelephone then "public.rotate_operator_telephones_hmac"
      else raise ArgumentError, "unsupported identifier rotation model"
      end
    response = @maintenance_connection.exec_params(
      "SELECT #{function}($1::bigint, $2::text, $3::text, $4::uuid)::text",
      [record.id, digest, record[target.fetch(:digest_column)], @operation_ref],
    ).getvalue(0, 0)
    case response
    when "true" then :updated
    when "false" then :unchanged
    else raise ArgumentError, "invalid identifier rotation database receipt"
    end
  rescue ActiveRecord::Encryption::Errors::Decryption, ActiveRecord::RecordNotFound, OpenSSL::Cipher::CipherError
    :failed
  end
end
