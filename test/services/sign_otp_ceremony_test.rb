# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyTest < ActiveSupport::TestCase
  test "rejects an app email sign-up ticket with no bound contact record" do
    result = SignOtpCeremony.issue!(
      purpose: :sign_up,
      surface: :app,
      channel: :email,
      subject: create_email_flow,
    )

    assert_not result.success?
    assert_equal :missing_destination, result.status
    assert_nil result.record
  end

  test "binds an issued OTP to the ticket email destination and consumes it once" do
    email = create_verified_client_email("sign-otp@example.test")
    flow = create_email_flow(pending_contact_id: email.id)
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
      )

      assert_not mismatch.success?
      assert_equal :destination_mismatch, mismatch.status

      issued = SignOtpCeremony.issue!(
        purpose: :sign_up,
        surface: :app,
        channel: :email,
        subject: flow,
        destination: email.address,
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
      )

      assert_predicate verified, :success?
      assert_equal :verified, verified.status
      assert_nil email.reload.get_otp
    end
  end

  test "verify! refuses a code aimed at a destination the ticket is not bound to" do
    email = create_verified_client_email("sign-otp-mismatch@example.test")
    flow = create_email_flow(pending_contact_id: email.id)
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
        )
      end

    assert_predicate issued, :success?

    result = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: "someone-else@example.test", code: issued.code,
    )

    assert_not result.success?
    assert_equal :destination_mismatch, result.status
    assert_not_nil email.reload.get_otp,
                   "#{email.address}: mismatched destination must not consume the bound OTP"
  end

  test "verify! treats malformed code lengths as invalid input" do
    email = create_verified_client_email("sign-otp-malformed@example.test")
    flow = create_email_flow(pending_contact_id: email.id)
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| nil }

    issued =
      OtpAdapter.stub(:for, adapter) do
        SignOtpCeremony.issue!(
          purpose: :sign_up, surface: :app, channel: :email, subject: flow, destination: email.address,
        )
      end

    assert_predicate issued, :success?

    result = SignOtpCeremony.verify!(
      purpose: :sign_up, surface: :app, channel: :email, subject: flow,
      destination: email.address, code: "12345",
    )

    assert_not result.success?
    assert_equal :invalid_code, result.status
    assert_not_nil email.reload.get_otp
  end

  test "issue! refuses a channel the sign-up ticket is not waiting on" do
    flow = create_email_flow

    error =
      assert_raises(ArgumentError) do
        SignOtpCeremony.issue!(purpose: :sign_up, surface: :app, channel: :telephone, subject: flow)
      end

    assert_equal "OTP channel does not match sign-up ticket", error.message
  end

  test "issue! rechecks the resend cooldown after acquiring the record lock" do
    cooldown_checks = 0
    delivery_attempted = false
    record = Object.new
    record.define_singleton_method(:locked?) { false }
    record.define_singleton_method(:otp_cooldown_active?) do
      cooldown_checks += 1
      cooldown_checks > 1
    end
    record.define_singleton_method(:with_lock) { |&block| block.call }
    record.define_singleton_method(:store_otp) do |*_arguments|
      raise RuntimeError, "the locked cooldown must refuse issuance before storing an OTP"
    end

    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**| delivery_attempted = true }

    ceremony = SignOtpCeremony.new(
      purpose: :sign_up,
      surface: :app,
      channel: :email,
      subject: Object.new,
      destination: "sign-otp@example.test",
    )
    ceremony.define_singleton_method(:validate_scope!) { nil }
    ceremony.define_singleton_method(:bound_record) { record }
    ceremony.define_singleton_method(:destination_matches?) { |_| true }

    OtpAdapter.stub(:for, adapter) do
      result = ceremony.issue!

      assert_not result.success?
      assert_equal :rate_limited, result.status
    end

    assert_equal 2, cooldown_checks
    assert_not delivery_attempted
  end

  private

  def create_email_flow(pending_contact_id: nil)
    ClientSignUpFlow.create!(
      principal_id: 123,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-nonce-#{SecureRandom.hex(4)}"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
      pending_contact_type: "email",
      pending_contact_id: pending_contact_id,
    )
  end

  def create_verified_client_email(address)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientEmail.create!(
      user: clients(:one),
      address: address,
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end
end
