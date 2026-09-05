# typed: false
# frozen_string_literal: true

# Shared rendering for the deployment-identifier endpoints.
#
# The identifier comes only from the official Rails application revision
# (`Rails.application.revision`, which the framework resolves from `ENV["REVISION"]`, a `REVISION`
# file, or Git). No endpoint here reads Git, the filesystem, or the environment itself, and none
# fabricates a value.
#
# Two representations, one value:
#
# - `render_revision`      -> `text/plain`, body exactly `"<revision>\n"`. `GET /revision`.
# - `render_revision_json` -> `application/json`, body `{"revision": "<revision>"}`. `/api/v0/revision.json`.
#
# A missing revision is a normal state, not an error. The text endpoint renders it as an empty
# line (`"\n"`); the JSON endpoint renders it as `{"revision": null}`. Both come from the single
# `application_revision` helper.
module ApplicationRevisionRendering
  extend ActiveSupport::Concern

  # `GET /revision`: text/plain, no redirect, no auth, no negotiation. `render plain:` ignores
  # `Accept`, so the response is text/plain whatever the caller asked for.
  def render_revision
    apply_revision_response_headers

    render plain: "#{application_revision}\n"
  end

  # `/api/v0/revision.json`: machine JSON only. The caller-facing 406 for a non-JSON `Accept` is
  # enforced by `MachineJsonNegotiation` in the controller; this method only shapes the body.
  def render_revision_json
    apply_revision_response_headers

    render json: { revision: application_revision }
  end

  private

  # The one revision code path shared by both representations. `nil` is passed through as `nil`;
  # callers decide how to represent absence.
  def application_revision
    Rails.application.revision&.to_s
  end

  def apply_revision_response_headers
    response.set_header("Cache-Control", "no-store")
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
