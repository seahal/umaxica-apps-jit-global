# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: enterprise_units
# Database name: app_zenith
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  name          :string           default(""), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  enterprise_id :bigint           not null
#  parent_id     :bigint
#  public_id     :string           default(""), not null
#
# Indexes
#
#  idx_enterprise_units_id_enterprise       (id,enterprise_id) UNIQUE
#  index_enterprise_units_on_enterprise_id  (enterprise_id)
#  index_enterprise_units_on_parent_id      (parent_id)
#  index_enterprise_units_on_public_id      (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_enterprise_units_parent_same_enterprise  ([parent_id, enterprise_id] => enterprise_units[id, enterprise_id]) ON DELETE => restrict
#  fk_rails_...                                (enterprise_id => enterprises.id)
#  fk_rails_...                                (parent_id => enterprise_units.id)
#
class EnterpriseUnit < AppRpRecord
  include ::CollectiveUnit

  collective_unit_config collective_foreign_key: :enterprise_id,
                         closure_class_name: "EnterpriseUnitClosure"

  belongs_to :enterprise, inverse_of: :enterprise_units
  belongs_to :parent,
             class_name: "EnterpriseUnit",
             inverse_of: :children
  has_many :children,
           class_name: "EnterpriseUnit",
           foreign_key: :parent_id,
           dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :ancestor_links,
           class_name: "EnterpriseUnitClosure",
           foreign_key: :descendant_id,
           dependent: :destroy,
           inverse_of: :descendant
  has_many :descendant_links,
           class_name: "EnterpriseUnitClosure",
           foreign_key: :ancestor_id,
           dependent: :destroy,
           inverse_of: :ancestor
  has_many :ancestors, through: :ancestor_links, source: :ancestor
  has_many :descendants, through: :descendant_links, source: :descendant
  has_many :persona_memberships, dependent: :restrict_with_error, inverse_of: :enterprise_unit

  validates :enterprise_id, exclusion: { in: [nil] }
  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: { scope: %i(enterprise_id) }, allow_nil: true, if: :will_save_change_to_id?
end
