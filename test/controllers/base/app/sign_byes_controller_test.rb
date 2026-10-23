# frozen_string_literal: true

require "test_helper"

class Base::App::SignByesControllerTest < ActionController::TestCase
  fixtures :clients

  setup do
    @request.host = URI.parse(ENV.fetch("PUBLIC_BASE_SERVICE_URL")).host || ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @request.env["HTTPS"] = "on"
    @request.headers["Sec-Fetch-Site"] = "same-origin"
    @request.headers["Origin"] = "https://#{@request.host}"
    root = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    @result = OpLogoutCommitter.call(
      realm: "app", root_token: root, idempotency_key: "k", browser_binding: "b", audit_ref: "a",
    )
    @stored = { "flow" => @result.flow.public_id, "realm" => "app", "nonce" => @result.receipt_nonce }
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
    assert_nil OpAppLogoutReceipt.find_by!(logout_flow_id: @result.flow.id).consumed_at
  end

  test "POST consumes the one-time receipt once; a replay of the same receipt is refused" do
    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }

    assert_response :ok
    assert response.parsed_body.fetch("receipt_consumed")
    assert_not_nil OpAppLogoutReceipt.find_by!(logout_flow_id: @result.flow.id).consumed_at

    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }

    assert_response :not_found
  end

  test "a receipt with a wrong nonce is refused" do
    post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored.merge("nonce" => "forged") }

    assert_response :not_found
  end

  test "another realm receipt cannot select that realm's OP store from this surface" do
    foreign = @stored.merge("realm" => "org")
    OpOrgLogoutFlow.stub(:find_by!, ->(**) { flunk("app completion must not query the org OP") }) do
      OpOrgLogoutFlow.stub(:find_by, ->(**) { flunk("app completion must not query the org OP") }) do
        get :show, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => foreign }

        assert_response :not_found
        post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => foreign }

        assert_response :not_found
      end
    end

    assert_nil OpAppLogoutReceipt.find_by!(logout_flow_id: @result.flow.id).consumed_at
  end

  test "receipt consumption checks fresh writer expiry immediately before at and after the cutoff" do
    now = Time.current.change(usec: 0) + 30
    receipt = OpAppLogoutReceipt.find_by!(logout_flow_id: @result.flow.id)
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      receipt.update!(expires_at: now + offset)
      OpAppLogoutReceipt.stub(:database_now, now) do
        post :create, params: { ri: "jp" }, session: { OpLogoutReceiptSession::KEY => @stored }
      end

      assert_response offset.positive? ? :ok : :not_found
      assert_equal offset.positive?, receipt.reload.consumed_at.present?
    end
    assert_equal now, receipt.consumed_at
  end
end
