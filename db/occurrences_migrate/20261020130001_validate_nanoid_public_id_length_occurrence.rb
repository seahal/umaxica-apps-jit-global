# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOccurrence < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:area_occurrences, name: "chk_area_occurrences_pid")
    validate_check_constraint(:client_occurrences, name: "chk_client_occurrences_pid")
    validate_check_constraint(:domain_occurrences, name: "chk_domain_occurrences_pid")
    validate_check_constraint(:email_occurrences, name: "chk_email_occurrences_pid")
    validate_check_constraint(:ip_occurrences, name: "chk_ip_occurrences_pid")
    validate_check_constraint(:jwt_occurrences, name: "chk_jwt_occurrences_pid")
    validate_check_constraint(:operator_occurrences, name: "chk_operator_occurrences_pid")
    validate_check_constraint(:telephone_occurrences, name: "chk_telephone_occurrences_pid")
    validate_check_constraint(:visitor_occurrences, name: "chk_visitor_occurrences_pid")
    validate_check_constraint(:zip_occurrences, name: "chk_zip_occurrences_pid")
  end
end
