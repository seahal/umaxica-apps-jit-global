# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SelectorsController < Base::Org::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_operator, to: :show?)
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: current_operator)
        render json: BaseSelectorAuthority.prepare(
          surface: :org, principal: current_operator,
          session: current_session,
        )
      end

      def update
        authorize!(current_operator, to: :update?)
        render json: BaseSelectorAuthority.select(
          surface: :org,
          principal: current_operator,
          session: current_session,
          params: selector_params,
        )
      rescue BaseSelectorAuthority::InvalidSelection => e
        render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
      end

      private

      def selector_params
        # `slice` first: this reads a fixed set of keys and ignores everything else the
        # request carries (`ri`, the Turnstile token). Permitting without narrowing would
        # report those as unpermitted, which they are not - they are simply not ours.
        keys = %i(
          account_public_id organization_public_id organization_unit_public_id
          collective_public_id collective_unit_public_id
        )
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end
    end
  end
end
