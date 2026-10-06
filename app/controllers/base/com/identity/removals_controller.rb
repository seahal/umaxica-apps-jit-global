# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class RemovalsController < ::Base::Com::ApplicationController
        AUTHENTICATION_MODE = :private
        step_up only: :create, scope: "settings_secret_credential"

        def create
          secret = current_visitor.visitor_secret_credentials.find_by!(public_id: params.expect(:secret_id))
          authorize!(secret)
          current_visitor.with_lock do
            secret = VisitorSecretCredential.lock.find_by!(id: secret.id, visitor_id: current_visitor.id)
            unless AuthMethodGuard.can_remove_secret_credential?(current_visitor, secret)
              redirect_to(base_com_identity_secrets_path(ri: params[:ri]), status: :see_other)
              return
            end

            secret.discard_now!(purge_after: 1.day)
            secret.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(:deleted)
            secret.save!
          end
          redirect_to(base_com_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
