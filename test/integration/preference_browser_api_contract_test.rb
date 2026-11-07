# frozen_string_literal: true

require "openssl"
require "test_helper"

# One HTTP contract for Base's browser theme and cookie-consent endpoints. Auth, Core, and Warp read
# the realm projection without exposing Preference write controls. These contracts cover media
# types, cache policy, validation, and how a refused request is reported.
#
# The paths come from PreferenceBrowserControlsRegistry, the same source the page chrome hands the
# browser, so this contract follows the endpoint the controls actually call.
class PreferenceBrowserApiContractTest < ActionDispatch::IntegrationTest
  SURFACE_HOST_KEYS = { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.freeze
  PREFERENCE_CLASSES = { "app" => AppPreference, "com" => ComPreference, "org" => OrgPreference }.freeze

  # Only Base renders controls for the realms it writes.
  ENDPOINTS =
    %w(base auth core warp).product(%w(app com org)).filter_map do |family, surface|
      controls =
        begin
          PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
        rescue KeyError
          next
        end
      next if controls.theme_endpoint_path.nil?

      {
        label: "#{family}/#{surface}",
        surface: surface,
        host: ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL"),
        theme: controls.theme_endpoint_path,
        cookie: controls.cookie_endpoint_path,
      }
    end.freeze

  JSON_HEADERS = { "Accept" => "application/json", "Content-Type" => "application/json" }.freeze
  PROBLEM_TYPE = "application/problem+json"

  # Equivalence partitions of the `theme` member. Accepted: the three names (case-insensitive) and the
  # wire codes. Refused: everything else, including the sentinels of a JSON body.
  ACCEPTED_THEMES = { "dark" => "dr", "light" => "li", "system" => "sy", "DARK" => "dr", "dr" => "dr" }.freeze
  REFUSED_THEME_BODIES = {
    "missing member" => {},
    "null" => { theme: nil },
    "empty string" => { theme: "" },
    "whitespace" => { theme: " " },
    "padded name" => { theme: " dark " },
    "unknown name" => { theme: "sepia" },
    "escaped NUL" => { theme: "\u0000" },
    "number 0" => { theme: 0 },
    "boolean" => { theme: false },
    "array" => { theme: ["dark"] },
    "object" => { theme: { name: "dark" } },
  }.freeze

  # Accepted boolean spellings are the existing contract: true/false, 1/0, "1"/"0", "true"/"false",
  # "t"/"f" and their upper-case forms. The boundary cases are the neighbors that are not on the list.
  ACCEPTED_CONSENT_BODIES = {
    "booleans" => { cookie: { consented: true, functional: false, performant: false, targetable: false } },
    "integer 0 and 1" => { cookie: { consented: 1, functional: 0 } },
    "string 0" => { cookie: { consented: "0" } },
    "string false and true" => { cookie: { consented: "false", functional: "true" } },
    "upper-case spelling" => { cookie: { consented: "TRUE", targetable: "F" } },
    "top-level consented" => { consented: "t" },
    "unknown keys ignored" => { cookie: { consented: true, analytics: "yes" }, extra: 1 },
  }.freeze
  REFUSED_CONSENT_BODIES = {
    "no body members" => [{}, ["/cookie/consented"]],
    "cookie without consented" => [{ cookie: { functional: true } }, ["/cookie/consented"]],
    "cookie null" => [{ cookie: nil }, ["/cookie/consented"]],
    "cookie string" => [{ cookie: "yes" }, ["/cookie"]],
    "cookie array" => [{ cookie: [true] }, ["/cookie"]],
    "consented null" => [{ cookie: { consented: nil } }, ["/cookie/consented"]],
    "consented empty string" => [{ cookie: { consented: "" } }, ["/cookie/consented"]],
    "consented whitespace" => [{ cookie: { consented: " " } }, ["/cookie/consented"]],
    "consented integer 2" => [{ cookie: { consented: 2 } }, ["/cookie/consented"]],
    "consented integer -1" => [{ cookie: { consented: -1 } }, ["/cookie/consented"]],
    "consented yes" => [{ cookie: { consented: "yes" } }, ["/cookie/consented"]],
    "consented escaped NUL" => [{ cookie: { consented: "\u0000" } }, ["/cookie/consented"]],
    "consented array" => [{ cookie: { consented: [true] } }, ["/cookie/consented"]],
    "consented object" => [{ cookie: { consented: { value: true } } }, ["/cookie/consented"]],
    "functional invalid" => [{ cookie: { consented: true, functional: "maybe" } }, ["/cookie/functional"]],
    "several invalid" => [{ cookie: { consented: true, performant: [], targetable: "x" } },
                          ["/cookie/performant", "/cookie/targetable"],],
    "top-level consented null" => [{ consented: nil }, ["/consented"]],
  }.freeze

  test "GET answers JSON, no-store, and writes no preference row" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)
      preference_class = PREFERENCE_CLASSES.fetch(endpoint.fetch(:surface))

      assert_no_difference -> { preference_class.count }, endpoint.fetch(:label) do
        get endpoint.fetch(:theme), headers: { "Accept" => "application/json" }

        assert_response :ok, endpoint.fetch(:label)
        assert_equal "application/json", response.media_type, endpoint.fetch(:label)
        assert_equal "no-store", response.headers["Cache-Control"], endpoint.fetch(:label)
        assert_includes %w(sy li dr), response.parsed_body.fetch("theme"), endpoint.fetch(:label)

        get endpoint.fetch(:cookie), headers: { "Accept" => "application/json" }

        assert_response :ok, endpoint.fetch(:label)
        assert_equal "no-store", response.headers["Cache-Control"], endpoint.fetch(:label)
        assert_equal({ "show_banner" => true }, response.parsed_body, endpoint.fetch(:label))
      end
    end
  end

  test "Auth, Core, and Warp read default preferences without issuing or persisting state" do
    %w(auth core warp).product(%w(app org)).each do |family, surface|
      host = ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")
      host! host
      preference_class = PREFERENCE_CLASSES.fetch(surface)
      before = preference_class.count
      headers = { "Accept" => "application/json", "Cookie" => "" }

      get "/api/v0/preferences/theme", headers: headers

      assert_response :ok, "#{family}/#{surface} theme"
      assert_equal "sy", response.parsed_body.fetch("theme")
      assert_no_preference_state_cookies

      get "/api/v0/preferences/cookie", headers: headers

      assert_response :ok, "#{family}/#{surface} cookie"
      assert_equal({ "show_banner" => true }, response.parsed_body)
      assert_no_preference_state_cookies
      assert_equal before, preference_class.count
    end
  end

  # Browser callers forward the page's `ri`, so the region context is present as it is in production.
  test "a request without Accept is served" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      get endpoint.fetch(:theme), params: { ri: "jp" }

      assert_response :ok, endpoint.fetch(:label)
    end
  end

  test "PATCH theme stores each accepted spelling and answers the stored code" do
    https!
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      ACCEPTED_THEMES.each do |requested, code|
        patch endpoint.fetch(:theme), params: { theme: requested }.to_json, headers: JSON_HEADERS

        assert_response :ok, "#{endpoint.fetch(:label)} #{requested}"
        assert_equal({ "theme" => code }, response.parsed_body, "#{endpoint.fetch(:label)} #{requested}")
        assert_equal "no-store", response.headers["Cache-Control"]
        set_cookie = response.headers["Set-Cookie"].to_s

        assert_includes set_cookie, "#{PreferenceCookieName.anonymous_jwt}="
        assert_includes set_cookie, "language="
        assert_includes set_cookie, "#{PreferenceCookieName.anonymous_experience}="
        assert_not_includes set_cookie, "ct="
      end
    end
  end

  test "Base realm theme writes issue 400-day preference and shared-cookie expiries" do
    https!
    ENDPOINTS.select { |endpoint| endpoint.fetch(:label).start_with?("base/") }.each do |endpoint|
      host! endpoint.fetch(:host)
      preference_class = PREFERENCE_CLASSES.fetch(endpoint.fetch(:surface))
      issued_at = 1.hour.ago.change(usec: 0)

      preference_class.stub(:database_now, issued_at) do
        patch endpoint.fetch(:theme), params: { theme: "dark" }.to_json, headers: JSON_HEADERS
      end

      assert_response :ok, endpoint.fetch(:label)
      claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
      expected_exp = issued_at.to_i + 400.days.to_i

      assert_equal issued_at.to_i, claims.fetch("iat"), endpoint.fetch(:label)
      assert_equal expected_exp, claims.fetch("exp"), endpoint.fetch(:label)

      preference = preference_class.find_by!(public_id: claims.fetch("sub"))

      assert_equal issued_at, preference.last_issued_at, endpoint.fetch(:label)
      assert_equal Time.at(expected_exp).utc, preference.last_issued_expires_at, endpoint.fetch(:label)

      cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
      [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
       PreferenceCookieName.anonymous_experience,].each do |name|
        header = cookie_headers.find { |entry| entry.start_with?("#{name}=") }

        assert_not_nil header, "#{endpoint.fetch(:label)} #{name}"
        assert_equal Time.at(expected_exp).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1]),
                     "#{endpoint.fetch(:label)} #{name}"
      end
    end
  end

  test "PATCH theme refuses every other value with a 422 pointing at /theme" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      REFUSED_THEME_BODIES.each do |name, body|
        patch endpoint.fetch(:theme), params: body.to_json, headers: JSON_HEADERS

        label = "#{endpoint.fetch(:label)} #{name}"

        assert_response :unprocessable_content, label
        assert_validation_problem(["/theme"], label)
      end
    end
  end

  test "PATCH cookie returns the recorded decision for every Base realm" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      ACCEPTED_CONSENT_BODIES.each do |name, body|
        patch endpoint.fetch(:cookie), params: body.to_json, headers: JSON_HEADERS

        assert_response :ok, "#{endpoint.fetch(:label)} #{name}"
        assert_kind_of Hash, response.parsed_body.fetch("cookie"), "#{endpoint.fetch(:label)} #{name}"

        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "PATCH cookie refuses a missing or unreadable decision with a 422 naming each field" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      REFUSED_CONSENT_BODIES.each do |name, (body, pointers)|
        patch endpoint.fetch(:cookie), params: body.to_json, headers: JSON_HEADERS

        label = "#{endpoint.fetch(:label)} #{name}"

        assert_response :unprocessable_content, label
        assert_validation_problem(pointers, label)
      end
    end
  end

  test "a body that is not JSON is a 400 problem, including a raw NUL byte" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      [[endpoint.fetch(:theme), '{"theme": '], [endpoint.fetch(:cookie), "{\"cookie\": {\"consented\": \"\0\"}}"],
       [endpoint.fetch(:theme), "[1, 2"],].each do |path, raw|
        patch path, params: raw, headers: JSON_HEADERS

        assert_response :bad_request, "#{endpoint.fetch(:label)} #{raw.inspect}"
        assert_problem("bad-request", 400)
      end
    end
  end

  test "a body that is not declared as application/json is a 415 problem" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      ["text/plain", "application/x-www-form-urlencoded"].each do |content_type|
        patch endpoint.fetch(:theme), params: "theme=dark",
                                      headers: { "Accept" => "application/json", "Content-Type" => content_type }

        assert_response :unsupported_media_type, "#{endpoint.fetch(:label)} #{content_type}"
        assert_problem("unsupported-media-type", 415)
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "an Accept that excludes JSON is a 406 problem" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      get endpoint.fetch(:cookie), headers: { "Accept" => "text/html" }

      assert_response :not_acceptable, endpoint.fetch(:label)
      assert_problem("not-acceptable", 406)
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "a cross-site PATCH without a valid CSRF token is forbidden and changes nothing" do
    with_forgery_protection do
      ENDPOINTS.each do |endpoint|
        host! endpoint.fetch(:host)

        [[endpoint.fetch(:theme), { theme: "dark" }],
         [endpoint.fetch(:cookie), { cookie: { consented: true } }],].each do |path, body|
          patch path, params: body.to_json, headers: JSON_HEADERS.merge("Sec-Fetch-Site" => "cross-site")

          if endpoint.fetch(:label).start_with?("auth/", "base/")
            assert_response :forbidden, "#{endpoint.fetch(:label)} #{path}"
            assert_problem("csrf-verification-failed", 403)
          else
            assert_response :unprocessable_content, "#{endpoint.fetch(:label)} #{path}"
            assert_nil response.headers["Location"]
          end

          assert_not_includes response.headers["Set-Cookie"].to_s, "#{"ct"}=dr"
        end
      end
    end
  end

  # API standard: 406 and 415 are decided before CSRF and before any credential is read.
  test "media-type refusals come before CSRF and credential checks" do
    with_forgery_protection do
      ENDPOINTS.each do |endpoint|
        host! endpoint.fetch(:host)
        anonymous_cookie = "#{PreferenceCookieName.anonymous_jwt}=not-a-preference-token"

        patch endpoint.fetch(:theme), params: "theme=dark",
                                      headers: { "Accept" => "application/json",
                                                 "Content-Type" => "text/plain",
                                                 "Sec-Fetch-Site" => "cross-site", }

        assert_response :unsupported_media_type, endpoint.fetch(:label)

        patch endpoint.fetch(:theme), params: { theme: "dark" }.to_json,
                                      headers: { "Accept" => "text/html",
                                                 "Content-Type" => "application/json",
                                                 "Sec-Fetch-Site" => "cross-site",
                                                 "Cookie" => anonymous_cookie, }

        assert_response :not_acceptable, endpoint.fetch(:label)
      end
    end
  end

  test "an invalid foreign-host Preference JWT is never used to seed a Base write" do
    https!
    ENDPOINTS.each do |endpoint|
      # Section 4.2: realm is the token audience. A valid token from the other realm must not
      # become an input source for this realm's write.
      next if endpoint.fetch(:surface) == "com"

      host = endpoint.fetch(:host)
      host! host
      foreign_surface = (endpoint.fetch(:surface) == "app") ? "org" : "app"
      foreign_endpoint =
        ENDPOINTS.find do |candidate|
          candidate.fetch(:label) == "base/#{foreign_surface}"
        end
      foreign = preference_token_for(
        host: foreign_endpoint.fetch(:host),
        surface: foreign_surface,
      )
      foreign_subject = JWT.decode(foreign, nil, false).first.fetch("sub")
      preference_class = PREFERENCE_CLASSES.fetch(endpoint.fetch(:surface))

      assert_nil preference_class.find_by(public_id: foreign_subject), endpoint.fetch(:label)
      # Sent as a header: the integration cookie jar would scope a cookie to the previous host.
      headers = JSON_HEADERS.merge("Cookie" => "#{PreferenceCookieName.anonymous_jwt}=#{foreign}")

      with_preference_realm_issuers do
        patch endpoint.fetch(:theme), params: { theme: "dark" }.to_json, headers: headers

        assert_response :ok, endpoint.fetch(:label)
        issued_cookie = cookies[PreferenceCookieName.anonymous_jwt]

        assert_predicate issued_cookie, :present?, endpoint.fetch(:label)
        issued, = JWT.decode(issued_cookie, nil, false)

        assert_not_equal foreign_subject, issued.fetch("sub"), endpoint.fetch(:label)
        assert_equal "dark", issued.fetch("preferences").fetch("theme"), endpoint.fetch(:label)
      end
      assert_nil preference_class.find_by(public_id: foreign_subject), endpoint.fetch(:label)
    end
  end

  test "Auth, Core, and Warp keep Preference display read-only" do
    %w(auth core warp).product(%w(app org)).each do |family, surface|
      host! ENV.fetch("PUBLIC_#{family.upcase}_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")

      patch "/api/v0/preferences/theme", params: { theme: "dark" }.to_json, headers: JSON_HEADERS

      assert_response :forbidden, "#{family}/#{surface} theme write"
      assert_no_preference_state_cookies

      patch "/api/v0/preferences/cookie", params: { consented: true }.to_json, headers: JSON_HEADERS

      assert_response :forbidden, "#{family}/#{surface} consent write"
      assert_no_preference_state_cookies
    end
  end

  test "an anonymous com token is readable on another com host and is not a credential in another realm" do
    com_endpoint = ENDPOINTS.find { |endpoint| endpoint.fetch(:surface) == "com" }
    https!
    host! com_endpoint.fetch(:host)
    patch com_endpoint.fetch(:theme), params: { theme: "dark" }.to_json, headers: JSON_HEADERS

    assert_response :ok
    com_token = cookies[PreferenceCookieName.anonymous_jwt]
    com_public_id = JWT.decode(com_token, nil, false).first.fetch("sub")

    assert_equal com_public_id, PreferenceToken.decode(com_token, host: "www-jp.umaxica.com").fetch("sub")
    %w(app org).each do |surface|
      endpoint = ENDPOINTS.find { |candidate| candidate.fetch(:label) == "base/#{surface}" }
      host! endpoint.fetch(:host)
      headers = { "Accept" => "application/json", "Cookie" => "#{PreferenceCookieName.anonymous_jwt}=#{com_token}" }
      get endpoint.fetch(:theme), headers: headers

      assert_response :ok, endpoint.fetch(:label)
      assert_equal "sy", response.parsed_body.fetch("theme"), endpoint.fetch(:label)
      assert_nil PreferenceToken.decode(com_token, host: endpoint.fetch(:host))
    end
  end

  # Anonymous visitors use these endpoints; the absence of a credential is not a refusal.
  test "a PATCH with no preference credential at all is served" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      patch endpoint.fetch(:cookie), params: { cookie: { consented: true } }.to_json, headers: JSON_HEADERS

      assert_response :ok, endpoint.fetch(:label)
      assert_kind_of Hash, response.parsed_body.fetch("cookie"), endpoint.fetch(:label)
    end
  end

  test "the endpoints are not served for PUT or on a host of another family" do
    ENDPOINTS.each do |endpoint|
      host! endpoint.fetch(:host)

      put endpoint.fetch(:theme), params: { theme: "dark" }.to_json, headers: JSON_HEADERS

      assert_response :not_found, "#{endpoint.fetch(:label)} PUT"
    end

    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    get ENDPOINTS.first.fetch(:theme), headers: { "Accept" => "application/json" }

    assert_response :not_found
  end

  test "the negotiation filters run exactly once and ahead of forgery protection" do
    [
      Base::App::Api::V0::Preferences::ThemesController,
      Auth::Org::Api::V0::Preferences::CookiesController,
      Core::Org::Api::V0::Preferences::ThemesController,
      Warp::App::Api::V0::Preferences::CookiesController,
    ].each do |controller|
      filters = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      %i(enforce_api_acceptable_response_type! enforce_api_request_media_type!
         set_preference_browser_api_no_store!).each do |filter|
        assert_equal 1, filters.count(filter), "#{controller.name} #{filter}"
      end
      assert_operator filters.index(:enforce_api_request_media_type!), :<, filters.index(:verify_authenticity_token),
                      controller.name
    end
  end

  private

  def assert_no_preference_state_cookies
    set_cookie = response.headers["Set-Cookie"].to_s

    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceCookieName.binding, PreferenceIoKeys::Cookies::LANGUAGE,].each do |name|
      assert_not_includes set_cookie, "#{name}=", name
    end
  end

  def assert_problem(slug, status)
    assert_equal PROBLEM_TYPE, response.media_type
    body = response.parsed_body

    assert_equal "#{ProblemType::NAMESPACE}:#{slug}", body.fetch("type")
    assert_equal status, body.fetch("status")
  end

  def assert_validation_problem(pointers, label)
    assert_problem("validation-failed", 422)
    errors = response.parsed_body.fetch("errors")

    assert_equal pointers, errors.map { |error| error.fetch("pointer") }, label
    errors.each { |error| assert_equal PreferenceBrowserApi::INVALID_FIELD_TYPE, error.fetch("type"), label }
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def preference_token_for(host:, surface:)
    token = nil
    preferences = {
      "theme" => "system",
      "language" => "ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }
    with_preference_realm_issuers do
      token = PreferenceToken.encode(
        preferences,
        host: host,
        preference_type: PREFERENCE_CLASSES.fetch(surface).name,
        jwt_issuer_id: "preference_#{surface}",
        public_id: "foreign-#{SecureRandom.hex(4)}",
        jti: "test-jti-#{SecureRandom.uuid}",
        issued_at: Time.current,
      )
    end
    token
  end
end
