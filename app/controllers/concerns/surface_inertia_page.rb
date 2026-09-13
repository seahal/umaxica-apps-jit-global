# typed: false
# frozen_string_literal: true

# Marks a controller as rendering Inertia pages, and derives its layout from its own surface.
#
# Including this concern is the single marker for "this controller renders Inertia": the layout is
# no longer a hand-written string that can name another surface's shell, and
# `grep -rl SurfaceInertiaPage app/controllers` is an accurate inventory. It pairs with
# `render inertia: true`, which derives the component name from the same controller_path.
#
# It also brings in the surface chrome, because a page rendered into the slim Inertia shell has no
# header or footer of its own: those are React components fed by the shared `chrome` prop.
module SurfaceInertiaPage
  extend ActiveSupport::Concern

  include SurfaceChrome

  included do
    family, surface = controller_path.to_s.split("/").first(2)

    if family.blank? || surface.blank?
      raise ArgumentError,
            "#{name} cannot derive an Inertia layout from controller_path #{controller_path.inspect}; " \
            "SurfaceInertiaPage expects a <family>/<surface>/... controller path"
    end

    layout "#{family}/#{surface}/inertia"
  end

  private

  # Page prop keys are composed from the screen scope, so they cannot be literals at the call site;
  # passing the composed key through here keeps every page translation lookup in one place, the same
  # way `SurfaceChrome#chrome_t` does for the chrome props.
  def page_t(key, **)
    t(key, **)
  end

  # Parent of the signed-in self-service screens is the surface dashboard. The href is a route
  # helper so PreferenceGlobal can attach the request region (`ri`) and any other context params.
  def dashboard_up_link(label: t("actions.up"))
    family, surface = controller_path.to_s.split("/").first(2)

    {
      label: label,
      href: public_send("#{family}_#{surface}_dashboard_path", ri: params[:ri]),
    }
  end
end
