# typed: false
# frozen_string_literal: true

require "test_helper"

# Rendered contract for the UMAXICA brand title.
#
#   root HTML:      "UMAXICA (TLD)"
#   non-root HTML:  "{LOCALIZED PAGE TITLE}" then an EM DASH then "UMAXICA (TLD)"
#
# Non-root cases assert the page-specific title itself, not merely that the title
# is non-empty: a view that forgets `content_for :page_title` collapses to the
# root title and would otherwise look healthy.
class HtmlTitleContractTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  # Routing and deployment vocabulary that must never reach a title.
  FORBIDDEN_WORDS = %w(Auth Base Core Warp Palm Jump Global Rails Inertia API Home).freeze

  ROOT_SURFACES = [
    { host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_CORE_STAFF_URL"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_WARP_SERVICE_URL"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_WARP_CORPORATE_URL"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_WARP_STAFF_URL"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"), tld: "APP" },
    { host: "core.dev.localhost", tld: "DEV" },
  ].freeze

  # `/health` is served on the network and developer hosts too, which carry their own TLD labels
  # rather than inheriting one from the surface. Only the host is needed now: the title assertion
  # these entries once fed was removed when `/health` stopped rendering HTML.
  HEALTH_HOSTS = [
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL") },
    { host: ENV.fetch("PRIVATE_BASE_NETWORK_URL") },
    { host: ENV.fetch("PRIVATE_BASE_DEVELOPER_URL") },
  ].freeze

  # Prefixes that answer with JSON, XML or plain text. Listed rather than inferred
  # so that a new HTML route is never silently treated as out of scope.
  # Warp answers an anonymous direct dashboard request with 404 rather than a redirect; see
  # test/controllers/warp/*/dashboards_controller_test.rb.
  ANONYMOUS_NOT_FOUND_PATHS = [
    ENV.fetch("PUBLIC_WARP_SERVICE_URL"),
    ENV.fetch("PUBLIC_WARP_CORPORATE_URL"),
    ENV.fetch("PUBLIC_WARP_STAFF_URL"),
  ].index_with { ["/dashboard"] }.freeze

  NON_HTML_PATH_PATTERNS = [
    %r{\A/health(/(liveness|readiness|startup))?\z},
    %r{\A/\.well-known/},
    %r{\A/(web|edge|api)/v\d},
    %r{\A/csp-violation-report\z},
    %r{\A/revision\z},
    %r{\A/robots\.txt},
    %r{\A/sitemap\.xml\z},
    %r{\A/service-worker\z},
    # turbo-rails native navigation endpoint (turbo/native/navigation#recede).
    %r{\A/recede_historical_location\z},
    %r{\A/(resume|refresh)_historical_location\z},
  ].freeze

  test "root pages render the brand alone" do
    ROOT_SURFACES.each do |surface|
      host! surface.fetch(:host)
      get "/"

      next if response.redirect?

      assert_response :success, "GET / on #{surface.fetch(:host)}"
      assert_single_html_document
      assert_equal "#{BRAND} (#{surface.fetch(:tld)})", rendered_title,
                   "root title on #{surface.fetch(:host)}"
      assert_title_shape(rendered_title, surface.fetch(:tld))
    end
  end

  test "non-root pages render the localized page title before the brand" do
    cases = [
      {
        host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        path: -> { auth_app_sign_in_path(ri: "jp") },
        admission: %w(app sign_in),
        tld: "APP",
        page_title: -> { I18n.t("sign.app.authentication.new.page_title") },
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
        path: -> { auth_com_sign_in_path(ri: "jp") },
        admission: %w(com sign_in),
        tld: "COM",
        page_title: -> { I18n.t("sign.com.authentication.new.page_title") },
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        path: -> { auth_org_sign_in_path(ri: "jp") },
        admission: %w(org sign_in),
        tld: "ORG",
        page_title: -> { I18n.t("sign.org.authentication.new.page_title") },
      },
      {
        host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
        path: -> { palm_app_sign_show_path(ri: "jp") },
        tld: "APP",
        page_title: -> { I18n.t("actions.continue") },
      },
    ]

    cases.each do |entry|
      host! entry.fetch(:host)
      # Auth pages open only from a Base-issued admission (E01); enter them the way Base sends a browser.
      if entry.key?(:admission)
        begin
          fv5127 = instance_exec(&entry.fetch(:path))
          fv5126 = admission_reference_for(*entry.fetch(:admission))
          fv5125 = :entry_ref
          fv5124 = {}
          fv5123 = {}
          fv5122 = false
          fv5121 = nil
          fv5120 = nil
          begin
            fv5068 = self
            fv5075 = fv5127
            fv5118 = fv5126
            fv5119 = fv5125
            fv5084 = fv5124
            fv5077 = fv5123
            fv5106 = fv5122
            fv5105 = fv5121
            fv5080 = fv5120
            fv5074 = fv5084.merge(fv5119 => fv5118)
            fv5068.get(fv5075, params: fv5074, headers: fv5077)
            fv5112 =
              begin
                fv5117 = fv5068.response.body
                fv5116 = true
                fv5115 = Nokogiri::HTML(fv5117).at_css("form")
                if fv5115.nil? && fv5116
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5115

                  fv5114 = fv5115.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5114.blank?

                  fv5113 = fv5115.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5115["action"], fv5114, fv5113]
                end
              end
            if fv5112

              fv5111, fv5109, fv5110 = fv5112

              fv5068.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5068.post(
                fv5111,
                params: fv5110.merge(authenticity_token: fv5109),
                headers: fv5077,
              )
              fv5108 = fv5068.response.location
              if fv5108.present?

                fv5104 = URI.parse(fv5108)
                fv5103 = fv5104.host
                fv5079 =
                  begin
                    fv5107 = fv5103
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5107)
                  end
                fv5078 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5079, reference: fv5104.path.split("/").fetch(-2),
                )

                if fv5106
                  fv5086 = fv5105 || fv5068
                  fv5086.host!(fv5103)
                  fv5086.https!
                  fv5086.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5102 = fv5104.request_uri
                  fv5093 = fv5077.merge(
                    "Host" => fv5103,
                    "Origin" => "https://#{fv5103}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5086.get(fv5102, headers: fv5093)
                  fv5096, fv5094, fv5095 =
                    begin
                      fv5101 = fv5086.response.body
                      fv5100 = false
                      fv5099 = Nokogiri::HTML(fv5101).at_css("form")
                      if fv5099.nil? && fv5100
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5099

                        fv5098 = fv5099.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5098.blank?

                        fv5097 = fv5099.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5099["action"], fv5098, fv5097]
                      end
                    end
                  fv5086.post(
                    fv5096,
                    params: fv5095.merge(authenticity_token: fv5094),
                    headers: fv5093,
                  )
                  begin
                    fv5087 = fv5086
                    fv5089 = "session"
                    fv5088 = fv5087.response.cookies[fv5089]
                    if fv5088.nil?
                      fv5092 = fv5087.response.headers["Set-Cookie"] || fv5087.response.headers["set-cookie"]
                      fv5091 =
                        if fv5092.is_a?(String) && fv5092.start_with?("[")
                          JSON.parse(fv5092)
                        else
                          Array(fv5092)
                        end
                      fv5090 =
                        fv5091.flat_map { |cookie_entry| cookie_entry.to_s.split("\n") }.find do |cookie_entry|
                          cookie_entry.split(";", 2).first.to_s.start_with?("#{fv5089}=")
                        end
                      if fv5090

                        _, fv5088 = fv5090.split(";", 2).first.to_s.split("=", 2)
                        fv5088 = Rack::Utils.unescape(fv5088.to_s)
                      end
                    end

                    unless fv5088.nil?
                      fv5087.cookies.delete(fv5089)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5087.cookies.merge(
                        "#{fv5089}=#{Rack::Utils.escape(fv5088)}",
                        URI.parse("https://#{fv5087.host}/"),
                      )
                    end
                  end
                  fv5085 = fv5086.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5085.blank?

                  fv5082 = URI.parse(fv5085)
                  if fv5084[:ri].present?
                    fv5083 = Rack::Utils.parse_nested_query(fv5082.query.to_s)
                    fv5083["ri"] ||= fv5084[:ri].to_s
                    fv5082.query = URI.encode_www_form(fv5083)
                  end
                  fv5068.host!(fv5082.host)
                  fv5068.https!
                  fv5081 = fv5082.request_uri
                  fv5064 = fv5077.merge("Host" => fv5082.host)
                  fv5068.get(fv5081, headers: fv5064)
                else
                  fv5078.confirm_base!(
                    base_token: fv5080,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5079,
                      entry_ref: fv5078.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5076 = fv5068.host
                  fv5068.host!(fv5076)
                  fv5068.https!
                  fv5064 = fv5077.merge("Host" => fv5076)
                  fv5068.get(fv5075, params: fv5074, headers: fv5064)
                end
                fv5067, fv5065, fv5066 =
                  begin
                    fv5073 = fv5068.response.body
                    fv5072 = false
                    fv5071 = Nokogiri::HTML(fv5073).at_css("form")
                    if fv5071.nil? && fv5072
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5071

                      fv5070 = fv5071.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5070.blank?

                      fv5069 = fv5071.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5071["action"], fv5070, fv5069]
                    end
                  end
                fv5068.post(
                  fv5067,
                  params: fv5066.merge(authenticity_token: fv5065),
                  headers: fv5064,
                )
              end
            end
          end
        end
        follow_redirect!
      else
        get instance_exec(&entry.fetch(:path))
      end

      next if response.redirect?

      assert_response :success, "GET #{entry.fetch(:path).call} on #{entry.fetch(:host)}"
      assert_single_html_document

      expected = "#{instance_exec(&entry.fetch(:page_title))} — #{BRAND} (#{entry.fetch(:tld)})"

      assert_equal expected, rendered_title, "title on #{entry.fetch(:host)}"
      assert_title_shape(rendered_title, entry.fetch(:tld))
    end
  end

  test "the health snapshot is a non-HTML probe and is excluded from title contracts" do
    HEALTH_HOSTS.each do |entry|
      host! entry.fetch(:host)
      get "/health"

      assert_response :success, "GET /health on #{entry.fetch(:host)}"
      assert_equal "text/plain", response.media_type, "GET /health on #{entry.fetch(:host)}"
      # `HealthCheckRendering#render_snapshot` emits a fixed seven-line text/plain block that
      # opens with a `title:` field. That field is a plain-text line, not an HTML <title>, which
      # is exactly why this path is excluded from the title contracts above.
      assert_match(/\Atitle: Health status\nnamespace: \S+\nstatus: \w+\n/, response.body)
      assert_includes response.body.lines, "status: ok\n"
    end

    assert_includes non_html_get_paths, "/health"
  end

  # Auth is ceremony-only: a direct, un-bridged `GET /sign/in` now 303s to Base
  # (AuthCeremonyAdmission#bridge_to_base_admission!) instead of rendering, so this must redeem a
  # real Base-issued admission code to reach the page it's asserting on. Same pattern as
  # AuthRegionContractTest and AuthOidcEntrancesTest.
  test "the page title is localized while the brand stays constant" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    titles =
      %w(jp us).to_h do |region|
        begin
          fv5063 = auth_app_sign_in_path
          fv5062 = admission_reference_for("app", "sign_in")
          fv5061 = :entry_ref
          fv5060 = { ri: region }
          fv5059 = {}
          fv5058 = false
          fv5057 = nil
          fv5056 = nil
          begin
            fv5004 = self
            fv5011 = fv5063
            fv5054 = fv5062
            fv5055 = fv5061
            fv5020 = fv5060
            fv5013 = fv5059
            fv5042 = fv5058
            fv5041 = fv5057
            fv5016 = fv5056
            fv5010 = fv5020.merge(fv5055 => fv5054)
            fv5004.get(fv5011, params: fv5010, headers: fv5013)
            fv5048 =
              begin
                fv5053 = fv5004.response.body
                fv5052 = true
                fv5051 = Nokogiri::HTML(fv5053).at_css("form")
                if fv5051.nil? && fv5052
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5051

                  fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5050.blank?

                  fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5051["action"], fv5050, fv5049]
                end
              end
            if fv5048

              fv5047, fv5045, fv5046 = fv5048

              fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5004.post(
                fv5047,
                params: fv5046.merge(authenticity_token: fv5045),
                headers: fv5013,
              )
              fv5044 = fv5004.response.location
              if fv5044.present?

                fv5040 = URI.parse(fv5044)
                fv5039 = fv5040.host
                fv5015 =
                  begin
                    fv5043 = fv5039
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5043)
                  end
                fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
                )

                if fv5042
                  fv5022 = fv5041 || fv5004
                  fv5022.host!(fv5039)
                  fv5022.https!
                  fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5038 = fv5040.request_uri
                  fv5029 = fv5013.merge(
                    "Host" => fv5039,
                    "Origin" => "https://#{fv5039}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5022.get(fv5038, headers: fv5029)
                  fv5032, fv5030, fv5031 =
                    begin
                      fv5037 = fv5022.response.body
                      fv5036 = false
                      fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                      if fv5035.nil? && fv5036
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5035

                        fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5034.blank?

                        fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5035["action"], fv5034, fv5033]
                      end
                    end
                  fv5022.post(
                    fv5032,
                    params: fv5031.merge(authenticity_token: fv5030),
                    headers: fv5029,
                  )
                  begin
                    fv5023 = fv5022
                    fv5025 = "session"
                    fv5024 = fv5023.response.cookies[fv5025]
                    if fv5024.nil?
                      fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                      fv5027 =
                        if fv5028.is_a?(String) && fv5028.start_with?("[")
                          JSON.parse(fv5028)
                        else
                          Array(fv5028)
                        end
                      fv5026 =
                        fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                        end
                      if fv5026

                        _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                        fv5024 = Rack::Utils.unescape(fv5024.to_s)
                      end
                    end

                    unless fv5024.nil?
                      fv5023.cookies.delete(fv5025)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5023.cookies.merge(
                        "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                        URI.parse("https://#{fv5023.host}/"),
                      )
                    end
                  end
                  fv5021 = fv5022.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

                  fv5018 = URI.parse(fv5021)
                  if fv5020[:ri].present?
                    fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                    fv5019["ri"] ||= fv5020[:ri].to_s
                    fv5018.query = URI.encode_www_form(fv5019)
                  end
                  fv5004.host!(fv5018.host)
                  fv5004.https!
                  fv5017 = fv5018.request_uri
                  fv5000 = fv5013.merge("Host" => fv5018.host)
                  fv5004.get(fv5017, headers: fv5000)
                else
                  fv5014.confirm_base!(
                    base_token: fv5016,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5015,
                      entry_ref: fv5014.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5012 = fv5004.host
                  fv5004.host!(fv5012)
                  fv5004.https!
                  fv5000 = fv5013.merge("Host" => fv5012)
                  fv5004.get(fv5011, params: fv5010, headers: fv5000)
                end
                fv5003, fv5001, fv5002 =
                  begin
                    fv5009 = fv5004.response.body
                    fv5008 = false
                    fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                    if fv5007.nil? && fv5008
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5007

                      fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5006.blank?

                      fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5007["action"], fv5006, fv5005]
                    end
                  end
                fv5004.post(
                  fv5003,
                  params: fv5002.merge(authenticity_token: fv5001),
                  headers: fv5000,
                )
              end
            end
          end
        end

        assert_response :see_other
        follow_redirect!

        [region, rendered_title]
      end

    titles.each_value do |title|
      assert_match(/ — #{Regexp.escape("#{BRAND} (APP)")}\z/, title)
    end
  end

  # One test per surface host, not one test sweeping all 14 hosts x ~156 candidate paths serially:
  # that single-test form measured 135s alone (about a quarter of the full suite's wall time),
  # ran under one Minitest worker with no parallelism across hosts, and named every failure
  # "every routed GET HTML page carries a non-empty title" regardless of which host broke. Splitting
  # by host keeps the same per-request assertions and lets `parallelize` spread the 14 sweeps across
  # workers instead of serializing them behind a single slow test.
  # One test per surface host, not one test sweeping all 14 hosts serially: that single-test form
  # measured 135s alone, ran under one Minitest worker and named every failure the same regardless
  # of which host broke. Splitting by host lets `parallelize` spread the sweeps across workers.
  #
  # Each host is swept only over the routes it declares in its own host constraint. Sending every
  # route to every host made almost every request a 404 that the sweep then skipped, so a host
  # could pass while checking nothing. Any other unexpected status or an exception now fails.
  ROOT_SURFACES.each do |surface|
    test "every routed GET HTML page carries a non-empty title on #{surface.fetch(:tld)} " \
         "(#{surface.fetch(:host)})" do
      host = surface.fetch(:host)
      host! host
      paths = host_html_get_paths(host)

      assert_predicate paths, :any?, "#{host} declares no GET HTML route to sweep"

      checked = []
      unexpected = []
      paths.each do |path|
        get(path)

        if response.successful? && response.media_type.to_s.start_with?("text/html")
          checked << path

          assert_equal 1, css_select("title").size, "#{path} on #{host} needs exactly one <title>"
          assert_predicate rendered_title.strip, :present?, "#{path} on #{host} renders an empty <title>"
          assert_title_shape(rendered_title, surface.fetch(:tld))
        elsif response.server_error? ||
            (response.not_found? && ANONYMOUS_NOT_FOUND_PATHS.fetch(host, []).exclude?(path))
          unexpected << "GET #{path}: #{response.status}"
        end
      end

      assert_empty unexpected, "#{host} answered its own routes unexpectedly:\n#{unexpected.join("\n")}"
      puts "HTML title sweep on #{host}: #{checked.size} of #{paths.size} responses checked"
    end
  end

  test "the route sweep itself discovers candidate HTML paths" do
    # Guards the discovery mechanism the per-host sweep tests above depend on (not a live request):
    # a broken `NON_HTML_PATH_PATTERNS` or route-introspection regression that made `html_get_paths`
    # vacuously empty would otherwise leave every per-host test trivially, silently passing with
    # zero checks. Per-host live-request success/failure is each host's own concern, not this one's.
    assert_predicate html_get_paths, :any?, "the HTML route sweep discovered nothing to check"
  end

  test "non-HTML paths are excluded from the title sweep for a documented reason" do
    skipped = non_html_get_paths

    assert_predicate skipped, :any?, "expected at least one path excluded from the HTML title sweep"
    puts "HTML title sweep: non-HTML paths excluded: #{skipped.inspect}"
  end

  private

  REALM_BY_SURFACE = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze
  CLIENT_ID_BY_SURFACE = { "app" => "core-app-jp", "com" => "core-com-jp", "org" => "core-org-jp" }.freeze

  # Issues a real transaction and redeems it through `BaseAuthAdmissionCoordinator`, the same path
  # `AuthOidcEntrancesTest` and `AuthRegionContractTest` use, so the code carries a genuine
  # signature rather than a stub.
  def admission_reference_for(surface, intent)
    client_id = CLIENT_ID_BY_SURFACE.fetch(surface)
    client = OidcClientRegistry.find!(client_id)
    transaction =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: intent,
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(REALM_BY_SURFACE.fetch(surface)).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    ).reference
  end

  def assert_title_shape(title, tld)
    assert_predicate title.strip, :present?, "title must not be blank"
    assert_includes title, "#{BRAND} (#{tld})", "title must carry the brand and its TLD edition"
    assert_not_includes title, "Umaxica", "brand must be upper case"
    assert_not_includes title, "translation missing"
    assert_not_includes title, "|", "the separator is an EM DASH, not a pipe"

    FORBIDDEN_WORDS.each do |word|
      assert_no_match(/\b#{word}\b/, title, "#{title.inspect} leaks #{word}")
    end
  end

  def assert_single_html_document
    assert_match %r{\Atext/html}, response.media_type
    assert_equal 1, css_select("html").size, "expected exactly one <html> element"
    assert_equal 1, css_select("head").size, "expected exactly one <head> element"
    assert_equal 1, css_select("title").size, "expected exactly one <title> element"
  end

  def rendered_title
    css_select("title").first&.text.to_s
  end

  def static_get_paths
    Rails.application.routes.routes
      .select { |route| route.verb == "GET" }
      .map { |route| route.path.spec.to_s.sub(/\(\.:format\)\z/, "") }
      .reject { |path| path.include?(":") || path.include?("*") }
      .uniq
  end

  def non_html_get_paths
    static_get_paths.select { |path| NON_HTML_PATH_PATTERNS.any? { |pattern| pattern.match?(path) } }
  end

  def html_get_paths
    static_get_paths - non_html_get_paths
  end

  def host_html_get_paths(host)
    Rails.application.routes.routes
      .select { |route| route.verb == "GET" && Array(route.constraints[:host]).include?(host) }
      .map { |route| route.path.spec.to_s.sub(/\(\.:format\)\z/, "") }
      .reject { |path| path.include?(":") || path.include?("*") || path.include?("(") }
      .uniq - non_html_get_paths
  end
end
