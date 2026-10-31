# typed: false
# frozen_string_literal: true

# Applies the URL request context (ri/lx/tz/ct/...) over an already resolved preference without
# persisting anything.
#
# Both actor lifecycles need it: ActorSupport for authenticated app/org requests, and
# ComAnonymousActorContext for the corporate surface, which installs an anonymous preference
# without including ActorSupport. Keeping the overlay here means the com surface localizes from
# `?ri=` exactly like the account surfaces.
module PreferenceRequestOverlay
  extend ActiveSupport::Concern

  private

  def preference_with_request_overlay(preference)
    return preference unless respond_to?(:requested_context, true)

    context = requested_context
    return preference if context.blank?

    Actor::Preference.new(
      language: overlay_language(context, preference),
      region: context[:ri] || preference.region,
      timezone: context[:tz] || preference.timezone,
      theme: context[:ct] || preference.theme,
      currency: context[:cu] || preference.currency,
      date_format: context[:df] || preference.date_format,
      time_format: context[:tf] || preference.time_format,
      motion: context[:mo] || preference.motion,
      density: context[:dn] || preference.density,
      page_size: context[:ps] || preference.page_size,
      cookie: preference.cookie,
      web_push: preference.web_push,
      null: preference.null?,
    )
  end

  # Resolve the request-overlay language. An explicit `lx` wins; otherwise a valid
  # regional request supplies its locale, with the verified Preference snapshot as fallback.
  def overlay_language(context, preference)
    context[:lx] ||
      locale_from_request_region(context[:ri]) ||
      preference.language
  end

  def locale_from_request_region(region)
    return if region.blank?
    return locale_from_region(region) if respond_to?(:locale_from_region, true)

    {
      "jp" => "ja",
      "us" => "en",
    }[region.to_s.downcase]
  end
end
