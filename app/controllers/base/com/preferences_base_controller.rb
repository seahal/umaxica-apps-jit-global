# typed: false
# frozen_string_literal: true

module Base
  module Com
    class PreferencesBaseController < Base::Com::ApplicationController
      include ::PreferenceCore
      include ::BasePreferenceViewRouteAliases
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      helper_method :preference_base_i18n_key, :preference_acme_i18n_key

      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      # Corporate identity storage is being retired; anonymous Base does not read its banners.
      def chrome_banner(_domain)
        nil
      end

      def preference_write_request?
        !request.get? && !request.head?
      end

      # The com surface has no principal, so there is no user policy to consult. A write is
      # authorized only when it targets the anonymous ComPreference family that this surface owns;
      # CSRF/Origin/Fetch Metadata and the per-field permit lists remain the enforcing boundary.
      # The write goes through the closed WU-7 boundary contract first (D-54/AC-24): operation is
      # `save` for every anonymous com write, and the realm is the one whose model this controller
      # owns. Com has no Visa surface, so `sign_in`/`sign_out` never apply here.
      def authorize_preference_write!
        realm_model = preference_class
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :save, realm_model: realm_model,
        )
        return if realm_model == ComPreference

        raise PreferenceOperationError
      end
    end
  end
end
