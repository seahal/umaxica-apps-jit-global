# typed: false
# frozen_string_literal: true

# Answers the Home/Dashboard authentication boundary (adr/home-dashboard-authentication-boundary.md)
# with an ordinary 404 response.
#
# A session on the wrong side of the boundary is expected control flow, not a failure, so it is
# rendered here instead of raised. Raising would route the request through the exceptions app, whose
# behavior depends on `consider_all_requests_local` and `show_exceptions`; this response does not.
# The representation matches what ApiProblemExceptionsApp serves for a non-API 404: the static
# public page, or the ActionDispatch::PublicExceptions JSON document, never cached by shared caches.
module SessionBoundaryNotFound
  extend ActiveSupport::Concern

  private

  def render_session_boundary_not_found
    response.headers["Cache-Control"] = "private, no-store"

    if request.format.json?
      render json: { status: 404, error: Rack::Utils::HTTP_STATUS_CODES.fetch(404) }, status: :not_found
    else
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false,
             content_type: "text/html", formats: [:html]
    end
  end
end
