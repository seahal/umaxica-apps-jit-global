# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_dpop_proof_states
# Database name: op_base_com
#
#  id            :bigint           not null, primary key
#  expires_at    :datetime         not null
#  htm           :string
#  htu           :string
#  jkt           :string
#  jti           :string
#  nonce         :string
#  nonce_used_at :datetime
#  seen_at       :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_visitor_dpop_proof_states_on_expires_at  (expires_at)
#  index_visitor_dpop_proof_states_on_jti         (jti) UNIQUE WHERE (jti IS NOT NULL)
#  index_visitor_dpop_proof_states_on_nonce       (nonce) UNIQUE WHERE (nonce IS NOT NULL)
#
class VisitorDpopProofState < OpBaseComRecord
  include DpopProofStateable
end
