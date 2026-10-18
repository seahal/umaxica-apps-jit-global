# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Support
          # Org Support owner for app Client / com Visitor administration (R5-WU12, approved
          # pattern). The org operator's signed caller is verified here; the existing target-specific
          # Support policies and Enforcement case policy decide; session revocation keeps its audit,
          # Step-Up and AccountSessionRevocation semantics. No cross-TLD user login is involved.
          class AccountsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint
            include ::OrgAdministrationPage
            include ::OrgAdministrativeAudit
            include ::OrgSupportSessionRevocationPage

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"
            STEP_UP_SCOPE = "support_session_revoke"
            REALMS = {
              "app" => [Client, SupportClientPolicy, AppEnforcementCase],
              "com" => [Visitor, SupportVisitorPolicy, ComEnforcementCase],
            }.freeze

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, ActionController::BadRequest, with: :render_bad_request

            public

            def index
              authorize!(account_class, to: :index?, with: policy)
              query = admin_query
              relation = account_class.order(created_at: :desc, id: :desc)
              relation = relation.where(public_id: query) if query
              accounts, page, more = admin_paginate(relation)
              render json: { accounts: accounts.map { |row|
                account_json(row)
              },
                             page:,
                             next_page: more ? page + 1 : nil, }
            end

            def show
              account = find_account!
              authorize!(account, to: :show?, with: policy)
              can_index_cases = allowed_to?(:index?, case_class.new, with: EnforcementCasePolicy)
              render json: {
                account: account_json(account).merge(
                  active_sessions: AuthenticationSessionRevoker.tokens_for(account).not_revoked.count,
                ),
                can_revoke_sessions: allowed_to?(:revoke_sessions?, account, with: policy),
                can_create_case: allowed_to?(:create?, case_class.new, with: EnforcementCasePolicy),
                cases: (if can_index_cases
                          case_class.where(principal_public_id: account.public_id).order(created_at: :desc).limit(20)
                            .map { |row| { public_id: row.public_id, kind: row.kind, state: row.state } }
                        end),
              }
            end

            def revocation_screen
              account = find_account!
              authorize!(account, to: :revoke_sessions?, with: policy)
              with_owner_step_up(STEP_UP_SCOPE) do
                count = AuthenticationSessionRevoker.tokens_for(account).not_revoked.count
                render json: { account: account_json(account).merge(active_sessions: count) }
              end
            end

            def revoke
              account = find_account!
              authorize!(account, to: :revoke_sessions?, with: policy)
              with_owner_step_up(STEP_UP_SCOPE) { revoke_sessions(account) }
            end

            def revocation
              account = find_account!
              authorize!(account, to: :show?, with: policy)
              chronicle = Chronicle.find_by(
                event_uuid: params.expect(:event_uuid), action: AUDIT_ACTION,
                subject_type: account.class.name, subject_id: account.id,
              )
              raise ActiveRecord::RecordNotFound, "revocation not found" if chronicle.nil?

              performer = Operator.find_by(id: chronicle.actor_id) if chronicle.actor_type == "Operator"
              render json: {
                account: account_json(account),
                event_uuid: chronicle.event_uuid,
                result_label: revocation_result_label(chronicle),
                notices: revocation_result_notices(chronicle),
                performed_by: performer&.public_id,
                reason_code: chronicle.reason.to_s,
                ticket_id: chronicle.metadata["ticket_id"],
                occurred_at: chronicle.occurred_at&.iso8601,
                revoked_count: chronicle.changeset["revoked_count"],
              }
            end

            private

            def current_operator = avatar_actor

            def t(...) = I18n.t(...)

            def realm = params.expect(:realm)

            def account_class = REALMS.fetch(realm) { raise ActiveRecord::RecordNotFound }[0]

            def policy = REALMS.fetch(realm)[1]

            def case_class = REALMS.fetch(realm)[2]

            def find_account! = account_class.find_by!(public_id: params.expect(:ref))

            def audit_request
              Struct.new(:request_id, :remote_ip, :user_agent).new(
                request.headers["X-Browser-Request-Id"].presence || request.request_id,
                request.headers["X-Browser-Ip"].presence || request.remote_ip,
                request.headers["X-Browser-User-Agent"].to_s,
              )
            end

            def account_json(account)
              { public_id: account.public_id,
                access_state: account.access_state,
                created_at: account.created_at&.iso8601, }
            end

            def revoke_sessions(account)
              reason_code, ticket_id, operation_id = revocation_input!
              chronicle =
                audited_administrative_operation(
                  operation_id:, action: AUDIT_ACTION, subject: account, reason_code:,
                  metadata: revocation_audit_metadata(target: account, realm:, ticket_id:),
                  changeset: revocation_audit_changeset(account),
                ) do
                  result = AccountSessionRevocation.purge!(
                    account:, operator: avatar_actor, reason_code:, ticket_id:,
                  )
                  { revoked_count: result.revoked_count, account_access_event_id: result.event.id }
                end
              render json: { event_uuid: chronicle.event_uuid }, status: :created
            rescue InvalidRevocationInput => e
              render json: { errors: e.errors }, status: :unprocessable_content
            rescue OrgAdministrativeAudit::OperationConflictError
              render json: { errors: { operation_id: t("base.org.admin.errors.conflict") } }, status: :conflict
            rescue OrgAdministrativeAudit::IntentUnavailableError
              render json: { errors: { base: t("base.org.admin.errors.audit_unavailable") } },
                     status: :service_unavailable
            end
          end
        end
      end
    end
  end
end
