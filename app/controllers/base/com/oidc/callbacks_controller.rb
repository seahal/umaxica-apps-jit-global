# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Oidc
      class CallbacksController < Base::Com::ApplicationController
        include ::OidcCallback
        include ::OidcRpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        class_attribute :oidc_rp_actor_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_identity_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_binding_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_bridge_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        provisions_oidc_rp_identity actor_class: Visitor, identity_class: VisitorIdentity,
                                    binding_class: VisitorOidcIdentityBinding
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def consume_oidc_pt
          destination = super
          (destination == "/") ? base_com_dashboard_path(ri: params[:ri]) : destination
        end

        def oidc_rp_credentials_only?
          true
        end

        def oidc_client_id
          "base-com-ww"
        end
      end
    end
  end
end
