# frozen_string_literal: true

# E1: SignUpCycleLocator#current needs the admitted Binding, which an integration test does not hold.
# Tests that only need the Flow the browser is working on read it by the session hint.
module SessionSignUpFlowTestSupport
  FLOW_CLASSES = { app: ClientSignUpFlow, com: VisitorSignUpFlow }.freeze

  def session_sign_up_flow(session, surface:, **)
    hint = session[SignUpCycleLocator::SESSION_KEYS.fetch(surface)]
    hint && FLOW_CLASSES.fetch(surface).find_by(public_id: hint.stringify_keys["public_id"])
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include SessionSignUpFlowTestSupport }
