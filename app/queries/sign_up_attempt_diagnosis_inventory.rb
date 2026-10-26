# typed: false
# frozen_string_literal: true

# WU-26 (D-82): owner-scoped, read-only diagnosis for one or more APP/COM sign-up attempts.
# Reports contain identifiers, states, timestamps and counts; never contact values, provider
# subjects, tokens, digests, names or birthdates.
class SignUpAttemptDiagnosisInventory
  class WritingRoleRefused < StandardError; end

  PUBLIC_ID_PATTERN = /\A[A-Za-z0-9_-]{21}\z/.freeze
  DIGEST_PATTERN = /\A[0-9a-f]{64}\z/.freeze

  SURFACES = {
    app: {
      flow: ClientSignUpFlow,
      binding: ClientAuthAdmissionBinding,
      authorization_transaction: ClientOidcAuthorizationTransaction,
      ceremony_session: ClientAuthCeremonySession,
      actor: Client,
      owner_key: :user_id,
      contacts: {
        emails: [ClientEmail, :user_email_status_id],
        telephones: [ClientTelephone, :user_identity_telephone_status_id],
      }.freeze,
      passkeys: ClientPasskey,
      external_identities: ClientExternalIdentity,
      graph: ClientIdentity,
      tokens: [ClientToken, :user_token_status_id],
      social_candidate: IdentitySocialCeremonyCandidate,
      audit_outboxes: [
        {
          model: ClientContactAuditOutbox,
          flow_column: :operation_ref,
          event_id_column: :event_uuid,
          event_name_column: :event_name,
          timestamp_column: :occurred_at,
        },
        {
          model: ClientPasskeyAuditOutbox,
          flow_column: :operation_ref,
          event_id_column: :event_uuid,
          event_name_column: :event_type,
          timestamp_column: :occurred_at,
        },
        {
          model: ClientSecretAuditOutbox,
          flow_column: :issuance_sign_up_flow_ref,
          event_id_column: :event_id,
          event_name_column: :event_name,
          timestamp_column: :occurred_at,
        },
      ].freeze,
    }.freeze,
    com: {
      flow: VisitorSignUpFlow,
      binding: VisitorAuthAdmissionBinding,
      authorization_transaction: VisitorOidcAuthorizationTransaction,
      ceremony_session: VisitorAuthCeremonySession,
      actor: Visitor,
      owner_key: :visitor_id,
      contacts: {
        emails: [VisitorEmail, :visitor_email_status_id],
        telephones: [VisitorTelephone, :visitor_telephone_status_id],
      }.freeze,
      passkeys: VisitorPasskey,
      external_identities: nil,
      graph: VisitorIdentity,
      tokens: [VisitorToken, :visitor_token_status_id],
      social_candidate: nil,
      audit_outboxes: [
        {
          model: VisitorContactAuditOutbox,
          flow_column: :operation_ref,
          event_id_column: :event_uuid,
          event_name_column: :event_name,
          timestamp_column: :occurred_at,
        },
        {
          model: VisitorPasskeyAuditOutbox,
          flow_column: :operation_ref,
          event_id_column: :event_uuid,
          event_name_column: :event_type,
          timestamp_column: :occurred_at,
        },
      ].freeze,
    }.freeze,
  }.freeze

  TERMINAL_STATUSES = %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).freeze
  SOCIAL_PROVIDERS = IdentitySocialCeremonyContract::PROVIDERS

  class << self
    public

    def call(surface:, **selectors)
      new(surface:, selectors:).call
    end
  end

  public

  def initialize(surface:, selectors:)
    unless surface.is_a?(String) || surface.is_a?(Symbol)
      raise ArgumentError, "sign-up diagnosis surface is invalid"
    end

    @surface = surface.to_sym
    @config =
      SURFACES.fetch(@surface) do
        raise ArgumentError, "sign-up diagnosis surface is invalid"
      end
    @selectors = selectors
    validate_selectors!
  end

  def call
    flow_public_ids = matching_flow_public_ids
    return not_found if flow_public_ids.empty?

    attempts = flow_public_ids.map { |public_id| report_for(public_id) }
    return attempts.first if attempts.one?

    { surface: surface, classification: "multiple_attempts_found", attempts: }
  end

  private

  attr_reader :config, :selectors, :surface

  def validate_selectors!
    keys = selectors.keys.sort
    valid_shapes = [
      [:flow_public_id],
      [:entry_reference_digest],
      [:principal_public_id],
      [:provider, :subject_digest],
    ]
    raise ArgumentError, "exactly one sign-up diagnosis selector is required" unless valid_shapes.include?(keys)

    case keys
    when [:flow_public_id]
      validate_public_id!(selectors.fetch(:flow_public_id), "flow public id")
    when [:entry_reference_digest]
      validate_digest!(selectors.fetch(:entry_reference_digest), "entry reference digest")
    when [:principal_public_id]
      validate_public_id!(selectors.fetch(:principal_public_id), "principal public id")
    when [:provider, :subject_digest]
      provider = selectors.fetch(:provider)
      unless provider.is_a?(String) && SOCIAL_PROVIDERS.include?(provider)
        raise ArgumentError, "social provider is invalid"
      end

      validate_digest!(selectors.fetch(:subject_digest), "provider subject digest")
    end
  end

  def validate_public_id!(value, label)
    return if value.is_a?(String) && PUBLIC_ID_PATTERN.match?(value)

    raise ArgumentError, "#{label} is invalid"
  end

  def validate_digest!(value, label)
    return if value.is_a?(String) && DIGEST_PATTERN.match?(value)

    raise ArgumentError, "#{label} is invalid"
  end

  # Every read runs on the reading role with writes prevented. An explicit caller writing scope is
  # refused instead of being hidden by a nested role switch (A26-2).
  def read(model, &)
    if ActiveRecord::Base.connected_to_stack.any? { |entry| entry[:role] == :writing }
      raise WritingRoleRefused, "sign-up diagnosis runs only on a reading role"
    end

    model.connection_class_for_self.connected_to(role: :reading, prevent_writes: true, &)
  end

  def matching_flow_public_ids
    case selectors.keys.sort
    when [:flow_public_id]
      [selectors.fetch(:flow_public_id)]
    when [:entry_reference_digest]
      matching_flows_for_entry_reference
    when [:principal_public_id]
      matching_flows_for_principal
    when [:provider, :subject_digest]
      matching_flows_for_social_subject
    end
  end

  def matching_flows_for_entry_reference
    binding_model = config.fetch(:binding)
    expected_digest = selectors.fetch(:entry_reference_digest)
    binding_ids =
      read(binding_model) do
        binding_model.where(purpose: "authentication_handoff", entry_intent: "sign_up")
          .pluck(:id, :entry_ref)
          .filter_map do |binding_id, reference|
            digest = Valkey::AuthState::OpaqueAdmissionStore.reference_digest(reference: reference)
            binding_id if ActiveSupport::SecurityUtils.secure_compare(digest, expected_digest)
          end
      end

    flow_ids_for_bindings(binding_ids)
  end

  def matching_flows_for_principal
    actor_model = config.fetch(:actor)
    public_id = selectors.fetch(:principal_public_id)
    principal_id =
      read(actor_model) do
        actor_model.unscoped.find_by(public_id: public_id)&.id
      end
    return [] if principal_id.nil?

    read(config.fetch(:flow)) do
      config.fetch(:flow).unscoped.where(principal_id:).order(:id).pluck(:public_id)
    end
  end

  def matching_flows_for_social_subject
    candidate_model = config.fetch(:social_candidate)
    return [] if candidate_model.nil?

    provider = selectors.fetch(:provider)
    expected_digest = selectors.fetch(:subject_digest)
    flow_ids =
      read(candidate_model) do
        candidate_model.unscoped.where(surface: surface.to_s, operation: "signup", provider:)
          .find_each.filter_map do |candidate|
            subject = candidate.auth_hash.fetch("principal").fetch("subject")
            digest = IdentitySocialCeremonyContract.provider_subject_digest(provider:, subject:)
            candidate.actor_ref if ActiveSupport::SecurityUtils.secure_compare(digest, expected_digest)
          end
      end

    flow_ids.uniq!
    flow_ids.sort!
  end

  def flow_ids_for_bindings(binding_ids)
    return [] if binding_ids.empty?

    read(config.fetch(:flow)) do
      config.fetch(:flow).unscoped.where(auth_admission_binding_id: binding_ids).order(:id).pluck(:public_id)
    end
  end

  def not_found
    { surface: surface, flow: nil, classification: "flow_not_found" }
  end

  def report_for(public_id)
    flow_model = config.fetch(:flow)
    flow = read(flow_model) { flow_model.unscoped.find_by(public_id:) }
    return not_found if flow.nil?

    op = op_section(flow)
    principal = principal_section(flow.principal_id)
    graph = graph_section(flow.principal_id)
    authority = token_section(flow)
    correlations = correlation_section(flow)
    {
      surface: surface,
      op: op,
      principal: principal,
      graph: graph,
      authority: authority,
      correlations: correlations,
      classification: classify(op.fetch(:flow), principal, graph, authority),
    }
  end

  def op_section(flow)
    binding_model = config.fetch(:binding)

    read(binding_model) do
      read_at = binding_model.database_now
      binding = binding_model.unscoped.find_by(id: flow.auth_admission_binding_id)
      {
        read_at: read_at.iso8601(6),
        flow: flow_report(flow),
        binding: binding_report(binding),
        oidc_authorization: oidc_authorization_report(binding),
        ceremony_sessions: ceremony_session_reports(binding),
        social_candidates: social_candidate_reports(flow),
      }
    end
  end

  def flow_report(flow)
    {
      public_id: flow.public_id,
      status: flow.class::STATUS_NAMES[flow.status_id],
      step: flow.step,
      entry_method: flow.entry_method,
      requirement_names: flow.completed_requirements.to_h.keys.sort,
      principal_id: flow.principal_id,
      issued_at: flow.issued_at&.iso8601(6),
      expires_at: flow.expires_at&.iso8601(6),
      completed_at: flow.completed_at&.iso8601(6),
      auth_admission_binding_id: flow.auth_admission_binding_id,
    }
  end

  def binding_report(binding)
    return nil if binding.nil?

    {
      id: binding.id,
      purpose: binding.purpose,
      entry_intent: binding.entry_intent,
      curfew_at: binding.curfew_at&.iso8601(6),
      redeemed: binding.redeemed?,
      retired: binding.retired?,
    }
  end

  def oidc_authorization_report(binding)
    return nil if binding.nil? || binding.authorization_transaction_id.nil?

    transaction = config.fetch(:authorization_transaction).unscoped.find_by(
      id: binding.authorization_transaction_id,
    )
    return nil if transaction.nil?

    {
      id: transaction.id,
      status: transaction.status,
      consumed_at: transaction.consumed_at&.iso8601(6),
      result_generation: transaction.result_generation,
      result_expires_at: transaction.result_expires_at&.iso8601(6),
      result_consumed_at: transaction.result_consumed_at&.iso8601(6),
    }
  end

  def ceremony_session_reports(binding)
    return { attached: nil, admitted: nil } if binding.nil?

    session_ids = [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id].compact
    sessions = config.fetch(:ceremony_session).unscoped.where(id: session_ids).index_by(&:id)

    {
      attached: ceremony_session_report(sessions[binding.auth_ceremony_session_id]),
      admitted: ceremony_session_report(sessions[binding.admitted_auth_ceremony_session_id]),
    }
  end

  def ceremony_session_report(session)
    return nil if session.nil?

    {
      id: session.id,
      admission_purpose: session.admission_purpose,
      admitted_at: session.admitted_at&.iso8601(6),
      completed_at: session.completed_at&.iso8601(6),
      cancelled_at: session.cancelled_at&.iso8601(6),
      revoked_at: session.revoked_at&.iso8601(6),
      expires_at: session.expires_at&.iso8601(6),
    }
  end

  def social_candidate_reports(flow)
    candidate_model = config.fetch(:social_candidate)
    return [] if candidate_model.nil?

    candidate_model.unscoped.where(
      surface: surface.to_s, actor_ref: flow.public_id, operation: "signup",
    ).order(:id).map do |candidate|
      {
        id: candidate.id,
        provider: candidate.provider,
        operation: candidate.operation,
        consumed_at: candidate.consumed_at&.iso8601(6),
        expires_at: candidate.expires_at&.iso8601(6),
      }
    end
  end

  def principal_section(principal_id)
    actor_model = config.fetch(:actor)
    return { read_at: nil, actor: nil } if principal_id.nil?

    read(actor_model) do
      actor = actor_model.unscoped.find_by(id: principal_id)
      owner_key = config.fetch(:owner_key)
      {
        read_at: actor_model.database_now.iso8601(6),
        actor: actor && {
          id: actor.id,
          status_id: actor.status_id,
          security_mode_id: actor.security_mode_id,
          login_allowed: actor.login_allowed?,
          access_enabled: actor.access_enabled?,
        },
        contacts: config.fetch(:contacts).transform_values do |(model, status_column)|
          model.unscoped.where(owner_key => principal_id).group(status_column).count
        end,
        passkeys: config.fetch(:passkeys).unscoped.where(owner_key => principal_id).group(:status_id).count,
        external_identities: external_identities(principal_id),
      }
    end
  end

  def external_identities(principal_id)
    model = config.fetch(:external_identities)
    return nil if model.nil?

    model.unscoped.where(client_id: principal_id).order(:id).map do |identity|
      {
        id: identity.id,
        owner_id: identity.client_id,
        provider: identity.provider,
        state: identity.state,
        released_at: identity.released_at&.iso8601(6),
      }
    end
  end

  def graph_section(principal_id)
    model = config.fetch(:graph)
    return { read_at: nil, identity: false } if principal_id.nil?

    read(model) do
      { read_at: model.database_now.iso8601(6), identity: model.exists?(source_record_id: principal_id) }
    end
  end

  def token_section(flow)
    model, status_column = config.fetch(:tokens)
    return { read_at: nil, root_tokens: 0 } if flow.principal_id.nil?

    read(model) do
      scope = model.unscoped.where(config.fetch(:owner_key) => flow.principal_id).where(created_at: flow.issued_at..)
      {
        read_at: model.database_now.iso8601(6),
        root_tokens: scope.count,
        by_status: scope.group(status_column).count,
      }
    end
  end

  def correlation_section(flow)
    {
      audit: audit_correlation_section(flow),
      chronicle: chronicle_correlation_section(flow),
    }
  end

  def audit_correlation_section(flow)
    outboxes =
      config.fetch(:audit_outboxes).map do |definition|
        model = definition.fetch(:model)
        flow_column = definition.fetch(:flow_column)
        event_id_column = definition.fetch(:event_id_column)
        event_name_column = definition.fetch(:event_name_column)
        timestamp_column = definition.fetch(:timestamp_column)
        read(model) do
          {
            name: model.name,
            read_at: model.database_now.iso8601(6),
            events: model.unscoped.where(flow_column => flow.public_id).order(:id).map do |event|
              {
                id: event.id,
                event_id: event.public_send(event_id_column),
                event_name: event.public_send(event_name_column),
                occurred_at: event.public_send(timestamp_column)&.iso8601(6),
              }
            end,
          }
        end
      end
    { owner_read_at: outboxes.first.fetch(:read_at), outboxes: }
  end

  def chronicle_correlation_section(flow)
    read(ClientChronicle) do
      read_at = ClientChronicle.database_now.iso8601(6)
      chronicles =
        ClientChronicle.unscoped.where(
          "context ->> 'flow_public_id' = ? AND context ->> 'surface' = ?",
          flow.public_id,
          surface.to_s,
        ).order(:id).map do |event|
          context = event.context.to_h
          {
            id: event.id,
            event_id: event.event_id,
            request_id: context.fetch("request_id", nil),
            occurred_at: event.occurred_at&.iso8601(6),
          }
        end
      outbox_entries =
        ChronicleOutboxEntry.unscoped.where(
          "payload -> 'context' ->> 'flow_public_id' = ? AND payload -> 'context' ->> 'surface' = ?",
          flow.public_id,
          surface.to_s,
        ).order(:id).map do |entry|
          {
            id: entry.id,
            event_id: entry.event_uuid,
            event_name: entry.event,
            status: entry.status,
            request_id: entry.request_id,
            occurred_at: entry.created_at&.iso8601(6),
          }
        end

      {
        read_at: read_at,
        structured_log_search: { surface: surface, flow_public_id: flow.public_id },
        chronicles:,
        outbox_entries:,
      }
    end
  end

  # six.md C.2 scenarios, from the rows that exist.
  def classify(flow, principal, graph, authority)
    completed = flow.fetch(:status) == "COMPLETED"
    terminal = TERMINAL_STATUSES.include?(flow.fetch(:status))
    actor = principal[:actor]
    return "completed_without_principal" if completed && actor.nil?
    return "complete" if completed && graph.fetch(:identity)
    return "in_progress_without_principal" if !terminal && actor.nil?
    return "principal_committed_graph_missing_flow_open" if !terminal && actor && !graph.fetch(:identity)
    return "principal_and_graph_committed_flow_open" if !terminal && actor && graph.fetch(:identity)
    return "ended_without_principal" if terminal && actor.nil?
    return "ended_with_authority_issued" if terminal && authority.fetch(:root_tokens).positive?

    "unclassified"
  end
end
