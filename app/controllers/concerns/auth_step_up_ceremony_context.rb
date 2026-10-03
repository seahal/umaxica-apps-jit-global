# frozen_string_literal: true

# Includers provide actor/session models, token ownership, method limits and explicit authorization.
# The admitted actor is ceremony-scoped; it does not establish an Auth browser login.
module AuthStepUpCeremonyContext
  private

  def load_step_up_ceremony_context!
    transaction = auth_ceremony_step_up_transaction
    return render_invalid_step_up_context! unless transaction

    session_record =
      ceremony_step_up_session_model.connection_class_for_self.connected_to(role: :writing) do
        ceremony_step_up_session_model.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
      end
    token = ceremony_session_token(session_record)
    actor =
      ceremony_actor_model.connection_class_for_self.connected_to(role: :writing) do
        ceremony_actor_model.find_by!(public_id: transaction.actor_ref)
      end
    unless token.public_id == transaction.session_ref && ceremony_token_owned_by?(token, actor) &&
        token.currently_usable? && actor.login_allowed?
      return render_invalid_step_up_context!
    end

    @step_up_ceremony_actor = actor
    @step_up_ceremony_transaction = transaction
    @step_up_ceremony_session = session_record
    authorize_step_up_ceremony_actor!(actor)
    true
  rescue ActiveRecord::RecordNotFound
    render_invalid_step_up_context!
  end

  def current_policy_user = @step_up_ceremony_actor

  def admitted_step_up_methods
    ceremony_supported_methods & @step_up_ceremony_transaction.allowed_methods_array.map(&:to_sym)
  end

  def render_invalid_step_up_context!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    false
  end

  def ceremony_actor_model
    raise NotImplementedError, "#{self.class} must define #ceremony_actor_model"
  end

  def ceremony_step_up_session_model
    raise NotImplementedError, "#{self.class} must define #ceremony_step_up_session_model"
  end

  def ceremony_session_token(_session_record)
    raise NotImplementedError, "#{self.class} must define #ceremony_session_token"
  end

  def ceremony_token_owned_by?(_token, _actor)
    raise NotImplementedError, "#{self.class} must define #ceremony_token_owned_by?"
  end

  def authorize_step_up_ceremony_actor!(_actor)
    raise NotImplementedError, "#{self.class} must define #authorize_step_up_ceremony_actor!"
  end

  def ceremony_supported_methods
    raise NotImplementedError, "#{self.class} must define #ceremony_supported_methods"
  end
end
