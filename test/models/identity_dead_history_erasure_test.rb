# frozen_string_literal: true

require "test_helper"

class IdentityDeadHistoryErasureTest < ActiveSupport::TestCase
  CLIENT_ERASURE_ASSOCIATIONS = %i(
    client_external_identities client_apple_notification_events client_emails client_telephones
    client_totp_credentials client_passkeys client_withdrawal_ceremonies client_tokens client_device_sessions
    oidc_connections client_memberships clients client_banners client_members client_member_discoveries
    client_member_observations client_member_revocations client_member_impersonations client_member_suspensions
    client_member_deletions owned_members client_bulletins rp_account authority_lock core_app_client_bridge
    client_preference
  ).freeze

  %w(app).each do |realm|
    test "#{realm} permitted physical Identity erasure removes only its dead histories" do
      owner_model, email_history, telephone_history, owner_key, email_model, telephone_model =
        case realm
        when "app" then [Client, ClientEmailHistory, ClientTelephoneHistory, :user_id, ClientEmail, ClientTelephone]
        end
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, created_at: 3.days.ago,
        discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
      )
      peer = owner_model.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_model))
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "whole-erasure-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :created_at => 2.days.ago, :discard_at => 2.days.ago,
        :purge_eligible_at => 1.day.ago,
      )
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+819012399928", :confirm_policy => true,
        :confirm_using_mfa => true, :created_at => 2.days.ago, :discard_at => 2.days.ago,
        :purge_eligible_at => 1.day.ago,
      )
      facts = {
        fingerprint: "prior-dead-fingerprint",
        attached_at: 3.days.ago,
        detached_at: 2.days.ago,
        created_at: 2.days.ago,
      }
      histories = [email_history.create!(facts.merge(owner_key => owner.id)),
                   telephone_history.create!(facts.merge(owner_key => owner.id)),]
      peer_history = email_history.create!(facts.merge(owner_key => peer.id))

      owner = preload_for_erasure(owner)
      owner.destroy!

      assert_not owner_model.exists?(owner.id)
      histories.each { |history| assert_not history.class.exists?(history.id) }
      assert email_history.exists?(peer_history.id)
      assert owner_model.exists?(peer.id)
      assert_not email_model.exists?(email.id)
      assert_not telephone_model.exists?(telephone.id)
      assert_empty email_history.where(owner_key => owner.id)
      assert_empty telephone_history.where(owner_key => owner.id)
    end

    test "#{realm} database transport failure preserves Identity and history for an identical retry" do
      owner_model, email_history, owner_key =
        case realm
        when "app" then [Client, ClientEmailHistory, :user_id]
        end
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, created_at: 3.days.ago,
        discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
      )
      history = email_history.create!(
        owner_key => owner.id, :fingerprint => "retry-history", :attached_at => 3.days.ago,
        :detached_at => 2.days.ago, :created_at => 2.days.ago,
      )
      owner = preload_for_erasure(owner)
      # Only the database write fails; admission and transaction rollback stay real.
      email_history.connection_class_for_self.connected_to(role: :writing) do
        email_history.connection.stub(
          :delete, ->(*) { raise ActiveRecord::StatementInvalid, "erasure transport unavailable" },
        ) do
          assert_raises(ActiveRecord::StatementInvalid) { owner.destroy! }
        end
      end

      assert owner_model.exists?(owner.id)
      assert email_history.exists?(history.id)
      owner = preload_for_erasure(owner)
      owner.destroy!

      assert_not owner_model.exists?(owner.id)
      assert_not email_history.exists?(history.id)
    end

    test "#{realm} physical Identity erasure refuses an active legal hold without deleting history" do
      owner_model, email_history, owner_key, hold_model, hold_key =
        case realm
        when "app" then [Client, ClientEmailHistory, :user_id, ClientRetentionHold, :client]
        end
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, created_at: 3.days.ago,
        discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
      )
      history = email_history.create!(
        owner_key => owner.id, :fingerprint => "held-history", :attached_at => 3.days.ago,
        :detached_at => 2.days.ago, :created_at => 2.days.ago,
      )
      hold = hold_model.create!(hold_key => owner, :reason_code => "legal_hold")
      owner = preload_for_erasure(owner)

      assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }
      assert owner_model.exists?(owner.id)
      assert email_history.exists?(history.id)
      assert hold_model.exists?(hold.id)
    end

    test "#{realm} protected Contact rolls back physical Identity erasure and prior Source archive" do
      owner_model, email_model, email_history, owner_key =
        case realm
        when "app" then [Client, ClientEmail, ClientEmailHistory, :user_id]
        end
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, created_at: 3.days.ago,
        discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
      )
      original = email_model.create!(
        owner_key => owner.id, :raw_address => "first-erasure-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )
      protected = email_model.create!(
        owner_key => owner.id, :raw_address => "protected-erasure-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :undeletable => true,
      )
      history = email_history.create!(
        owner_key => owner.id, :fingerprint => "prior-protected-history", :attached_at => 3.days.ago,
        :detached_at => 2.days.ago, :created_at => 2.days.ago,
      )
      owner = preload_for_erasure(owner)

      assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }
      assert owner_model.exists?(owner.id)
      assert email_model.exists?(original.id)
      assert email_model.exists?(protected.id)
      assert email_history.exists?(history.id)
      assert_equal 1, email_history.where(owner_key => owner.id).count
    end

    test "#{realm} recoverable Identity cannot physically delete its dead histories" do
      owner_model, email_history, owner_key =
        case realm
        when "app" then [Client, ClientEmailHistory, :user_id]
        end
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, created_at: 3.days.ago,
        discard_at: 2.days.ago, purge_eligible_at: 1.day.from_now,
      )
      history = email_history.create!(
        owner_key => owner.id, :fingerprint => "retained-history", :attached_at => 3.days.ago,
        :detached_at => 2.days.ago, :created_at => 2.days.ago,
      )
      owner = preload_for_erasure(owner)

      assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }
      assert owner_model.exists?(owner.id)
      assert email_history.exists?(history.id)
    end
  end

  private

  def preload_for_erasure(owner)
    raise ArgumentError, "unsupported Identity erasure owner" unless owner.is_a?(Client)

    Client.includes(CLIENT_ERASURE_ASSOCIATIONS).find(owner.id)
  end
end
