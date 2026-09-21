# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_verifications
# Database name: app_ticket
#
#  id            :bigint           not null, primary key
#  discard_at  :datetime         default(Infinity), not null
#  last_used_at  :datetime
#  purge_eligible_at     :datetime         default(Infinity), not null
#  token_digest  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_client_verifications_on_token_digest   (token_digest) UNIQUE
#  index_client_verifications_on_user_token_id  (user_token_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => client_tokens.id) ON DELETE => cascade
#
require "test_helper"

class ClientVerificationTest < ActiveSupport::TestCase
  fixtures :clients, :client_tokens

  test "issue_for_token! revokes previous active verification for same token" do
    token = client_tokens(:one)
    first, = ClientVerification.issue_for_token!(token: token)
    second, raw = ClientVerification.issue_for_token!(token: token)

    assert_predicate first.reload.discard_at, :present?
    assert_predicate second, :active?
    assert_equal ClientVerification.digest_token(raw), second.token_digest
  end

  test "active scope only returns non-revoked and non-expired verifications" do
    token = client_tokens(:one)
    active, = ClientVerification.issue_for_token!(token: token)
    expired = ClientVerification.create!(
      user_token: token,
      token_digest: SecureRandom.hex(48),
      discard_at: 1.minute.ago,
    )

    ids = ClientVerification.active.pluck(:id)

    assert_includes ids, active.id
    assert_not_includes ids, expired.id
  end
end
