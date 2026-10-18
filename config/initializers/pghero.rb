# typed: false
# frozen_string_literal: true

# `pghero` is a `group :development` gem, required from config/application.rb (it has to be
# loaded before the routing paths are collected). This file only configures it, so everything
# here stays behind the same development guard.
if Rails.env.development?
  # Cloudflare Access fronts pghero.umaxica.dev, but the mounted engine must not depend on the
  # edge alone: PgHero::Engine subclasses nothing of this application, so enforce_access_policy!
  # and surface isolation never run for it, and any request that reached the origin directly
  # would get unauthenticated read access to query stats/table stats and the ability to kill
  # running queries.
  #
  # The check lives in the engine's own middleware stack rather than wrapping the engine at the
  # mount point (config/routes/pghero.rb explains why). Fails closed: when the credentials are
  # not configured the block returns false and every request is answered with 401, rather than
  # defaulting to open access.
  PgHero::Engine.middleware.use(Rack::Auth::Basic, "PgHero") do |user, password|
    expected_user = Rails.app.creds.option(:PGHERO_USERNAME)
    expected_password = Rails.app.creds.option(:PGHERO_PASSWORD)

    if expected_user.blank? || expected_password.blank?
      false
    else
      # Non-short-circuiting `&` so both comparisons always run.
      ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
    end
  end

  # PgHero builds one anonymous ActiveRecord model per database with a plain
  # `establish_connection`, which registers a pool for the writing role only. The
  # DatabaseSelector middleware (config/initializers/multi_db.rb) wraps every GET in
  # `connected_to(role: :reading)`, and a model without a reading pool raises
  # ActiveRecord::ConnectionNotDefined there, the same reason Flipper's model declares
  # both roles in config/initializers/flipper.rb.
  #
  # Each PgHero database resolves from a config/database.yml entry (PgHero's default
  # config maps every ActiveRecord configuration to a `spec`), so both roles point at
  # that same entry. PgHero only ever reads through these models, and the replica
  # entries stay read-only at the PostgreSQL level.
  PgHero.databases.each_value do |database|
    spec = database.config["spec"]
    next if spec.blank?

    # `connection_model` is PgHero-private; it returns the built model without connecting.
    model = database.send(:connection_model)
    # connects_to is only allowed on an abstract class. These models are connection
    # holders that PgHero never instantiates, so marking them abstract changes nothing else.
    model.abstract_class = true
    model.connects_to(database: { writing: spec.to_sym, reading: spec.to_sym })
  end
end
