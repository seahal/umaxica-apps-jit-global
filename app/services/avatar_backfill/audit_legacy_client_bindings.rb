# typed: false
# frozen_string_literal: true

require "json"

module AvatarBackfill
  class AuditLegacyClientBindings < ApplicationService
    Result =
      Data.define(:summary, :details) do
        def to_h = { summary: summary, details: details }

        def to_json(*) = JSON.pretty_generate(to_h)
      end

    BUCKETS = %w(
      safe_to_backfill
      already_bound_consistent
      already_bound_inconsistent
      subject_already_has_active_binding
      multiple_legacy_avatars_for_subject
      avatar_has_multiple_active_bindings
      missing_client
      unresolved_subject
      ambiguous_subject
      cross_db_reference_error
      deleted_avatar_skipped
      legacy_ugc_related
      unknown
    ).freeze

    def initialize(output_path: nil)
      super()
      @output_path = output_path
    end

    def call
      details = legacy_avatars.map { |avatar| audit_avatar(avatar) }
      summary = build_summary(details)
      result = Result.new(summary: summary, details: details)
      write_report(result) if output_path.present?
      result
    end

    private

    attr_reader :output_path

    def legacy_avatars
      Avatar.includes(:lifecycle_state).where.not(client_id: nil).order(:id)
    end

    def audit_avatar(avatar)
      resolved = resolve_subject(avatar.client_id)
      active_bindings = active_bindings_for_avatar(avatar)
      bucket, reason, action = classify(avatar, resolved, active_bindings)

      detail_for(
        avatar: avatar,
        resolved: resolved,
        active_bindings: active_bindings,
        bucket: bucket,
        reason: reason,
        action: action,
      )
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      detail_for(
        avatar: avatar,
        resolved: nil,
        active_bindings: [],
        bucket: "cross_db_reference_error",
        reason: e.message,
        action: "review cross-database reference state before retrying",
      )
    rescue StandardError => e
      detail_for(
        avatar: avatar,
        resolved: nil,
        active_bindings: [],
        bucket: "unknown",
        reason: "#{e.class}: #{e.message}",
        action: "manual review required",
      )
    end

    def classify(avatar, resolved, active_bindings)
      return bucket("deleted_avatar_skipped", "avatar lifecycle is deleted", "skip automatic backfill") if
        avatar.lifecycle_state&.key == "deleted" || !avatar.accessible?
      return bucket(
        "avatar_has_multiple_active_bindings", "avatar has multiple active bindings",
        "manual review required",
      ) if
        active_bindings.size > 1
      return bucket("missing_client", "legacy client_id does not resolve to a Client", "manual review required") if
        resolved == :missing_client
      return bucket("unresolved_subject", "legacy client_id has no ClientPersona", "manual review required") if
        resolved.blank?
      return bucket(
        "ambiguous_subject", "legacy client_id resolves to multiple candidate Personas",
        "manual review required",
      ) if
        resolved.is_a?(Array)

      existing_binding = active_bindings.first
      if existing_binding
        if binding_matches_subject?(existing_binding, resolved)
          return bucket(
            "already_bound_consistent", "avatar already has the expected active binding",
            "no change needed",
          )
        end

        return bucket(
          "already_bound_inconsistent", "avatar active binding points at another subject",
          "manual review required",
        )
      end

      legacy_avatar_count = Avatar.where(client_id: avatar.client_id).where.not(id: avatar.id).count
      return bucket(
        "multiple_legacy_avatars_for_subject", "subject has multiple legacy avatars.client_id rows",
        "manual review required",
      ) if
        legacy_avatar_count.positive?

      subject_binding = active_binding_for_subject(resolved)
      return bucket(
        "subject_already_has_active_binding", "resolved subject already has another active Avatar binding",
        "manual review required",
      ) if
        subject_binding.present?

      bucket(
        "safe_to_backfill", "legacy client_id resolves to one unbound active ClientPersona",
        "create AvatarPersonaBinding",
      )
    end

    def bucket(name, reason, action)
      [name, reason, action]
    end

    def resolve_subject(client_id)
      client = Client.find_by(id: client_id)
      return :missing_client unless client

      identities = ClientIdentity.where(source_record_id: client.id).to_a
      return nil if identities.empty?
      if identities.many?
        return identities.flat_map { |identity| ClientPersona.where(client_identity_id: identity.id).to_a }
      end

      personas = ClientPersona.where(client_identity_id: identities.first.id).to_a
      return nil if personas.empty?
      return personas if personas.many?

      personas.first
    end

    def active_bindings_for_avatar(avatar)
      [
        AvatarPersonaBinding.active.find_by(avatar_id: avatar.id),
        AvatarAgentBinding.active.find_by(avatar_id: avatar.id),
        AvatarIndividualBinding.active.find_by(avatar_id: avatar.id),
      ].compact
    end

    def active_binding_for_subject(subject)
      case subject
      when ClientPersona
        AvatarPersonaBinding.active.find_by(persona_id: subject.id)
      when Agent
        AvatarAgentBinding.active.find_by(agent_id: subject.id)
      when Individual
        AvatarIndividualBinding.active.find_by(individual_id: subject.id)
      end
    end

    def binding_matches_subject?(binding, subject)
      case [binding, subject]
      in [AvatarPersonaBinding, ClientPersona]
        binding.persona_id == subject.id
      in [AvatarAgentBinding, Agent]
        binding.agent_id == subject.id
      in [AvatarIndividualBinding, Individual]
        binding.individual_id == subject.id
      else
        false
      end
    end

    def detail_for(avatar:, resolved:, active_bindings:, bucket:, reason:, action:)
      binding = active_bindings.first
      subject = resolved.is_a?(Array) ? resolved.first : resolved

      {
        avatar_id: avatar.id,
        avatar_public_id: avatar.public_id,
        lifecycle_state: avatar.lifecycle_state&.key,
        legacy_client_id: avatar.client_id,
        resolved_subject_type: subject.is_a?(ActiveRecord::Base) ? subject.class.name : nil,
        resolved_subject_id: subject.respond_to?(:id) ? subject.id : nil,
        resolved_subject_public_id: subject.respond_to?(:public_id) ? subject.public_id : nil,
        existing_binding_type: binding&.class&.name,
        existing_binding_public_id: binding&.public_id,
        conflict_bucket: bucket,
        reason: reason,
        recommended_next_action: action,
      }
    end

    def build_summary(details)
      summary = {
        total_avatars_scanned: Avatar.count,
        avatars_with_legacy_client_id: details.size,
        avatars_already_actively_bound: details.count { |detail| detail[:existing_binding_type].present? },
      }
      BUCKETS.each { |bucket|
        summary[:"#{bucket}_count"] =
          details.count { |detail|
            detail[:conflict_bucket] == bucket
          }
      }
      summary
    end

    def write_report(result)
      path = Rails.root.join(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, result.to_json)
    end
  end
end
