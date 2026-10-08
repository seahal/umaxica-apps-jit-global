# frozen_string_literal: true

class VisitorEmailHistory < ComPrincipalRecord
  belongs_to :visitor, class_name: "Visitor"
  validates :fingerprint, :attached_at, :detached_at, :created_at, presence: true
  before_update :reject_history_update

  self.filter_attributes += %w(fingerprint)

  public

  def matches_identifier?(candidate)
    IdentifierHistoryFingerprintVerifier.matches?(
      fingerprint: fingerprint, identifier: candidate, realm: "com", channel: "email",
    )
  end

  private

  def reject_history_update
    raise ActiveRecord::ReadOnlyRecord, "dead identifier history is append-only"
  end
end
