# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md: one platform-scoped grant of one fixed capability to one
# operator. A grant is in force only while it is unrevoked, inside its validity window, and held by
# an operator who is still eligible; nothing is derived from Bureau ownership or role names.
#
# Capability identifiers are data. Policies compare them against the fixed constants below; no code
# path builds a class, method, or policy name from one.
class OperatorCapabilityGrant < OrgPrincipalRecord
  include PublicId

  SUPPORT_CONSOLE_READ = "support.console.read"
  SUPPORT_ACCOUNT_READ_APP = "support.account.read.app"
  SUPPORT_ACCOUNT_READ_COM = "support.account.read.com"
  SUPPORT_SESSION_REVOKE_APP = "support.session.revoke.app"
  SUPPORT_SESSION_REVOKE_COM = "support.session.revoke.com"
  ENFORCEMENT_READ_APP = "enforcement.read.app"
  ENFORCEMENT_READ_COM = "enforcement.read.com"
  ENFORCEMENT_APPLY_APP = "enforcement.apply.app"
  ENFORCEMENT_APPLY_COM = "enforcement.apply.com"
  ENFORCEMENT_APPROVE_APP = "enforcement.approve.app"
  ENFORCEMENT_APPROVE_COM = "enforcement.approve.com"
  ENFORCEMENT_RELEASE_APP = "enforcement.release.app"
  ENFORCEMENT_RELEASE_COM = "enforcement.release.com"
  ENFORCEMENT_REVIEW_APPEAL_APP = "enforcement.review_appeal.app"
  ENFORCEMENT_REVIEW_APPEAL_COM = "enforcement.review_appeal.com"
  IAM_CAPABILITY_READ = "iam.capability.read"
  IAM_CAPABILITY_GRANT = "iam.capability.grant"
  IAM_CAPABILITY_REVOKE = "iam.capability.revoke"

  CAPABILITIES = [
    SUPPORT_CONSOLE_READ,
    SUPPORT_ACCOUNT_READ_APP, SUPPORT_ACCOUNT_READ_COM,
    SUPPORT_SESSION_REVOKE_APP, SUPPORT_SESSION_REVOKE_COM,
    ENFORCEMENT_READ_APP, ENFORCEMENT_READ_COM,
    ENFORCEMENT_APPLY_APP, ENFORCEMENT_APPLY_COM,
    ENFORCEMENT_APPROVE_APP, ENFORCEMENT_APPROVE_COM,
    ENFORCEMENT_RELEASE_APP, ENFORCEMENT_RELEASE_COM,
    ENFORCEMENT_REVIEW_APPEAL_APP, ENFORCEMENT_REVIEW_APPEAL_COM,
    IAM_CAPABILITY_READ, IAM_CAPABILITY_GRANT, IAM_CAPABILITY_REVOKE,
  ].freeze

  # IAM capabilities control who can hand out capabilities. They are issued only through the audited
  # bootstrap procedure, never delegated through the console, so no operator can widen the set of
  # operators able to grant.
  BOOTSTRAP_ONLY_CAPABILITIES = [IAM_CAPABILITY_READ, IAM_CAPABILITY_GRANT, IAM_CAPABILITY_REVOKE].freeze
  # The capabilities whose loss would leave nobody able to repair grants.
  CONTINUITY_CAPABILITIES = [IAM_CAPABILITY_GRANT, IAM_CAPABILITY_REVOKE].freeze

  ORIGIN_GRANT = "grant"
  ORIGIN_BOOTSTRAP = "bootstrap"
  ORIGINS = [ORIGIN_GRANT, ORIGIN_BOOTSTRAP].freeze

  REASON_BOOTSTRAP = "bootstrap"
  GRANT_REASON_CODES = [REASON_BOOTSTRAP, "duty_assignment", "incident_response", "access_review"].freeze
  DELEGATED_GRANT_REASON_CODES = (GRANT_REASON_CODES - [REASON_BOOTSTRAP]).freeze
  REVOKE_REASON_CODES = %w(duty_ended access_review security_incident operator_error_recovery).freeze

  MAX_VALIDITY = 366.days
  TICKET_ID_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

  class LastCapabilityHolderError < StandardError; end

  class AlreadyRevokedError < StandardError; end

  belongs_to :operator, inverse_of: :capability_grants
  belongs_to :granted_by_operator, class_name: "Operator", optional: true, inverse_of: false
  belongs_to :revoked_by_operator, class_name: "Operator", optional: true, inverse_of: false

  validates :capability, inclusion: { in: CAPABILITIES }
  validates :origin, inclusion: { in: ORIGINS }
  validates :reason_code, inclusion: { in: GRANT_REASON_CODES }
  validates :ticket_id, format: { with: TICKET_ID_FORMAT }, allow_nil: true
  validates :starts_at, :expires_at, presence: true
  validates :revoke_reason_code, inclusion: { in: REVOKE_REASON_CODES }, allow_nil: true
  validate :validity_window_is_bounded
  validate :granter_shape_matches_origin

  scope :unrevoked, -> { where(revoked_at: nil) }
  scope :in_force,
        lambda { |now = Time.current|
          unrevoked.where(starts_at: ..now).where("expires_at > ?", now)
        }

  public

  # A delegated grant from one operator to another. Authorization (who may grant what) is the
  # policy's job; this enforces the record's own invariants.
  public_class_method def self.issue!(operator:, granted_by:, capability:, reason_code:, ticket_id:, duration:,
                                      now: Time.current)
    create!(
      operator: operator,
      granted_by_operator: granted_by,
      origin: ORIGIN_GRANT,
      capability: capability,
      reason_code: reason_code,
      ticket_id: ticket_id,
      starts_at: now,
      expires_at: now + duration,
    )
  end

  # The audited bootstrap procedure (lib/tasks/operator_capabilities.rake). It names one existing,
  # eligible operator explicitly; there is no "first operator" or "all operators" form.
  public_class_method def self.bootstrap!(operator:, capabilities:, ticket_id:, expires_at:, now: Time.current,
                                          dry_run: false)
    raise ArgumentError, "operator is not eligible for capabilities" unless operator.capability_eligible?(now)
    raise ArgumentError, "at least one capability is required" if capabilities.empty?

    unknown = capabilities - CAPABILITIES
    raise ArgumentError, "unknown capabilities: #{unknown.join(", ")}" if unknown.any?
    raise ArgumentError, "expires_at must be after now" unless expires_at > now

    held = operator.capability_grants.in_force(now).where(capability: capabilities).pluck(:capability)
    raise ArgumentError, "already held in force: #{held.sort.join(", ")}" if held.any?

    # Every grant is validated before any is written, and all are written in one transaction, so a
    # bootstrap either grants every requested capability or none.
    grants =
      capabilities.uniq.map! do |capability|
        new(
          operator: operator, origin: ORIGIN_BOOTSTRAP, capability: capability, reason_code: REASON_BOOTSTRAP,
          ticket_id: ticket_id, starts_at: now, expires_at: expires_at,
        )
      end
    grants.each(&:validate!)
    return grants if dry_run

    transaction { grants.each(&:save!) }
    grants
  end

  # Revokes this grant. For a continuity capability, every unrevoked grant of that capability is
  # row-locked in id order first, so two concurrent revocations serialize and the second one sees
  # the first; the revocation is refused if no other eligible operator would still hold the
  # capability in force.
  def revoke!(by:, reason_code:, now: Time.current)
    self.class.transaction do
      if CONTINUITY_CAPABILITIES.include?(capability)
        holders = self.class.unrevoked.where(capability: capability).order(:id).lock.to_a
        remaining = holders.select { |grant| grant.id != id && grant.in_force?(now) }
        unless remaining.any? { |grant| grant.operator.capability_eligible?(now) }
          raise LastCapabilityHolderError, "revoking this grant would leave no operator holding #{capability}"
        end
      end

      lock!
      raise AlreadyRevokedError, "grant #{public_id} is already revoked" if revoked?

      update!(revoked_at: now, revoked_by_operator: by, revoke_reason_code: reason_code)
    end
  end

  def in_force?(now = Time.current)
    revoked_at.nil? && starts_at <= now && expires_at > now
  end

  def revoked?
    revoked_at.present?
  end

  private

  def validity_window_is_bounded
    return if starts_at.blank? || expires_at.blank?

    errors.add(:expires_at, :invalid) unless expires_at > starts_at
    errors.add(:expires_at, :invalid) if expires_at > starts_at + MAX_VALIDITY
  end

  def granter_shape_matches_origin
    case origin
    when ORIGIN_GRANT
      errors.add(:granted_by_operator, :blank) if granted_by_operator_id.nil?
      errors.add(:granted_by_operator, :invalid) if granted_by_operator_id.present? &&
        granted_by_operator_id == operator_id
      errors.add(:reason_code, :inclusion) if reason_code == REASON_BOOTSTRAP
      errors.add(:capability, :exclusion) if BOOTSTRAP_ONLY_CAPABILITIES.include?(capability)
    when ORIGIN_BOOTSTRAP
      errors.add(:granted_by_operator, :present) if granted_by_operator_id.present?
      errors.add(:reason_code, :inclusion) unless reason_code == REASON_BOOTSTRAP
    end
  end
end
