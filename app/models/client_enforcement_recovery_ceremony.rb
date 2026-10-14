# typed: false
# frozen_string_literal: true

class ClientEnforcementRecoveryCeremony < AppPrincipalRecord
  include EnforcementRecoveryCeremonyRecordable

  belongs_to :client

  def self.subject_association_name = :client

  def subject = Client.find(client_id)
end
