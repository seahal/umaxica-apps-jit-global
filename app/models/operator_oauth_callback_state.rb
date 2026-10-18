# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_oauth_callback_states
# Database name: op_base_org
#
#  id           :bigint           not null, primary key
#  consumed_at  :datetime
#  expires_at   :datetime         not null
#  intent       :string
#  issued_at    :datetime         not null
#  provider     :string           not null
#  state_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_operator_oauth_callback_states_on_expires_at    (expires_at)
#  index_operator_oauth_callback_states_on_state_digest  (state_digest) UNIQUE
#
class OperatorOauthCallbackState < OpBaseOrgRecord
  include OauthCallbackStateable
end
