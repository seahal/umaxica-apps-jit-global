# frozen_string_literal: true

# Visa CSP intake is stateless even when framework after-actions try to emit cookies.
class VisaCspReportResponseBoundary
  CONTROLLERS = %w(visa/app/csp_violation_reports visa/org/csp_violation_reports).freeze

  public

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    route = env["action_dispatch.request.path_parameters"]
    return [status, headers, body] unless route.is_a?(Hash) &&
      CONTROLLERS.include?(route[:controller]) && route[:action] == "create"

    filtered = headers.dup
    filtered.delete_if { |name, _| name.casecmp("set-cookie").zero? }
    [status, filtered, body]
  end
end
