# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: member_avatar_extractions
# Database name: avatar
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  avatar_id  :bigint           not null
#  member_id  :bigint           not null
#
# Indexes
#
#  index_member_avatar_extractions_on_avatar_id                (avatar_id)
#  index_member_avatar_extractions_on_member_id_and_avatar_id  (member_id,avatar_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#


require "test_helper"

class MemberAvatarExtractionTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "MemberAvatarExtraction", MemberAvatarExtraction.name
  end
end
