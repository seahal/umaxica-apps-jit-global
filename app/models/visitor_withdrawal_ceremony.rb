# typed: false
# frozen_string_literal: true

class VisitorWithdrawalCeremony < ComPrincipalRecord
  include WithdrawalCeremonyRecordable

  belongs_to :visitor, inverse_of: :visitor_withdrawal_ceremonies

  def self.subject_association_name = :visitor

  def subject = Visitor.find(visitor_id)
end
