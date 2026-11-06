# frozen_string_literal: true

# Consume OP authorization first, then commit Source while keeping the OP parent locked until
# Source commit is known. The second OP transaction is read-only except for row locks.
class AppSignUpRegistrationCommitter
  class << self
    public

    def call!(flow:, client:, method:)
      unless flow.is_a?(ClientSignUpFlow) && client.is_a?(Client) && flow.persisted? && client.persisted? &&
          flow.principal_id == client.id && flow.entry_method == method &&
          ClientRegistrationCompletionMethod::IDS.key?(method)
        raise ArgumentError, "Registration source ownership mismatch"
      end

      commit =
        lambda do
          existing = authorize!(flow)
          next existing if existing

          receipt = nil
          OpBaseAppRecord.connected_to(role: :writing) do
            ClientSignUpFlow.transaction do
              AppZenithRecord.connected_to(role: :writing) do
                Client.transaction do
                  client.lock!
                  flow.lock_registration_parent!
                  flow.lock!
                  flow.require_registration_authority!
                  unless source_available?(flow, client, method)
                    raise FlowInvalidTransition, "Registration consumed authorization is unavailable"
                  end

                  yield
                  receipt = ClientRegistrationCompletion.create!(
                    public_id: PublicId.generate, client: client, sign_up_flow_ref: flow.public_id,
                    method_id: ClientRegistrationCompletionMethod::IDS.fetch(method), completed_at: Client.database_now,
                  )
                  receipt.verify_flow!(flow)
                end
              end
            end
          end
          receipt
        end

      contact =
        case method
        when "email" then ClientEmail.find_by(id: flow.pending_contact_id)
        when "telephone" then ClientTelephone.find_by(id: flow.pending_contact_id)
        end
      if contact && contact.user_id == client.id && %w(email telephone).include?(method)
        AppRegisteredContactDestinationGuard.with_available_destination(contact: contact, owner: client, &commit)
      else
        commit.call
      end
    end

    private

    def authorize!(flow)
      existing = nil
      flow.with_cycle_lock do
        existing = flow.registration_completion
        next if existing

        flow.require_registration_authority!
        unless flow.sign_up_checkpoint_pending? &&
            SignUpRequirementRegistry.for_ticket(flow).missing_requirements(flow.completed_requirements).empty?
          raise FlowInvalidTransition, "Registration authorization is not at the final checkpoint"
        end

        flow.begin_sign_up_finalization!
      end
      existing
    end

    def source_available?(flow, client, method)
      flow.status_id == ClientSignUpFlowStatus::FINALIZING &&
        flow.principal_id == client.id && flow.entry_method == method &&
        client.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP && client.active? &&
        client.access_enabled? && client.accessible?(Client.database_now)
    end
  end
end
