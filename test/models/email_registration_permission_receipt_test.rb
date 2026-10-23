# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean snapshots keep durable permission references out of failure diagnostics.
class EmailRegistrationPermissionReceiptTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %i(app com).each do |surface|
    %i(success terminal_retry expiry_before expiry_at expiry_after wrong_method caller_nil_clock
       caller_clock).each do |kind|
      test "#{surface} email permission receipt #{kind} uses original locked database clock" do
        actor =
          if surface == :app
            Client.create!(
              security_mode_id: SecurityModeConfigurable::NORMAL,
              id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
            )
          else
            Visitor.create!(
              security_mode_id: SecurityModeConfigurable::NORMAL,
              id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
            )
          end
        token =
          if surface == :app
            ClientToken.create!(
              authentication_epoch: 0, user: actor,
              root_login_established_at: ClientToken.database_now,
            )
          else
            VisitorToken.create!(
              authentication_epoch: 0, visitor: actor,
              root_login_established_at: VisitorToken.database_now,
            )
          end
        token.rotate_refresh_token!
        requirement = StepUpRequirement.new(
          step_up_required: false, scope: "settings_email", purpose: "bootstrap",
          allowed_methods: [(kind == :wrong_method) ? :passkey : :email_otp], ttl: 15.minutes,
          audience: "step_up:#{surface}", phishing_resistant_required: false,
          user_verification_required: false, full_reauthentication_required: false,
          session_binding: token.public_id, token_binding: token.public_id,
          require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        )
        parent = BaseStepUpAdmissionIssuer.call!(
          actor:, token:, requirement:, return_to: "/identity/emails",
          base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
        ).transaction
        contact =
          if surface == :app
            actor.client_emails.create!(
              raw_address: "permission-#{SecureRandom.hex(8)}@example.test",
              confirm_policy: "1",
            )
          else
            actor.visitor_emails.create!(
              raw_address: "permission-#{SecureRandom.hex(8)}@example.test",
              confirm_policy: "1",
            )
          end
        initial = parent.attributes
        now = parent.class.database_now
        case kind
        when :expiry_before then now = parent.expires_at - Rational(1, 1_000_000)
        when :expiry_at then now = parent.expires_at
        when :expiry_after then now = parent.expires_at + Rational(1, 1_000_000)
        end
        parent.class.stub(:database_now, now) do
          if %i(success terminal_retry expiry_before).include?(kind)
            assert_same parent, parent.consume_email_registration!(registered_credential_ref: contact.public_id)
            assert_equal "consumed", parent.reload.status
            assert_equal now, parent.consumed_at
            assert_equal "email_otp", parent[:method]
            assert_equal contact.public_id, parent.verified_credential_ref
            assert_nil token.reload.last_step_up_at
            if kind == :terminal_retry
              committed = parent.attributes

              assert_raises(IdentityStepUpCeremonyContract::Error) do
                parent.consume_email_registration!(registered_credential_ref: contact.public_id)
              end
              assert_withheld("Terminal receipt must remain unchanged") { committed == parent.reload.attributes }
            end
          elsif %i(caller_nil_clock caller_clock).include?(kind)
            assert_raises(ArgumentError) do
              parent.consume_email_registration!(
                registered_credential_ref: contact.public_id, now: (kind == :caller_nil_clock) ? nil : now,
              )
            end
            assert_withheld("Caller clock must not mutate permission") { initial == parent.reload.attributes }
          else
            assert_raises(IdentityStepUpCeremonyContract::Error) do
              parent.consume_email_registration!(registered_credential_ref: contact.public_id)
            end
            assert_withheld("Unavailable original permission must remain unchanged") {
              initial == parent.reload.attributes
            }
          end
        end
      end
    end
  end
end
