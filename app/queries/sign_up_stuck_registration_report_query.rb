# typed: false
# frozen_string_literal: true

# Read-only inventory for unfinished APP/COM registrations that the scheduled cleanup cannot reach.
class SignUpStuckRegistrationReportQuery
  class WritingRoleRefused < StandardError; end

  CASE_FLOW_MISSING = "flow_missing"
  CASE_CLEANUP_ATTEMPTS_EXHAUSTED = "cleanup_attempts_exhausted"

  SURFACES = {
    app: {
      flow: ClientSignUpFlow,
      actor: Client,
      actor_status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      contacts: [
        {
          type: "email",
          model: ClientEmail,
          owner_foreign_key: :user_id,
          status_column: :user_email_status_id,
          status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
        },
        {
          type: "telephone",
          model: ClientTelephone,
          owner_foreign_key: :user_id,
          status_column: :user_identity_telephone_status_id,
          status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        },
      ].freeze,
    }.freeze,
    com: {
      flow: VisitorSignUpFlow,
      actor: Visitor,
      actor_status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
      contacts: [
        {
          type: "email",
          model: VisitorEmail,
          owner_foreign_key: :visitor_id,
          status_column: :visitor_email_status_id,
          status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
        },
        {
          type: "telephone",
          model: VisitorTelephone,
          owner_foreign_key: :visitor_id,
          status_column: :visitor_telephone_status_id,
          status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        },
      ].freeze,
    }.freeze,
  }.freeze

  class << self
    public

    def call(surface:)
      new(surface:).call
    end
  end

  public

  def initialize(surface:)
    @surface = surface.to_sym
    @config = SURFACES.fetch(@surface)
  end

  def call
    actors, contacts = unfinished_records
    flow_links, exhausted_flows = flow_records(actors:, contacts:)
    missing_flow_records(actors:, contacts:, flow_links:) + exhausted_flow_records(exhausted_flows)
  end

  private

  attr_reader :config, :surface

  def unfinished_records
    actor_model = config.fetch(:actor)
    contact_definitions = config.fetch(:contacts)
    pending_contacts =
      contact_definitions.flat_map do |contact|
        model = contact.fetch(:model)
        read(model) do
          model.unscoped.where(contact.fetch(:status_column) => contact.fetch(:status_id))
            .pluck(:id, contact.fetch(:owner_foreign_key), :public_id)
            .map do |id, owner_id, public_id|
              { type: contact.fetch(:type), id:, owner_id:, public_id: }
            end
        end
      end

    owner_ids = pending_contacts.filter_map { |contact| contact.fetch(:owner_id) }
    owner_ids.uniq!
    actor_scope = actor_model.unscoped.where(status_id: config.fetch(:actor_status_id))
    actor_scope = actor_scope.or(actor_model.unscoped.where(id: owner_ids)) if owner_ids.any?
    actors =
      read(actor_model) do
        actor_scope.pluck(:id, :public_id, :status_id).map do |id, public_id, status_id|
          { id:, public_id:, status_id: }
        end
      end
    [actors, pending_contacts]
  end

  def flow_records(actors:, contacts:)
    flow_model = config.fetch(:flow)
    principal_ids =
      actors.filter_map do |actor|
        actor.fetch(:id) if actor.fetch(:status_id) == config.fetch(:actor_status_id)
      end
    contact_ids = contacts.map { |contact| contact.fetch(:id) }

    flow_links, exhausted_flows =
      read(flow_model) do
        principal_flow_links =
          if principal_ids.any?
            flow_model.unscoped.where(principal_id: principal_ids)
              .pluck(:principal_id, :pending_contact_type, :pending_contact_id)
          else
            []
          end
        contact_flow_links =
          if contact_ids.any?
            flow_model.unscoped.where(pending_contact_id: contact_ids)
              .pluck(:principal_id, :pending_contact_type, :pending_contact_id)
          else
            []
          end
        exhausted = flow_model.unscoped
          .where(status_id: SignUpArtifactCleanup.cleanup_status_ids(flow_model))
          .where(
            cleanup_status_id: [flow_model.cleanup_status_id_for(:pending), flow_model.cleanup_status_id_for(:failed)],
          )
          .where(cleanup_attempts_count: SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS..)
          .pluck(:public_id, :principal_id, :pending_contact_type, :pending_contact_id, :cleanup_attempts_count)

        [principal_flow_links + contact_flow_links, exhausted]
      end
    [flow_links, exhausted_flows]
  end

  def missing_flow_records(actors:, contacts:, flow_links:)
    actor_status_id = config.fetch(:actor_status_id)
    actors_by_id = actors.index_by { |actor| actor.fetch(:id) }
    principal_flow_ids = flow_links.filter_map { |link| link.fetch(0) }.to_set
    contact_flow_keys = flow_links.filter_map do |link|
      type = link.fetch(1)
      id = link.fetch(2)
      [type, id] if type && id
    end.to_set

    missing_contacts =
      contacts.select do |contact|
        owner = actors_by_id[contact.fetch(:owner_id)]
        owner_status_is_eligible = owner.nil? || owner.fetch(:status_id) == actor_status_id
        owner_status_is_eligible && contact_flow_keys.exclude?([contact.fetch(:type), contact.fetch(:id)])
      end
    missing_contact_owner_ids = missing_contacts.filter_map { |contact| contact.fetch(:owner_id) }.to_set

    contact_records =
      missing_contacts.map do |contact|
        owner = actors_by_id[contact.fetch(:owner_id)]
        report_row(
          case_name: CASE_FLOW_MISSING,
          principal_public_id: owner&.fetch(:public_id),
          contact_public_id: contact.fetch(:public_id),
        )
      end

    missing_principals =
      actors.select do |actor|
        actor.fetch(:status_id) == actor_status_id && principal_flow_ids.exclude?(actor.fetch(:id))
      end
    principal_records = []
    missing_principals.each do |actor|
      next if missing_contact_owner_ids.include?(actor.fetch(:id))

      principal_records << report_row(case_name: CASE_FLOW_MISSING, principal_public_id: actor.fetch(:public_id))
    end

    contact_records + principal_records
  end

  def exhausted_flow_records(flow_rows)
    actor_model = config.fetch(:actor)
    principal_ids = flow_rows.filter_map { |row| row.fetch(1) }
    principal_ids.uniq!
    actors_by_id =
      read(actor_model) do
        actor_model.unscoped.where(id: principal_ids).pluck(:id, :public_id, :status_id).to_h do
          |id, public_id, status_id|
          [id, { public_id:, status_id: }]
        end
      end

    contact_public_ids = {}
    config.fetch(:contacts).each do |contact|
      type = contact.fetch(:type)
      contact_ids = flow_rows.filter_map { |row| row.fetch(3) if row.fetch(2) == type }
      contact_ids.uniq!
      next if contact_ids.empty?

      model = contact.fetch(:model)
      contact_public_ids[type] = read(model) { model.unscoped.where(id: contact_ids).pluck(:id, :public_id).to_h }
    end

    flow_rows.filter_map do |flow_public_id, principal_id, contact_type, contact_id, attempts_count|
      actor = actors_by_id[principal_id]
      next if actor && actor.fetch(:status_id) != config.fetch(:actor_status_id)

      report_row(
        case_name: CASE_CLEANUP_ATTEMPTS_EXHAUSTED,
        flow_public_id:,
        principal_public_id: actor&.fetch(:public_id),
        contact_public_id: contact_public_ids.dig(contact_type, contact_id),
        cleanup_attempts_count: attempts_count,
      )
    end
  end

  def report_row(case_name:, principal_public_id: nil, contact_public_id: nil, flow_public_id: nil,
                 cleanup_attempts_count: nil)
    {
      surface: surface.to_s,
      case: case_name,
      principal_public_id:,
      contact_public_id:,
      flow_public_id:,
      cleanup_attempts_count:,
    }
  end

  # Each database read uses its replica and forbids writes. An explicit writer context is a caller
  # error, not an invitation to change its transaction role silently.
  def read(model, &)
    if ActiveRecord::Base.connected_to_stack.any? { |entry| entry[:role] == :writing }
      raise WritingRoleRefused, "stuck sign-up reporting runs only on a reading role"
    end

    model.connection_class_for_self.connected_to(role: :reading, prevent_writes: true, &)
  end
end
