# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: client_member_observations
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
#  index_client_member_observations_on_member_id              (member_id)
#  index_client_member_observations_on_user_id_and_member_id  (user_id,member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (member_id => members.id)
#  fk_rails_...  (user_id => clients.id)
#

require "test_helper"

class ClientMemberObservationTest < ActiveSupport::TestCase
  fixtures :client_member_observations, :clients, :client_statuses, :members, :member_statuses, :divisions,
           :division_statuses, :organizations, :organization_statuses

  test "fixture is valid" do
    assert_predicate client_member_observations(:one), :valid?
  end
end
