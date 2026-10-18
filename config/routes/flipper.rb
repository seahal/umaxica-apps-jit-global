# yped: false
# frozen_string_literal: true

# Flipper owns the feature-flag control surface (Flipper::UI), on its own dedicated host.
# Public canonical host: flipper.umaxica.dev. Development host: flipper.core.dev.localhost.
constraints host: [ENV["PUBLIC_FLIPPER_URL"], ENV["PRIVATE_FLIPPER_URL"],
                   "flipper.core.dev.localhost",].compact do
  # Cloudflare Access fronts this host, but the mounted Rack app must not depend on the edge
  # alone: Flipper::UI subclasses nothing of this application, so enforce_access_policy! and
  # surface isolation never run for it, and any request that reaches the origin directly would
  # get unauthenticated read/write over every feature flag.
  #
  # Fails closed: when the credentials are not configured the block returns false and every
  # request is answered with 401, rather than defaulting to open access.
  mount(
    Rack::Auth::Basic.new(Flipper::UI.app(Flipper)) do |user, password|
      expected_user = Rails.app.creds.option(:FLIPPER_UI_USER)
      expected_password = Rails.app.creds.option(:FLIPPER_UI_PASSWORD)

      if expected_user.blank? || expected_password.blank?
        false
      else
        # Non-short-circuiting `&` so both comparisons always run.
        ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
          ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
      end
    end.tap { |app| app.realm = "Flipper" } => "/",
    :as => :flipper,
  )
end
