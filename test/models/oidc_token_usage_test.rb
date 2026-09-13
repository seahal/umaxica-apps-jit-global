# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcTokenUsageTest < ActiveSupport::TestCase
  CASES = [
    {
      name: "client",
      model: ClientTokenUsage,
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
      model: OperatorTokenUsage,
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
      model: VisitorTokenUsage,
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

  CASES.each do |usage_case|
    test "#{usage_case[:name]} usage generates a public id and validates parent and rp identity" do
      root = usage_case[:root_builder].call
      usage = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_predicate usage.public_id, :present?
      assert_equal 21, usage.public_id.length
      assert_predicate usage.public_id, :ascii_only?
      assert_equal root.id, usage.public_send(usage_case[:parent_key])
      assert_equal "core-next-rp", usage.oidc_client_id
      assert_predicate usage, :active?
    end

    test "#{usage_case[:name]} usage enforces active parent and RP uniqueness" do
      root = usage_case[:root_builder].call
      first = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_raises(ActiveRecord::RecordNotUnique) do
        usage_case[:model].create!(
          usage_case[:parent_label] => root,
          :oidc_client_id => "core-next-rp",
          :oidc_scope => "openid profile",
          :refresh_token_expires_at => 1.hour.from_now,
        )
      end

      first.update!(revoked_at: Time.current)

      replacement = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid email",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_predicate replacement, :persisted?
      assert_equal root.id, replacement.public_send(usage_case[:parent_key])
      assert_equal "openid email", replacement.oidc_scope
    end

    test "#{usage_case[:name]} usage is deleted when the parent root is physically deleted" do
      root = usage_case[:root_builder].call
      usage = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      assert_difference -> { usage_case[:model].count }, -1 do
        usage_case[:root_model].delete(root.id)
      end

      assert_not usage_case[:model].exists?(usage.id)
    end

    test "#{usage_case[:name]} usage rotates refresh tokens without exposing raw secrets" do
      root = usage_case[:root_builder].call
      usage = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      raw_refresh_token = usage.issue_refresh_token!

      assert_predicate raw_refresh_token, :present?
      assert_predicate usage.refresh_token_digest, :present?
      assert_predicate usage.refresh_token_digest, :ascii_only?
      assert usage.authenticate_refresh_token(raw_refresh_token.split(".", 2).last)
      assert_not usage.authenticate_refresh_token("wrong-verifier")
    end

    test "#{usage_case[:name]} usage refresh expiry cannot exceed its root session" do
      root = usage_case[:root_builder].call
      absolute_expiry = 1.hour.from_now
      root.update!(discarded_at: absolute_expiry)
      usage = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => absolute_expiry + 1.day,
      )

      usage.issue_refresh_token!(expires_at: absolute_expiry + 2.days)
      assert_operator usage.reload.refresh_token_expires_at, :<=, absolute_expiry
      assert_equal absolute_expiry.to_i, usage.refresh_token_expires_at.to_i

      usage.rotate_refresh_token!(expires_at: absolute_expiry + 3.days)
      assert_operator usage.reload.refresh_token_expires_at, :<=, absolute_expiry
      assert_equal absolute_expiry.to_i, usage.refresh_token_expires_at.to_i
    end
    test "#{usage_case[:name]} usage detects a replay of the digest superseded by rotation" do
      root = usage_case[:root_builder].call
      usage = usage_case[:model].create!(
        usage_case[:parent_label] => root,
        :oidc_client_id => "core-next-rp",
        :oidc_scope => "openid profile",
        :refresh_token_expires_at => 1.hour.from_now,
      )

      superseded_verifier = usage.issue_refresh_token!.split(".", 2).last

      # Nothing has been rotated away yet, so no verifier can be a replay.
      assert_not usage.previous_refresh_token_digest_matches?(superseded_verifier)

      current_verifier = usage.rotate_refresh_token!.split(".", 2).last

      assert usage.previous_refresh_token_digest_matches?(superseded_verifier)
      assert_not usage.previous_refresh_token_digest_matches?(current_verifier)
      assert_not usage.authenticate_refresh_token(superseded_verifier)
      assert usage.authenticate_refresh_token(current_verifier)
    end
  end
end
