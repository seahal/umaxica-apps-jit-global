# typed: false
# frozen_string_literal: true

module CollectiveMembership
  extend ActiveSupport::Concern

  included do
    self.belongs_to_required_by_default = false

    scope :current, lambda {
      now = Time.current
      table = arel_table

      where(revoked_at: nil)
        .where(table[:starts_at].eq(nil).or(table[:starts_at].lteq(now)))
        .where(table[:ends_at].eq(nil).or(table[:ends_at].gt(now)))
    }
    scope :active, -> { current.where(membership_state_id: membership_state_active_id) }
    scope :primary_first, -> { order(primary: :desc, created_at: :asc, id: :asc) }
    scope :primary_active, -> { active.where(primary: true) }

    validates :membership_kind, :membership_state, presence: true
    validate :unit_must_belong_to_same_collective
    validate :only_one_active_primary_membership
  end

  CONFIG_REGISTRY = {}
  private_constant :CONFIG_REGISTRY

  public

  def account
    public_send(self.class.account_association_name)
  end

  def collective
    public_send(self.class.collective_association_name)
  end

  def organization
    collective
  end

  def collective_unit
    public_send(self.class.unit_association_name)
  end

  def organization_unit
    collective_unit
  end

  def active?
    membership_state_id == self.class.membership_state_active_id &&
      revoked_at.blank? &&
      starts_at_not_future? &&
      ends_at_not_reached?
  end

  def primary_active?
    primary? && active?
  end

  def revoked?
    revoked_at.present?
  end

  def ended?
    ends_at.present? && ends_at <= Time.current
  end

  private

  def starts_at_not_future?
    starts_at.blank? || starts_at <= Time.current
  end

  def ends_at_not_reached?
    ends_at.blank? || ends_at > Time.current
  end

  def unit_must_belong_to_same_collective
    unit = public_send(self.class.unit_association_name)
    return if unit.blank?

    collective_id = public_send(self.class.collective_foreign_key)
    unit_collective_id = unit.public_send(self.class.collective_foreign_key)
    return if collective_id == unit_collective_id

    errors.add(self.class.unit_association_name, :invalid)
  end

  def only_one_active_primary_membership
    return unless self[:primary]
    return if revoked_at.present? || ends_at.present?

    account_id = public_send(self.class.account_foreign_key)
    return if account_id.blank?

    duplicate = self.class
      .where(self.class.account_foreign_key => account_id, :primary => true, :revoked_at => nil, :ends_at => nil)
      .where.not(id:)
      .exists?
    errors.add(:primary, :taken) if duplicate
  end

  class_methods do
    def collective_membership_config(account_foreign_key:, collective_foreign_key:, unit_association_name:)
      CONFIG_REGISTRY[self] = {
        account_foreign_key: account_foreign_key,
        collective_foreign_key: collective_foreign_key,
        unit_association_name: unit_association_name,
      }
    end

    def account_foreign_key
      CONFIG_REGISTRY.fetch(self)[:account_foreign_key]
    end

    def account_association_name
      account_foreign_key.to_s.delete_suffix("_id").to_sym
    end

    def collective_foreign_key
      CONFIG_REGISTRY.fetch(self)[:collective_foreign_key]
    end

    def collective_association_name
      collective_foreign_key.to_s.delete_suffix("_id").to_sym
    end

    def unit_association_name
      CONFIG_REGISTRY.fetch(self)[:unit_association_name]
    end

    def membership_state_active_id
      reflect_on_association(:membership_state).klass::ACTIVE
    end
  end
end
