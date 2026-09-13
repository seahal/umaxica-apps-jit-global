# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenReuseActivityRecorderTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :client_chronicle_events, :client_chronicle_levels,
           :operator_chronicle_events, :operator_chronicle_levels

  %i(app com org).each do |surface|
    test "#{surface} refresh reuse writes only non-secret family metadata" do
      token = create_token(surface)
      raw_refresh_token = token.rotate_refresh_token!

      assert RefreshTokenReuseActivityRecorder.call(token: token, result: "token_family_revoked")

      event_model = surface == :org ? OperatorChronicle : ClientChronicle
      event_id = surface == :org ? OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED : ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
      record = ChronicleRecord.connected_to(role: :writing) do
        event_model.where(event_id: event_id, subject_id: activity_subject_id(token)).order(occurred_at: :desc).first
      end

      assert_predicate record, :present?
      context = record.context.deep_stringify_keys
      assert_equal %w(generation result surface token_family_id), context.keys.sort
      assert_equal surface.to_s, context.fetch("surface")
      assert_equal "token_family_revoked", context.fetch("result")
      refute_includes context.values.join(" "), raw_refresh_token
      refute_includes context.values.join(" "), token.refresh_token_digest.to_s
    end
  end

  private

  def create_token(surface)
    case surface
    when :app
      client = clients(:one)
      client.update!(status_id: ClientStatus::ACTIVE)
      ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
                           user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now)
    when :com
      VisitorToken.create!(visitor: visitors(:reserved_visitor), visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
                            visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now)
    when :org
      OperatorToken.create!(staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
                             staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 1.day.from_now)
    end
  end

  def activity_subject_id(token)
    return token.user_id if token.respond_to?(:user_id)
    return token.visitor_id if token.respond_to?(:visitor_id)

    token.staff_id
  end
end
