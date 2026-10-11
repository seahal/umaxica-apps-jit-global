# typed: false
# frozen_string_literal: true

require "test_helper"

# Contract for the Inertia protocol on /preference, which every base surface serves from its own
# FQDN (www.umaxica.app, www.umaxica.com, www.umaxica.org).
#
# The page object rather than the markup is what the client navigates on, so every assertion here
# reads component, props, url and version. The cross-surface assertions matter most: each surface
# boots its own Inertia application and globs only its own page directory, so a component name from
# another surface is a trust boundary violation the client refuses to render.
class PreferenceInertiaPageContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = [
    { name: "app", host_env: "PUBLIC_BASE_SERVICE_URL", fallback_host: "base.app.localhost" },
    { name: "com", host_env: "PUBLIC_BASE_CORPORATE_URL", fallback_host: "base.com.localhost" },
    { name: "org", host_env: "PUBLIC_BASE_STAFF_URL", fallback_host: "base.org.localhost" },
  ].freeze

  SCREEN_KEYS = %w(
    region timezone language motion density pagination theme cookie customization calendar clock currency
  ).freeze

  # Every screen under /preference and the component shape it renders. The four shapes are the four
  # shared ERB templates the Inertia pages replaced.
  SCREEN_COMPONENTS = {
    "region" => "option",
    "timezone" => "option",
    "language" => "option",
    "theme" => "option",
    "cookie" => "cookie",
    "motion" => "selectable",
    "density" => "selectable",
    "pagination" => "selectable",
    "currency" => "selectable",
    "calendar" => "selectable",
    "clock" => "selectable",
    "customization" => "customizations",
  }.freeze

  setup do
    https!
  end

  SURFACES.each do |surface|
    name = surface.fetch(:name)

    test "base_#{name} embeds the full page object for the preference index" do
      get_preference_index(surface)

      assert_response :success
      assert_equal "text/html", response.media_type

      page = inertia_page

      assert_equal "base/#{name}/preferences/show", page.fetch("component")
      assert_equal "/preference?ri=jp", page.fetch("url")
      assert_equal ViteRuby.digest, page.fetch("version")
      assert page.fetch("encryptHistory"), "encrypt_history is configured on, so the page must carry it"
    end

    test "base_#{name} serves the preference index to a guest" do
      get_preference_index(surface)

      # AUTHENTICATION_MODE is :open, so the preference authority answers unauthenticated requests.
      assert_response :success
    end

    test "base_#{name} props carry every screen link with the request region" do
      get_preference_index(surface)

      assert_response :success

      props = inertia_page.fetch("props")

      assert_predicate props.fetch("title"), :present?
      assert_predicate props.fetch("description"), :present?
      assert_predicate props.dig("up_link", "label"), :present?
      assert_predicate props.dig("up_link", "href"), :present?

      screens = props.fetch("screens")

      assert_equal SCREEN_KEYS, screens.map { |screen| screen.fetch("key") }

      screens.each do |screen|
        assert_predicate screen.fetch("label"), :present?
        assert_match(/\Ahttps?:\/\/|\A\//, screen.fetch("href"))
        assert_match(
          /ri=jp/, screen.fetch("href"),
          "every screen link must carry the resolved region: #{screen.fetch("href")}",
        )
      end
    end

    test "base_#{name} boots its own Inertia entrypoint" do
      get_preference_index(surface)

      assert_response :success
      # The entrypoint is referenced by name in dev mode and by a hashed asset path in
      # manifest/built mode (e.g. /vite-test/assets/base_org-XXXX.js); match either form.
      assert_select "script[src*=?]", "base_#{name}"
    end

    test "base_#{name} never renders another surface's page component" do
      get_preference_index(surface)

      assert_response :success

      (SURFACES.map { |other| other.fetch(:name) } - [name]).each do |other_name|
        assert_no_match(
          /base\/#{other_name}\//, response.body,
          "base_#{name} must not reference the base/#{other_name} surface",
        )
      end
    end

    test "base_#{name} answers an Inertia visit with the page object as JSON" do
      get_preference_index(surface, headers: inertia_headers(surface, version: ViteRuby.digest))

      assert_response :success
      assert_equal "true", response.headers["X-Inertia"]
      assert_equal "application/json", response.media_type

      page = response.parsed_body

      assert_equal "base/#{name}/preferences/show", page.fetch("component")
      assert_equal "/preference?ri=jp", page.fetch("url")
      assert_equal ViteRuby.digest, page.fetch("version")
    end

    test "base_#{name} answers a stale asset version with a hard location refresh" do
      get_preference_index(surface, headers: inertia_headers(surface, version: "stale-asset-version"))

      assert_response :conflict
      assert_equal(
        preference_url(surface),
        response.headers["X-Inertia-Location"],
      )
    end
  end

  SURFACES.each do |surface|
    name = surface.fetch(:name)

    test "base_#{name} renders every preference screen through its own surface component" do
      SCREEN_COMPONENTS.each do |screen, component|
        get_preference_screen(surface, screen)

        assert_response :success
        assert_equal "base/#{name}/preference/#{component}", inertia_component,
                     "/preference/#{screen}/edit must render the #{component} component"
        assert_predicate inertia_props.fetch("title"), :present?
        assert_predicate inertia_props.dig("back_link", "href"), :present?
        assert_match(/ri=jp/, inertia_props.dig("form", "action"))
      end
    end

    test "base_#{name} preference screens never reference another surface" do
      others = SURFACES.map { |other| other.fetch(:name) } - [name]

      SCREEN_COMPONENTS.each_key do |screen|
        get_preference_screen(surface, screen)

        assert_response :success

        others.each do |other|
          assert_no_match(
            /base\/#{other}\//, response.body,
            "/preference/#{screen}/edit on base_#{name} must not reference base/#{other}",
          )
        end
      end
    end

    # A 302 on a PATCH would make the browser repeat the PATCH against the redirect target. The
    # Inertia middleware rewrites it, but only for requests that carry the Inertia header.
    test "base_#{name} answers an Inertia update with a see-other back to the screen" do
      get_preference_screen(surface, "theme")

      assert_response :success

      patch(
        public_send("base_#{name}_preference_theme_url", host: surface_host(surface), ri: "jp"),
        params: { preference_theme: { option_id: "dr" } },
        headers: inertia_headers(surface, version: ViteRuby.digest),
      )

      assert_response :see_other

      get_preference_screen(surface, "theme")

      assert_response :success
      assert_equal 2, inertia_props.dig("form", "value")
    end

    # Inertia reads a 4xx as a transport exception, so a refused reset has to come back as a
    # redirect whose next page carries the errors.
    test "base_#{name} sends an unconfirmed reset back to the screen with errors" do
      get_preference_screen(surface, "customization")

      assert_response :success

      delete(
        public_send("base_#{name}_preference_customization_url", host: surface_host(surface), ri: "jp"),
        headers: inertia_headers(surface, version: ViteRuby.digest),
      )

      assert_response :see_other

      get_preference_screen(surface, "customization", headers: inertia_headers(surface, version: ViteRuby.digest))

      assert_response :success

      errors = response.parsed_body.fetch("props").fetch("errors")

      assert_predicate errors, :present?, "the refused reset must surface its error on the next page"
    end
  end

  private

  def get_preference_screen(surface, screen, headers: nil)
    host!(surface_host(surface))
    get(
      public_send(
        "edit_base_#{surface.fetch(:name)}_preference_#{screen}_url",
        host: surface_host(surface), ri: "jp",
      ),
      headers: headers,
    )
  end

  def surface_host(surface)
    ENV.fetch(surface.fetch(:host_env), surface.fetch(:fallback_host))
  end

  def preference_url(surface)
    public_send("base_#{surface.fetch(:name)}_preference_url", host: surface_host(surface), ri: "jp")
  end

  def get_preference_index(surface, headers: nil)
    host!(surface_host(surface))
    get(preference_url(surface), headers: headers)
  end

  def inertia_headers(surface, version:)
    host_headers(surface_host(surface)).merge(
      "X-Inertia" => "true",
      "X-Inertia-Version" => version,
      "Accept" => "text/html, application/xhtml+xml",
    )
  end
end
