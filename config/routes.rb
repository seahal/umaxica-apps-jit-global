# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Base owns the OP/Authorization Server and durable identity/session authority.
  draw :base

  # Auth owns the credential gateway for sign-in/sign-up ceremonies.
  draw :auth

  # Info owns public informational content.
  draw :info

  # GUID owns domain-level globally-unique-identifier resolution.
  draw :guid

  # Core owns the regional BFF surface.
  draw :core

  # Side owns the Rails foundation/control-plane surface.
  draw :side

  # Palm owns the native RP and bearer-token API surface.
  draw :palm

  # Help owns the public help content surface.
  draw :help

  # Docs owns the public documentation content surface.
  draw :docs

  # News owns the public news content surface.
  draw :news

  # Edit owns the staff Publishing management surface.
  draw :edit

  # Mission owns the Solid Queue job-monitoring surface (Mission Control Jobs), staff-only.
  draw :mission

  # Flipper owns the feature-flag control surface (Flipper::UI), staff-only.
  draw :flipper

  # Blazer owns the SQL exploration dashboard (Blazer::Engine), staff-only, development-only.
  draw :blazer

  # PgHero owns the PostgreSQL monitoring dashboard (PgHero::Engine), staff-only, development-only.
  draw :pghero

  # Swagger owns the rendered view of the bundled OpenAPI descriptions and the authenticated
  # endpoint that serves them (Rswag::Ui and Rswag::Api engines), staff-only, development-only.
  draw :swagger

  # Performance owns the request performance dashboard (RailsPerformance::Engine), staff-only,
  # development-only. Also the only place the engine is mounted: its self-mount is suppressed in
  # config/application.rb because it carries no host constraint.
  draw :performance

  # Coverband owns the runtime code-execution report (Coverband::Reporters::Web), staff-only,
  # development-only, and only in the process that serves requests.
  draw :coverband

  # Any host that reached the app without matching a surface above is unknown;
  # answer it here rather than leaking a routing error.
  get "/", to: "unknown_hosts#show" # FIXIME: I want to remove this, or use root!
end
