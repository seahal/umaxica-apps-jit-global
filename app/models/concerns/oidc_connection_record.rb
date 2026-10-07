# typed: false
# frozen_string_literal: true

module OidcConnectionRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId

    validates :client_id, presence: true
    validates :client_id, length: { maximum: 64 }

    scope :recent_first, -> { order(Arel.sql("COALESCE(last_used_at, updated_at, created_at) DESC")) }
    scope :active, -> { where(revoked_at: nil) }
  end

  def active?
    revoked_at.blank?
  end

  def revoked?
    revoked_at.present?
  end

  def status
    active? ? "active" : "revoked"
  end

  def rp_client
    OidcClientRegistry.find(client_id)
  end

  def rp_name
    rp_client&.name || client_id
  end

  def rp_domains
    rp_client&.domains || []
  end

  def rp_domain_text
    domains = rp_domains
    domains.present? ? domains.join(", ") : "-"
  end

  def scopes
    scope.to_s.split.filter_map(&:presence)
  end

  def connected_at
    created_at
  end

  class_methods do
    def actor_foreign_key
      raise NotImplementedError, "#{name} must define actor_foreign_key"
    end
  end
end
