# frozen_string_literal: true

if ENV["COVERAGE"] == "true"
  # `require "simplecov"` already loads ./.simplecov, and that file loads the
  # "rails" profile along with the rest of the configuration. Passing the
  # profile to `start` as well would apply it a second time (only duplicating
  # filters, but splitting the configuration across two places). Keep .simplecov
  # as the single source of configuration and let `start` just begin tracking.
  require "simplecov"
  SimpleCov.start
end

ENV["RAILS_ENV"] ||= "test"
# Host names are deliberately NOT set here. This file is read after the application has
# already booted whenever the runner boots first (`bin/rails test` with no path argument,
# which is the documented command), and config/application.rb freezes
# Rails.configuration.x.boot_config from ENV at boot. An assignment made here therefore
# reaches ENV but never boot_config, leaving two disagreeing sources of truth for the same
# host and making results depend on how the suite was invoked. Host configuration belongs
# to the process environment (compose.yaml, the CI job env), which is set before boot.
# test/config/host_configuration_consistency_test.rb fails loudly if the two ever diverge.
ENV["SOCIAL_AUTH_CEREMONY_HMAC_KEY"] = "test-social-auth-ceremony-hmac-key"
ENV["SMTP_FROM_ADDRESS_APP"] = "from@umaxica.app"
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

require_relative "../config/environment"

# Build the test-mode Vite assets before anything renders a view.
#
# `config/vite.json` sets `"autoBuild": false` for test, and `/public/vite*` is gitignored, so
# nothing else in the repository guarantees that `public/vite-test` exists or is current. Every
# layout under `app/views/layouts` calls `vite_stylesheet_tag`/`vite_typescript_tag`, and
# `ViteRuby::Manifest#lookup!` raises from inside view rendering when an entry is absent, so a
# fresh checkout, a CI runner, or a run made after editing `src/` failed with an error naming an
# entrypoint instead of the missing build. Building here keeps that dependency explicit and
# satisfied in every environment.
#
# Placement matters: this runs in the parent process, before
# `ActiveSupport::TestCase.parallelize` forks workers, so one build serves the whole run instead
# of every worker racing to write the same output directory. `ViteRuby::Builder#build` compares a
# digest of the watched files against `tmp/cache/vite/last-build-test.json` and skips the Vite
# call when nothing changed, so a repeat run pays only for the digest.
unless ViteRuby.commands.build
  # rubocop:disable I18n/RailsI18n/DecorateString
  abort <<~MESSAGE
    Vite test-mode build failed, so public/vite-test has no usable manifest and every test that
    renders a layout would fail on a missing entrypoint. See the Vite output above; the same build
    runs standalone as `pnpm exec vite build --mode test`.
  MESSAGE
  # rubocop:enable I18n/RailsI18n/DecorateString
end

require "rails/test_help"
require_relative "support/parallel_test_database_cloner"
require_relative "support/external_identity_test_helper"
require_relative "support/publishing_content_helper"
require_relative "support/form_action_policy_helper"
require_relative "support/fetch_metadata_defaults"
require_relative "support/turnstile_verifier_stub"
require_relative "support/outbound_http_stub"
require_relative "support/login_cooldown_helper"
require_relative "support/inertia_page_object"
require_relative "support/rate_limit_store_override"

# Inject the Turnstile stub for the whole suite. Application code resolves the verifier
# through Turnstile::VerifierFactory, so no production class knows about the test suite.
Rails.application.config.x.turnstile.verifier = "TurnstileVerifierStub"

