# frozen_string_literal: true

# Entry controllers expose only the actor and operation admitted by Base. This context is used
# for the ceremony's ownership policy; it never becomes an Auth browser session or Base authority.
module AuthStepUpCeremonyEntry
  public

  def show
    admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) do
      return unless load_step_up_ceremony_context!

      @available_methods = StepUpMethodsResolver.call(
        actor: @step_up_ceremony_actor, ticket: @step_up_ceremony_session,
        supported_methods: admitted_step_up_methods,
      ).available
      render_verification_entry_page
    end
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    render_invalid_admission_request!
  end

  private

  def auth_ceremony_entry_intent
    if admission_reference_param.present?
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: auth_ceremony_surface, reference: admission_reference_param,
      )
      case binding.purpose
      when "step_up_handoff" then return "step_up"
      when "reauthentication_handoff" then return "reauthentication"
      end
    else
      transaction = auth_ceremony_step_up_transaction
      return transaction.purpose if transaction
    end

    raise BaseAuthAdmissionCoordinator::Denied.new(
      "verification entry purpose is unavailable",
      code: "invalid_admission",
    )
  end
end
