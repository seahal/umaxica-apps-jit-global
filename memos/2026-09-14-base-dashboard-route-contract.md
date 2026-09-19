# Base App Dashboard Route Contract

The self-service UI request described the Avatar up link as `/dashboard?ri=jp` and suggested a
`base_app_dashboard_path` helper, while also saying the route structure should remain unchanged. The
current Base app routes define `root "roots#index"` and no dashboard resource route. The root
controller renders the dashboard component, and `SurfaceInertiaPage#dashboard_up_link` intentionally
uses the Base root helper as the parent destination.

The implementation therefore keeps the existing route contract and supplies the localized Dashboard
label with `base_app_root_path(ri: params[:ri])`. Adding `/dashboard` would require a route change
and would create a URL absent from the current routing architecture. If the product requires that
literal URL, treat it as a separate route-contract decision rather than emitting a dead link from
the UI.

Evidence checked: `config/routes/base.rb`, `app/controllers/base/app/roots_controller.rb`,
`app/controllers/concerns/surface_inertia_page.rb`, the existing Accounts and Organizations index
contracts, and the Avatar index integration test.
