# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class WithdrawalsController < ::Base::Org::ApplicationController
        include ::VerificationOperator
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authorize_withdrawal!, only: :show

        def show
          render inertia: true, props: {
            title: t("sign.org.settings.withdrawal.show.title"),
            paragraphs: [
              t("sign.org.settings.withdrawal.show.description"),
              t("sign.org.settings.withdrawal.show.direct_message_unavailable"),
            ],
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path,
            },
          }
        end

        private

        def authorize_withdrawal!
          authorize!(current_operator, to: :show?, with: OperatorWithdrawalPolicy)
        end

        def verification_required_action? = true

        def verification_scope = "operator_lifecycle"
      end
    end
  end
end
