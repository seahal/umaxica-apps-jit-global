# frozen_string_literal: true

require "test_helper"

class Visa::App::SignByesControllerTest < ActionController::TestCase
  fixtures :clients

  setup do
    @request.host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    @request.env["HTTPS"] = "on"
    @request.headers["Sec-Fetch-Site"] = "same-origin"
    @request.headers["Origin"] = "https://#{@request.host}"
    root = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    @result = OpAuthorityStopCommitter.stop_root(
      root:, cause: "browser_logout", principal_public_id: clients(:one).public_id, authority_evidence_ref: "a",
      browser_binding: "b",
    )
    @stored = {
      "stop" => @result.stop.public_id,
      "realm" => "app",
      "nonce" => @result.receipt_nonce,
      "browser_binding" => "b",
    }
  end

  test "without a receipt in this browser there is nothing to show or consume" do
    get :show, params: { ri: "jp" }

    assert_response :not_found
    post :create, params: { ri: "jp" }

    assert_response :not_found
  end

  test "GET reads the committed outcome without consuming the receipt" do
    get :show, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }

    assert_response :ok
    assert response.parsed_body.fetch("op_logout_established")
    assert_not receipt_record.receipt_consumed
  end

  test "POST consumes the one-time receipt once; a replay of the same receipt is refused" do
    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }

    assert_response :ok
    assert response.parsed_body.fetch("receipt_consumed")
    assert receipt_record.receipt_consumed

    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }

    assert_response :not_found
  end

  test "a receipt with a wrong nonce is refused" do
    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored.merge("nonce" => "forged") }

    assert_response :not_found
  end

  test "a receipt presented from another browser binding is refused" do
    post :create, params: { ri: "jp" },
                  session: { OpLogoutReceiptSession::KEY => @stored.merge("browser_binding" => "other-browser") }

    assert_response :not_found
    assert_not receipt_record.receipt_consumed
  end

  test "another realm receipt cannot select that realm's OP store from this surface" do
    foreign = @stored.merge("realm" => "org")
    OpOrgAuthorityStop.stub(:find_by!, ->(**) { flunk("app completion must not query the org OP") }) do
      OpOrgAuthorityStop.stub(:find_by, ->(**) { flunk("app completion must not query the org OP") }) do
        get :show, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => foreign }

        assert_response :not_found
        post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => foreign }

        assert_response :not_found
      end
    end

    assert_not receipt_record.receipt_consumed
  end

  test "receipt consumption checks fresh writer expiry immediately before at and after the cutoff" do
    now = Time.current.change(usec: 0) + 30
    receipt = receipt_record
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      receipt.update!(receipt_expires_at: now + offset)
      OpAppAuthorityStopBrowserLogout.stub(:database_now, now) do
        post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }
      end

      assert_response offset.positive? ? :ok : :not_found
      assert_equal offset.positive?, receipt.reload.receipt_consumed
    end
  end

  private

  def receipt_record
    OpAppAuthorityStopBrowserLogout.find_by!(stop_id: @result.stop.id)
  end
end
