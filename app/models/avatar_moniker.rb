# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_monikers
# Database name: avatar
#
#  id                       :bigint           not null, primary key
#  moniker                  :string           not null
#  valid_from               :datetime         not null
#  valid_to                 :datetime         default(Infinity), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  avatar_id                :bigint           not null
#
# Indexes
#
#  index_avatar_monikers_on_avatar_id                 (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_monikers_on_avatar_id_and_valid_from  (avatar_id,valid_from DESC)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)

class AvatarMoniker < AvatarRecord
  belongs_to :avatar, inverse_of: :avatar_monikers

  def self.validate_column_size(attribute_name)
    # Rails' generated ciphertext-length validator calls String#blank? on malformed UTF-8 before
    # AvatarMonikerValidator can reject it. The domain validator checks plaintext bytes, and the
    # persisted-ciphertext test verifies the physical varchar bound for the maximum valid input.
    return if attribute_name.to_s == "moniker"

    super
  end
  private_class_method :validate_column_size

  encrypts :moniker

  before_validation :normalize_moniker_to_nfc

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  validates :avatar_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } },
            if: :current_temporal_row?
  validates :moniker, avatar_moniker: true
  validates :valid_from, presence: true

  private

  def current_temporal_row?
    valid_to.nil? || valid_to == Float::INFINITY
  end

  def normalize_moniker_to_nfc
    return unless moniker.is_a?(String) && moniker.valid_encoding?

    self.moniker = moniker.encode(Encoding::UTF_8).unicode_normalize(:nfc)
  rescue EncodingError
    # Keep malformed input intact so AvatarMonikerValidator can report it on the field.
  end
end
