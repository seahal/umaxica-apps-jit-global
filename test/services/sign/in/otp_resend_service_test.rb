# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module In
    class OtpResendServiceTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      # SMS OTP is not an accepted sign-in proof. Neither a telephone resend
      # state nor a telephone resender may exist, so no SMS can be sent here.
      test "telephone resend state cannot be minted" do
        telephone = ClientTelephone.create!(
          user: clients(:one),
          raw_number: "+819012399991",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        )

        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          assert_raises(ArgumentError) do
            SignInOtpResendState.issue(kind: :telephone, target: telephone.number, surface: :app)
          end
        end
      end

      test "telephone resender cannot be constructed" do
        state = SignInOtpResendState.issue(
          kind: :email, target: "resend-guard@example.com", surface: :app,
        )

        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          assert_raises(ArgumentError) do
            SignInOtpResender.new(kind: :telephone, state: state, surface: :app)
          end
        end
      end

      test "parse returns nil for blank token" do
        assert_nil SignInOtpResendState.parse("")
        assert_nil SignInOtpResendState.parse(nil)
      end

      test "parse returns nil for invalid token signature" do
        assert_nil SignInOtpResendState.parse("invalid-token-signature")
      end

      test "resend rejects an invalid state without enqueuing a delivery" do
        result = nil

        assert_no_enqueued_jobs do
          result = SignInOtpResender.new(
            kind: :email, state: "invalid-token-signature", surface: :app,
          ).call
        end

        assert_equal :bad_request, result.status
        assert_not result.resendable
        assert_equal SignInOtpResender::INVALID_RETRY_AFTER, result.retry_after
      end

      test "unknown email resend records a rate-limit event without revealing account existence" do
        state = SignInOtpResendState.issue(
          kind: :email, target: "unknown-resend@example.test", surface: :app,
        )
        result = nil

        assert_difference("EmailOccurrence.count", 1) do
          assert_no_enqueued_jobs do
            result = SignInOtpResender.new(kind: :email, state: state, surface: :app).call
          end
        end

        assert_equal :ok, result.status
        assert_predicate result, :resendable
        assert_equal 0, result.retry_after
        assert_match "purpose=in", EmailOccurrence.order(:id).last.memo
      end

      test "known email resend refreshes its OTP and delivers it through the email adapter" do
        email = ClientEmail.create!(
          user: clients(:one),
          address: "known-resend@example.test",
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        state = SignInOtpResendState.issue(kind: :email, target: email.address, surface: :app)
        delivery = nil
        adapter = Object.new
        adapter.define_singleton_method(:deliver) { |**arguments| delivery = arguments }

        requested_surface = nil
        adapter_factory =
          lambda do |surface:, channel:|
            requested_surface = surface

            assert_equal :email, channel
            adapter
          end

        OtpAdapter.stub(:for, adapter_factory) do
          result = SignInOtpResender.new(kind: :email, state: state, surface: :app).call

          assert_equal :ok, result.status
          assert_predicate result, :resendable
        end

        assert_equal email, delivery.fetch(:record)
        assert_predicate delivery.fetch(:otp_code), :present?
        assert_equal :app, requested_surface
        assert_equal :sign_in, delivery.fetch(:purpose)
        assert_predicate email.reload.get_otp, :present?
      end

      test "a failed delivery still consumes the resend slot" do
        address = "failed-resend-#{SecureRandom.hex(4)}@example.test"
        ClientEmail.create!(
          user: clients(:one),
          address: address,
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        state = SignInOtpResendState.issue(kind: :email, target: address, surface: :app)
        adapter = Object.new
        delivery_attempts = 0
        adapter.define_singleton_method(:deliver) do |**|
          delivery_attempts += 1
          raise IOError, "provider unavailable"
        end

        adapter_factory =
          lambda do |surface:, channel:|
            assert_equal :app, surface
            assert_equal :email, channel
            adapter
          end

        OtpAdapter.stub(:for, adapter_factory) do
          result = SignInOtpResender.new(kind: :email, state: state, surface: :app).call

          assert_equal :bad_request, result.status
          assert_not result.resendable

          blocked = SignInOtpResender.new(kind: :email, state: state, surface: :app).call

          assert_equal :too_many_requests, blocked.status
          assert_not blocked.resendable
        end

        occurrence = EmailOccurrence.find_by!(body: OccurrenceHmac.digest(kind: "email", body: address.downcase))

        assert_match(/purpose=in issued=/, occurrence.memo)
        assert_equal 1, delivery_attempts
      end

      test "corporate resend selects the visitor email and corporate adapter" do
        VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
        address = "corporate-resend-#{SecureRandom.hex(4)}@example.test"
        email = VisitorEmail.create!(
          visitor: visitors(:reserved_visitor),
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
        )
        state = SignInOtpResendState.issue(kind: :email, target: email.address, surface: :com)
        delivery = nil
        requested_surface = nil
        adapter = Object.new
        adapter.define_singleton_method(:deliver) { |**arguments| delivery = arguments }

        OtpAdapter.stub(
          :for,
          lambda do |surface:, channel:|
            requested_surface = surface

            assert_equal :email, channel
            adapter
          end,
        ) do
          result = SignInOtpResender.new(kind: :email, state: state, surface: :com).call

          assert_equal :ok, result.status
        end

        assert_equal :com, requested_surface
        assert_equal email, delivery.fetch(:record)
        assert_equal :sign_in, delivery.fetch(:purpose)
      end

      test "a resend state is bound to its surface" do
        state = SignInOtpResendState.issue(
          kind: :email, target: "surface-bound@example.test", surface: :app,
        )

        result = SignInOtpResender.new(kind: :email, state: state, surface: :com).call

        assert_equal :bad_request, result.status
        assert_not result.resendable
      end
    end
  end
end
