# frozen_string_literal: true

class ClientTelephoneHistory < AppPrincipalRecord
  belongs_to :user, class_name: "Client"
  validates :fingerprint, :attached_at, :detached_at, :created_at, presence: true
  before_update :reject_history_update

  self.filter_attributes += %w(fingerprint)

  public

  def matches_identifier?(candidate)
    IdentifierHistoryFingerprintVerifier.matches?(
      fingerprint: fingerprint, identifier: candidate, realm: "app", channel: "telephone",
    )
  end

  private

  def reject_history_update
    raise ActiveRecord::ReadOnlyRecord, "dead identifier history is append-only"
  end
end
