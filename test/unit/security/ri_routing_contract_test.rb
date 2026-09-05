# typed: false
# frozen_string_literal: true

require "test_helper"

# Guards the RI (region identifier) request-context contract across every routing target.
#
# Why this test exists: `PreferenceGlobal#default_url_options` reads the *request params* only, so
# `ri` reaches generated URLs solely because `before_action :set_region` has already redirected it
# into the query string. There is no fallback path. A single `skip_before_action :set_region` on a
# controller that renders regional HTML therefore silently strips the region from every link on the
# page. That is exactly what happened to the auth sign-in and sign-up entry pages, and it survived
# two months of green CI because the existing callback assertions were aimed at the surface
# ApplicationController -- which was never the thing that broke.
#
# The four tests below close that gap from four directions:
#
#   1. every routing target is classified as participating or exempt (catches a new surface),
#   2. every participating target actually wires the mechanism up (catches a dropped include),
#   3. the set of controllers opting out is pinned exactly (catches a new skip, and a lost one),
#   4. every routed controller that renders HTML resolves `set_region` in its *effective* callback
#      chain (catches a leaf that loses the mechanism through inheritance rather than through a
#      visible `skip_before_action`).
#
# Tests 1-3 read source files, so they run without booting a full request stack. Test 4 resolves the
# real classes, because that is the only way to see a chain assembled across a parent controller.
class RiRoutingContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CONTROLLER_ROOT = "app/controllers"

  # Targets that serve regional HTML and therefore owe the `ri` contract described in
  # docs/architecture/preference.md:197.
  RI_PARTICIPATING_TARGETS = %w(
    auth/app auth/com auth/org
    base/app base/com base/org
    core/app core/com core/org
    side/app side/com side/org
    palm/app
  ).freeze

  # Targets deliberately outside the contract. An unexplained absence is indistinguishable from the
  # oversight this test exists to catch, so every exemption is grouped under a stated reason.

  # Infrastructure editions: health probes, CSP sinks and root stubs only. They serve no regional
  # HTML and are not reachable by ordinary users.
  RI_EXEMPT_INFRASTRUCTURE_TARGETS = %w(base/dev base/net core/dev core/net).freeze

  # Publishing content surfaces. Their language comes from the published document
  # (PublishingContentRendering), not from request context, so they do not carry `ri`.
  RI_EXEMPT_CONTENT_TARGETS = %w(
    docs/app docs/com docs/org
    help/app help/com help/org
    info/app info/com info/org
    news/app news/com news/org
  ).freeze

  RI_EXEMPT_TARGETS = (RI_EXEMPT_INFRASTRUCTURE_TARGETS + RI_EXEMPT_CONTENT_TARGETS).freeze

  # Controllers inside a participating target that legitimately do not run `set_region`. Every entry
  # is a machine-to-machine endpoint: protocol redirects and token/cookie transports that must not
  # bounce a caller through a region canonicalization redirect. None of them render regional HTML.
  #
  # This list is compared by equality, not inclusion, so a NEW skip fails the test and so does a
  # skip that silently disappears. Adding an entry is a deliberate, reviewable act.
  RI_SKIP_ALLOWLIST = %w(
    app/controllers/auth/app/edge/v0/token/checks_controller.rb
    app/controllers/auth/app/edge/v0/token/dbsc_controller.rb
    app/controllers/auth/app/oidc/authorizations_controller.rb
    app/controllers/auth/app/oidc/callbacks_controller.rb
    app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb
    app/controllers/auth/com/edge/v0/token/checks_controller.rb
    app/controllers/auth/com/edge/v0/token/dbsc_controller.rb
    app/controllers/auth/com/oidc/authorizations_controller.rb
    app/controllers/auth/com/oidc/callbacks_controller.rb
    app/controllers/auth/org/edge/v0/token/checks_controller.rb
    app/controllers/auth/org/edge/v0/token/dbsc_controller.rb
    app/controllers/auth/org/oidc/authorizations_controller.rb
    app/controllers/auth/org/oidc/callbacks_controller.rb
    app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb
    app/controllers/base/app/edge/v0/cookies_controller.rb
    app/controllers/base/app/oauth/authorizations_controller.rb
    app/controllers/base/app/oidc/authorizations_controller.rb
    app/controllers/base/app/oidc/callbacks_controller.rb
    app/controllers/base/com/edge/v0/cookies_controller.rb
    app/controllers/base/com/oauth/authorizations_controller.rb
    app/controllers/base/com/oidc/authorizations_controller.rb
    app/controllers/base/com/oidc/callbacks_controller.rb
    app/controllers/base/org/edge/v0/cookies_controller.rb
    app/controllers/base/org/oauth/authorizations_controller.rb
    app/controllers/base/org/oidc/authorizations_controller.rb
    app/controllers/base/org/oidc/callbacks_controller.rb
    app/controllers/core/app/edge/v0/cookies_controller.rb
    app/controllers/core/app/edge/v0/dbsc_controller.rb
    app/controllers/core/app/oidc/authorizations_controller.rb
    app/controllers/core/app/oidc/callbacks_controller.rb
    app/controllers/core/com/edge/v0/cookies_controller.rb
    app/controllers/core/com/edge/v0/dbsc_controller.rb
    app/controllers/core/com/oidc/authorizations_controller.rb
    app/controllers/core/com/oidc/callbacks_controller.rb
    app/controllers/core/org/edge/v0/cookies_controller.rb
    app/controllers/core/org/edge/v0/dbsc_controller.rb
    app/controllers/core/org/oidc/authorizations_controller.rb
    app/controllers/core/org/oidc/callbacks_controller.rb
    app/controllers/side/app/oidc/authorizations_controller.rb
    app/controllers/side/app/oidc/callbacks_controller.rb
    app/controllers/side/com/oidc/authorizations_controller.rb
    app/controllers/side/com/oidc/callbacks_controller.rb
    app/controllers/side/org/oidc/authorizations_controller.rb
    app/controllers/side/org/oidc/callbacks_controller.rb
  ).freeze

  # Controllers that render HTML on a participating target and still run without region
  # enforcement. Each is reached by a token URL sent in an email, not by in-surface navigation: the
  # page carries a one-click unsubscribe form back to itself and generates no regional link, and a
  # canonicalization redirect there would rewrite a URL the recipient received out of band.
  RI_HTML_EXEMPT_CONTROLLERS = %w(
    base/app/preference/emails
    base/com/preference/emails
    base/org/preference/emails
  ).freeze

  SKIP_SET_REGION_PATTERN = /^\s*skip_before_action\s+.*\bset_region\b/
  INCLUDE_PREFERENCE_GLOBAL_PATTERN = /^\s*include\s+::?PreferenceGlobal\b/
  BEFORE_ACTION_SET_REGION_PATTERN = /^\s*before_action\s+:set_region\b/

  test "every routing target is classified as participating in or exempt from the ri contract" do
    classified = (RI_PARTICIPATING_TARGETS + RI_EXEMPT_TARGETS).sort

    assert_equal classified, discovered_targets,
                 "Routing targets changed. Every <family>/<edition> that serves requests must be " \
                 "listed in RI_PARTICIPATING_TARGETS (it renders regional HTML and owes the ri " \
                 "contract) or in RI_EXEMPT_TARGETS with a stated reason. Leaving a new surface " \
                 "unclassified is how a surface silently ships without region routing.\n" \
                 "unclassified: #{(discovered_targets - classified).inspect}\n" \
                 "stale entry:  #{(classified - discovered_targets).inspect}"
  end

  test "every participating target wires up the ri mechanism on its ApplicationController" do
    offenders =
      RI_PARTICIPATING_TARGETS.filter_map do |target|
        relative_path = "#{CONTROLLER_ROOT}/#{target}/application_controller.rb"
        absolute_path = Rails.root.join(relative_path)

        next "#{relative_path}: missing" unless absolute_path.exist?

        content = read_source(absolute_path)
        missing = []
        missing << "include ::PreferenceGlobal" unless content.match?(INCLUDE_PREFERENCE_GLOBAL_PATTERN)
        missing << "before_action :set_region" unless content.match?(BEFORE_ACTION_SET_REGION_PATTERN)
        next if missing.empty?

        "#{relative_path}: missing #{missing.join(" and ")}"
      end

    assert_empty offenders,
                 "Participating surfaces must both include PreferenceGlobal and register " \
                 "set_region. Without the before_action, default_url_options has no ri in params " \
                 "to propagate and every generated link loses the region:\n#{offenders.join("\n")}"
  end

  test "set_region is skipped only in the reviewed allowlist" do
    offenders =
      controller_paths.filter_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        next unless read_source(path).match?(SKIP_SET_REGION_PATTERN)

        relative_path
      end.sort

    assert_equal RI_SKIP_ALLOWLIST, offenders,
                 "Controllers skipping set_region changed. Skipping it on a controller that " \
                 "renders regional HTML strips ri from every URL that controller generates -- the " \
                 "auth sign-in/sign-up regression. Confirm the endpoint is machine-to-machine and " \
                 "update RI_SKIP_ALLOWLIST deliberately.\n" \
                 "added:   #{(offenders - RI_SKIP_ALLOWLIST).inspect}\n" \
                 "removed: #{(RI_SKIP_ALLOWLIST - offenders).inspect}"
  end

  test "every routed controller rendering HTML resolves set_region in its effective callback chain" do
    unresolved = []
    without_set_region =
      html_rendering_controllers.filter_map do |controller|
        klass = controller_class(controller)

        if klass.nil?
          unresolved << controller
          next
        end

        controller unless before_action_filters(klass).include?(:set_region)
      end

    assert_empty unresolved, "Routed controllers that do not resolve to a class: #{unresolved.inspect}"

    assert_equal RI_HTML_EXEMPT_CONTROLLERS, without_set_region,
                 "The set of HTML-rendering controllers running without set_region changed. This " \
                 "test resolves the effective callback chain, so it also catches a controller that " \
                 "loses the mechanism by inheriting a bare base rather than by skipping the " \
                 "callback -- which the source scan above cannot see:\n" \
                 "added:   #{(without_set_region - RI_HTML_EXEMPT_CONTROLLERS).inspect}\n" \
                 "removed: #{(RI_HTML_EXEMPT_CONTROLLERS - without_set_region).inspect}"
  end

  private

  # Family/edition pairs that own controllers, e.g. "auth/app". Derived from the controller tree so
  # a newly added surface shows up here without anyone remembering to register it.
  def discovered_targets
    Rails.root.join(CONTROLLER_ROOT).glob("*/*")
      .select(&:directory?)
      .map { |path| path.relative_path_from(Rails.root.join(CONTROLLER_ROOT)).to_s }
      .reject { |target| target.start_with?("concerns/") }
      .sort
  end

  def controller_paths
    Rails.root.join(CONTROLLER_ROOT).glob("**/*.rb").select(&:file?)
  end

  def read_source(path)
    File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
  end

  # Routed controllers on a participating target that own at least one HTML template. Owning a
  # template is the mechanical signal that the controller renders a page whose links must carry the
  # region; protocol, health, and bearer-API endpoints own none and are out of the contract.
  def html_rendering_controllers
    routed_controllers
      .select { |controller| RI_PARTICIPATING_TARGETS.any? { |target| controller.start_with?("#{target}/") } }
      .select { |controller| html_rendering_controller?(controller) }
  end

  # A controller renders a regional page whether that page is an ERB template or an Inertia
  # component; after the Inertia migration most of these controllers own a page under `src/pages`
  # instead of a template under `app/views`, and only counting templates would quietly empty this
  # contract out.
  def html_rendering_controller?(controller)
    Rails.root.join("app/views", controller).glob("*.html.erb").any? ||
      Rails.root.join("src/pages", controller).glob("*.tsx").any?
  end

  def routed_controllers
    Rails.application.routes.routes
      .filter_map { |route| route.defaults[:controller].presence }
      .uniq
      .sort
  end

  def controller_class(controller)
    "#{controller.camelize}Controller".safe_constantize
  end

  def before_action_filters(klass)
    klass._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)
  end
end
