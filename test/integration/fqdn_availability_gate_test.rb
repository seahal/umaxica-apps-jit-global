# typed: false
# frozen_string_literal: true

require "test_helper"

# Behaviour contract for the per-FQDN availability kill switch.
#
# The switch is only worth having if it fails closed and if it runs before everything it is supposed
# to protect, so both properties are asserted directly rather than inferred from a status code.
class FqdnAvailabilityGateTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    @host = configured_host(:base_service)
    @slot = FqdnAvailabilityRegistry.slot_for(@host)
    @flag = FqdnAvailabilityRegistry.flag_name_for(@slot)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "the registry resolves a served hostname to exactly one slot" do
    assert_equal :base_service, @slot
    assert_equal :fqdn_available_base_service, @flag
    assert_nil FqdnAvailabilityRegistry.slot_for("not-served.example.com")
    assert_nil FqdnAvailabilityRegistry.slot_for(nil)
  end

  test "every slot has a registered availability flag" do
    FqdnAvailabilityRegistry::SLOT_NAMES.each do |slot|
      flag = FeatureFlags.fetch(FqdnAvailabilityRegistry.flag_name_for(slot))

      assert_equal :availability, flag.polarity, "#{slot} must fail closed"
    end
  end

  test "an enabled FQDN serves the request" do
    Flipper.enable(@flag)

    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success
  end

  test "an explicitly disabled FQDN is refused with 503" do
    Flipper.disable(@flag)

    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :service_unavailable
    assert_equal "60", response.headers["Retry-After"]
  end

  # Availability polarity: a flag store that was never written must not read as permission.
  test "an FQDN whose feature was never written is refused with 503" do
    Flipper.remove(@flag)

    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :service_unavailable
  end

  # A hostname the application does not serve never matches a `constraints(host:)` block, so routing
  # rejects it before any controller exists to consult a switch. That is the outer fail-closed layer.
  test "an unknown Host is never routed to a surface" do
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: as_user_headers(@user, host: @host).merge("Host" => "unlisted.example.com"),
    )

    assert_response :not_found
  end

  # The inner layer: if a host ever becomes routable without being registered -- a new
  # `constraints(host:)` entry added without a registry entry -- the gate must refuse rather than
  # serve, and must not attempt to derive a feature name from the header.
  test "a routable host with no registry entry is refused with 503" do
    FqdnAvailabilityRegistry.stub(:slot_for, nil) do
      get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

      assert_response :service_unavailable
      assert_includes response.body, I18n.t("errors.fqdn_availability.unavailable")

      get(
        base_app_groups_url(ri: "jp", host: @host, format: :json),
        headers: as_user_headers(@user, host: @host),
      )

      assert_equal "unknown_fqdn", response.parsed_body.fetch("error")
    end
  end

  # A flag store that cannot answer is not permission to continue.
  test "a flag store failure fails closed" do
    FeatureFlags.stub(:enabled?, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))
    end

    assert_response :service_unavailable
  end

  test "a JSON client is refused with 503 and a machine readable reason" do
    Flipper.disable(@flag)

    get(
      base_app_groups_url(ri: "jp", host: @host, format: :json),
      headers: as_user_headers(@user, host: @host),
    )

    assert_response :service_unavailable
    assert_equal "fqdn_unavailable", response.parsed_body.fetch("error")
    assert_equal "base_service", response.parsed_body.fetch("surface")
  end

  # The point of running first is that the request costs nothing downstream. A 503 that had already
  # spent a rate-limit token would still let an attacker exhaust the budget of a surface that is
  # supposed to be switched off.
  test "a disabled FQDN never reaches the rate limiter" do
    Flipper.disable(@flag)
    store = Rails.configuration.x.rate_limit.fetch(:store)
    increments = 0

    store.stub(:increment, ->(*_args, **_options) { increments += 1 }) do
      get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))
    end

    assert_response :service_unavailable
    assert_equal 0, increments, "the rate limiter must not have counted a request it never saw"
  end

  test "a disabled FQDN never reaches the controller action" do
    Flipper.disable(@flag)

    # AvatarGroup is loaded by the action and by nothing ahead of it in the chain.
    group_queries = 0
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        group_queries += 1 if payload[:sql].to_s.include?("avatar_groups")
      end

    begin
      get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_response :service_unavailable
    assert_equal 0, group_queries, "the controller action must not run for a switched-off FQDN"
  end

  # An unauthenticated request to a switched-off surface must report the surface as unavailable, not
  # send the visitor into a credential ceremony for a surface that cannot serve them.
  test "a disabled FQDN is refused before the authentication redirect" do
    Flipper.disable(@flag)

    get(base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host))

    assert_response :service_unavailable
    assert_nil response.headers["Location"]
  end

  # Ordering is a property of the callback chain, so assert it on the chain rather than trusting a
  # status code to imply it.
  test "the gate is registered before rate limiting on every gated controller" do
    gated_controllers.each do |controller|
      names = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)
      gate_index = names.index(:enforce_fqdn_availability!)

      assert gate_index, "#{controller} includes the gate but has no gate callback"

      rate_limit_index = names.index { |filter| filter.to_s.include?("rate_limit") || filter.is_a?(Proc) }

      next if rate_limit_index.nil?

      assert_operator gate_index, :<, rate_limit_index,
                      "#{controller} must consult the FQDN switch before spending rate-limit budget"
    end
  end

  # The one exception is `DefaultNoStore#apply_default_no_store` on Global and Publishing policy
  # roots (adr/global-and-publishing-default-no-store-policy.md). It only replaces the in-memory
  # cache directives of the response, so it spends no rate-limit budget and touches no state, and
  # running it first is what puts `no-store` on the 503 this gate renders.
  test "the gate is the very first before_action on every gated controller" do
    gated_controllers.each do |controller|
      filters = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)
      filters = filters.drop(1) if filters.first == :apply_default_no_store

      assert_equal :enforce_fqdn_availability!, filters.first,
                   "#{controller} must not run anything ahead of the availability switch"
    end
  end

  # Internal probes are how an operator finds out why a surface is down. Switching the surface off
  # must not switch off the reporting. See adr/internal-health-endpoint-edge-isolation.md.
  test "health endpoints keep answering while their FQDN is switched off" do
    Flipper.disable(@flag)

    get(base_app_health_url(host: @host), headers: host_headers(@host))

    assert_response :success

    get(base_app_health_liveness_url(host: @host), headers: host_headers(@host))

    assert_response :success
  end

  private

  def gated_controllers
    controllers =
      ObjectSpace.each_object(Class).select do |klass|
        klass < ActionController::Base && klass.include?(FqdnAvailabilityGate)
      end

    assert_predicate controllers, :any?, "no controller includes the gate"

    controllers
  end

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
