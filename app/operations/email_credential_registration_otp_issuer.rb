# frozen_string_literal: true

class EmailCredentialRegistrationOtpIssuer
  class << self
    public

    def call(actor:, token:, email:, browser_nonce:, bootstrap_transaction: nil)
      surface, transaction_model, pending_status = components(actor, token, email)
      if surface == "org" && bootstrap_transaction
        raise ArgumentError, "ORG Email registration does not accept bootstrap permission"
      end

      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          transaction_model.connection_owner.connected_to(role: :writing) do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                email.with_lock do
                  if bootstrap_transaction
                    EmailCredentialRegistrationBootstrapGuard.call(
                      actor: actor, token: token, bootstrap_transaction: bootstrap_transaction,
                      browser_nonce: browser_nonce,
                    ) do
                      issue_locked(
                        actor, token, email, transaction_model, pending_status, browser_nonce, bootstrap_transaction,
                        device_session:,
                      )
                    end || result(:unavailable)
                  else
                    issue_locked(
                      actor, token, email, transaction_model, pending_status, browser_nonce,
                      device_session:,
                    )
                  end
                end
              end
            end
          end
        end
      end
    end

    private

    def components(actor, token, email)
      case [actor, token, email]
      in [Client, ClientToken, ClientEmail]
        ["app", ClientEmailCeremonyTransaction, ClientEmailStatus::UNVERIFIED]
      in [Visitor, VisitorToken, VisitorEmail]
        ["com", VisitorEmailCeremonyTransaction, VisitorEmailStatus::UNVERIFIED]
      in [Operator, OperatorToken, OperatorEmail]
        ["org", OperatorEmailCeremonyTransaction, OperatorEmailStatus::UNVERIFIED]
      else raise ArgumentError, "unsupported Email credential registration realm"
      end
    end

    def issue_locked(actor, token, email, transaction_model, pending_status, browser_nonce,
                     bootstrap_transaction = nil, device_session:)
      ticket_now = transaction_model.database_now
      source_now = email.class.database_now
      unless current_binding?(actor, token, email, pending_status, ticket_now, source_now, device_session)
        return result(:unavailable)
      end
      return result(:locked) if email.locked?(now: source_now)
      return result(:rate_limited) if email.otp_cooldown_active?(now: source_now)

      cancel_original_browser_challenges!(actor, token, email, transaction_model, browser_nonce)
      transaction = create_transaction_with_generated_reference!(
        surface: transaction_model.ceremony_surface, transaction_model: transaction_model,
        actor: actor, token: token, email: email, browser_nonce: browser_nonce, now: ticket_now,
        expires_at: [ticket_now + EmailCeremonyTransactionable::DEFAULT_TTL, token.discard_at].min,
      )
      if bootstrap_transaction
        transaction.update!(
          purpose: "credential_registration", bootstrap_ceremony_transaction_ref: bootstrap_transaction.transaction_id,
          expires_at: [transaction.expires_at, bootstrap_transaction.expires_at].min,
        )
      end
      code = transaction.issue_email_otp!(purpose: "credential_registration")
      email.update!(otp_last_sent_at: source_now)
      result(:issued, transaction: transaction, code: code.freeze)
    end

    def create_transaction_with_generated_reference!(surface:, transaction_model:, actor:, token:, email:,
                                                     browser_nonce:, now:, expires_at:)
      retries = 0

      loop do
        begin
          transaction_model.transaction(requires_new: true) do
            transaction_ref = PublicId.generate
            session_binding = CredentialRegistrationOtpSessionValue.for(
              surface: surface, channel: :email, transaction_ref: transaction_ref,
              root_ref: token.public_id, browser_nonce: browser_nonce,
            )
            return transaction_model.create_transaction!(
              transaction_id: transaction_ref, grant_jti: PublicId.generate,
              actor_ref: actor.public_id, session_ref: session_binding.dump,
              operation: "registration", email_candidate_ref: email.public_id,
              normalized_email_digest: email.address_digest, now: now, expires_at: expires_at,
            )
          end
        rescue ActiveRecord::RecordInvalid => e
          raise unless generated_reference_collision_validation?(e)
        rescue ActiveRecord::RecordNotUnique => e
          raise unless generated_reference_collision?(transaction_model, e)
        end

        retries += 1
        raise if retries > PublicId::MAX_COLLISION_RETRIES
      end
    end

    def generated_reference_collision_validation?(error)
      %i(transaction_id grant_jti).any? { |attribute| error.record.errors.of_kind?(attribute, :taken) }
    end

    def generated_reference_collision?(transaction_model, error)
      result = error.cause&.result
      return false unless result

      constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      transaction_model.lease_connection.schema_cache.indexes(transaction_model.table_name).any? do |index|
        index.name == constraint && index.unique && index.where.nil? &&
          index.columns.one? && %w(transaction_id grant_jti).include?(index.columns.first)
      end
    end

    def cancel_original_browser_challenges!(actor, token, email, transaction_model, browser_nonce)
      transaction_model.where(
        actor_ref: actor.public_id, email_candidate_ref: email.public_id, operation: "registration",
        purpose: "credential_registration", status: "pending", otp_consumed_at: nil, otp_cancelled_at: nil,
      ).find_each do |previous|
        expected = CredentialRegistrationOtpSessionValue.for(
          surface: previous.surface, channel: :email, transaction_ref: previous.transaction_id,
          root_ref: token.public_id, browser_nonce: browser_nonce,
        ).dump
        previous.cancel_email_otp! if previous.session_ref == expected
      end
    end

    def current_binding?(actor, token, email, pending_status, ticket_now, source_now, device_session)
      source_owned_pending?(
        actor, token, email, device_session,
        pending_status,
      ) && actor.login_allowed? && actor.accessible?(source_now) &&
        uncommitted_candidate?(email, source_now) &&
        token.active_status?(ticket_now) && device_session.usable? &&
        device_session.current_refresh_token_id == token.id
    end

    def source_owned_pending?(actor, token, email, device_session, pending_status)
      case actor
      when Client
        token.user_id == actor.id && device_session.user_id == actor.id && email.user_id == actor.id &&
          email.user_email_status_id == pending_status
      when Visitor
        token.visitor_id == actor.id && device_session.visitor_id == actor.id && email.visitor_id == actor.id &&
          email.visitor_email_status_id == pending_status
      when Operator
        token.staff_id == actor.id && device_session.staff_id == actor.id && email.staff_id == actor.id &&
          email.staff_email_status_id == pending_status
      end
    end

    def uncommitted_candidate?(email, now)
      case email
      when ClientEmail, VisitorEmail
        email.accessible?(now) && !email.binding_finalized_at && !email.binding_released?
      when OperatorEmail then email.staff_email_status_id == OperatorEmailStatus::UNVERIFIED
      else raise ArgumentError, "unsupported Email registration candidate"
      end
    end

    def result(status, transaction: nil, code: nil)
      EmailCredentialRegistrationOtpIssueResult.new(status: status, transaction: transaction, code: code)
    end
  end
end
