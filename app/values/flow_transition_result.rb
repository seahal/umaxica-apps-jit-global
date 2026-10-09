# frozen_string_literal: true

class FlowTransitionResult < Data.define(:status)
  public

  def expired?
    status == :expired
  end

  def value!
    raise FlowInvalidTransition, "cycle is expired" if expired?

    raise FlowConfigurationError, "unknown lifecycle refusal: #{status.inspect}"
  end
end
