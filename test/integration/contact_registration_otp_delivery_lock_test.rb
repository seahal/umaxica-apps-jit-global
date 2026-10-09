# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "minitest/mock"
require "timeout"

# Committed unique fixtures are required for independent PostgreSQL connection visibility.
# Boolean snapshots prevent disclosure of OTP, proof and root facts.
class ContactRegistrationOtpDeliveryLockTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_email_statuses client_telephone_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
    visitor_statuses visitor_visibilities visitor_mfa_levels visitor_mfa_statuses
    visitor_email_statuses visitor_telephone_statuses
    visitor_token_statuses visitor_token_kinds visitor_token_binding_methods visitor_token_dbsc_statuses
  )

  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      test "#{surface} #{channel} delivery holds Source and Ticket locks through transport until release" do
        actor, token, contact, source_base, ticket_base, flow_model =
          case surface
          when :app
            owner = Client.create!(status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
            candidate =
              if channel == :email
                owner.client_emails.create!(
                  raw_address: "locks-#{SecureRandom.hex(8)}@example.test",
                  confirm_policy: "1",
                )
              else
                owner.client_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              end
            [owner, root, candidate, AppZenithRecord, AppTicketRecord,
             (channel == :email) ? ClientEmailCeremonyTransaction : ClientTelephoneCeremonyTransaction,]
          when :com
            owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
            root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
            candidate =
              if channel == :email
                owner.visitor_emails.create!(
                  raw_address: "locks-#{SecureRandom.hex(8)}@example.test",
                  confirm_policy: "1",
                )
              else
                owner.visitor_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              end
            [owner, root, candidate, ComZenithRecord, ComTicketRecord,
             (channel == :email) ? VisitorEmailCeremonyTransaction : VisitorTelephoneCeremonyTransaction,]
          end
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        issued =
          case channel
          when :email
            EmailCredentialRegistrationOtpIssuer.call(actor:, token:, email: contact, browser_nonce: nonce)
          when :telephone
            TelephoneCredentialRegistrationOtpIssuer.call(actor:, token:, telephone: contact, browser_nonce: nonce)
          end

        assert_predicate issued, :success?
        transaction = issued.transaction
        code = issued.code
        generation = transaction.otp_generation
        destination = (channel == :email) ? contact.address : contact.number
        clear_enqueued_jobs
        if channel == :email
          notifier = (surface == :app) ? Notify::App::OtpNotifier : Notify::Com::OtpNotifier
          notifier.issue(
            record: contact, otp_code: code, purpose: "credential_registration", public_id: contact.public_id,
            contact_ceremony_transaction_ref: transaction.transaction_id, contact_otp_generation: generation,
          )
        else
          OtpTelephoneAdapter.new(surface:).deliver(
            record: contact, otp_code: code, purpose: "credential_registration", public_id: contact.public_id,
            contact_ceremony_transaction_ref: transaction.transaction_id, contact_otp_generation: generation,
          )
        end

        assert_equal 1, enqueued_jobs.length
        arguments = enqueued_jobs.first.fetch(:args)

        assert_not arguments.to_s.include?(code), "Delivery queue must not disclose its random code"
        if channel == :email
          params = ActiveJob::Arguments.deserialize(arguments).last.fetch(:params).symbolize_keys
          transported_code = OutboundSensitivePayload.decrypt_email_otp(params.fetch(:encrypted_hotp_token))

          assert_withheld { params.fetch(:contact_ceremony_transaction_ref) == transaction.transaction_id }
          assert_withheld { params.fetch(:contact_otp_generation) == generation }
        else
          payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.first.fetch("encrypted_payload"))
          transported_code = payload.fetch(:otp_code)

          assert_equal 4, payload.fetch(:version)
          assert_withheld {
            payload.fetch(:otp_binding) ==
              [surface.to_s, "credential_registration", transaction.transaction_id, contact.public_id, generation]
          }
        end

        assert_withheld("Transport must retain the actual issued code") { transported_code == code }
        device = token.device_session
        protected_rows = [actor, contact, device, token, transaction]
        facts = protected_rows.map { |row| row.reload.attributes }
        main_source_pid =
          source_base.connection_pool.with_connection { |db|
            db.select_value("SELECT pg_backend_pid()")
          }
        main_ticket_pid =
          ticket_base.connection_pool.with_connection { |db|
            db.select_value("SELECT pg_backend_pid()")
          }
        ready = Queue.new
        release = Queue.new
        holder =
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            source_base.connected_to(role: :writing) do
              source_base.connection_pool.with_connection(prevent_permanent_checkout: true) do |source_db|
                ticket_base.connected_to(role: :writing) do
                  ticket_base.connection_pool.with_connection(prevent_permanent_checkout: true) do |ticket_db|
                    original = flow_model.find(transaction.id)
                    guard =
                      case channel
                      when :email
                        EmailCredentialRegistrationOtpDeliveryGuard.new(
                          transaction: original, email: contact, generation:, destination:, code: transported_code,
                        )
                      when :telephone
                        TelephoneCredentialRegistrationOtpDeliveryGuard.new(
                          transaction: original, telephone: contact, generation:, destination:, code: transported_code,
                        )
                      end
                    guard.call do
                      ready << [source_db.select_value("SELECT pg_backend_pid()"),
                                ticket_db.select_value("SELECT pg_backend_pid()"),]
                      Timeout.timeout(20) { release.pop }
                    end
                  end
                end
              end
            end
          rescue StandardError => e
            ready << e
            raise
          ensure
            # Release model-clock leases before the dedicated worker exits.
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        holding = Timeout.timeout(20) { ready.pop }
        raise holding if holding.is_a?(Exception)

        assert_not_equal main_source_pid, holding.fetch(0)
        assert_not_equal main_ticket_pid, holding.fetch(1)
        protected_rows.each do |row|
          assert_raises(ActiveRecord::LockWaitTimeout) do
            row.class.transaction(requires_new: true) do
              row.class.lock("FOR UPDATE NOWAIT").find(row.id)
              if row.equal?(contact)
                case channel
                when :email then transaction.reissue_email_otp!
                when :telephone then transaction.issue_telephone_otp!(purpose: "credential_registration")
                end
              elsif row.equal?(token)
                token.revoke!
              end
            end
          end
        end

        assert_withheld(
          "While transport is held, competing reissue and revoke lock acquisition must preserve all facts",
        ) {
          facts == protected_rows.map { |row|
            row.reload.attributes
          }
        }
        assert_not holder.complete?, "The external transport barrier must still hold the delivery operation"
        release << true

        delivery_result = Timeout.timeout(20) { holder.value! }

        assert_withheld("Eligible delivery must finish only after the transport barrier is released") {
          delivery_result == true
        }
        protected_rows.each do |row|
          row.class.transaction(requires_new: true) do
            acquired = row.class.lock("FOR UPDATE NOWAIT").find(row.id)

            assert_equal row.id, acquired.id
          end
        end

        assert_withheld("Delivery must not mutate protected facts") {
          facts == protected_rows.map { |row|
            row.reload.attributes
          }
        }
        contact.with_lock do
          case channel
          when :email then transaction.reissue_email_otp!
          when :telephone then transaction.issue_telephone_otp!(purpose: "credential_registration")
          end
        end

        assert_not_equal generation, transaction.reload.otp_generation
        token.revoke!

        assert_predicate token.reload, :revoked?
        delivered_again = false

        stale_guard =
          case channel
          when :email
            EmailCredentialRegistrationOtpDeliveryGuard.new(
              transaction: transaction.reload, email: contact, generation:, destination:, code: transported_code,
            )
          when :telephone
            TelephoneCredentialRegistrationOtpDeliveryGuard.new(
              transaction: transaction.reload, telephone: contact, generation:, destination:, code: transported_code,
            )
          end
        stale_result = stale_guard.call { delivered_again = true }

        assert_withheld("Reissued and revoked evidence must refuse stale delivery") { stale_result == false }
        assert_not delivered_again, "Released locks must not restore stale queued delivery authority"
      ensure
        release << true if release
        holder&.wait(25)
        if contact&.persisted?
          case channel
          when :email then transaction&.reload&.cancel_email_otp!
          when :telephone then transaction&.reload&.cancel_telephone_otp!
          end
          contact.discard_now!(purge_after: 1.day)
        end
        if token&.persisted?
          token.reload.revoke! unless token.revoked?
          token.discard_now!(purge_after: 1.day)
          token.device_session.revoke!
        end
        actor.reload.discard_now!(purge_after: 1.day) if actor&.persisted?
      end
    end
  end
end
