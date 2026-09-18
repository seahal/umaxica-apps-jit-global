# typed: false
# frozen_string_literal: true

# `blazer` is a `group :development` gem, required from config/application.rb (it has to be
# loaded before the routing paths are collected). This file only configures it, so everything
# here stays behind the same development guard.
if Rails.env.development?
  # Blazer persists a query-audit row on every run by default (Blazer.audit), which needs a
  # `blazer_audits` table. Auditing is off here, so db/migrate/20260915000000_create_blazer_tables.rb
  # omits that table and creates only the storage the dashboard itself reads.
  Blazer.audit = false

  # Cloudflare Access fronts blazer.umaxica.dev, but the mounted engine must not depend on the
  # edge alone: Blazer::Engine subclasses nothing of this application, so enforce_access_policy!
  # and surface isolation never run for it, and any request that reached the origin directly
  # would get unauthenticated arbitrary read access to every data source Blazer is configured
  # with (config/blazer.yml).
  #
  # The check lives in the engine's own middleware stack rather than wrapping the engine at the
  # mount point (config/routes/blazer.rb explains why). Fails closed: when the credentials are
  # not configured the block returns false and every request is answered with 401, rather than
  # defaulting to open access.
  Blazer::Engine.middleware.use(Rack::Auth::Basic, "Blazer") do |user, password|
    expected_user = Rails.app.creds.option(:BLAZER_USERNAME)
    expected_password = Rails.app.creds.option(:BLAZER_PASSWORD)

    if expected_user.blank? || expected_password.blank?
      false
    else
      # Non-short-circuiting `&` so both comparisons always run.
      ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
    end
  end
end
