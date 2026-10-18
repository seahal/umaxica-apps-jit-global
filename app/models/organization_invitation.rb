# typed: false
# frozen_string_literal: true

#
# == Schema Information
#
# Table name: organization_invitations
# Database name: op_base_org
#
#  id              :bigint           not null, primary key
#  code            :string(32)       not null
#  consumed_at     :datetime
#  email           :string           not null
#  expires_at      :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  invited_by_id   :bigint           not null
#  organization_id :bigint           not null
#  role_id         :bigint           default(0), not null
#
# Indexes
#
#  index_organization_invitations_on_code             (code) UNIQUE
#  index_organization_invitations_on_email            (email)
#  index_organization_invitations_on_invited_by_id    (invited_by_id)
#  index_organization_invitations_on_organization_id  (organization_id)
#

class OrganizationInvitation < OpBaseOrgRecord
  belongs_to :invited_by,
             class_name: "Operator",
             primary_key: :id

  validates :code, presence: true, uniqueness: true, length: { maximum: 32 }
  validates :email, presence: true
  validates :organization_id, presence: true
  validates :expires_at, presence: true

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  scope :active, -> { where(consumed_at: nil).where(arel_table[:expires_at].gt(Time.current)) }
  scope :expired, -> { where(expires_at: ..Time.current) }
  scope :consumed, -> { where.not(consumed_at: nil) }

  def active?
    consumed_at.nil? && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def consume!
    self.class.transaction do
      lock!
      return false unless active?

      update!(consumed_at: Time.current)
    end
  end

  class << self
    def find_valid(code, email: nil)
      invitation = active.find_by(code: code)
      return nil if invitation.blank?
      return nil if email.present? && !invitation.email.casecmp(email).zero?

      invitation
    end

    def generate_unique_code
      operation =
        lambda do
          loop do
            code = SecureRandom.alphanumeric(32).downcase
            break code unless exists?(code: code)
          end
        end

      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end
  end

  private

  def generate_code
    self.code ||= self.class.generate_unique_code
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end
