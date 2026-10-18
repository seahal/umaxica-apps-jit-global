# frozen_string_literal: true

require "test_helper"

class PublicIdNullOnlyBackfillOperationTest < ActiveSupport::TestCase
  test "post-cutover supported scopes are idempotent and preserve source rows" do
    targets = [
      [ClientPreference, ClientPreference.create!(user: Client.create!(status_id: ClientStatus::ACTIVE))],
      [VisitorPreference, VisitorPreference.create!(visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE))],
      [OperatorPreference, OperatorPreference.create!(staff: Operator.create!(status_id: OperatorStatus::ACTIVE))],
      [ClientPasskey, ClientPasskey.create!(
        user: Client.create!(status_id: ClientStatus::ACTIVE),
        webauthn_id: SecureRandom.uuid,
        public_key: "public-key",
        description: "backfill-test",
      ),],
    ]

    targets.each do |model, record|
      before = record.reload.attributes
      result = PublicIdNullOnlyBackfillOperation.call(
        scope: model.where(id: record.id), dry_run: false, batch_size: 1,
      )

      assert_equal 0, result.fetch(:assigned), model.name
      assert_equal 0, result.fetch(:missing), model.name
      assert_equal before, record.reload.attributes, model.name

      repeated = PublicIdNullOnlyBackfillOperation.call(
        scope: model.where(id: record.id), dry_run: false, batch_size: 1,
      )

      assert_equal 0, repeated.fetch(:assigned), model.name
      assert_equal before, record.reload.attributes, model.name
    end
  end

  test "dry run does not generate identities for supported scopes" do
    calls = 0
    generator =
      lambda do |**|
        calls += 1
        raise RuntimeError, "unexpected post-cutover generation"
      end

    Nanoid.stub(:generate, generator) do
      result = PublicIdNullOnlyBackfillOperation.call(
        scope: ClientPreference.none, dry_run: true, batch_size: 1,
      )

      assert_equal 0, result.fetch(:assigned)
      assert_equal 0, result.fetch(:missing)
    end

    assert_equal 0, calls
  end

  test "rejects unsupported scopes and invalid batch settings before writing" do
    [nil, Client.all].each do |scope|
      assert_raises(ArgumentError) do
        PublicIdNullOnlyBackfillOperation.call(scope: scope, dry_run: true, batch_size: 1)
      end
    end

    [nil, 0, -1, 1001, "1", false].each do |batch_size|
      assert_raises(ArgumentError) do
        PublicIdNullOnlyBackfillOperation.call(
          scope: ClientPreference.none, dry_run: true, batch_size: batch_size,
        )
      end
    end

    [nil, "true", 0].each do |dry_run|
      assert_raises(ArgumentError) do
        PublicIdNullOnlyBackfillOperation.call(
          scope: ClientPreference.none, dry_run: dry_run, batch_size: 1,
        )
      end
    end
  end
end
