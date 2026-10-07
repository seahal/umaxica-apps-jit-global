# frozen_string_literal: true

require "test_helper"
require "timeout"

# Committed unique fixtures are required for independent PostgreSQL connection visibility.
# Boolean snapshots prevent disclosure of OTP, proof and root facts.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpDeliveryLockTest < ActiveSupport::TestCase
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
        secret = ROTP::Base32.random_base32
        contact.store_otp(secret, 1, (contact.class.database_now + 10.minutes).to_i)
        otp = contact.get_otp
        code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
        transaction = ContactRegistrationOtpIssuer.call!(
          actor:, token:, contact:, channel:, browser_nonce: SecureRandom.urlsafe_base64(32), code:,
        )
        destination = (channel == :email) ? contact.address : contact.number
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
          Concurrent::Future.execute do
            source_base.connected_to(role: :writing) do
              source_base.connection_pool.with_connection(prevent_permanent_checkout: true) do |source_db|
                ticket_base.connected_to(role: :writing) do
                  ticket_base.connection_pool.with_connection(prevent_permanent_checkout: true) do |ticket_db|
                    original = flow_model.find(transaction.id)
                    ContactRegistrationOtpDeliveryIssuer.call(
                      transaction: original, contact_ref: contact.public_id, counter: "1", destination:, code:,
                    ) do
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
                contact.store_otp(secret, 2, (contact.class.database_now + 10.minutes).to_i)
              elsif row.equal?(token)
                token.revoke!
              end
            end
          end
        end

        assert facts == protected_rows.map { |row| row.reload.attributes },
               "While transport is held, competing reissue and revoke lock acquisition must preserve all facts"
        assert_not holder.complete?, "The external transport barrier must still hold the delivery operation"
        release << true

        delivery_result = Timeout.timeout(20) { holder.value! }

        assert delivery_result == true, "Eligible delivery must finish only after the transport barrier is released"
        protected_rows.each do |row|
          row.class.transaction(requires_new: true) do
            acquired = row.class.lock("FOR UPDATE NOWAIT").find(row.id)

            assert_equal row.id, acquired.id
          end
        end

        assert facts == protected_rows.map { |row| row.reload.attributes }, "Delivery must not mutate protected facts"
        contact.with_lock { contact.store_otp(secret, 2, (contact.class.database_now + 10.minutes).to_i) }

        assert_equal "2", contact.reload.otp_counter.to_s
        token.revoke!

        assert_predicate token.reload, :revoked?
        delivered_again = false

        stale_result =
          ContactRegistrationOtpDeliveryIssuer.call(
            transaction: transaction.reload, contact_ref: contact.public_id, counter: "1", destination:, code:,
          ) { delivered_again = true }

        assert stale_result == false, "Reissued and revoked evidence must refuse stale delivery"
        assert_not delivered_again, "Released locks must not restore stale queued delivery authority"
      ensure
        release << true if release
        holder&.wait(25)
        if contact&.persisted?
          contact.reload.clear_otp
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
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
