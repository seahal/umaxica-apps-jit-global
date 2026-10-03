# typed: false
# frozen_string_literal: true

require "test_helper"

# A controller outside the Auth, Sign, Acme, and Base namespaces has no sign-in surface. Asking it
# for a sign-in destination is a programmer error and must fail, never resolve to Home "/" or to a
# guessed "/dashboard" or "/welcome" (no-silent-fallback).
class AuthenticationRedirectsUnknownSurfaceTest < ActionController::TestCase
  self.fixture_table_names = []

  # Defined inside this test class, so its name does not begin with a surface namespace.
  class SignInCompletionsController < ApplicationController
    include AuthenticationRedirects

    public

    def dashboard
      redirect_to(after_dashboard_path)
    end

    def welcome
      redirect_to(sign_in_welcome_path)
    end
  end

  tests SignInCompletionsController

  test "default sign-in destination fails for a controller without a sign-in surface" do
    with_surface_probe_routes do
      error = assert_raises(AuthenticationRedirects::UnknownSignInSurfaceError) { get(:dashboard) }

      assert_includes error.message, SignInCompletionsController.name
    end

    assert_nil response.location
  end

  test "welcome destination fails for a controller without a sign-in surface" do
    with_surface_probe_routes do
      assert_raises(AuthenticationRedirects::UnknownSignInSurfaceError) { get :welcome }
    end

    assert_nil response.location
  end

  private

  def with_surface_probe_routes(&)
    with_routing do |set|
      set.draw do
        get("/probe/dashboard", to: "authentication_redirects_unknown_surface_test/sign_in_completions#dashboard")
        get("/probe/welcome", to: "authentication_redirects_unknown_surface_test/sign_in_completions#welcome")
      end
      yield
    end
  end
end
