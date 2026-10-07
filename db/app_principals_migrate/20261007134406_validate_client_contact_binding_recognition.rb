# frozen_string_literal: true

class ValidateClientContactBindingRecognition < ActiveRecord::Migration[8.2]
  CONTACTS = {
    client_emails: { kind: "email", status: "user_email_status_id", verified_statuses: [2, 3].freeze },
    client_telephones: { kind: "telephone", status: "user_identity_telephone_status_id", verified_statuses: [1, 3].freeze },
  }.freeze

  public

  def up
    # Recognition is a Source-local transaction. Ticket is read-only evidence, not a second writer.
    recognition_time = connection.select_value("SELECT CURRENT_TIMESTAMP")
    completion_groups = nil
    CONTACTS.each do |table, facts|
      rows = recognition_rows(table, facts)
      next if rows.empty?

      completion_groups ||= signup_completion_groups
      classified = rows.group_by { |row| recognition_classification(row, facts, completion_groups) }
      unknown = classified.fetch(:unknown, []).pluck("id")
      unless unknown.empty?
        raise ActiveRecord::MigrationError,
              "#{table} has unknown historical binding completion/release: rows=#{unknown.sort.join(",")}"
      end
      recognized = classified.fetch(:recognize, []).pluck("id")
      recognize_proven_rows!(table, recognized, recognition_time)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Contact recognition preserves security facts; repair forward"
  end

  private

  def recognition_classification(row, facts, completion_groups)
    return :unknown unless row.fetch("owner_present")

    kind = facts.fetch(:kind)
    matching = completion_groups.fetch([row.fetch("owner_id").to_s, kind, row.fetch("id").to_s], [])
    proven = row.fetch("finalization_proven") || matching.any? { |flow| completed_signup?(flow, kind) }
    finalized = row["binding_finalized_at"].present?
    released = row["binding_released_at"].present?
    status = row.fetch("status").to_i
    return :unknown if released != row.fetch("release_proven")
    return :unknown if ambiguous_completion?(
      status: status, finalized: finalized, proven: proven, matching: matching, verified: facts.fetch(:verified_statuses),
    )
    return :recognize if proven && !finalized

    :retained
  end

  def ambiguous_completion?(status:, finalized:, proven:, matching:, verified:)
    return !proven if finalized
    return true if status == 4 && (proven || matching.empty?)
    return false if proven

    matching.any? { |flow| flow["status_id"].to_i == 100 } || verified.include?(status) ||
      (status == 7 && matching.empty?)
  end

  def signup_completion_groups
    signup_completion_rows.group_by do |flow|
      [flow["principal_id"].to_s, flow["pending_contact_type"], flow["pending_contact_id"].to_s]
    end
  end

  def recognition_rows(table, facts)
    connection.select_all(<<~SQL.squish).to_a
      SELECT contact.id, contact.user_id AS owner_id,
             owner.id IS NOT NULL AS owner_present,
             contact.#{facts.fetch(:status)} AS status,
             contact.binding_finalized_at, contact.binding_released_at,
             EXISTS (
               SELECT 1 FROM client_contact_audit_outboxes fact
                WHERE fact.owner_ref = owner.public_id AND fact.contact_ref = contact.public_id
                  AND fact.contact_kind = #{connection.quote(facts.fetch(:kind))}
                  AND fact.event_name = 'finalized'
             ) AS finalization_proven,
             EXISTS (
               SELECT 1 FROM client_contact_audit_outboxes fact
                WHERE fact.owner_ref = owner.public_id AND fact.contact_ref = contact.public_id
                  AND fact.contact_kind = #{connection.quote(facts.fetch(:kind))}
                  AND fact.event_name = 'released'
             ) AS release_proven
        FROM #{table} contact LEFT JOIN clients owner ON owner.id = contact.user_id
       ORDER BY contact.id
       FOR UPDATE OF contact
    SQL
  end

  def signup_completion_rows
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "app_ticket")
    raise ActiveRecord::MigrationError, "app_ticket configuration is required for Contact recognition" unless config

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    pool = handler.establish_connection(config, owner_name: self.class.name)
    pool.with_connection do |ticket|
      ticket.select_all(<<~SQL.squish).to_a
        SELECT principal_id, pending_contact_id, pending_contact_type, status_id,
               completed_at, completed_requirements
          FROM client_sign_up_flows
         WHERE pending_contact_type IN ('email', 'telephone')
         ORDER BY id DESC
      SQL
    end
  ensure
    pool&.disconnect!
  end

  def completed_signup?(flow, kind)
    return false unless flow && flow["status_id"].to_i == 100 && flow["completed_at"]

    requirements = flow.fetch("completed_requirements")
    requirements = JSON.parse(requirements) if requirements.is_a?(String)
    required = (kind == "telephone") ? %w(otp passkey birthdate) : %w(otp birthdate)
    required.all? { |key| requirements.is_a?(Hash) && requirements.dig(key, "cleared") == true }
  end

  def recognize_proven_rows!(table, ids, recognition_time)
    return if ids.empty?

    # Only DB-read integer IDs enter SQL. Existing facts are never rewritten and conflicts pick no winner.
    id_list = ids.map { |id| Integer(id) }.join(",")
    conflicts = connection.select_values(<<~SQL.squish)
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM #{table}
       WHERE (binding_finalized_at IS NOT NULL AND binding_released_at IS NULL) OR id IN (#{id_list})
       GROUP BY user_id HAVING COUNT(*) > 1
    SQL
    digest = (table == :client_emails) ? "address_digest" : "number_digest"
    conflicts.concat(connection.select_values(<<~SQL.squish))
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM #{table}
       WHERE (binding_finalized_at IS NOT NULL AND binding_released_at IS NULL) OR id IN (#{id_list})
       GROUP BY #{digest} HAVING COUNT(*) > 1 OR #{digest} IS NULL OR #{digest} = ''
    SQL
    unless conflicts.empty?
      raise ActiveRecord::MigrationError, "#{table} has effective recognition conflicts: rows=#{conflicts.join(";")}"
    end

    safety_assured do
      execute(<<~SQL.squish)
        UPDATE #{table} SET binding_finalized_at = #{connection.quote(recognition_time)}
         WHERE id IN (#{id_list}) AND binding_finalized_at IS NULL
      SQL
    end
  end
end
