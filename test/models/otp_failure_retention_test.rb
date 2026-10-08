# frozen_string_literal: true

require "test_helper"

class OtpFailureRetentionTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :operators, :operator_statuses

  [ClientEmail, VisitorEmail, OperatorEmail, ClientTelephone, VisitorTelephone, OperatorTelephone].each do |model|
    test "#{model.name} issuance and resend retain failure boundaries and deny MAX and MAX plus one" do
      owner_model, root_model, owner_key, active_status, policy, channel =
        case model.name
        when "ClientEmail"
          [Client, ClientToken, :user_id, ClientStatus::ACTIVE, EmailOtpPolicy, :email]
        when "VisitorEmail"
          [Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE, EmailOtpPolicy, :email]
        when "OperatorEmail"
          [Operator, OperatorToken, :staff_id, OperatorStatus::ACTIVE, EmailOtpPolicy, :email]
        when "ClientTelephone"
          [Client, ClientToken, :user_id, ClientStatus::ACTIVE, TelephoneOtpPolicy, :telephone]
        when "VisitorTelephone"
          [Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE, TelephoneOtpPolicy, :telephone]
        when "OperatorTelephone"
          [Operator, OperatorToken, :staff_id, OperatorStatus::ACTIVE, TelephoneOtpPolicy, :telephone]
        end
      owner = owner_model.create!(status_id: active_status)
      root = root_model.create!(owner_key => owner.id)
      root.rotate_refresh_token!
      attributes = { owner_key => owner.id, :confirm_policy => true }
      if channel == :email
        attributes[:address] = "all-realm-budget@example.com"
      else
        attributes.merge!(number: "+819012399920", confirm_using_mfa: true)
      end
      record = model.create!(attributes)
      now = model.database_now
      binding = { actor: owner, token: root, browser_nonce: SecureRandom.urlsafe_base64(32) }
      [0, 1, policy::MAX_OTP_ATTEMPTS - 1, policy::MAX_OTP_ATTEMPTS,
       policy::MAX_OTP_ATTEMPTS + 1,].each do |failures|
        record.update!(otp_attempts_count: failures, locked_at: -Float::INFINITY, otp_last_sent_at: now - 1.minute)
        issued =
          if channel == :email
            EmailCredentialRegistrationOtpIssuer.call(**binding, email: record)
          else
            TelephoneCredentialRegistrationOtpIssuer.call(**binding, telephone: record)
          end

        assert_equal (failures >= policy::MAX_OTP_ATTEMPTS) ? :locked : :issued, issued.status
        assert_equal failures, record.reload.otp_attempts_count
        assert_equal failures >= policy::MAX_OTP_ATTEMPTS, record.locked?(now: now)
        record.update!(otp_last_sent_at: now - 1.minute)
        resent =
          if channel == :email
            EmailCredentialRegistrationOtpIssuer.call(**binding, email: record)
          else
            TelephoneCredentialRegistrationOtpIssuer.call(**binding, telephone: record)
          end

        assert_equal (failures >= policy::MAX_OTP_ATTEMPTS) ? :locked : :issued, resent.status
        assert_equal failures, record.reload.otp_attempts_count
        assert_equal failures >= policy::MAX_OTP_ATTEMPTS, record.locked?(now: now)
      end
    end

    test "#{model.name} expiry and cancellation retain failures while explicit consumed success clears them" do
      owner_model, root_model, owner_key, active_status, channel =
        case model.name
        when "ClientEmail"
          [Client, ClientToken, :user_id, ClientStatus::ACTIVE, :email]
        when "VisitorEmail"
          [Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE, :email]
        when "OperatorEmail"
          [Operator, OperatorToken, :staff_id, OperatorStatus::ACTIVE, :email]
        when "ClientTelephone"
          [Client, ClientToken, :user_id, ClientStatus::ACTIVE, :telephone]
        when "VisitorTelephone"
          [Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE, :telephone]
        when "OperatorTelephone"
          [Operator, OperatorToken, :staff_id, OperatorStatus::ACTIVE, :telephone]
        end
      owner = owner_model.create!(status_id: active_status)
      root = root_model.create!(owner_key => owner.id)
      root.rotate_refresh_token!
      attributes = { owner_key => owner.id, :confirm_policy => true, :otp_attempts_count => 1 }
      if channel == :email
        attributes[:address] = "all-realm-cancel@example.com"
      else
        attributes.merge!(number: "+819012399921", confirm_using_mfa: true)
      end
      record = model.create!(attributes)
      binding = { actor: owner, token: root, browser_nonce: SecureRandom.urlsafe_base64(32) }
      issued =
        if channel == :email
          EmailCredentialRegistrationOtpIssuer.call(**binding, email: record)
        else
          TelephoneCredentialRegistrationOtpIssuer.call(**binding, telephone: record)
        end

      assert_predicate issued, :success?
      issued.transaction.update!(otp_expires_at: issued.transaction.class.database_now - Rational(1, 1_000_000))
      expired =
        if channel == :email
          EmailCredentialRegistrationOtpVerificationCommitter.call(
            **binding, email: record, transaction: issued.transaction, code: issued.code,
          )
        else
          TelephoneCredentialRegistrationOtpVerificationCommitter.call(
            **binding, telephone: record, transaction: issued.transaction, code: issued.code,
          )
        end

      assert_not expired.success?
      assert_nil issued.transaction.reload.otp_consumed_at
      assert_equal 1, record.reload.otp_attempts_count
      if channel == :email
        assert issued.transaction.cancel_email_otp!
      else
        assert issued.transaction.cancel_telephone_otp!
      end

      assert_equal 1, record.reload.otp_attempts_count
      record.update!(otp_last_sent_at: record.class.database_now - 1.minute)
      renewed =
        if channel == :email
          EmailCredentialRegistrationOtpIssuer.call(**binding, email: record)
        else
          TelephoneCredentialRegistrationOtpIssuer.call(**binding, telephone: record)
        end

      assert_predicate renewed, :success?
      verified =
        if channel == :email
          EmailCredentialRegistrationOtpVerificationCommitter.call(
            **binding, email: record, transaction: renewed.transaction, code: renewed.code,
          )
        else
          TelephoneCredentialRegistrationOtpVerificationCommitter.call(
            **binding, telephone: record, transaction: renewed.transaction, code: renewed.code,
          )
        end

      assert_predicate verified, :success?
      assert_equal 0, record.reload.otp_attempts_count
      assert_nil record.lockout_expires_at
    end
  end

  [ClientEmail, VisitorEmail, OperatorEmail].each do |model|
    test "#{model.name} resend after finite lockout expires retains failures and admits a new active challenge" do
      owner, root, owner_attributes =
        case model.name
        when "ClientEmail"
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor), { user: actor }]
        when "VisitorEmail"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(visitor: actor), { visitor: actor }]
        when "OperatorEmail"
          actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
          [actor, OperatorToken.create!(staff: actor), { staff: actor }]
        end
      root.rotate_refresh_token!
      record = model.create!(
        **owner_attributes, address: "unlock-#{SecureRandom.hex(8)}@example.com", confirm_policy: true,
      )
      previous_expiry = model.database_now - 1.minute
      record.update!(otp_attempts_count: EmailOtpPolicy::MAX_OTP_ATTEMPTS, locked_at: previous_expiry)
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: owner, token: root, email: record, browser_nonce: SecureRandom.urlsafe_base64(32),
      )

      assert_predicate issued, :success?
      assert_equal EmailOtpPolicy::MAX_OTP_ATTEMPTS, record.reload.otp_attempts_count
      assert_equal previous_expiry, record.lockout_expires_at
      assert_not record.locked?
      assert issued.transaction.email_otp_deliverable?(
        generation: issued.transaction.otp_generation, at: issued.transaction.class.database_now,
      )
    end
  end

  [ClientTelephone, VisitorTelephone, OperatorTelephone].each do |model|
    test "#{model.name} resend after finite lockout expires retains failures and admits a new active challenge" do
      owner, root, owner_attributes =
        case model.name
        when "ClientTelephone"
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor), { user: actor }]
        when "VisitorTelephone"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(visitor: actor), { visitor: actor }]
        when "OperatorTelephone"
          actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
          [actor, OperatorToken.create!(staff: actor), { staff: actor }]
        end
      root.rotate_refresh_token!
      record = model.create!(
        **owner_attributes, number: "+819012399910", confirm_policy: true, confirm_using_mfa: true,
      )
      previous_expiry = model.database_now - 1.minute
      record.update!(otp_attempts_count: TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, locked_at: previous_expiry)
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: owner, token: root, telephone: record, browser_nonce: SecureRandom.urlsafe_base64(32),
      )

      assert_predicate issued, :success?
      assert_equal TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, record.reload.otp_attempts_count
      assert_equal previous_expiry, record.lockout_expires_at
      assert_not record.locked?
      assert issued.transaction.telephone_otp_deliverable?(
        generation: issued.transaction.otp_generation, at: issued.transaction.class.database_now,
      )
    end
  end

  test "cancelling an email challenge preserves failures until a new valid proof is consumed" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: owner)
    root.rotate_refresh_token!
    email = ClientEmail.create!(
      user: owner, address: "cancel-budget@example.com", confirm_policy: true, otp_attempts_count: 1,
    )
    binding = { actor: owner, token: root, email: email, browser_nonce: SecureRandom.urlsafe_base64(32) }
    issued = EmailCredentialRegistrationOtpIssuer.call(**binding)

    assert_predicate issued, :success?
    assert issued.transaction.cancel_email_otp!

    assert_equal 1, email.reload.otp_attempts_count
    denied = EmailCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: issued.transaction, code: issued.code,
    )

    assert_not denied.success?
    assert_equal 1, email.reload.otp_attempts_count
    email.update!(otp_last_sent_at: email.class.database_now - 1.minute)
    renewed = EmailCredentialRegistrationOtpIssuer.call(**binding)
    verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: renewed.transaction, code: renewed.code,
    )

    assert_predicate verified, :success?
    assert_equal 0, email.reload.otp_attempts_count
  end

  test "cancelling a telephone challenge preserves failures until a new valid proof is consumed" do
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: owner)
    root.rotate_refresh_token!
    telephone = OperatorTelephone.create!(
      staff: owner, number: "+819012345680", confirm_policy: true, confirm_using_mfa: true, otp_attempts_count: 1,
    )
    binding = { actor: owner, token: root, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32) }
    issued = TelephoneCredentialRegistrationOtpIssuer.call(**binding)

    assert_predicate issued, :success?
    assert issued.transaction.cancel_telephone_otp!

    assert_equal 1, telephone.reload.otp_attempts_count
    denied = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: issued.transaction, code: issued.code,
    )

    assert_not denied.success?
    assert_equal 1, telephone.reload.otp_attempts_count
    telephone.update!(otp_last_sent_at: telephone.class.database_now - 1.minute)
    renewed = TelephoneCredentialRegistrationOtpIssuer.call(**binding)
    verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: renewed.transaction, code: renewed.code,
    )

    assert_predicate verified, :success?
    assert_equal 0, telephone.reload.otp_attempts_count
  end

  test "email issuance and resend preserve zero one MAX minus one MAX and MAX plus one failures" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: owner)
    root.rotate_refresh_token!
    email = ClientEmail.create!(
      user: owner, address: "email-issuance-boundaries@example.com", confirm_policy: true,
    )
    binding = { actor: owner, token: root, email: email, browser_nonce: SecureRandom.urlsafe_base64(32) }

    [0, 1, EmailOtpPolicy::MAX_OTP_ATTEMPTS - 1,
     EmailOtpPolicy::MAX_OTP_ATTEMPTS, EmailOtpPolicy::MAX_OTP_ATTEMPTS + 1,].each do |failures|
      email.update!(
        otp_attempts_count: failures, otp_last_sent_at: email.class.database_now - 1.minute,
        locked_at: -Float::INFINITY,
      )
      issued = EmailCredentialRegistrationOtpIssuer.call(**binding)

      assert_equal (failures >= EmailOtpPolicy::MAX_OTP_ATTEMPTS) ? :locked : :issued, issued.status
      assert_equal failures, email.reload.otp_attempts_count
      email.update!(otp_last_sent_at: email.class.database_now - 1.minute)
      renewed = EmailCredentialRegistrationOtpIssuer.call(**binding)

      assert_equal (failures >= EmailOtpPolicy::MAX_OTP_ATTEMPTS) ? :locked : :issued, renewed.status
      assert_equal failures, email.reload.otp_attempts_count
    end
  end

  test "telephone issuance and resend preserve zero one MAX minus one MAX and MAX plus one failures" do
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: owner)
    root.rotate_refresh_token!
    telephone = OperatorTelephone.create!(
      staff: owner, number: "+819012345679", confirm_policy: true, confirm_using_mfa: true,
    )
    binding = { actor: owner, token: root, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32) }

    [0, 1, TelephoneOtpPolicy::MAX_OTP_ATTEMPTS - 1,
     TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, TelephoneOtpPolicy::MAX_OTP_ATTEMPTS + 1,].each do |failures|
      telephone.update!(
        otp_attempts_count: failures, otp_last_sent_at: telephone.class.database_now - 1.minute,
        locked_at: -Float::INFINITY,
      )
      issued = TelephoneCredentialRegistrationOtpIssuer.call(**binding)

      assert_equal (failures >= TelephoneOtpPolicy::MAX_OTP_ATTEMPTS) ? :locked : :issued, issued.status
      assert_equal failures, telephone.reload.otp_attempts_count
      telephone.update!(otp_last_sent_at: telephone.class.database_now - 1.minute)
      renewed = TelephoneCredentialRegistrationOtpIssuer.call(**binding)

      assert_equal (failures >= TelephoneOtpPolicy::MAX_OTP_ATTEMPTS) ? :locked : :issued, renewed.status
      assert_equal failures, telephone.reload.otp_attempts_count
    end
  end

  test "email failure count survives expiry of its issuance and attempt window" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: owner)
    root.rotate_refresh_token!
    email = ClientEmail.create!(
      user: owner, address: "failure-retention@example.com",
      confirm_policy: true,
    )
    issued = EmailCredentialRegistrationOtpIssuer.call(
      actor: owner, token: root, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
    )

    assert_predicate issued, :success?
    issued.transaction.update!(otp_expires_at: issued.transaction.class.database_now - 1.day)
    email.update!(
      otp_attempts_count: 1, otp_last_sent_at: email.class.database_now - 1.day,
      locked_at: -Float::INFINITY,
    )

    email.increment_attempts!

    assert_equal 2, email.reload.otp_attempts_count
  end

  test "telephone failure count survives expiry of its issuance and attempt window" do
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: owner)
    root.rotate_refresh_token!
    telephone = OperatorTelephone.create!(
      staff: owner, number: "+819012345678", confirm_policy: true, confirm_using_mfa: true,
    )
    issued = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: owner, token: root, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
    )

    assert_predicate issued, :success?
    issued.transaction.update!(otp_expires_at: issued.transaction.class.database_now - 1.day)
    telephone.update!(
      otp_attempts_count: 1, otp_last_sent_at: telephone.class.database_now - 1.day,
      locked_at: -Float::INFINITY,
    )

    telephone.increment_attempts!

    assert_equal 2, telephone.reload.otp_attempts_count
  end

  test "Email and Telephone do not include the superseded shared OTP policy" do
    assert_not_includes ClientEmail.included_modules.map(&:name), "OtpLockable"
    assert_not_includes VisitorEmail.included_modules.map(&:name), "OtpLockable"
    assert_not_includes OperatorEmail.included_modules.map(&:name), "OtpLockable"
    assert_not_includes ClientTelephone.included_modules.map(&:name), "OtpLockable"
    assert_not_includes VisitorTelephone.included_modules.map(&:name), "OtpLockable"
    assert_not_includes OperatorTelephone.included_modules.map(&:name), "OtpLockable"
  end

  test "Email and Telephone binding lifecycles do not share a stateful concern" do
    [ClientEmail, VisitorEmail, ClientTelephone, VisitorTelephone].each do |model|
      assert_not_includes model.included_modules.map(&:name), "ContactBinding"
    end
  end
end
