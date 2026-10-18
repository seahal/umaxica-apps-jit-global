# frozen_string_literal: true

# Role ingress boundary (R5-WU17): a role process serves only the controllers RuntimeRole assigns to
# it. See lib/runtime_role_route_guard.rb.
require Rails.root.join("lib/runtime_role_route_guard").to_s

ActiveSupport.on_load(:action_controller_base) { prepend RuntimeRoleRouteGuard }
ActiveSupport.on_load(:action_controller_api) { prepend RuntimeRoleRouteGuard }
