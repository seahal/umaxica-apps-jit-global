# typed: false
# frozen_string_literal: true

module SignedSessionReference
  extend ActiveSupport::Concern

  REF_EXPIRES_IN = 1.hour

  class_methods do
    def signed_ref_lookup_role
      :reading
    end

    def find_from_signed_ref(signed_ref)
      return nil if signed_ref.blank?

      data = decode_signed_ref(signed_ref)
      return nil unless data

      token_id = data[:id] || data["id"]
      public_id = data[:pid] || data["pid"]
      find_logic = -> { find_by(id: token_id, public_id: public_id) }

      connection_owner.connected_to(role: signed_ref_lookup_role, &find_logic)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
      nil
    end

    def find_from_signed_refs(signed_refs)
      refs = Array(signed_refs).compact_blank
      return [] if refs.empty?

      decoded_refs = refs.filter_map { |signed_ref| decode_signed_ref(signed_ref) }
      return [] if decoded_refs.empty?

      ids = decoded_refs.filter_map { |data| data[:id] || data["id"] }
      public_ids = decoded_refs.filter_map { |data| data[:pid] || data["pid"] }
      find_logic =
        -> do
          where(id: ids, public_id: public_ids).to_a
        end

      connection_owner.connected_to(role: signed_ref_lookup_role, &find_logic)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
      []
    end

    private

    def decode_signed_ref(signed_ref)
      Rails.application.message_verifier(:session_ref).verify(signed_ref)
    end

    def connection_owner
      klass = self
      klass = klass.superclass until klass.connection_class? || klass == ApplicationRecord
      klass
    end
  end

  def signed_ref
    Rails.application.message_verifier(:session_ref).generate(
      { id: id, pid: public_id },
      expires_in: REF_EXPIRES_IN,
    )
  end
end
