# typed: false
# frozen_string_literal: true

module PromotionalEmailUnsubscribeHeaders
  extend ActiveSupport::Concern

  # Promotional unsubscribe links point at base/www, which owns the preference and
  # email-unsubscribe boundary (adr/identity-authority-boundary.md).
  SURFACE_OPTIONS = {
    client: {
      edit_route: :edit_base_app_preference_email_url,
      one_click_route: :base_app_preference_email_url,
      host_envs: ["PUBLIC_BASE_SERVICE_URL"],
      default_host: "www.app.localhost",
    },
    operator: {
      edit_route: :edit_base_org_preference_email_url,
      one_click_route: :base_org_preference_email_url,
      host_envs: ["PUBLIC_BASE_STAFF_URL"],
      default_host: "www.org.localhost",
    },
  }.freeze

  private

  def set_promotional_unsubscribe_headers(email_record)
    one_click_url = promotional_unsubscribe_url(email_record, route: :one_click_route)

    headers["List-Unsubscribe"] = "<#{one_click_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end

  def promotional_unsubscribe_url(email_record, route:)
    scope = email_record.promotional_unsubscribe_scope
    options = SURFACE_OPTIONS.fetch(scope)
    token = email_record.promotional_unsubscribe_token

    Rails.application.routes.url_helpers.public_send(
      options.fetch(route),
      email_record,
      token: token,
      host: configured_promotional_unsubscribe_host(options.fetch(:host_envs)),
    )
  end

  def configured_promotional_unsubscribe_host(env_keys)
    env_keys.each do |key|
      return ENV.fetch(key) if ENV.key?(key)
    end

    options = SURFACE_OPTIONS.values.find { |surface_options| surface_options.fetch(:host_envs) == env_keys }
    options.fetch(:default_host)
  end
end
