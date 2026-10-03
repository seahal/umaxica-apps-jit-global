# frozen_string_literal: true

# Entry controllers expose only the actor and operation admitted by Base. This context is used
# for the ceremony's ownership policy; it never becomes an Auth browser session or Base authority.
module AuthStepUpCeremonyEntry
  public

  def show
    admit_or_render_sign_ceremony!(expected_intent: "step_up") do
      return unless load_step_up_ceremony_context!

      @available_methods = StepUpMethodsResolver.call(
        actor: @step_up_ceremony_actor, ticket: @step_up_ceremony_session,
        supported_methods: admitted_step_up_methods,
      ).available
      render_verification_entry_page
    end
  end

  private

  def auth_ceremony_entry_intent = "step_up"
end
