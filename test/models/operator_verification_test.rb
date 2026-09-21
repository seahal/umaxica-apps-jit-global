# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_verifications
# Database name: org_ticket
#
#  id             :bigint           not null, primary key
#  discard_at   :datetime         default(Infinity), not null
#  last_used_at   :datetime
#  purge_eligible_at      :datetime         default(Infinity), not null
#  token_digest   :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  staff_token_id :bigint           not null
#
# Indexes
#
#  index_operator_verifications_on_staff_token_id  (staff_token_id)
#  index_operator_verifications_on_token_digest    (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_token_id => operator_tokens.id) ON DELETE => cascade
#
require "test_helper"

class OperatorVerificationTest < ActiveSupport::TestCase
  fixtures :operators, :operator_tokens

  test "issue_for_token! revokes previous active verification for same token" do
    token = operator_tokens(:one)
    first, = OperatorVerification.issue_for_token!(token: token)
    second, raw = OperatorVerification.issue_for_token!(token: token)

    assert_predicate first.reload.discard_at, :present?
    assert_predicate second, :active?
    assert_equal OperatorVerification.digest_token(raw), second.token_digest
  end

  test "active scope only returns non-revoked and non-expired verifications" do
    token = operator_tokens(:one)
    active, = OperatorVerification.issue_for_token!(token: token)
    expired = OperatorVerification.create!(
      staff_token: token,
      token_digest: SecureRandom.hex(48),
      discard_at: 1.minute.ago,
    )

    ids = OperatorVerification.active.pluck(:id)

    assert_includes ids, active.id
    assert_not_includes ids, expired.id
  end
end
