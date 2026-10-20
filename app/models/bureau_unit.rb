# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: bureau_units
# Database name: org_zenith
#
#  id           :bigint           not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string           default(""), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  bureau_id    :bigint           not null
#  parent_id    :bigint
#  public_id    :string           default(""), not null
#
# Indexes
#
#  idx_bureau_units_id_bureau       (id,bureau_id) UNIQUE
#  index_bureau_units_on_bureau_id  (bureau_id)
#  index_bureau_units_on_parent_id  (parent_id)
#  index_bureau_units_on_public_id  (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_bureau_units_parent_same_bureau  ([parent_id, bureau_id] => bureau_units[id, bureau_id]) ON DELETE => restrict
#  fk_rails_...                        (bureau_id => bureaus.id)
#  fk_rails_...                        (parent_id => bureau_units.id)
#
class BureauUnit < OrgRpRecord
  include ::CollectiveUnit

  collective_unit_config collective_foreign_key: :bureau_id,
                         closure_class_name: "BureauUnitClosure"

  belongs_to :bureau, inverse_of: :bureau_units
  belongs_to :parent,
             class_name: "BureauUnit",
             inverse_of: :children
  has_many :children,
           class_name: "BureauUnit",
           foreign_key: :parent_id,
           dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :ancestor_links,
           class_name: "BureauUnitClosure",
           foreign_key: :descendant_id,
           dependent: :destroy,
           inverse_of: :descendant
  has_many :descendant_links,
           class_name: "BureauUnitClosure",
           foreign_key: :ancestor_id,
           dependent: :destroy,
           inverse_of: :ancestor
  has_many :ancestors, through: :ancestor_links, source: :ancestor
  has_many :descendants, through: :descendant_links, source: :descendant
  has_many :agent_memberships, dependent: :restrict_with_error, inverse_of: :bureau_unit

  validates :bureau_id, exclusion: { in: [nil] }
  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: { scope: %i(bureau_id) }, allow_nil: true, if: :will_save_change_to_id?
end
