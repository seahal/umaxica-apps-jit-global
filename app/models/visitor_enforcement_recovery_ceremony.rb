# typed: false
# frozen_string_literal: true

class VisitorEnforcementRecoveryCeremony < ComPrincipalRecord
  include EnforcementRecoveryCeremonyRecordable

  belongs_to :visitor

  def self.subject_association_name = :visitor

  def subject = Visitor.find(visitor_id)
end
