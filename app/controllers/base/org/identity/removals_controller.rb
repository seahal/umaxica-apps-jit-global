# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class RemovalsController < ::Base::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        before_action :authenticate_operator!
        step_up only: :create, scope: "settings_secret_credential"

        def create
          secret = current_operator.staff_secret_credentials.find_by!(public_id: params.expect(:secret_id))
          authorize!(secret)
          unless AuthMethodGuard.can_remove_secret_credential?(current_operator, secret)
            redirect_to(base_org_identity_secrets_path(ri: params[:ri]), status: :see_other)
            return
          end

          OperatorSecretCredentialsDestroy.call(actor: current_operator, secret_credential: secret)
          redirect_to(base_org_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
