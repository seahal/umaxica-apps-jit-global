# typed: false
# frozen_string_literal: true

class ClientWithdrawalCeremony < AppPrincipalRecord
  include WithdrawalCeremonyRecordable

  belongs_to :client, inverse_of: :client_withdrawal_ceremonies

  def self.subject_association_name = :client

  def subject = Client.find(client_id)
end
