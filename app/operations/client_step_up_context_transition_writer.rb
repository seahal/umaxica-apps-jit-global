# frozen_string_literal: true

class ClientStepUpContextTransitionWriter
  class << self
    public

    def call!(context:, to_state_id:, reason_code:)
      unless context.is_a?(ClientStepUpContext) &&
          [ClientStepUpContextState::COMMITTED, ClientStepUpContextState::CANCELLED,
           ClientStepUpContextState::EXPIRED, ClientStepUpContextState::FAILED,].include?(to_state_id) &&
          StepUpAuditCodesRegistry::REASON_CODES.include?(reason_code)
        raise ArgumentError, "client step-up context transition is invalid"
      end

      OpBaseAppRecord.connected_to(role: :writing) do
        OpBaseAppRecord.transaction do
          context.with_lock do
            locked = ClientStepUpContext.lock.find(context.id)
            now = OpBaseAppRecord.database_now
            return false unless locked.state_id == ClientStepUpContextState::PENDING

            if to_state_id == ClientStepUpContextState::EXPIRED
              raise ArgumentError, "client step-up context has not expired" if locked.expires_at > now
            elsif locked.expires_at <= now
              raise ArgumentError, "client step-up context has expired"
            end

            valid_reason =
              case to_state_id
              when ClientStepUpContextState::COMMITTED then reason_code == "completed"
              when ClientStepUpContextState::CANCELLED then reason_code == "user_cancelled"
              when ClientStepUpContextState::EXPIRED then reason_code == "expired"
              when ClientStepUpContextState::FAILED
                StepUpAuditCodesRegistry::FAILED_CODES.include?(reason_code)
              else false
              end
            raise ArgumentError, "client step-up context transition reason is invalid" unless valid_reason

            ClientStepUpContextTransition.create!(
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
