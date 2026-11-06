# frozen_string_literal: true

class CreateOrgIamOperationOutcomes < ActiveRecord::Migration[8.2]
  def change
    create_table(:org_iam_operation_outcomes) do |t|
      t.uuid(:operation_id, null: false)
      t.string(:operation_kind, null: false)
      t.string(:actor_public_id, null: false)
      t.string(:subject_public_id, null: false)
      t.string(:request_digest, null: false, limit: 64)
      t.jsonb(:result, null: false)
      t.timestamps(null: false)

      t.index(:operation_id, unique: true)
    end

    add_check_constraint(
      :org_iam_operation_outcomes, "operation_kind IN ('grant', 'revoke')",
      name: "chk_org_iam_outcomes_kind",
    )
    add_check_constraint(
      :org_iam_operation_outcomes, "request_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_org_iam_outcomes_digest",
    )
    add_check_constraint(
      :org_iam_operation_outcomes,
      "length(btrim(actor_public_id)) > 0 AND length(btrim(subject_public_id)) > 0",
      name: "chk_org_iam_outcomes_owners",
    )
    add_check_constraint(
      :org_iam_operation_outcomes,
      "jsonb_typeof(result) = 'object' " \
      "AND COALESCE(jsonb_typeof(result->'grant_public_id') = 'string', false) " \
      "AND length(btrim(result->>'grant_public_id')) > 0 " \
      "AND ((operation_kind = 'grant' " \
      "AND COALESCE(jsonb_typeof(result->'expires_at') = 'string', false) " \
      "AND length(btrim(result->>'expires_at')) > 0 " \
      "AND result - ARRAY['grant_public_id', 'expires_at'] = '{}'::jsonb) " \
      "OR (operation_kind = 'revoke' AND result - ARRAY['grant_public_id'] = '{}'::jsonb))",
      name: "chk_org_iam_outcomes_result",
    )
  end
end
