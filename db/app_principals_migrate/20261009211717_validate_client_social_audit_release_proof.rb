# frozen_string_literal: true

class ValidateClientSocialAuditReleaseProof < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:client_social_audit_outboxes, name: "client_social_audit_digest")
    validate_check_constraint(:client_social_audit_outboxes, name: "client_social_audit_release")
  end
end
