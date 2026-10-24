# typed: false
# frozen_string_literal: true

require "test_helper"

# WU-06 (REQ-CURFEW 3, D-160): an admitted Sign-in path request is allowed before the Binding's
# curfew and refused at it and after it. The owner's own browser leaves through the Cancel exit and
# the RP receives access_denied with its unchanged state; a browser without the ceremony gets the
# uniform error. Boundaries are set relative to the Binding's own OP database clock.
class AdmissionCurfewTest < ActionDispatch::IntegrationTest
  setup do
    ri = "jp"
    @base_browser = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/sign", params: { ri: ri, pt: "/dashboard?ri=#{ri}" })
    form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    current_browser = @base_browser
    current_host = base_host
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      target = URI.parse(jump_rt_url_from_location_for_test(target.to_s)) if target.host == jump_host

      case target.host
      when base_host
        @base_browser.host!(base_host)
        @base_browser.https!
        @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = @base_browser
        current_host = base_host
      when visa_host_for_test_base_host(base_host)
        @base_browser.host!(target.host)
        @base_browser.https!
        @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = @base_browser
        current_host = target.host
      when auth_host
        host!(auth_host)
        https!
        get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = self
        current_host = auth_host
      else
        raise RuntimeError, "Unexpected curfew bootstrap host: #{target.host.inspect}"
      end
    end

    raise RuntimeError, "Curfew setup did not reach Auth" unless current_browser.equal?(self)
    raise RuntimeError, "Curfew setup did not render Auth entry" unless response.successful?

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @binding = ClientAuthAdmissionBinding.where.not(admitted_auth_ceremony_session_id: nil).order(:id).last
    @transaction = ClientOidcAuthorizationTransaction.find(@binding.authorization_transaction_id)
  end

  test "an admitted page one minute before the curfew is served" do
    move_curfew!(1.minute)
    get "/sign/in", params: { ri: "jp" }

    assert_response :success
  end

  [0, -1].each do |offset|
    test "the owner's browser #{offset.zero? ? "at" : "one second after"} the curfew leaves with access_denied" do
      move_curfew!(offset.seconds)
      before_tokens = ClientToken.count
      get "/sign/in", params: { ri: "jp" }

      assert_response :see_other
      target = URI.parse(jump_rt_url_from_location_for_test(response.location))
      @base_browser.host!(target.host)
      @base_browser.https!
      @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))

      assert_response :see_other
      target = URI.parse(jump_rt_url_from_location_for_test(@base_browser.response.location))
      query = Rack::Utils.parse_query(target.query)

      assert_equal [303, "access_denied", @transaction.state],
                   [@base_browser.response.status, query["error"], query["state"]]
      assert_equal "canceled", @transaction.reload.status
      assert_equal before_tokens, ClientToken.count
    end
  end

  test "a social Admission is still usable after the 60 second acceptance expiry within the curfew" do
    # F5: the Binding's acceptance expiry has passed, the curfew has not.
    @binding.update_columns(expires_at: ClientAuthAdmissionBinding.database_now - 1.minute)
    move_curfew!(5.minutes)
    post auth_app_social_google_session_path(ri: "jp")

    assert_response :temporary_redirect
  end

  test "a browser without the ceremony after the curfew gets the uniform error and ends nothing" do
    move_curfew!(-1.second)
    stranger = open_session
    stranger.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    stranger.https!
    stranger.get("/sign/in", params: { ri: "jp" })

    assert_not_equal 303, stranger.response.status
    assert_equal "pending", @transaction.reload.status
  end

  test "the owner's browser after the curfew without its authorization transaction gets the uniform error" do
    move_curfew!(-1.second)
    # A06-9: the Admission keeps pointing at a transaction row that is gone.
    OpBaseAppRecord.connected_to(role: :writing) do
      @transaction.class.connection.execute("SET session_replication_role = replica")
      @transaction.class.where(id: @transaction.id).delete_all
      @transaction.class.connection.execute("SET session_replication_role = origin")
    end
    get "/sign/in", params: { ri: "jp" }

    assert_response :bad_request
  end

  private

  def navigation_headers(site:)
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end

  def move_curfew!(offset)
    @binding.update_columns(curfew_at: ClientAuthAdmissionBinding.database_now + offset)
  end
end
