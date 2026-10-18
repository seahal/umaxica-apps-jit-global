# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Iam
          # Operator capability grants owner for the org Base Self-RP (R5-WU12, approved pattern).
          # Same rules as the former page (adr/operator-capability-authorization.md): grant needs
          # iam.capability.grant and the delegated capability itself, never the granter, never an
          # IAM capability; Step-Up is re-checked here under the root lock; every write is audited
          # with the browser facts forwarded by the authenticated RP.
          class GrantsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint
            include ::OrgAdministrationPage
            include ::OrgAdministrativeAudit

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"
            STEP_UP_SCOPE = "operator_capability"
            DURATIONS = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "180" => 180.days }.freeze

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, ActionController::BadRequest, with: :render_bad_request

            public

            def index
              authorize!(OperatorCapabilityGrant, to: :index?, with: OperatorCapabilityGrantPolicy)
              query = admin_query
              relation = OperatorCapabilityGrant.includes(:operator).order(created_at: :desc, id: :desc)
              relation = relation.joins(:operator).where(operators: { public_id: query }) if query
              grants, page, more = admin_paginate(relation)
              render json: { grants: grants.map { |grant| grant_json(grant) },
                             page:,
                             next_page: more ? page + 1 : nil,
                             can_grant: grantable_capabilities.any?, }
            end

            def show
              grant = find_grant!(:ref)
              authorize!(OperatorCapabilityGrant, to: :index?, with: OperatorCapabilityGrantPolicy)
              render json: { grant: grant_json(grant, detail: true),
                             can_revoke: allowed_to?(:revoke?, grant, with: OperatorCapabilityGrantPolicy), }
            end

            # Form data for the grant screen; reaching it already needs the grant capability and Step-Up.
            def screen
              authorize!(OperatorCapabilityGrant, to: :grant_screen?, with: OperatorCapabilityGrantPolicy)
              with_owner_step_up(STEP_UP_SCOPE) do
                render json: { grantable_capabilities:,
                               reason_codes: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES,
                               durations: DURATIONS.keys, }
              end
            end

            def create
              authorize!(OperatorCapabilityGrant, to: :grant_screen?, with: OperatorCapabilityGrantPolicy)
              with_owner_step_up(STEP_UP_SCOPE) { issue_grant }
            end

            def revoke
              grant = find_grant!(:ref)
              authorize!(grant, to: :revoke?, with: OperatorCapabilityGrantPolicy)
              with_owner_step_up(STEP_UP_SCOPE) { revoke_grant(grant) }
            end

            private

            def current_operator = avatar_actor

            # Browser facts for the audit row, forwarded by the authenticated RP caller.
            def audit_request
              Struct.new(:request_id, :remote_ip, :user_agent).new(
                request.headers["X-Browser-Request-Id"].presence || request.request_id,
                request.headers["X-Browser-Ip"].presence || request.remote_ip,
                request.headers["X-Browser-User-Agent"].to_s,
              )
            end

            def find_grant!(key)
              OperatorCapabilityGrant.includes(:operator, :granted_by_operator, :revoked_by_operator)
                .find_by!(public_id: params.expect(key))
            end

            def grantable_capabilities
              (OperatorCapabilityGrant::CAPABILITIES - OperatorCapabilityGrant::BOOTSTRAP_ONLY_CAPABILITIES)
                .select { |capability| avatar_actor.capability?(capability) }
            end

            def issue_grant
              input = grant_input
              return render(json: { errors: input }, status: :unprocessable_content) if input.key?(:invalid)

              grant = OperatorCapabilityGrant.new(
                operator: input.fetch(:operator),
                capability: input.fetch(:capability),
              )
              authorize!(grant, to: :create?, with: OperatorCapabilityGrantPolicy)
              chronicle =
                audited_administrative_operation(
                  operation_id: input.fetch(:operation_id), action: "iam.capability.granted",
                  subject: input.fetch(:operator), reason_code: input.fetch(:reason_code),
                  metadata: { capability: input.fetch(:capability),
                              ticket_id: input.fetch(:ticket_id),
                              subject_public_id: input.fetch(:operator).public_id, },
                  changeset: {},
                ) do
                  issued = OperatorCapabilityGrant.issue!(
                    operator: input.fetch(:operator), granted_by: avatar_actor, capability: input.fetch(:capability),
                    reason_code: input.fetch(:reason_code), ticket_id: input.fetch(:ticket_id),
                    duration: input.fetch(:duration),
                  )
                  { grant_public_id: issued.public_id, expires_at: issued.expires_at.iso8601 }
                end
              render json: { grant_public_id: chronicle.changeset["grant_public_id"] }, status: :created
            rescue OrgAdministrativeAudit::OperationConflictError
              render json: { errors: { operation_id: t("base.org.admin.errors.conflict") } }, status: :conflict
            rescue OrgAdministrativeAudit::IntentUnavailableError
              render json: { errors: { base: t("base.org.admin.errors.audit_unavailable") } },
                     status: :service_unavailable
            end

            def revoke_grant(grant)
              reason_code = params[:reason_code]
              operation_id = params[:operation_id]
              errors = {}
              unless reason_code.is_a?(String) && OperatorCapabilityGrant::REVOKE_REASON_CODES.include?(reason_code)
                errors[:reason_code] = t("base.org.admin.errors.reason_code")
              end
              unless operation_id.is_a?(String) && OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id)
                errors[:operation_id] = t("base.org.admin.errors.operation_id")
              end
              return render(json: { errors: }, status: :unprocessable_content) if errors.any?

              audited_administrative_operation(
                operation_id:, action: "iam.capability.revoked", subject: grant.operator, reason_code:,
                metadata: { capability: grant.capability,
                            grant_public_id: grant.public_id,
                            subject_public_id: grant.operator.public_id, },
                changeset: { before: { revoked: false } },
              ) do
                grant.revoke!(by: avatar_actor, reason_code:)
                { revoked: true }
              end
              render json: { grant_public_id: grant.public_id }
            rescue OperatorCapabilityGrant::LastCapabilityHolderError
              render json: { errors: { base: t("base.org.admin.errors.last_holder") } }, status: :unprocessable_content
            rescue OperatorCapabilityGrant::AlreadyRevokedError, OrgAdministrativeAudit::OperationConflictError
              render json: { errors: { base: t("base.org.admin.errors.conflict") } }, status: :conflict
            rescue OrgAdministrativeAudit::IntentUnavailableError
              render json: { errors: { base: t("base.org.admin.errors.audit_unavailable") } },
                     status: :service_unavailable
            end

            # Same validation as the former page; an invalid input answers with its field messages.
            def grant_input
              errors = {}
              public_id = params[:operator_public_id]
              operator = Operator.find_by(public_id:) if public_id.is_a?(String) && Operator::PUBLIC_ID_FORMAT.match?(public_id)
              if operator.nil? || !operator.capability_eligible?
                errors[:operator_public_id] = t("base.org.admin.errors.operator")
              elsif operator.id == avatar_actor.id
                errors[:operator_public_id] = t("base.org.admin.errors.self_grant")
              end
              capability = listed(
                :capability, OperatorCapabilityGrant::CAPABILITIES, errors,
                "base.org.admin.errors.capability",
              )
              reason_code = listed(
                :reason_code, OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES, errors,
                "base.org.admin.errors.reason_code",
              )
              duration_key = listed(:duration_days, DURATIONS.keys, errors, "base.org.admin.errors.duration")
              ticket_id = params[:ticket_id]
              ticket_id = nil if ticket_id == ""
              if ticket_id && !(ticket_id.is_a?(String) && OperatorCapabilityGrant::TICKET_ID_FORMAT.match?(ticket_id))
                errors[:ticket_id] = t("base.org.admin.errors.ticket_id")
              end
              operation_id = params[:operation_id]
              unless operation_id.is_a?(String) && OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id)
                errors[:operation_id] = t("base.org.admin.errors.operation_id")
              end
              return errors.merge(invalid: true) if errors.any?

              { operator:,
                capability:,
                reason_code:,
                duration: DURATIONS.fetch(duration_key),
                ticket_id:,
                operation_id:, }
            end

            def listed(key, allowed, errors, message_key)
              value = params[key]
              return value if value.is_a?(String) && allowed.include?(value)

              errors[key] = t(message_key)
              nil
            end

            def t(...) = I18n.t(...)

            def grant_json(grant, detail: false)
              row = {
                public_id: grant.public_id,
                operator_public_id: grant.operator.public_id,
                capability: grant.capability,
                state: grant_state(grant),
                expires_at: grant.expires_at&.iso8601,
              }
              return row unless detail

              row.merge(
                origin: grant.origin, granted_by_public_id: grant.granted_by_operator&.public_id,
                reason_code: grant.reason_code, ticket_id: grant.ticket_id, starts_at: grant.starts_at&.iso8601,
                revoked_at: grant.revoked_at&.iso8601, revoked_by_public_id: grant.revoked_by_operator&.public_id,
              )
            end

            def grant_state(grant)
              if grant.revoked? then "revoked"
              elsif grant.in_force? then "in_force"
              elsif grant.starts_at > Time.current then "pending"
              else "expired"
              end
            end
          end
        end
      end
    end
  end
end
