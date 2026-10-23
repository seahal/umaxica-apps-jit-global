# frozen_string_literal: true

require "test_helper"

class SignUpFinalizationDatabaseClockTest < ActiveSupport::TestCase
  test "finalization follows the Ticket database deadline immediately before at and after expiry in both realms" do
    [[ClientSignUpFlow, Client, :app], [VisitorSignUpFlow, Visitor, :com]].each do |flow_class, owner_class, surface|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      deadline = flow_class.database_now + 1.hour
      flow = flow_class.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_class),
        principal_id: owner.id, status_id: flow_class::STATUS_MODEL::CHECKPOINT_PENDING, step: "checkpoint",
        nonce_digest: flow_class.digest_nonce("finalization-clock"), issued_at: deadline - 15.minutes,
        expires_at: deadline, entry_method: "email",
        completed_requirements: { "otp" => { "cleared" => true }, "birthdate" => { "cleared" => true } },
      )
      context = SignUpFinalizationContext.build(
        surface: surface, ticket: flow, pending_actor: owner,
        actor_authentication: Actor::Authentication.new(active_sign_sequence_id: flow.public_id),
      )
      [[-Rational(1, 1_000_000), true], [0, false], [Rational(1, 1_000_000), false]].each do |offset, allowed|
        flow_class.stub(:database_now, deadline + offset) do
          assert_equal allowed, SignUp::FinalizationPolicy.new(context, user: nil).finalize?,
                       "#{surface}: Ticket database deadline offset #{offset}"
        end
      end
    end
  end
end
