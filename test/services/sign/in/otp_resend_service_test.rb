# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Boolean snapshot comparisons keep identifier attributes out of failure output.
module Sign
  module In
    class OtpResendServiceTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      skip_transactional_tests_for_database :op_base_app
      skip_transactional_tests_for_database :occurrence

      setup do
        @ceremonies = {}
        @occurrence_body = nil
        %i(app).each do |surface|
          admission = OidcTestEntry.issue!(
            surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
          )
          @admission = admission
          model = ClientAuthCeremonySession
          @ceremonies[surface] = model.rotate_and_admit!(
            admission_purpose: "authentication_handoff",
            authorization_transaction_ref: admission.transaction.transaction_id,
          ).first
        end
      end

      teardown do
        EmailOccurrence.where(body: @occurrence_body).delete_all if @occurrence_body
        if @admission
          ClientAuthAdmissionBinding.where(authorization_transaction_id: @admission.transaction.id).delete_all
          @ceremonies.each_value(&:delete)
          @admission.transaction.delete
        end
      end

      [[:app, Client, ClientEmail, :user_id]].each do |surface, owner_class, model, owner_key|
        test "#{surface} resend preserves independent candidates and delivers only to the effective owner" do
          address = "resend-candidates-#{SecureRandom.hex(8)}@example.test"
          candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

          assert_not EmailOccurrence.exists?(body: candidate_body)
          @occurrence_body = candidate_body
          candidates =
            2.times.map do
              owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
              contact = model.create!(owner_key => owner.id, :address => address, :confirm_policy => "1")
              contact
            end
          snapshots = candidates.map { |contact| contact.reload.attributes }
          owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
          effective = model.create!(owner_key => owner.id, :address => address, :confirm_policy => "1")
          effective.finalize_binding!
          ceremony = @ceremonies.fetch(surface)
          ceremony.issue_email_otp!(contact: effective, destination: address)
          generation = ceremony.reload.email_otp_context.fetch("generation")
          source_generation = effective.reload.attributes
          state = SignInOtpResendState.issue(
            kind: :email, target: address, surface: surface,
            browser_binding: ceremony.sid_digest, contact: effective,
          )
          delivered = []
          adapter = Minitest::Mock.new
          adapter.expect(:deliver, nil) { |**arguments|
            delivered << arguments.fetch(:record).id
            true
          }
          OtpAdapter.stub(:for, adapter) do
            result = SignInOtpResender.new(
              kind: :email, state: state, surface:, browser_binding: ceremony.sid_digest,
              ceremony:,
            ).call

            assert_equal :ok, result.status
          end

          assert_equal [effective.id], delivered
          assert_withheld { snapshots == candidates.map { |contact| contact.reload.attributes } }
          assert_withheld { source_generation == effective.reload.attributes.slice(*source_generation.keys) }
          assert_not_equal generation, ceremony.reload.email_otp_context.fetch("generation")
          adapter.verify
        end
      end

      %i(app).each do |surface|
        { before_expiry: -1.second, at_expiry: 0.seconds, after_expiry: 1.second }.each do |label, offset|
          test "#{surface} resend state #{label} honors its absolute deadline" do
            freeze_time do
              binding = @ceremonies.fetch(surface).sid_digest
              state = SignInOtpResendState.issue(
                kind: :email, target: "resend-expiry@example.test", surface: surface,
                browser_binding: binding, contact: nil,
              )
              issued_at = Time.current
              travel_to issued_at + SignInOtpResendState::TTL + offset
              parsed = SignInOtpResendState.parse(state, browser_binding: binding)

              if label == :before_expiry
                assert_not_nil parsed
                assert_equal surface.to_s, parsed.fetch(:surface)
                assert_equal "fake", parsed.fetch(:contact_mode)
              else
                assert_nil parsed
              end
            end
          end
        end
      end

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
            SignInOtpResendState.issue(
              kind: :telephone, target: telephone.number, surface: :app,
              browser_binding: "b" * 64, contact: nil,
            )
          end
        end
      end

      test "telephone resender cannot be constructed" do
        state = SignInOtpResendState.issue(
          kind: :email, target: "resend-guard@example.com", surface: :app, browser_binding: "b" * 64, contact: nil,
        )

        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          error =
            assert_raises(ArgumentError) do
              SignInOtpResender.new(
                kind: :telephone, state:, surface: :app,
                browser_binding: @ceremonies.fetch(:app).sid_digest, ceremony: @ceremonies.fetch(:app),
              )
            end
          assert_equal "unsupported sign-in OTP resend kind: telephone", error.message
        end
      end

      test "parse returns nil for blank token" do
        assert_nil SignInOtpResendState.parse("", browser_binding: "b" * 64)
        assert_nil SignInOtpResendState.parse(nil, browser_binding: "b" * 64)
      end

      test "real and dummy resend proof fields have equal encrypted state length for the same destination" do
        address = "length-parity-#{SecureRandom.hex(8)}@example.test"
        owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
        email = owner.client_emails.create!(address: address, confirm_policy: "1").tap(&:finalize_binding!)
        real = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: "b" * 64, contact: email,
        )
        dummy = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: "b" * 64, contact: nil,
        )

        assert_equal real.bytesize, dummy.bytesize
      end

      test "parse returns nil for invalid token signature" do
        assert_nil SignInOtpResendState.parse("invalid-token-signature", browser_binding: "b" * 64)
      end

      test "browser binding requires 64 lowercase hex characters across neighboring lengths and sentinels" do
        state = SignInOtpResendState.issue(
          kind: :email, target: "bound-state@example.test", surface: :app, browser_binding: "b" * 64, contact: nil,
        )

        assert_equal "bound-state@example.test",
                     SignInOtpResendState.parse(state, browser_binding: "b" * 64).fetch(:target)
        assert_nil SignInOtpResendState.parse(state, browser_binding: "c" * 64)
        [nil, "", 0, false, [], "b" * 63, "b" * 65, "B" * 64, "z" * 64].each do |invalid_binding|
          assert_raises(ArgumentError) do
            SignInOtpResendState.issue(
              kind: :email, target: "bound-state@example.test", surface: :app,
              browser_binding: invalid_binding, contact: nil,
            )
          end
          assert_raises(ArgumentError) do
            SignInOtpResendState.parse(state, browser_binding: invalid_binding)
          end
        end
      end

      test "resend rejects an invalid state without enqueuing a delivery" do
        ceremony = @ceremonies.fetch(:app)
        result = nil

        assert_no_enqueued_jobs do
          result = SignInOtpResender.new(
            kind: :email, state: "invalid-token-signature", surface: :app,
            browser_binding: ceremony.sid_digest, ceremony:,
          ).call
        end

        assert_equal :bad_request, result.status
        assert_not result.resendable
        assert_equal SignInOtpResender::INVALID_RETRY_AFTER, result.retry_after
      end

      test "unknown email resend records a rate-limit event without revealing account existence" do
        address = "unknown-resend-#{SecureRandom.hex(8)}@example.test"
        candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

        assert_not EmailOccurrence.exists?(body: candidate_body)
        @occurrence_body = candidate_body
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        state = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app,
          browser_binding: ceremony.sid_digest, contact: nil,
        )
        result = nil

        assert_difference("EmailOccurrence.count", 1) do
          assert_no_enqueued_jobs do
            result = SignInOtpResender.new(
              kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest,
              ceremony:,
            ).call
          end
        end

        assert_equal :ok, result.status
        assert_predicate result, :resendable
        assert_equal 0, result.retry_after
        assert_match "purpose=in", EmailOccurrence.order(:id).last.memo
      end

      test "occurrence write failure after issuance keeps the new challenge and does not enqueue" do
        address = "occurrence-failure-#{SecureRandom.hex(8)}@example.test"
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        generation = ceremony.reload.email_otp_context.fetch("generation")
        state = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
        )
        failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished }
        result = nil

        Rails.error.stub(:report, ->(*, **) { }) do
          EmailOccurrence.stub(:create!, failure) do
            assert_no_enqueued_jobs do
              result = SignInOtpResender.new(
                kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest, ceremony:,
              ).call
            end
          end
        end

        assert_equal :service_unavailable, result.status
        assert_not_equal generation, ceremony.reload.email_otp_context.fetch("generation")
        assert_nil EmailOccurrence.find_by(body: OccurrenceHmac.digest(kind: :email, body: address))
      end

      test "cancelled challenge does not create a resend occurrence" do
        address = "cancelled-occurrence-#{SecureRandom.hex(8)}@example.test"
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        state = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
        )

        assert ceremony.cancel_email_otp_challenge!
        cancelled = ceremony.reload.email_otp_context.deep_dup
        result = SignInOtpResender.new(
          kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest, ceremony:,
        ).call

        assert_equal :bad_request, result.status
        assert_nil EmailOccurrence.find_by(body: OccurrenceHmac.digest(kind: :email, body: address))
        assert_withheld { cancelled == ceremony.reload.email_otp_context }
      end

      [" ", "junk", "purpose=in issued=0", "purpose=in issued=1,", "purpose=in issued=1,0",
       "purpose=in issued=1 invalid",].each do |invalid_memo|
        test "corrupt resend history #{invalid_memo.inspect} cannot reset the cooldown" do
          address = "corrupt-history-#{SecureRandom.hex(8)}@example.test"
          candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

          assert_not EmailOccurrence.exists?(body: candidate_body)
          @occurrence_body = candidate_body
          ceremony = @ceremonies.fetch(:app)
          ceremony.issue_email_otp!(contact: nil, destination: address)
          original = ceremony.reload.email_otp_context.deep_dup
          state = SignInOtpResendState.issue(
            kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
          )
          occurrence = EmailOccurrence.create!(
            body: OccurrenceHmac.digest(kind: :email, body: address), memo: invalid_memo,
          )
          before = occurrence.reload.attributes

          Rails.error.stub(:report, ->(*, **) { }) do
            assert_no_enqueued_jobs do
              assert_raises(SignInOtpResender::InvalidHistory) do
                SignInOtpResender.new(
                  kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest, ceremony:,
                ).call
              end
            end
          end

          assert_withheld { original == ceremony.reload.email_otp_context }
          assert_withheld { before == occurrence.reload.attributes }
        end
      end

      { before: -Rational(1, 1_000_000), at: 0, after: Rational(1, 1_000_000) }.each do |boundary, offset|
        test "locked sign-in resend checks the old OTP deadline #{boundary} expiry" do
          address = "locked-deadline-#{SecureRandom.hex(8)}@example.test"
          ceremony = @ceremonies.fetch(:app)
          ceremony.issue_email_otp!(contact: nil, destination: address)
          previous = ceremony.reload.email_otp_context.deep_dup
          deadline = Time.iso8601(previous.fetch("expires_at"))

          result =
            ClientAuthCeremonySession.stub(:database_now, deadline + offset) do
              ceremony.issue_email_otp!(
                contact: nil, destination: address, expected_generation: previous.fetch("generation"),
              )
            end

          if boundary == :before
            assert_nil result
            assert_not_equal previous.fetch("generation"), ceremony.reload.email_otp_context.fetch("generation")
          else
            assert_same false, result
            assert_withheld { previous == ceremony.reload.email_otp_context }
          end
        end
      end

      test "locked sign-in resend cannot overwrite a replaced generation" do
        address = "locked-generation-#{SecureRandom.hex(8)}@example.test"
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        previous_generation = ceremony.reload.email_otp_context.fetch("generation")
        ceremony.issue_email_otp!(contact: nil, destination: address)
        replacement = ceremony.reload.email_otp_context.deep_dup

        assert_same false, ceremony.issue_email_otp!(
          contact: nil, destination: address, expected_generation: previous_generation,
        )
        assert_withheld { replacement == ceremony.reload.email_otp_context }
      end

      test "locked sign-in resend cannot revive a cancelled real-contact challenge" do
        address = "locked-cancel-#{SecureRandom.hex(8)}@example.test"
        owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
        contact = owner.client_emails.create!(address:, confirm_policy: "1").tap(&:finalize_binding!)
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact:, destination: address)
        generation = ceremony.reload.email_otp_context.fetch("generation")

        assert ceremony.cancel_email_otp_challenge!
        cancelled = ceremony.reload.email_otp_context.deep_dup

        assert_same false, ceremony.issue_email_otp!(contact:, destination: address, expected_generation: generation)
        assert_withheld { cancelled == ceremony.reload.email_otp_context }
      end

      test "a dummy resend state cannot adopt an effective binding created afterward" do
        address = "dummy-before-binding-#{SecureRandom.hex(8)}@example.test"
        candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

        assert_not EmailOccurrence.exists?(body: candidate_body)
        @occurrence_body = candidate_body
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        state = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
        )
        email = ClientEmail.create!(
          user: clients(:one), address: address, confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
        unchanged = email.reload.attributes
        result = nil
        assert_no_enqueued_jobs do
          result = SignInOtpResender.new(
            kind: :email, state: state, surface: :app, browser_binding: ceremony.sid_digest, ceremony:,
          ).call
        end

        assert_equal :ok, result.status
        assert_predicate result, :resendable
        assert_withheld { unchanged == email.reload.attributes }
      end

      test "known email resend refreshes Ticket challenge, preserves identifier state and uses the email adapter" do
        address = "known-resend-#{SecureRandom.hex(8)}@example.test"
        candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

        assert_not EmailOccurrence.exists?(body: candidate_body)
        @occurrence_body = candidate_body
        email = ClientEmail.create!(
          user: clients(:one),
          address: address,
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: email, destination: email.address)
        generation = ceremony.reload.email_otp_context.fetch("generation")
        source_generation = email.reload.attributes
        state = SignInOtpResendState.issue(
          kind: :email, target: email.address, surface: :app,
          browser_binding: ceremony.sid_digest, contact: email,
        )
        delivery = nil
        adapter = Minitest::Mock.new
        adapter.expect(:deliver, nil) { |**arguments|
          delivery = arguments
          true
        }

        requested_surface = nil
        adapter_factory =
          lambda do |surface:, channel:|
            requested_surface = surface

            assert_equal :email, channel
            adapter
          end

        OtpAdapter.stub(:for, adapter_factory) do
          result = SignInOtpResender.new(
            kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest,
            ceremony:,
          ).call

          assert_equal :ok, result.status
          assert_predicate result, :resendable
        end

        assert_equal email, delivery.fetch(:record)
        assert_predicate delivery.fetch(:otp_code), :present?
        assert_equal :app, requested_surface
        assert_equal :sign_in, delivery.fetch(:purpose)
        assert_withheld { source_generation == email.reload.attributes.slice(*source_generation.keys) }
        assert_not_equal generation, ceremony.reload.email_otp_context.fetch("generation")
        adapter.verify
      end

      test "known email resend does not reset failed OTP attempts" do
        address = "known-resend-attempts-#{SecureRandom.hex(8)}@example.test"
        candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

        assert_not EmailOccurrence.exists?(body: candidate_body)
        @occurrence_body = candidate_body
        email = ClientEmail.create!(
          user: clients(:one),
          address: address,
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
        email.increment_attempts!

        assert_equal 1, email.reload.otp_attempts_count

        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: email, destination: email.address)
        source_generation = email.reload.attributes
        state = SignInOtpResendState.issue(
          kind: :email, target: email.address, surface: :app,
          browser_binding: ceremony.sid_digest, contact: email,
        )
        adapter = Minitest::Mock.new
        adapter.expect(:deliver, nil) { |**| true }

        OtpAdapter.stub(:for, adapter) do
          result = SignInOtpResender.new(
            kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest,
            ceremony:,
          ).call

          assert_equal :ok, result.status
        end

        assert_equal 1, email.reload.otp_attempts_count
        assert_withheld { source_generation == email.attributes.slice(*source_generation.keys) }
        adapter.verify
      end

      test "a failed delivery still consumes the resend slot" do
        address = "failed-resend-#{SecureRandom.hex(4)}@example.test"
        candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

        assert_not EmailOccurrence.exists?(body: candidate_body)
        @occurrence_body = candidate_body
        email = ClientEmail.create!(
          user: clients(:one),
          address: address,
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: email, destination: address)
        source_generation = email.reload.attributes
        state = SignInOtpResendState.issue(
          kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest,
          contact: email,
        )
        adapter = Minitest::Mock.new
        delivery_attempts = 0
        adapter.expect(:deliver, nil) do |**|
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
          error =
            assert_raises(IOError) do
              SignInOtpResender.new(
                kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest,
                ceremony:,
              ).call
            end
          assert_equal "provider unavailable", error.message

          blocked = SignInOtpResender.new(
            kind: :email, state:, surface: :app, browser_binding: ceremony.sid_digest,
            ceremony:,
          ).call

          assert_equal :too_many_requests, blocked.status
          assert_not blocked.resendable
        end

        occurrence = EmailOccurrence.find_by!(body: OccurrenceHmac.digest(kind: "email", body: address.downcase))

        assert_match(/purpose=in issued=/, occurrence.memo)
        assert_equal 1, delivery_attempts
        assert_withheld { source_generation == email.reload.attributes.slice(*source_generation.keys) }
      end
    end
  end
end
