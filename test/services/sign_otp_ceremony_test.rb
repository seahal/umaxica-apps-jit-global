# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyTest < ActiveSupport::TestCase
  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
    test "#{surface} #{channel} signup failure budget survives another candidate flow and browser" do
      destination =
        (channel == :email) ? "budget-#{SecureRandom.hex(8)}@example.test" :
               "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      flows =
        2.times.map do |index|
          owner = owner_class.create!(
            status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
          )
          contact = contact_class.create!(
            owner_key => owner.id, :confirm_policy => "1",
            ((channel == :email) ? :address : :number) => destination,
          )
          private_key = ROTP::Base32.random_base32
          contact.store_otp(private_key, 1, (contact_class.database_now + 10.minutes).to_i)
          now = flow_class.database_now
          flow = flow_class.create!(
            principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
            nonce_digest: flow_class.digest_nonce("budget-browser-#{index}"), issued_at: now,
            expires_at: now + 15.minutes, entry_method: channel.to_s,
            pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          code = ROTP::HOTP.new(private_key).at(1).to_s
          recorded = SignUpOtpChallengeRecorder.call(flow: flow, record: contact, channel: channel, code: code)

          assert recorded
          [flow, contact, code]
        end
      first_flow, first_contact, first_code = flows.first
      wrong_code = first_code.end_with?("0") ? first_code.sub(/0\z/, "1") : first_code.sub(/.\z/, "0")
      original_contact = first_contact.reload.attributes
      original_flow = first_flow.reload.attributes
      # This is the external connection boundary, not a mocked OTP comparison or ceremony outcome.
      Umaxica::Valkey::Connection.stub(:new, ->(**) { raise Umaxica::Valkey::Unavailable, "dependency unavailable" }) do
        [first_code, wrong_code].each do |submitted|
          assert_raises(Umaxica::Valkey::Unavailable) do
            SignOtpCeremony.verify!(
              purpose: :sign_up, surface: surface, channel: channel, subject: first_flow,
              destination: destination, code: submitted, session_nonce: first_flow.public_id,
            )
          end

          assert_equal original_contact, first_contact.reload.attributes
          assert_equal original_flow, first_flow.reload.attributes
        end
      end
      5.times do
        result = SignOtpCeremony.verify!(
          purpose: :sign_up, surface: surface, channel: channel, subject: first_flow,
          destination: destination, code: wrong_code, session_nonce: first_flow.public_id,
        )

        assert_not result.success?
      end
      assert_predicate first_contact.reload, :locked?
      replacement_flow, replacement_contact, replacement_code = flows.last
      retained_otp = replacement_contact.reload.get_otp
      result = SignOtpCeremony.verify!(
        purpose: :sign_up, surface: surface, channel: channel, subject: replacement_flow,
        destination: destination, code: replacement_code, session_nonce: replacement_flow.public_id,
      )

      assert_not result.success?
      assert_equal :locked, result.status
      assert_equal retained_otp, replacement_contact.reload.get_otp
      assert_not replacement_contact.binding_effective?
    end
  end

  test "released signup Contact bindings cannot consume retained OTP in either channel or realm" do
    [
      [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
      [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
      [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
      [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
    ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
      owner = owner_class.create!(
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      contact = contact_class.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) =>
          ((channel == :email) ? "released-signup@example.test" : "+819012345675"),
      )
      contact.finalize_binding!
      contact.release_binding!
      now = flow_class.database_now
      flow = flow_class.create!(
        principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
        nonce_digest: flow_class.digest_nonce("released-contact-signup"), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      private_key = ROTP::Base32.random_base32
      contact.store_otp(private_key, 1, (contact_class.database_now + 10.minutes).to_i)
      retained_otp = contact.reload.get_otp
      code = ROTP::HOTP.new(private_key).at(1).to_s
      result = SignOtpCeremony.verify!(
        purpose: :sign_up, surface: surface, channel: channel, subject: flow,
        code: code, session_nonce: flow.public_id,
      )

      assert_not result.success?
      assert_equal :inactive_candidate, result.status
      assert_equal retained_otp, contact.reload.get_otp
      assert_predicate contact, :binding_released?
      issued = SignOtpCeremony.issue!(
        purpose: :sign_up, surface: surface, channel: channel, subject: flow, session_nonce: flow.public_id,
      )

      assert_not issued.success?
      assert_equal :inactive_candidate, issued.status
      assert_equal retained_otp, contact.reload.get_otp
    end
  end

  test "signup OTP refuses another Identity's candidate in both channels and realms without consuming its proof" do
    [
      [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
      [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
      [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
      [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
    ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
      owner = owner_class.create!(
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      foreign = owner_class.create!
      contact = contact_class.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) =>
          ((channel == :email) ? "wrong-owner@example.test" : "+819012345676"),
      )
      now = flow_class.database_now
      flow = flow_class.create!(
        principal_id: foreign.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
        nonce_digest: flow_class.digest_nonce("wrong-owner-signup"), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      private_key = ROTP::Base32.random_base32
      contact.store_otp(private_key, 1, (contact_class.database_now + 10.minutes).to_i)
      retained_otp = contact.reload.get_otp
      code = ROTP::HOTP.new(private_key).at(1).to_s
      assert_raises(ArgumentError) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: surface, channel: channel, subject: flow, session_nonce: flow.public_id,
        )
      end
      assert_raises(ArgumentError) do
        SignOtpCeremony.verify!(
          purpose: :sign_up, surface: surface, channel: channel, subject: flow,
          code: code, session_nonce: flow.public_id,
        )
      end
      assert_equal retained_otp, contact.reload.get_otp
      assert_equal 0, contact.otp_attempts_count
      assert_not_predicate flow.reload, :sign_up_terminal?
    end
  end

  test "terminal or expired signup cannot issue or consume an OTP in either email realm" do
    [
      [ClientEmail, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, :user, clients(:one), ClientSignUpFlow],
      [VisitorEmail, VisitorEmailStatus::UNVERIFIED, :visitor, Visitor.create!, VisitorSignUpFlow],
    ].each do |email_class, status, owner_key, actor, flow_class|
      [:cancelled, :expired].each do |condition|
        status_key = (email_class == ClientEmail) ? :user_email_status_id : :visitor_email_status_id
        email = email_class.create!(
          owner_key => actor, :address => "terminal-#{condition}-#{SecureRandom.hex(6)}@example.test",
          :confirm_policy => "1", status_key => status,
        )
        decision_time = flow_class.database_now
        flow = flow_class.create!(
          principal_id: actor.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
          nonce_digest: flow_class.digest_nonce("terminal-signup-nonce"),
          issued_at: decision_time - 1.hour, expires_at: decision_time + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        private_key = ROTP::Base32.random_base32
        email.store_otp(private_key, 1, (email_class.database_now + 10.minutes).to_i)
        code = ROTP::HOTP.new(private_key).at(1).to_s
        if condition == :cancelled
          flow.cancel_sign_up!
        else
          flow.update!(expires_at: decision_time - Rational(1, 1_000_000))
        end
        retained_otp = email.reload.get_otp
        surface = (email_class == ClientEmail) ? :app : :com
        issued = SignOtpCeremony.issue!(
          purpose: :sign_up, surface: surface, channel: :email, subject: flow,
          destination: email.address, session_nonce: flow.public_id,
        )
        verified = SignOtpCeremony.verify!(
          purpose: :sign_up, surface: surface, channel: :email, subject: flow,
          destination: email.address, code: code, session_nonce: flow.public_id,
        )

        assert_equal [false, :inactive_flow, false, :inactive_flow],
                     [issued.success?, issued.status, verified.success?, verified.status]
        assert_equal retained_otp, email.reload.get_otp
      end
    end
  end

  test "authentication and confirmation OTPs share one finite lifetime bound" do
    assert_equal 10.minutes, CommonOtpPolicy::MAX_OOB_TTL
    assert_equal CommonOtpPolicy::MAX_OOB_TTL, CommonOtpPolicy::AUTHENTICATION_TTL
    assert_equal CommonOtpPolicy::MAX_OOB_TTL, CommonOtpPolicy::SIGN_UP_CONFIRMATION_TTL
  end

  test "rejects an app email sign-up ticket with no bound contact record" do
    flow = ClientSignUpFlow.create!(
      principal_id: Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP).id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: nil,
    )
    result = SignOtpCeremony.issue!(
      purpose: :sign_up,
      surface: :app,
      channel: :email,
      subject: flow,
      session_nonce: flow.public_id,
    )

    assert_not result.success?
    assert_equal :missing_destination, result.status
    assert_nil result.record
  end

  test "binds an issued OTP to the ticket email destination and consumes it once" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    delivery = nil
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**arguments| delivery = arguments }

    OtpAdapter.stub(:for, adapter) do
      mismatch = SignOtpCeremony.issue!(
        purpose: :sign_up,
        surface: :app,
        channel: :email,
        subject: flow,
        destination: "other-address@example.test",
        session_nonce: flow.public_id,
      )

      assert_not mismatch.success?
      assert_equal :destination_mismatch, mismatch.status

      issued = SignOtpCeremony.issue!(
        purpose: :sign_up,
        surface: :app,
        channel: :email,
        subject: flow,
        destination: email.address,
        session_nonce: flow.public_id,
      )

      assert_predicate issued, :success?
      assert_equal :issued, issued.status
      assert_equal email, delivery.fetch(:record)
      assert_equal issued.code, delivery.fetch(:otp_code)

      verified = SignOtpCeremony.verify!(
        purpose: :sign_up,
        surface: :app,
        channel: :email,
        subject: flow,
        destination: email.address,
        code: issued.code,
        session_nonce: flow.public_id,
      )

      assert_predicate verified, :success?
      assert_equal :verified, verified.status
      assert_nil email.reload.get_otp
    end
  end

  test "verify! refuses a code aimed at a destination the ticket is not bound to" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-mismatch@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    assert_predicate issued, :success?

    result = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: "someone-else@example.test", code: issued.code,
      session_nonce: flow.public_id,
    )

    assert_not result.success?
    assert_equal :destination_mismatch, result.status
    assert_not_nil email.reload.get_otp,
                   "#{email.address}: mismatched destination must not consume the bound OTP"
  end

  test "verify! treats malformed code lengths as invalid input" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-malformed@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    assert_predicate issued, :success?

    result = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: email.address, code: "12345",
      session_nonce: flow.public_id,
    )

    assert_not result.success?
    assert_equal :invalid_code, result.status
    assert_not_nil email.reload.get_otp
  end

  test "issuing a new sign-up OTP does not reset failed attempts" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-attempts@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    first =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    invalid_code = (first.code == "000000") ? "000001" : "000000"
    failed = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: email.address, code: invalid_code, session_nonce: flow.public_id,
    )

    assert_equal :invalid_code, failed.status
    assert_equal 1, email.reload.otp_attempts_count

    email.update!(otp_last_sent_at: CommonOtpPolicy::SEND_COOLDOWN.ago - 1.second)
    reissued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    assert_predicate reissued, :success?
    assert_equal 1, email.reload.otp_attempts_count

    verified = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: email.address, code: reissued.code, session_nonce: flow.public_id,
    )

    assert_predicate verified, :success?
    assert_equal 0, email.reload.otp_attempts_count
  end

  test "does not verify or consume a code under a different sign-up session nonce" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-session-binding@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    result = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: email.address, code: issued.code, session_nonce: "another-flow",
    )

    assert_not result.success?
    assert_equal :session_mismatch, result.status
    assert_not_nil email.reload.get_otp
  end

  test "issue! refuses a channel the sign-up ticket is not waiting on" do
    flow = ClientSignUpFlow.create!(
      principal_id: Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP).id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: nil,
    )

    error =
      assert_raises(ArgumentError) do
        SignOtpCeremony.issue!(purpose: :sign_up, surface: :app, channel: :telephone, subject: flow)
      end

    assert_equal "OTP channel does not match sign-up ticket", error.message
  end

  test "issue! refuses persisted resend cooldown without replacing OTP or delivering" do
    delivery_attempted = false
    record = ClientEmail.create!(
      user: Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP),
      address: "signup-cooldown@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: record.user_id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("signup-cooldown-nonce"),
      issued_at: ClientSignUpFlow.database_now, expires_at: 15.minutes.from_now,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: record.id,
    )
    record.store_otp(ROTP::Base32.random_base32, 1, (ClientEmail.database_now + 10.minutes).to_i)
    retained_otp = record.reload.get_otp
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| delivery_attempted = true }
    OtpAdapter.stub(:for, adapter) do
      result = SignOtpCeremony.issue!(
        purpose: :sign_up, surface: :app, channel: :email, subject: flow,
        destination: record.address, session_nonce: flow.public_id,
      )

      assert_not result.success?
      assert_equal :rate_limited, result.status
    end
    assert_equal retained_otp, record.reload.get_otp
    assert_not delivery_attempted
  end

  test "sign-up OTP expiry stays within the ten-minute confirmation bound" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-expiry@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
          session_nonce: flow.public_id,
        )
      end

    assert_predicate issued, :success?
    assert_operator email.reload.otp_counter.to_i, :<, 1 << 64
    assert_operator email.reload.otp_expires_at, :<=, 10.minutes.from_now + 1.second
  end

  test "sign-up OTP remains valid immediately before its ten-minute expiry" do
    issue_time = Time.zone.local(2026, 9, 22, 12, 0, 0)
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-expiry-before@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      ClientEmail.stub(:database_now, issue_time) do
        OtpAdapter.stub(:for, adapter) do
          SignOtpCeremony.issue!(
            purpose: :sign_up, surface: :app, channel: :email, subject: flow,
            destination: email.address, session_nonce: flow.public_id,
          )
        end
      end

    result =
      ClientEmail.stub(
        :database_now,
        issue_time + CommonOtpPolicy::SIGN_UP_CONFIRMATION_TTL - 1.second,
      ) do
        SignOtpCeremony.verify!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow,
          destination: email.address, code: issued.code, session_nonce: flow.public_id,
        )
      end

    assert_predicate result, :success?
    assert_equal :verified, result.status
  end

  test "sign-up OTP is rejected at its ten-minute expiry boundary" do
    issue_time = Time.zone.local(2026, 9, 22, 12, 0, 0)
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-expiry-boundary@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      ClientEmail.stub(:database_now, issue_time) do
        OtpAdapter.stub(:for, adapter) do
          SignOtpCeremony.issue!(
            purpose: :sign_up, surface: :app, channel: :email, subject: flow,
            destination: email.address, session_nonce: flow.public_id,
          )
        end
      end

    result =
      ClientEmail.stub(
        :database_now,
        issue_time + CommonOtpPolicy::SIGN_UP_CONFIRMATION_TTL,
      ) do
        SignOtpCeremony.verify!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow,
          destination: email.address, code: issued.code, session_nonce: flow.public_id,
        )
      end

    assert_not result.success?
    assert_equal :missing_otp, result.status
  end

  test "issue uses one writer database clock for OTP expiry and sent timestamp" do
    owner = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: owner, address: "sign-otp-database-clock@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    flow = ClientSignUpFlow.create!(
      principal_id: email.user_id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(32)),
      issued_at: ClientSignUpFlow.database_now, expires_at: ClientSignUpFlow.database_now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    database_now = 1.second.from_now
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        ClientEmail.stub(:database_now, database_now) do
          SignOtpCeremony.issue!(
            purpose: :sign_up, surface: :app, channel: :email, subject: flow,
            destination: email.address, session_nonce: flow.public_id,
          )
        end
      end

    assert_predicate issued, :success?
    email.reload

    assert_equal database_now.to_i, email.otp_last_sent_at.to_i
    assert_equal (database_now + SignOtpCeremony::OTP_EXPIRATION).to_i, email.otp_expires_at.to_i
  end
end
