# frozen_string_literal: true

require "test_helper"

class SignInTokenUniquenessTest < ActiveSupport::TestCase
  CELLS = [
    [Client, ClientStatus::ACTIVE, ClientVisibility::USER, ClientToken, :user, ClientSignInFlow],
    [Visitor, VisitorStatus::ACTIVE, VisitorVisibility::VISITOR, VisitorToken, :visitor, VisitorSignInFlow],
    [Operator, OperatorStatus::ACTIVE, OperatorVisibility::STAFF, OperatorToken, :staff, OperatorSignInFlow],
  ].freeze

  CELLS.each do |principal_class, status, visibility, root_class, root_owner_key, flow_class|
    test "#{flow_class.name} preserves nil parents raw uniqueness and unchanged-key query budget" do
      actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      first_root = root_class.create!(:authentication_epoch => 0, root_owner_key => actor)
      second_root = root_class.create!(:authentication_epoch => 0, root_owner_key => actor)
      now = flow_class.database_now
      metadata = { principal_id: actor.id,
                   state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
                   issued_at: now,
                   expires_at: now + 300, }
      first = flow_class.create!(
        metadata.merge(nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32))),
      )
      second = flow_class.create!(
        metadata.merge(nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32))),
      )

      assert_nil first.reload.token_id
      assert_nil second.reload.token_id
      first.update!(token: first_root, session_issued_at: now)
      assert_raises(ActiveRecord::RecordNotUnique) do
        flow_class.transaction(requires_new: true) {
          second.update_columns(token_id: first_root.id, session_issued_at: now)
        }
      end
      assert_nil second.reload.token_id
      candidate = flow_class.new(
        metadata.merge(
          token: second_root, session_issued_at: now,
          nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
        ),
      )
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          if sql.match?(/\ASELECT/i) && sql.include?(flow_class.table_name) && sql.include?("\"token_id\"")
            queries << sql
          end
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end

    test "#{flow_class.name} refuses duplicate roots before a new flow is persisted" do
      actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      root = root_class.create!(:authentication_epoch => 0, root_owner_key => actor)
      now = flow_class.database_now
      metadata = { principal_id: actor.id,
                   state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
                   issued_at: now,
                   expires_at: now + 300,
                   token: root,
                   session_issued_at: now, }
      flow_class.create!(metadata.merge(nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32))))
      duplicate = flow_class.new(metadata.merge(nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32))))

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:token_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end

    test "#{flow_class.name} validates token attachment to a reused flow" do
      actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      first_root = root_class.create!(:authentication_epoch => 0, root_owner_key => actor)
      second_root = root_class.create!(:authentication_epoch => 0, root_owner_key => actor)
      now = flow_class.database_now
      metadata = { principal_id: actor.id,
                   state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
                   issued_at: now,
                   expires_at: now + 300, }
      flow_class.create!(
        metadata.merge(
          token: first_root, session_issued_at: now,
          nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
        ),
      )
      second = flow_class.create!(
        metadata.merge(nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32))),
      )
      second.assign_attributes(token: first_root, session_issued_at: now)

      assert_not second.valid?
      assert second.errors.of_kind?(:token_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { second.save! }
      assert_nil second.reload.token_id
      second.update!(token: second_root, session_issued_at: now)

      assert_equal second_root.id, second.reload.token_id
    end
  end
end