module AuthenticationHarness
  TEST_BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV.fetch("DEFAULT_URL_HOST", nil)
    headers = { "Client-Agent" => TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      user,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "client",
      session_header: "X-TEST-CURRENT-USER",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      staff,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "operator",
      session_header: "X-TEST-CURRENT-STAFF",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      visitor,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "visitor",
      session_header: "X-TEST-CURRENT-RESOURCE",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def submit_step_up_completion_if_present!(host: nil, headers: {})
    return unless respond_to?(:response) && response.media_type == "text/html"
    return unless response.body.include?("step-up-completion-form")

    form = response.parsed_body.at_css("form#step-up-completion-form")
    raise StandardError, "step-up completion form missing" unless form

    params = {}
    form.css("input").each do |input|
      name = input["name"]
      params[name] = input["value"] if name.present?
    end

    action = form["action"].to_s
    action_uri = URI.parse(action)
    completion_headers = headers.except("Host", :Host).merge(host_headers(action_uri.host.presence || host))
    post(action, params: params, headers: completion_headers)
  end

  private

  def authenticated_resource_headers(resource, host:, headers:, session_public_id:, resource_type:, session_header:)
    token_record = authentication_harness_session_token(resource, session_public_id: session_public_id)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil)
    access_token = jwt_access_token_for(
      resource,
      host: host_value,
      session_public_id: token_record.public_id,
      resource_type: resource_type,
    )

    host_headers(host)
      .merge(headers)
      .merge(
        session_header => resource.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token_record.public_id,
        "Authorization" => "Bearer #{access_token}",
        "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
        "HTTP_COOKIE" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
      )
  end

  def authentication_harness_session_token(resource, session_public_id:)
    token = authentication_harness_token_model(resource).find_by(public_id: session_public_id) \
      if session_public_id.present?
    token || authentication_harness_latest_token(resource) || authentication_harness_create_token(resource)
  end

  def authentication_harness_latest_token(resource)
    authentication_harness_token_model(resource)
      .where(authentication_harness_token_owner_column(resource) => resource.id)
      .where("discarded_at > ?", Time.current)
      .order(created_at: :desc)
      .first
  end

  def authentication_harness_create_token(resource)
    case resource
    when Client
      ClientToken.create!(
        user_id: resource.id,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      )
    when Operator
      OperatorToken.create!(
        staff_id: resource.id,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
        staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
        staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
      )
    when Visitor
      VisitorToken.create!(
        visitor_id: resource.id,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
        visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
      )
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def authentication_harness_token_model(resource)
    case resource
    when Client then ClientToken
    when Operator then OperatorToken
    when Visitor then VisitorToken
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def authentication_harness_token_owner_column(resource)
    case resource
    when Client then :user_id
    when Operator then :staff_id
    when Visitor then :visitor_id
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end

    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = (normalized.include?("base") || normalized.include?("www.")) ? "BASE" : "SIGN"
    surface =
      if resource_type == "operator" || normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif resource_type == "visitor" || normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

module ActiveSupport
  class TestCase
    include AuthenticationHarness
    include ExternalIdentityTestHelper
    include PublishingContentHelper
    include FormActionPolicyHelper
    include LoginCooldownHelper
    include OutboundHttpStub
    include RateLimitStoreOverride

    # Physical cores, not logical: measured on a 16C/32T host -- 32 workers lost more in fork +
    # per-worker DB-clone overhead than they gained.
    #
    # A coverage run uses the same workers as any other run. `.simplecov` sets
    # `merge_subprocesses true`, so SimpleCov hooks `Process._fork` and each worker records and
    # writes its own resultset for the parent to merge; before that setting existed the run had to
    # be pinned to a single worker or the forked workers' coverage was lost.
    parallel_workers = Integer(ENV.fetch("PARALLEL_WORKERS") { Concurrent.physical_processor_count.to_s }, 10)
    raise ArgumentError, "PARALLEL_WORKERS must be positive" unless parallel_workers.positive?

    fixtures :all
    ParallelTestDatabaseCloner.install!(workers: parallel_workers)
    parallelize(workers: parallel_workers, parallelize_databases: false)

    # The rate_limit backing store (config.x.rate_limit.store) is created once at
    # boot and shared by every test in the process, and its counters are keyed by
    # request IP (127.0.0.1 for all tests). The default target is a NullStore, so
    # nothing accumulates; this clear covers the window inside a test that
    # declared `counts_rate_limits!` and swapped a MemoryStore in. Mutate the same
    # instance with #clear -- replacing it would not reach controllers that
    # captured the store at class-load time.
    setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

    # Social ceremony availability is a Flipper kill switch that fails closed, so the suite's
    # baseline is every provider enabled; tests that exercise a disabled provider turn it off
    # themselves. This runs per test rather than once at boot because the in-memory adapter is
    # rebuilt whenever Flipper's instance is, which would silently drop a boot-time enable.
    setup do
      ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES
        .each_value { |feature| Flipper.enable(feature) }
    end

    # Same reasoning for the per-FQDN availability kill switch: it fails closed, so every served
    # FQDN is on by default here and a test that wants a surface switched off disables it itself.
    setup do
      FqdnAvailabilityRegistry.flag_names.each { |feature| Flipper.enable(feature) }
    end

    # I18n.locale is thread-local and is set by controller `set_locale`
    # before_actions during integration/controller tests. Those tests share
    # worker processes with model tests, so a request that leaves I18n.locale
    # at, e.g., :en would make a later model test read English validation
    # messages where it expects the default locale. Reset to the default after
    # every test so locale never leaks across the shared process.
    teardown { I18n.locale = I18n.default_locale } # rubocop:disable Rails/I18nLocaleAssignment
  end
end
