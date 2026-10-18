# frozen_string_literal: true

require "test_helper"

class EmailReentryOtpDeliveryTest < ActiveJob::TestCase
  %w(app com org).each do |surface|
    test "#{surface} email worker refuses foreign actor destination generation realm and consumed proof" do
      email_model, transaction_model, owner_key, owner =
        case surface
        when "app" then [ClientEmail, ClientEmailCeremonyTransaction, :user_id, clients(:one)]
        when "com" then [VisitorEmail, VisitorEmailCeremonyTransaction, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorEmail, OperatorEmailCeremonyTransaction, :staff_id, operators(:one)]
        end
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "ceremony-binding-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )
      transaction = transaction_model.create_transaction!(
        actor_ref: owner.public_id, session_ref: SecureRandom.uuid, operation: "withdrawal",
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      code = transaction.issue_email_otp!(purpose: "withdrawal")
      payload = {
        surface: surface,
        purpose: "withdrawal",
        transaction_ref: transaction.transaction_id,
        generation: transaction.otp_generation,
        encrypted_code: OutboundSensitivePayload.encrypt_email_otp(code),
      }

      assert_no_difference "ActionMailer::Base.deliveries.size" do
        transaction.update!(actor_ref: "foreign-owner")
        begin
          fv5098 = { email: email, **payload }
          fv5092 = fv5098.fetch(:email)
          fv5097 = fv5098.fetch(:surface)
          fv5093 = fv5098.fetch(:purpose)
          fv5091 = fv5098.fetch(:transaction_ref)
          fv5090 = fv5098.fetch(:generation)
          fv5096 = fv5098.fetch(:encrypted_code)
          fv5095 =
            case fv5097
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5094 = OutboundSensitivePayload.decrypt_email_otp(fv5096)
          fv5095.issue(
            record: fv5092,
            otp_code: fv5094,
            purpose: fv5093,
            public_id: fv5092.public_id,
            email_ceremony_transaction_ref: fv5091,
            email_otp_generation: fv5090,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
        transaction.update!(actor_ref: owner.public_id, normalized_email_digest: SecureRandom.hex(32))
        begin
          fv5089 = { email: email, **payload }
          fv5083 = fv5089.fetch(:email)
          fv5088 = fv5089.fetch(:surface)
          fv5084 = fv5089.fetch(:purpose)
          fv5082 = fv5089.fetch(:transaction_ref)
          fv5081 = fv5089.fetch(:generation)
          fv5087 = fv5089.fetch(:encrypted_code)
          fv5086 =
            case fv5088
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5085 = OutboundSensitivePayload.decrypt_email_otp(fv5087)
          fv5086.issue(
            record: fv5083,
            otp_code: fv5085,
            purpose: fv5084,
            public_id: fv5083.public_id,
            email_ceremony_transaction_ref: fv5082,
            email_otp_generation: fv5081,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
        transaction.update!(normalized_email_digest: email.address_digest)

        [nil, "", 0].each do |generation|
          assert_raises(ArgumentError) {
            begin
              fv5080 = { email: email, **payload.merge(generation: generation) }
              fv5074 = fv5080.fetch(:email)
              fv5079 = fv5080.fetch(:surface)
              fv5075 = fv5080.fetch(:purpose)
              fv5073 = fv5080.fetch(:transaction_ref)
              fv5072 = fv5080.fetch(:generation)
              fv5078 = fv5080.fetch(:encrypted_code)
              fv5077 =
                case fv5079
                when "app" then Notify::App::OtpNotifier
                when "com" then Notify::Com::OtpNotifier
                when "org" then Notify::Org::OtpNotifier
                else raise ArgumentError, "unsupported test delivery surface"
                end
              fv5076 = OutboundSensitivePayload.decrypt_email_otp(fv5078)
              fv5077.issue(
                record: fv5074,
                otp_code: fv5076,
                purpose: fv5075,
                public_id: fv5074.public_id,
                email_ceremony_transaction_ref: fv5073,
                email_otp_generation: fv5072,
              )
              perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
            end
          }
        end
        begin
          fv5071 = { email: email, **payload.merge(generation: SecureRandom.uuid) }
          fv5065 = fv5071.fetch(:email)
          fv5070 = fv5071.fetch(:surface)
          fv5066 = fv5071.fetch(:purpose)
          fv5064 = fv5071.fetch(:transaction_ref)
          fv5063 = fv5071.fetch(:generation)
          fv5069 = fv5071.fetch(:encrypted_code)
          fv5068 =
            case fv5070
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5067 = OutboundSensitivePayload.decrypt_email_otp(fv5069)
          fv5068.issue(
            record: fv5065,
            otp_code: fv5067,
            purpose: fv5066,
            public_id: fv5065.public_id,
            email_ceremony_transaction_ref: fv5064,
            email_otp_generation: fv5063,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
        foreign_surface = (surface == "app") ? "com" : "app"
        begin
          fv5062 = { email: email, **payload.merge(surface: foreign_surface) }
          fv5056 = fv5062.fetch(:email)
          fv5061 = fv5062.fetch(:surface)
          fv5057 = fv5062.fetch(:purpose)
          fv5055 = fv5062.fetch(:transaction_ref)
          fv5054 = fv5062.fetch(:generation)
          fv5060 = fv5062.fetch(:encrypted_code)
          fv5059 =
            case fv5061
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5058 = OutboundSensitivePayload.decrypt_email_otp(fv5060)
          fv5059.issue(
            record: fv5056,
            otp_code: fv5058,
            purpose: fv5057,
            public_id: fv5056.public_id,
            email_ceremony_transaction_ref: fv5055,
            email_otp_generation: fv5054,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
      end
      assert transaction.verify_email_otp!(
        code: code, purpose: "withdrawal", actor_ref: owner.public_id,
        session_ref: transaction.session_ref, operation: "withdrawal", candidate_ref: email.public_id,
      )
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        begin
          fv5053 = { email: email, **payload }
          fv5047 = fv5053.fetch(:email)
          fv5052 = fv5053.fetch(:surface)
          fv5048 = fv5053.fetch(:purpose)
          fv5046 = fv5053.fetch(:transaction_ref)
          fv5045 = fv5053.fetch(:generation)
          fv5051 = fv5053.fetch(:encrypted_code)
          fv5050 =
            case fv5052
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5049 = OutboundSensitivePayload.decrypt_email_otp(fv5051)
          fv5050.issue(
            record: fv5047,
            otp_code: fv5049,
            purpose: fv5048,
            public_id: fv5047.public_id,
            email_ceremony_transaction_ref: fv5046,
            email_otp_generation: fv5045,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
      end
    end

    test "#{surface} email worker delivers encrypted current generation but refuses reissue cancellation and expiry" do
      email_model, transaction_model, owner_key, owner =
        case surface
        when "app" then [ClientEmail, ClientEmailCeremonyTransaction, :user_id, clients(:one)]
        when "com" then [VisitorEmail, VisitorEmailCeremonyTransaction, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorEmail, OperatorEmailCeremonyTransaction, :staff_id, operators(:one)]
        end
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "ceremony-delivery-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )
      transaction = transaction_model.create_transaction!(
        actor_ref: owner.public_id, session_ref: SecureRandom.uuid, operation: "recovery",
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      code = transaction.issue_email_otp!(purpose: "recovery")
      payload = {
        surface: surface,
        purpose: "recovery",
        transaction_ref: transaction.transaction_id,
        generation: transaction.otp_generation,
        encrypted_code: OutboundSensitivePayload.encrypt_email_otp(code),
      }

      assert_not OtpNotifierEmailDeliveryJob.log_arguments
      assert_not payload[:encrypted_code].include?(code)
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        begin
          fv5044 = { email: email, **payload }
          fv5038 = fv5044.fetch(:email)
          fv5043 = fv5044.fetch(:surface)
          fv5039 = fv5044.fetch(:purpose)
          fv5037 = fv5044.fetch(:transaction_ref)
          fv5036 = fv5044.fetch(:generation)
          fv5042 = fv5044.fetch(:encrypted_code)
          fv5041 =
            case fv5043
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5040 = OutboundSensitivePayload.decrypt_email_otp(fv5042)
          fv5041.issue(
            record: fv5038,
            otp_code: fv5040,
            purpose: fv5039,
            public_id: fv5038.public_id,
            email_ceremony_transaction_ref: fv5037,
            email_otp_generation: fv5036,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
      end
      assert_equal [email.address], ActionMailer::Base.deliveries.last.to
      assert_nil transaction.reload.otp_consumed_at
      transaction.issue_email_otp!(purpose: "recovery")
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        begin
          fv5035 = { email: email, **payload }
          fv5029 = fv5035.fetch(:email)
          fv5034 = fv5035.fetch(:surface)
          fv5030 = fv5035.fetch(:purpose)
          fv5028 = fv5035.fetch(:transaction_ref)
          fv5027 = fv5035.fetch(:generation)
          fv5033 = fv5035.fetch(:encrypted_code)
          fv5032 =
            case fv5034
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5031 = OutboundSensitivePayload.decrypt_email_otp(fv5033)
          fv5032.issue(
            record: fv5029,
            otp_code: fv5031,
            purpose: fv5030,
            public_id: fv5029.public_id,
            email_ceremony_transaction_ref: fv5028,
            email_otp_generation: fv5027,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
      end
      replacement = transaction.issue_email_otp!(purpose: "recovery")
      current_payload = payload.merge(
        generation: transaction.otp_generation, encrypted_code: OutboundSensitivePayload.encrypt_email_otp(replacement),
      )

      transaction_model.stub(:database_now, transaction.otp_expires_at) do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          begin
            fv5026 = { email: email, **current_payload }
            fv5020 = fv5026.fetch(:email)
            fv5025 = fv5026.fetch(:surface)
            fv5021 = fv5026.fetch(:purpose)
            fv5019 = fv5026.fetch(:transaction_ref)
            fv5018 = fv5026.fetch(:generation)
            fv5024 = fv5026.fetch(:encrypted_code)
            fv5023 =
              case fv5025
              when "app" then Notify::App::OtpNotifier
              when "com" then Notify::Com::OtpNotifier
              when "org" then Notify::Org::OtpNotifier
              else raise ArgumentError, "unsupported test delivery surface"
              end
            fv5022 = OutboundSensitivePayload.decrypt_email_otp(fv5024)
            fv5023.issue(
              record: fv5020,
              otp_code: fv5022,
              purpose: fv5021,
              public_id: fv5020.public_id,
              email_ceremony_transaction_ref: fv5019,
              email_otp_generation: fv5018,
            )
            perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
          end
        end
      end
      decision_time = transaction.otp_expires_at - 1.second
      transaction_model.stub(:database_now, -> { decision_time }) do
        ActiveSupport::Notifications.subscribed(
          ->(_event) { decision_time = transaction.otp_expires_at }, "process.action_mailer",
        ) do
          assert_no_difference "ActionMailer::Base.deliveries.size" do
            begin
              fv5017 = { email: email, **current_payload }
              fv5011 = fv5017.fetch(:email)
              fv5016 = fv5017.fetch(:surface)
              fv5012 = fv5017.fetch(:purpose)
              fv5010 = fv5017.fetch(:transaction_ref)
              fv5009 = fv5017.fetch(:generation)
              fv5015 = fv5017.fetch(:encrypted_code)
              fv5014 =
                case fv5016
                when "app" then Notify::App::OtpNotifier
                when "com" then Notify::Com::OtpNotifier
                when "org" then Notify::Org::OtpNotifier
                else raise ArgumentError, "unsupported test delivery surface"
                end
              fv5013 = OutboundSensitivePayload.decrypt_email_otp(fv5015)
              fv5014.issue(
                record: fv5011,
                otp_code: fv5013,
                purpose: fv5012,
                public_id: fv5011.public_id,
                email_ceremony_transaction_ref: fv5010,
                email_otp_generation: fv5009,
              )
              perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
            end
          end
        end
      end
      transaction.cancel_email_otp!
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        begin
          fv5008 = { email: email, **current_payload }
          fv5002 = fv5008.fetch(:email)
          fv5007 = fv5008.fetch(:surface)
          fv5003 = fv5008.fetch(:purpose)
          fv5001 = fv5008.fetch(:transaction_ref)
          fv5000 = fv5008.fetch(:generation)
          fv5006 = fv5008.fetch(:encrypted_code)
          fv5005 =
            case fv5007
            when "app" then Notify::App::OtpNotifier
            when "com" then Notify::Com::OtpNotifier
            when "org" then Notify::Org::OtpNotifier
            else raise ArgumentError, "unsupported test delivery surface"
            end
          fv5004 = OutboundSensitivePayload.decrypt_email_otp(fv5006)
          fv5005.issue(
            record: fv5002,
            otp_code: fv5004,
            purpose: fv5003,
            public_id: fv5002.public_id,
            email_ceremony_transaction_ref: fv5001,
            email_otp_generation: fv5000,
          )
          perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
        end
      end
    end
  end

  private
end
