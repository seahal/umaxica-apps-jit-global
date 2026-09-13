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

  # Any host that reached the app without matching a surface above is unknown;
  # answer it here rather than leaking a routing error.
  get "/", to: "unknown_hosts#show"
end
