# typed: false
# frozen_string_literal: true

# The credential check that stands in for the application authorization stack on every mounted
# diagnostic dashboard.
#
# A Rack app reached through `mount` subclasses nothing of this application, so AuthenticationBase,
# `enforce_access_policy!`, `FqdnAvailabilityGate`, surface isolation, and the per-surface CSRF
# origin configuration never run for it. A dedicated `*.umaxica.dev` host is not a substitute:
# Cloudflare Access fronts those names, but a request that reaches the origin directly carries
# whatever `Host` header it likes, and the origin must reject it on its own.
#
# Each surface therefore mounts behind `Rack::Auth::Basic` with a block built here.
#
# Fails closed. When either credential is unconfigured the block returns false and every request is
# answered with 401. That is the whole point of routing the check through one place: a guard that
# falls open when credentials are unset is worse than no guard, because it reads as protection.
#
# This is deliberately not applied to the existing Flipper, Blazer, and PgHero mounts, which carry
# the same comparison inline (config/routes/flipper.rb, config/initializers/{blazer,pghero}.rb).
# Rewriting working, tested authorization code is not part of adding new surfaces; the duplication
# is recorded here so a later pass has one obvious place to consolidate into.
#
# Lives in `lib/` with no Rails dependency beyond ActiveSupport because `config/coverband.rb` is
# loaded from Coverband's `before_configuration` railtie hook, long before autoloading is set up.
module DiagnosticSurfaceCredentials
  module_function

  # @param user_key [Symbol] credential name holding the expected user name
  # @param password_key [Symbol] credential name holding the expected password
  # @param credentials [#option] the unified ENV-then-credentials lookup; injectable for tests
  # @return [Proc] a block for `Rack::Auth::Basic` returning true only on a full credential match
  def guard(user_key:, password_key:, credentials: nil)
    lambda do |user, password|
      source = credentials || Rails.app.creds
      expected_user = source.option(user_key)
      expected_password = source.option(password_key)

      if expected_user.blank? || expected_password.blank?
        false
      else
        # Non-short-circuiting `&` so both comparisons always run: `&&` would return as soon as the
        # user name failed, and the time that takes reports whether the user name was right.
        ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
          ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
      end
    end
  end
end
