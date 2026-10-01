# frozen_string_literal: true

require "test_helper"

class XperBootstrapTest < ActionDispatch::IntegrationTest
  rate_limit_counters!

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  SURFACES = [
    ["app", "service", Xper::App::ApplicationController, Xper::App::BareController],
    ["com", "corporate", Xper::Com::ApplicationController, Xper::Com::BareController],
    ["org", "staff", Xper::Org::ApplicationController, Xper::Org::BareController],
  ].freeze

  CONTRACT = {
    "/" => ["roots", "index", :get],
    "/health" => ["healths", "show", :get],
    "/health/liveness" => ["health/livenesses", "show", :get],
    "/health/readiness" => ["health/readinesses", "show", :get],
    "/health/startup" => ["health/startups", "show", :get],
    "/revision" => ["revisions", "show", :get],
    "/api/v0/health.json" => ["api/v0/healths", "show", :get],
    "/api/v0/revision.json" => ["api/v0/revisions", "show", :get],
    "/csp-violation-report" => ["csp_violation_reports", "create", :post],
    "/robots.txt" => ["robots", "index", :get],
    "/sitemap.xml" => ["sitemaps", "index", :get],
  }.freeze

  SURFACES.each do |edition, slot, application, bare|
    test "#{edition} public and private hosts own exactly the Phase 0 route contract" do
      ["umaxica.#{edition}", "xper.#{edition}.localhost"].each do |host|
        assert_equal :"xper_#{slot}", FqdnAvailabilityRegistry.slot_for(host)
        CONTRACT.each do |path, (controller, action, verb)|
          recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: verb)

          assert_equal "xper/#{edition}/#{controller}", recognized[:controller]
          assert_equal action, recognized[:action]
        end
        %w(/api/v0/experience /service-worker /offline /manifest.json).each do |path|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
          end
        end
      end
      targets =
        Rails.application.routes.routes.select do |route|
          route.defaults[:controller].to_s.start_with?("xper/#{edition}/")
        end

      assert_equal CONTRACT.size, targets.size
    end

    test "#{edition} controller boundaries exclude preference authentication and Inertia lifecycle" do
      [application, bare].each do |controller|
        assert_equal ActionController::Base, controller.superclass
        assert_includes controller.ancestors, FqdnAvailabilityGate
        assert_includes controller.ancestors, RateLimit
        %w(PreferenceGlobal PreferenceBase SurfaceInertiaPage AuthenticationBase
           JumpRtReturnVerification).each do |name|
          assert_not controller.ancestors.any? { |ancestor| ancestor.name == name }
        end
      end
    end

    test "#{edition} protected ERB homepage issues no preference or Experience credentials" do
      ActionController::Base.allow_forgery_protection = true
      ["umaxica.#{edition}", "xper.#{edition}.localhost"].each do |host|
        host!(host)
        get("/")

        assert_response :success
        assert_equal "text/html", response.media_type
        assert_select "h1", "Experience"
        assert_select "p", "Surface: xper"
        assert_select "p", "Edition: #{edition}"
        # Inertia Rails installs a global CSRF cookie hook on ActionController::Base.
        # Framework CSRF/session cookies are distinct from either credential authority.
        set_cookie = response.headers["Set-Cookie"].to_s

        assert_no_match(/(?:preference|experience)_(?:access|refresh|dbsc)=/, set_cookie)
        assert_no_match(/inertia|serviceWorker|preference_access|experience_access/, response.body)
      end
    ensure
      ActionController::Base.allow_forgery_protection =
        Rails.configuration.action_controller.allow_forgery_protection
    end

    test "#{edition} homepage web rate boundary permits requests 299 and 300 and rejects 301" do
      host! "xper.#{edition}.localhost"
      301.times do |index|
        get "/", headers: { "Accept" => "text/html" }
        next if index < 298

        assert_response((index < 300) ? :success : :too_many_requests)
      end

      assert_equal "60", response.headers["Retry-After"]
      assert_equal "text/plain", response.media_type
      assert_empty response.headers["Set-Cookie"].to_s
    end

    test "#{edition} availability remains fail closed while health probes stay observable" do
      host!("xper.#{edition}.localhost")
      Flipper.disable(:"fqdn_available_xper_#{slot}")
      get("/")

      assert_response :service_unavailable
      get("/health/liveness")

      assert_response :success
    ensure
      Flipper.enable(:"fqdn_available_xper_#{slot}")
    end

    test "#{edition} CSP intake accepts null origin without CSRF and ignores missing empty and malformed bodies" do
      host!("xper.#{edition}.localhost")
      events = []
      ActionController::Base.allow_forgery_protection = true
      Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
        post(
          "/csp-violation-report",
          params: { "csp-report" => { "effective-directive" => "script-src" } }.to_json,
          headers: { "CONTENT_TYPE" => "application/csp-report", "HTTP_ORIGIN" => "null" },
        )

        assert_response :no_content
        assert_equal 1, events.size
        assert_equal CspViolationReportIntake::EVENT_NAME, events.first.first
        events.clear
        [nil, "", "{not-json", "null"].each do |body|
          post("/csp-violation-report", params: body, headers: { "CONTENT_TYPE" => "application/csp-report" })

          assert_response :no_content
          assert_empty events
        end
      end
    ensure
      ActionController::Base.allow_forgery_protection =
        Rails.configuration.action_controller.allow_forgery_protection
    end

    test "#{edition} CSP body boundary accepts limit minus one and limit and ignores limit plus one" do
      host! "xper.#{edition}.localhost"
      limit = CspViolationReportIntake::MAX_BODY_BYTES
      report = { "csp-report" => { "effective-directive" => "script-src" } }.to_json
      [limit - 1, limit, limit + 1].each do |bytes|
        events = []
        Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
          post "/csp-violation-report", params: report.ljust(bytes),
                                        headers: { "CONTENT_TYPE" => "application/csp-report" }
        end

        assert_response :no_content
        assert_equal((bytes <= limit) ? 1 : 0, events.size, "CSP body bytes: #{bytes}")
      end
    end

    test "#{edition} CSP rate boundary records requests 119 and 120 and ignores request 121 with 204" do
      host! "xper.#{edition}.localhost"
      events = []
      Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
        121.times do |index|
          post "/csp-violation-report",
               params: { "csp-report" => { "effective-directive" => "script-src" } }, as: :json
          next if index < 118

          assert_response :no_content
          assert_equal [index + 1, 120].min, events.size
        end
      end
    end

    test "#{edition} SEO placeholders use public configuration even on private origin" do
      ["umaxica.#{edition}", "xper.#{edition}.localhost"].each do |host|
        host! host
        get "/robots.txt"

        assert_response :success
        assert_equal "text/plain", response.media_type
        assert_equal "User-agent: *\nAllow: /\nSitemap: https://umaxica.#{edition}/sitemap.xml\n", response.body
        get "/sitemap.xml"

        assert_response :success
        assert_equal "application/xml", response.media_type
        document = Nokogiri::XML(response.body) { |config| config.strict }

        assert_equal "http://www.sitemaps.org/schemas/sitemap/0.9", document.root.namespace.href
        assert_equal ["https://umaxica.#{edition}/"], document.xpath("//xmlns:loc").map(&:text)
      end
    end
  end
end
