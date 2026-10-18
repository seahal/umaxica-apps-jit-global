# typed: false
# frozen_string_literal: true

# Refuses a request for a controller this process's runtime role does not own (R5-WU17, one.md
# section 591 "Role ingress/cookie boundary").
#
# Prepended to ActionController::Base and ActionController::API (config/initializers/
# runtime_role_route_guard.rb) so it runs before every controller callback, ahead of any
# `prepend_before_action` a subclass declares, and therefore before credential lookup or database
# access. The owner comes from the fixed table in RuntimeRole, never from request input. The shared
# transitional role serves every controller.
module RuntimeRoleRouteGuard
  private

  def process_action(*)
    return super if RuntimeRole.serves?(controller_path)

    head :not_found
  end
end
