# frozen_string_literal: true

class OperatorStepUpContextTransitionWriter
  class << self
    public

    def call!(context:, to_state_id:, reason_code:)
      unless context.is_a?(OperatorStepUpContext) &&
          [OperatorStepUpContextState::COMMITTED, OperatorStepUpContextState::CANCELLED,
           OperatorStepUpContextState::EXPIRED, OperatorStepUpContextState::FAILED,].include?(to_state_id) &&
          StepUpAuditCodesRegistry::REASON_CODES.include?(reason_code)
        raise ArgumentError, "operator step-up context transition is invalid"
      end

      OpBaseOrgRecord.connected_to(role: :writing) do
        OpBaseOrgRecord.transaction do
          context.with_lock do
            locked = OperatorStepUpContext.lock.find(context.id)
            now = OpBaseOrgRecord.database_now
            return false unless locked.state_id == OperatorStepUpContextState::PENDING

            if to_state_id == OperatorStepUpContextState::EXPIRED
              raise ArgumentError, "operator step-up context has not expired" if locked.expires_at > now
            elsif locked.expires_at <= now
              raise ArgumentError, "operator step-up context has expired"
            end

            valid_reason =
              case to_state_id
              when OperatorStepUpContextState::COMMITTED then reason_code == "completed"
              when OperatorStepUpContextState::CANCELLED then reason_code == "user_cancelled"
              when OperatorStepUpContextState::EXPIRED then reason_code == "expired"
              when OperatorStepUpContextState::FAILED
                StepUpAuditCodesRegistry::FAILED_CODES.include?(reason_code)
              else false
              end
            raise ArgumentError, "operator step-up context transition reason is invalid" unless valid_reason

            OperatorStepUpContextTransition.create!(
              owner: locked, from_state_id: locked.state_id, to_state_id:, reason_code:, occurred_at: now,
            )
            locked.update!(state_id: to_state_id, updated_at: now)
            true
          end
        end
      end
    end
  end
end
