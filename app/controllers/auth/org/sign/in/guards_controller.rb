# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        class GuardsController < ::Auth::Org::ApplicationController
          AUTHENTICATION_MODE = :open

          def show
            cycle = validated_guard_cycle
            return redirect_to_guard_entry unless cycle

            route_guard_cycle(cycle)
          end

          private

          def sign_in_sequence_surface = :org

          def guard_entry_path
            auth_org_sign_in_path(ri: current_region_identifier)
          end

          def route_guard_cycle(cycle)
            return redirect_to(auth_org_sign_in_session_path(ri: current_region_identifier, pt: guard_pt_for(cycle))) if
              session_limit_resolution
            return route_pending_guard(cycle) if cycle.sign_in_guardrail_pending?
            return redirect_to_guard_check(cycle) if cycle.sign_in_checkpoint_pending?
            return redirect_to(sign_in_selector_path(pt: guard_return_to(cycle))) if cycle.sign_in_selector_pending?
            return redirect_to(sign_in_welcome_path(pt: guard_return_to(cycle))) if
              cycle.sign_in_session_issuance_pending? ||
                cycle.sign_in_completed?

            redirect_to_guard_entry
          end

          def route_pending_guard(cycle)
            result = SignInGuardrailParticipant.new(cycle: cycle, actor: sign_in_flow_actor(cycle)).evaluate
            return render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden if result.blocking?

            redirect_to_guard_check(cycle)
          end

          def redirect_to_guard_check(cycle)
            redirect_to(auth_org_sign_in_check_path(ri: current_region_identifier, pt: guard_pt_for(cycle)))
          end

          def validated_guard_cycle
            return if invalid_guard_pt?

            cycle = current_db_sign_in_flow_for_sequence
            return unless cycle
            return if unsafe_guard_return_to?(cycle)

            cycle
          end

          def invalid_guard_pt?
            path_target_value.present? && signed_pt_param.blank?
          end

          def unsafe_guard_return_to?(cycle)
            cycle.return_to.present? && signed_pt_token(cycle.return_to).blank?
          end

          def guard_return_to(cycle)
            path_from_signed_pt(signed_pt_param).presence || cycle.return_to.presence
          end

          def guard_pt_for(cycle)
            signed_pt_param.presence || signed_pt_token(cycle.return_to)
          end

          def redirect_to_guard_entry
            redirect_to(guard_entry_path)
          end
        end
      end
    end
  end
end
