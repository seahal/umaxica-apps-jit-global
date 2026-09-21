# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_step_up_sessions
# Database name: app_ticket
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  discard_at  :datetime         default(Infinity), not null
#  method        :string
#  purge_eligible_at     :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_client_step_up_sessions_on_user_token_id  (user_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => client_tokens.id) ON DELETE => cascade
#
require "test_helper"

class ClientStepUpSessionTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_visibilities, :client_mfa_levels, :client_mfa_statuses

  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    @user_token = ClientToken.create!(user: @user)
    @valid_params = {
      user_token: @user_token,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      discard_at: 10.minutes.from_now,
    }.freeze
  end

  test "is valid with nil method" do
    assert_predicate ClientStepUpSession.new(@valid_params.merge(method: nil)), :valid?
  end

  test "is valid with known methods" do
    ClientStepUpSession::METHODS.each do |method|
      assert_predicate ClientStepUpSession.new(@valid_params.merge(method: method)), :valid?, method
    end
  end

  test "is invalid with unknown method" do
    session = ClientStepUpSession.new(@valid_params.merge(method: "sms"))

    assert_not session.valid?
    assert_not_empty session.errors[:method]
  end

  test "is valid with pending and verified statuses" do
    ClientStepUpSession::STATUSES.each do |status|
      assert_predicate ClientStepUpSession.new(@valid_params.merge(status: status)), :valid?, status
    end
  end

  test "is invalid with removed or unknown statuses" do
    %w(CANCELLED EXPIRED UNKNOWN).each do |status|
      session = ClientStepUpSession.new(@valid_params.merge(status: status))

      assert_not session.valid?, status
      assert_not_empty session.errors[:status]
    end
  end

  test "attempt count cannot be negative" do
    session = ClientStepUpSession.new(@valid_params.merge(attempt_count: -1))

    assert_not session.valid?
    assert_not_empty session.errors[:attempt_count]
  end

  test "database rejects retention order when validations are bypassed" do
    session = ClientStepUpSession.new(
      @valid_params.merge(
        discard_at: 2.days.from_now,
        purge_eligible_at: 1.day.from_now,
      ),
    )
    exception_classes = [ActiveRecord::StatementInvalid]
    exception_classes << ActiveRecord::CheckConstraintViolation if defined?(ActiveRecord::CheckConstraintViolation)

    assert_raises(*exception_classes) do
      ActiveRecord::Base.logger.silence { session.save!(validate: false) }
    end
  end

  test "belongs to token" do
    session = ClientStepUpSession.create!(@valid_params)

    assert_equal @user_token, session.user_token
  end

  test "duplicate token row raises record not unique" do
    ClientStepUpSession.create!(@valid_params)

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) do
      ClientStepUpSession.create!(@valid_params.merge(method: "email_otp", status: "VERIFIED"))
    end
  end

  test "expired? reflects discard_at boundary" do
    assert_predicate ClientStepUpSession.new(@valid_params.merge(discard_at: Time.current)), :expired?
    assert_not ClientStepUpSession.new(@valid_params.merge(discard_at: 1.second.from_now)).expired?
  end

  test "same actor can have independent token-bound tickets" do
    other_token = ClientToken.create!(user: @user)
    first = ClientStepUpSession.create!(@valid_params)
    second = ClientStepUpSession.create!(@valid_params.merge(user_token: other_token, return_to: "/other"))

    assert_equal [first, second].sort,
                 ClientStepUpSession.where(user_token_id: [@user_token.id, other_token.id]).to_a.sort
  end
end
