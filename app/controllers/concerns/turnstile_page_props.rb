# typed: false
# frozen_string_literal: true

# Serializes the Cloudflare Turnstile widget configuration an Inertia page needs to draw a challenge.
#
# The ERB partials `shared/_cloudflare_turnstile_stealth` and `shared/_cloudflare_turnstile_visible`
# read the site key inside the view. An Inertia page has no view, so the same lookup happens here and
# travels as a prop. Only the *site* key crosses the boundary; it is public by design and is already
# published in the rendered HTML today. The secret key and the verification of the returned token
# stay entirely server side, and this concern changes neither.
module TurnstilePageProps
  extend ActiveSupport::Concern

  private

  # Runs the widget invisibly and solves it on load, matching the `execute` mode of the stealth
  # partial.
  def turnstile_stealth_props(action: nil, cdata: nil)
    {
      site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
      mode: "execute",
      action: action,
      cdata: cdata,
    }
  end

  # Draws the interactive widget, matching the `render` mode of the visible partial.
  def turnstile_visible_props(action: nil, cdata: nil, challenge_id: nil)
    props = {
      site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY),
      mode: "render",
      action: action,
      cdata: cdata,
    }
    props[:challenge_id] = challenge_id if challenge_id.present?
    props
  end

  # Missing configuration fails loudly here exactly as it did in the partial, so a page can never
  # silently render without a challenge the server will then demand.
  def turnstile_site_key(name)
    key = Rails.app.creds.option(name)
    raise KeyError, "#{name} is required" if key.blank?

    key
  end
end
