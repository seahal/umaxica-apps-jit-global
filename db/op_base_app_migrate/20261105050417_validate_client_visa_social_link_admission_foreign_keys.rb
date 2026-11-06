# frozen_string_literal: true

class ValidateClientVisaSocialLinkAdmissionForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :client_visa_social_link_admissions, :client_oidc_authorization_transactions,
    )
    validate_foreign_key(
      :client_visa_social_link_admissions, :client_social_ceremony_transactions,
    )
    validate_foreign_key(
      :client_visa_social_link_admissions, :client_step_up_ceremony_transactions,
    )
    validate_foreign_key(
      :client_visa_social_link_admissions, :client_auth_admission_bindings,
    )
  end
end
