# frozen_string_literal: true
# typed: false

# == Schema name: client_member_deletions
#
# Table name: client_member_deletions
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  member_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_member_deletions_on_member_id              (member_id)
#  index_user_member_deletions_on_user_id_and_member_id  (user_id,member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (member_id => members.id)
#  fk_rails_...  (user_id => users.id)
#

# == Schema Information
#
# Table name: client_member_deletions
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  member_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_member_deletions_on_member_id              (member_id)
#  index_client_member_deletions_on_user_id_and_member_id  (user_id,member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (member_id => members.id)
#  fk_rails_...  (user_id => clients.id)
#
class ClientMemberDeletion < AppPrincipalRecord
  belongs_to :user, class_name: "Client", inverse_of: :client_member_deletions
  belongs_to :member, inverse_of: :client_member_deletions

  validates :member_id, uniqueness: { scope: :user_id }
end
