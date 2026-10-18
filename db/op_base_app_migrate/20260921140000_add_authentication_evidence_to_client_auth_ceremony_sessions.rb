# typed: false
# frozen_string_literal: true

class AddAuthenticationEvidenceToClientAuthCeremonySessions < ActiveRecord::Migration[8.2]
  METHODS = %w(email telephone secret passkey totp google apple entra).freeze

  def change
    add_column :client_auth_ceremony_sessions, :authentication_method, :string
    add_column :client_auth_ceremony_sessions, :authentication_event_at, :datetime
    add_check_constraint(
      :client_auth_ceremony_sessions,
      "authentication_method IS NULL OR authentication_method IN (#{METHODS.map { |method| "'#{method}'" }.join(', ')})",
      name: "client_auth_ceremony_sessions_authentication_method",
      validate: false,
    )
    add_check_constraint(
      :client_auth_ceremony_sessions,
      "(authentication_method IS NULL) = (authentication_event_at IS NULL)",
      name: "client_auth_ceremony_sessions_authentication_evidence_pair",
      validate: false,
    )
  end
end
