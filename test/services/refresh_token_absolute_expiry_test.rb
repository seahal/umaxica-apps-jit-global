# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenAbsoluteExpiryTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  %i(app com org).each do |surface|
    test "#{surface} refresh rotation preserves the fixed absolute session deadline" do
      travel_to Time.utc(2026, 9, 13, 9, 0) do
        token = create_token(surface, expires_at: 1.day.from_now)
        absolute_expiry = token.discarded_at
        refresh_token = token.rotate_refresh_token!(discarded_at: absolute_expiry + 1.day)

        result = AcmeRefreshTokenIssuer.call(refresh_token: refresh_token)

        assert_predicate result, :success?
        assert_equal absolute_expiry, result.token.discarded_at
        assert_equal absolute_expiry, result.previous_token.discarded_at
        assert_equal 2, result.token.refresh_token_generation
      end
    end

    test "#{surface} refresh is rejected after the absolute session deadline" do
      travel_to Time.utc(2026, 9, 13, 9, 0)
      token = create_token(surface, expires_at: 1.hour.from_now)
      absolute_expiry = token.discarded_at
      refresh_token = token.rotate_refresh_token!
      travel_to absolute_expiry + 1.second

      result = AcmeRefreshTokenIssuer.call(refresh_token: refresh_token)

      refute_predicate result, :success?
      assert_equal :inactive_token, result.reason
      refute token.reload.currently_usable?
    end
  end

  private

  def create_token(surface, expires_at:)
    case surface
    when :app
      client = clients(:one)
      client.update!(status_id: ClientStatus::ACTIVE)
      ClientToken.create!(
        user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: expires_at,
      )
    when :com
      VisitorToken.create!(
        visitor: visitors(:reserved_visitor), visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: expires_at,
      )
    when :org
      OperatorToken.create!(
        staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: expires_at,
      )
    end
  end
end
