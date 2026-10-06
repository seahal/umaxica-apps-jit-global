# frozen_string_literal: true

module SignInFlowStateStorage
  LEGACY_STATE_NAMES = {
    10 => "PRIMARY_PENDING",
    20 => "MFA_PENDING",
    30 => "SESSION_LIMIT_PENDING",
    40 => "GUARDRAIL_PENDING",
    50 => "SESSION_ISSUANCE_PENDING",
    60 => "CHECKPOINT_PENDING",
    65 => "SELECTOR_PENDING",
    70 => "DASHBOARD_PENDING",
    80 => "RETURN_PENDING",
    100 => "COMPLETED",
    900 => "FAILED",
    910 => "EXPIRED",
    920 => "CANCELLED",
    930 => "HALTED",
  }.freeze

  LEGACY_STEP_NAMES = {
    10 => "primary",
    20 => "mfa",
    30 => "session_limit",
    40 => "guardrail",
    50 => "session_issuance",
    60 => "checkpoint",
    65 => "selector",
    70 => "dashboard",
    80 => "return_to",
    100 => "completed",
    900 => "failed",
    910 => "expired",
    920 => "cancelled",
    930 => "halted",
  }.freeze

  def normalize_sign_in_flow_state_storage(flow_table:, status_table:, state_table:, state_index:, status_index:,
                                           state_constraint:, step_constraint:, completed_constraint:)
    verify_legacy_triples!(flow_table)
    remove_legacy_checks(flow_table, state_constraint, step_constraint)
    terminalize_obsolete_states!(flow_table)

    remove_foreign_key(flow_table, column: :status_id) if foreign_key_exists?(flow_table, column: :status_id)
    remove_index(flow_table, name: status_index, algorithm: :concurrently) if index_exists?(
      flow_table,
      name: status_index,
    )
    remove_index(flow_table, name: state_index, algorithm: :concurrently) if index_exists?(
      flow_table,
      name: state_index,
    )

    safety_assured do
      rename_table(status_table, state_table) unless table_exists?(state_table)
    end
    safety_assured do
      rename_column(flow_table, :status_id, :state_id) unless column_exists?(flow_table, :state_id)
    end

    safety_assured do
      remove_column(flow_table, :state, :string) if column_exists?(flow_table, :state)
      remove_column(flow_table, :step, :string) if column_exists?(flow_table, :step)
    end

    add_index(flow_table, :state_id, name: "index_#{flow_table}_on_state_id", algorithm: :concurrently) unless
      index_exists?(flow_table, column: :state_id)

    safety_assured do
      add_foreign_key(flow_table, state_table, column: :state_id, on_delete: :restrict, validate: false) unless
        foreign_key_exists?(flow_table, state_table, column: :state_id)
      validate_foreign_key(flow_table, state_table)
      add_check_constraint(
        flow_table,
        "(state_id = 100) = (completed_at IS NOT NULL)",
        name: completed_constraint, validate: false,
      ) unless
        check_constraint_exists?(flow_table, name: completed_constraint)
      validate_check_constraint(flow_table, name: completed_constraint)
    end
  end

  private

  def verify_legacy_triples!(flow_table)
    names_sql = legacy_case_sql(LEGACY_STATE_NAMES)
    steps_sql = legacy_case_sql(LEGACY_STEP_NAMES)
    invalid_ids = select_values(<<~SQL.squish)
      SELECT id
      FROM #{flow_table}
      WHERE status_id NOT IN (#{LEGACY_STATE_NAMES.keys.join(",")})
         OR state IS DISTINCT FROM (#{names_sql})
         OR step IS DISTINCT FROM (#{steps_sql})
         OR ((status_id = 100) <> (completed_at IS NOT NULL))
      ORDER BY id
    SQL
    return if invalid_ids.empty?

    raise ActiveRecord::MigrationError,
          "#{flow_table} contains ambiguous sign-in lifecycle rows (ids=#{invalid_ids.join(",")})"
  end

  def remove_legacy_checks(flow_table, state_constraint, step_constraint)
    remove_check_constraint(flow_table, name: state_constraint) if check_constraint_exists?(
      flow_table,
      name: state_constraint,
    )
    remove_check_constraint(flow_table, name: step_constraint) if check_constraint_exists?(
      flow_table,
      name: step_constraint,
    )
  end

  def terminalize_obsolete_states!(flow_table)
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE #{flow_table}
        SET status_id = CASE WHEN expires_at <= CURRENT_TIMESTAMP THEN 910 ELSE 930 END,
            state = CASE WHEN expires_at <= CURRENT_TIMESTAMP THEN 'EXPIRED' ELSE 'HALTED' END,
            step = CASE WHEN expires_at <= CURRENT_TIMESTAMP THEN 'expired' ELSE 'halted' END,
            updated_at = CURRENT_TIMESTAMP
        WHERE status_id IN (30, 70, 80)
      SQL
    end
  end

  def legacy_case_sql(mapping)
    clauses = mapping.map { |id, name| "WHEN #{id} THEN #{connection.quote(name)}" }.join(' ')
    "CASE status_id #{clauses} ELSE NULL END"
  end
end
