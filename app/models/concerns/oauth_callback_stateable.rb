# typed: false
# frozen_string_literal: true

module OauthCallbackStateable
  extend ActiveSupport::Concern

  TTL_SECONDS = 300

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
    scope :unconsumed, -> { where(consumed_at: nil) }

    validates :state_digest, :provider, :issued_at, :expires_at, presence: true
    validates :state_digest, uniqueness: true
  end

  class_methods do
    def issue!(state:, provider:, intent: nil, now: Time.current)
      return nil if state.blank? || provider.blank?

      connection_owner.connected_to(role: :writing) do
        find_or_create_by!(state_digest: digest_state(state)) do |record|
          record.provider = provider
          record.intent = intent
          record.issued_at = now
          record.expires_at = now + TTL_SECONDS.seconds
        end
      end
    rescue ActiveRecord::RecordNotUnique
      find_by(state_digest: digest_state(state))
    end

    def consume!(state:, provider:, now: Time.current)
      return false if state.blank? || provider.blank?

      consumed = nil
      connection_owner.connected_to(role: :writing) do
        transaction do
          consumed = active_at(now).unconsumed.lock.find_by(
            state_digest: digest_state(state),
            provider: provider,
          )
          consumed&.update!(consumed_at: now)
        end
      end
      consumed.present?
    end

    def digest_state(state)
      OpenSSL::Digest::SHA256.hexdigest(state.to_s)
    end

    def connection_owner
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      end
    end
  end
end
