# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class CallbacksController < Base::App::ApplicationController
        include ::OidcCallback
        include ::OidcRpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        class_attribute :oidc_rp_actor_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_identity_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_binding_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_bridge_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        provisions_oidc_rp_identity actor_class: Client, identity_class: ClientIdentity,
                                    binding_class: ClientOidcIdentityBinding
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def consume_oidc_pt
          destination = super
          (destination == "/") ? base_app_dashboard_path(ri: params[:ri]) : destination
        end

        def oidc_rp_credentials_only?
          true
        end

        def oidc_client_id
          "base-app-ww"
        end
      end
    end
  end
end
