# typed: false
# frozen_string_literal: true

require "test_helper"

class RpSessionTest < ActiveSupport::TestCase
  CASES = [
    {
      name: "client",
      model: ClientRpSession,
      root_model: ClientToken,
      root_builder: -> {
        client = Client.create!
        ClientToken.create!(user: client)
      },
      parent_key: :client_token_id,
      parent_label: :client_token,
    },
    {
      name: "operator",
      model: OperatorRpSession,
      root_model: OperatorToken,
      root_builder: -> {
        operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
        OperatorToken.create!(staff: operator)
      },
      parent_key: :operator_token_id,
      parent_label: :operator_token,
    },
    {
      name: "visitor",
      model: VisitorRpSession,
      root_model: VisitorToken,
      root_builder: -> {
        VisitorStatus.ensure_defaults!
        VisitorVisibility.ensure_defaults!
        visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
        VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      },
      parent_key: :visitor_token_id,
      parent_label: :visitor_token,
    },
  ].freeze

  CASES.each do |rp_session_case|
    test "#{rp_session_case[:name]} rp session generates a public id and validates parent and rp identity" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_predicate session.public_id, :present?
      assert_equal 21, session.public_id.length
      assert_predicate session.public_id, :ascii_only?
      assert_equal root.id, session.public_send(rp_session_case[:parent_key])
      assert_equal "core-next-rp", session.oidc_client_id
      assert_predicate session, :active?
    end

    test "#{rp_session_case[:name]} rp session enforces active parent and RP uniqueness" do
      root = rp_session_case[:root_builder].call
      first = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_raises(ActiveRecord::RecordNotUnique) do
        rp_session_case[:model].create!(
          rp_session_case[:parent_label] => root,
          :oidc_client_id => "core-next-rp",
          :oidc_scope => "openid profile",
          :refresh_token_expires_at => 1.hour.from_now,
        )
      end

      first.update!(revoked_at: Time.current)

      replacement = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid email",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_predicate replacement, :persisted?
      assert_equal root.id, replacement.public_send(rp_session_case[:parent_key])
      assert_equal "openid email", replacement.oidc_scope
    end

    test "#{rp_session_case[:name]} rp session is deleted when the parent root is physically deleted" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_difference -> { rp_session_case[:model].count }, -1 do
        rp_session_case[:root_model].delete(root.id)
      end

      assert_not rp_session_case[:model].exists?(session.id)
    end

    test "#{rp_session_case[:name]} rp session rotates refresh tokens without exposing raw secrets" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      raw_refresh_token = session.issue_refresh_token!

      assert_predicate raw_refresh_token, :present?
      assert_predicate session.refresh_token_digest, :present?
      assert_predicate session.refresh_token_digest, :ascii_only?
      assert session.authenticate_refresh_token(raw_refresh_token.split(".", 2).last)
      assert_not session.authenticate_refresh_token("wrong-verifier")
    end

    test "#{rp_session_case[:name]} rp session refresh expiry cannot exceed its root session" do
      root = rp_session_case[:root_builder].call
      absolute_expiry = 1.hour.from_now
      root.update!(discarded_at: absolute_expiry)
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => absolute_expiry + 1.day,
      )

      session.issue_refresh_token!(expires_at: absolute_expiry + 2.days)

      assert_operator session.reload.refresh_token_expires_at, :<=, absolute_expiry
      assert_equal absolute_expiry.to_i, session.refresh_token_expires_at.to_i

      session.rotate_refresh_token!(expires_at: absolute_expiry + 3.days)

      assert_operator session.reload.refresh_token_expires_at, :<=, absolute_expiry
      assert_equal absolute_expiry.to_i, session.refresh_token_expires_at.to_i
    end

    test "#{rp_session_case[:name]} rp session detects a replay of the digest superseded by rotation" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      superseded_verifier = session.issue_refresh_token!.split(".", 2).last

      # Nothing has been rotated away yet, so no verifier can be a replay.
      assert_not session.previous_refresh_token_digest_matches?(superseded_verifier)

      current_verifier = session.rotate_refresh_token!.split(".", 2).last

      assert session.previous_refresh_token_digest_matches?(superseded_verifier)
      assert_not session.previous_refresh_token_digest_matches?(current_verifier)
      assert_not session.authenticate_refresh_token(superseded_verifier)
      assert session.authenticate_refresh_token(current_verifier)
    end

    test "#{rp_session_case[:name]} rp session refuses access-token expiry recording after revoke" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )
      session.revoke!(status: "success")

      assert_raises(RpSession::IssuanceRejected) do
        session.record_access_token_expiry!(10.minutes.from_now)
      end
      assert_nil session.reload.oidc_access_token_max_expires_at
    end

    test "#{rp_session_case[:name]} rp session refuses refresh issuance after revoke" do
      root = rp_session_case[:root_builder].call
      session = rp_session_case[:model].create!(
        rp_session_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )
      session.revoke!(status: "success")

      assert_raises(RpSession::IssuanceRejected) do
        session.issue_refresh_token!
      end
      assert_nil session.reload.refresh_token_digest
    end
  end

  test "the retirement deadline uses the maximum recorded access-token expiry" do
    root = CASES.fetch(0).fetch(:root_builder).call
    session = ClientRpSession.create!(
      client_token: root,
      oidc_client_id: "core-next-rp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    later = 10.minutes.from_now
    earlier = 2.minutes.from_now

    session.record_access_token_expiry!(later)
    session.record_access_token_expiry!(earlier)

    assert_equal later.to_i, session.reload.oidc_access_token_max_expires_at.to_i
    assert_equal(
      (later + SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS).to_i,
      session.access_token_retirement_deadline.to_i,
    )
    assert_predicate session, :retirement_pending?
  end
end
