# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: company_units
# Database name: com_zenith
#
#  id           :bigint           not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string           default(""), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  company_id   :bigint           not null
#  parent_id    :bigint
#  public_id    :string           default(""), not null
#
# Indexes
#
#  idx_company_units_id_company       (id,company_id) UNIQUE
#  index_company_units_on_company_id  (company_id)
#  index_company_units_on_parent_id   (parent_id)
#  index_company_units_on_public_id   (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_company_units_parent_same_company  ([parent_id, company_id] => company_units[id, company_id]) ON DELETE => restrict
#  fk_rails_...                          (company_id => companies.id)
#  fk_rails_...                          (parent_id => company_units.id)
#
class CompanyUnit < ComRpRecord
  include ::CollectiveUnit

  collective_unit_config collective_foreign_key: :company_id,
                         closure_class_name: "CompanyUnitClosure"

  belongs_to :company, inverse_of: :company_units
  belongs_to :parent,
             class_name: "CompanyUnit",
             inverse_of: :children
  has_many :children,
           class_name: "CompanyUnit",
           foreign_key: :parent_id,
           dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :ancestor_links,
           class_name: "CompanyUnitClosure",
           foreign_key: :descendant_id,
           dependent: :destroy,
           inverse_of: :descendant
  has_many :descendant_links,
           class_name: "CompanyUnitClosure",
           foreign_key: :ancestor_id,
           dependent: :destroy,
           inverse_of: :ancestor
  has_many :ancestors, through: :ancestor_links, source: :ancestor
  has_many :descendants, through: :descendant_links, source: :descendant
  has_many :individual_memberships, dependent: :restrict_with_error, inverse_of: :company_unit

  validates :company_id, exclusion: { in: [nil] }
  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: { scope: %i(company_id) }, allow_nil: true, if: :will_save_change_to_id?
end
