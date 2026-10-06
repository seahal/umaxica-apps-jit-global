# typed: false
# frozen_string_literal: true

# Declarative step-up requirement DSL.
#
# `step_up` registers a before_action that calls the existing
# VerificationBase#require_step_up! / #require_step_up_unless_bootstrap!
# helpers. It lets a sensitive controller declare its step-up requirement in
# one line instead of hand-written hooks, reducing the risk that a new
# sensitive action silently ships without a step-up gate. The runtime
# behaviour (redirect/status) is identical to calling the underlying
# helper directly -- this concern only moves the declaration, not the logic.
module VerificationStepUpGuard
  extend ActiveSupport::Concern

  class_methods do
    # only:         actions the requirement applies to (forwarded to before_action only:)
    # scope:        step-up scope; defaults to the controller's #verification_scope
    #               so the scope stays single-sourced with the existing override.
    # bootstrap:    when true, uses require_step_up_unless_bootstrap! so actors with
    #               no step-up method configured are not blocked from setup.
    def step_up(only:, scope: nil, bootstrap: false, **policy)
      before_action(only: only) do
        options = { scope: scope || verification_scope }
        options.merge!(policy)

        if bootstrap
          require_step_up_unless_bootstrap!(**options)
        else
          require_step_up!(**options)
        end
      end
    end
  end
end
