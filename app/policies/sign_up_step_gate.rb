# typed: false
# frozen_string_literal: true

class SignUpStepGate
  Context =
    Data.define(
      :status,
      :surface,
      :family,
      :step,
      :ticket,
      :registry,
      :next_step,
      :current_step,
      :refusal,
      :errors,
    ) do
      def success?
        status == :ok
      end

      # The request contradicts the authoritative flow instance or phase. `refusal` says how:
      # `:no_active_flow`, `:flow_binding`, or `:phase`. Only `:phase` is attributable to the
      # browser's current flow, so only it may end that flow.
      def refused?
        status == :refused
      end

      def phase_violation?
        refusal == :phase
      end
    end

  STEP_ROUTES = {
    app: {
      "apple" => {
        confirmation: :auth_app_sign_up_check_apple_confirmation_path,
        birthdate: :auth_app_sign_up_check_apple_birthdate_path,
      },
      "google" => {
        confirmation: :auth_app_sign_up_check_google_confirmation_path,
        birthdate: :auth_app_sign_up_check_google_birthdate_path,
      },
      "email" => {
        otp: :auth_app_sign_up_check_email_otp_path,
        birthdate: :auth_app_sign_up_check_email_birthdate_path,
      },
      "telephone" => {
        otp: :auth_app_sign_up_check_telephone_otp_path,
        passkey: :auth_app_sign_up_check_telephone_passkey_path,
        birthdate: :auth_app_sign_up_check_telephone_birthdate_path,
      },
    },
    com: {
      "email" => {
        otp: :auth_com_sign_up_check_email_otp_path,
        birthdate: :auth_com_sign_up_check_email_birthdate_path,
      },
      "telephone" => {
        otp: :auth_com_sign_up_check_telephone_otp_path,
        passkey: :auth_com_sign_up_check_telephone_passkey_path,
        birthdate: :auth_com_sign_up_check_telephone_birthdate_path,
      },
    },
  }.freeze

  CREATE_STEPS = %i(otp passkey).freeze

  class << self
    public

    def for_show(controller:, surface:, family:, step:)
      new(controller: controller, surface: surface, family: family, step: step, mode: :show).call
    end

    def for_create(controller:, surface:, family:, step:)
      new(controller: controller, surface: surface, family: family, step: step, mode: :create).call
    end

    def for_update(controller:, surface:, family:, step:)
      new(controller: controller, surface: surface, family: family, step: step, mode: :update).call
    end

    def for_destroy(controller:, surface:, family:, step:)
      new(controller: controller, surface: surface, family: family, step: step, mode: :destroy).call
    end

    # The neutral re-entry of an active flow (the guard route, reached from provider callbacks and
    # contact verification). It names no phase and carries no flow binding; it only resolves the
    # authoritative step so the caller can send the browser there.
    def for_entry(controller:, surface:, family:, step:)
      new(controller: controller, surface: surface, family: family, step: step, mode: :entry).call
    end

    # The one step a flow accepts now, or nil when it accepts none. Contact entry flows serve the
    # OTP step before the checkpoint exists; every other step is a checkpoint requirement.
    def current_step_for(ticket, registry)
      if ticket.sign_up_checkpoint_pending?
        registry.next_requirement(ticket.completed_requirements)
      elsif ticket.step.in?(%w(contact contact_verified)) && registry.requirement?(:otp)
        :otp
      end
    end
  end

  def initialize(controller:, surface:, family:, step:, mode:)
    @controller = controller
    @surface = surface.to_sym
    @family = family.to_s
    @step = step.to_sym
    @mode = mode.to_sym
  end

  public

  def call
    return failure("unsupported sign-up route") unless route_known?

    ticket = current_ticket
    return refusal(:no_active_flow) unless ticket

    binding = binding_for_request
    return refusal(:flow_binding) unless mode == :entry || instance_bound_to?(ticket, binding)
    return refusal(:flow_binding) unless mode == :entry || binding_fresh?(ticket, binding)

    registry = SignUpRequirementRegistry.for_ticket(ticket, surface: surface)
    return failure("family does not match ticket") unless registry.entry_method == family
    return context(ticket, registry, current_step: nil) if mode == :destroy
    return failure("ticket is not usable") if unusable_ticket?(ticket)

    current_step = self.class.current_step_for(ticket, registry)
    return context(ticket, registry, current_step: current_step) if mode == :entry
    return refusal(:phase, ticket: ticket, registry: registry, current_step: current_step) unless
      phase_bound_to?(ticket, binding)
    return failure("step does not belong to ticket") unless registry.requirement?(step)
    if committed_email_finalization_retry?(ticket, registry, current_step)
      return context(ticket, registry, current_step: current_step)
    end
    return refusal(:phase, ticket: ticket, registry: registry, current_step: current_step) unless current_step == step
    if mode == :create && CREATE_STEPS.exclude?(step)
      return failure("challenge issuance is not allowed for this step")
    end

    context(ticket, registry, current_step: current_step)
  rescue ArgumentError => e
    failure(e.message)
  end

  private

  attr_reader :controller, :surface, :family, :step, :mode

  def route_known?
    STEP_ROUTES.dig(surface, family, step).present?
  end

  # E1 (WU-24h): the Flow is the one bound to the admitted ceremony's Binding; a session locator or a
  # sequence id never selects one on its own.
  def current_ticket
    controller.send(:current_sign_up_flow_ticket)
  end

  def cycle_class
    case surface
    when :app then ClientSignUpFlow
    when :com then VisitorSignUpFlow
    else
      raise ArgumentError, "unsupported sign-up surface"
    end
  end

  # The request must name the same flow instance that the session locator resolves. A page rendered
  # for an earlier flow, a request with no binding, and a binding minted for another surface fail
  # here and are never attributed to the current flow.
  def binding_for_request
    SignFlowBindingCodec.decode(controller.params[AuthIoKeys::Params::FLOW_BINDING])
  end

  def instance_bound_to?(ticket, binding)
    return false unless binding

    binding.kind == "sign_up" && binding.surface == surface.to_s &&
      ActiveSupport::SecurityUtils.secure_compare(binding.flow_public_id, ticket.public_id.to_s)
  end

  def binding_fresh?(ticket, binding)
    binding && binding.expires_at > ticket.class.database_now.to_i
  end

  # A binding for this exact flow can still be stale: the authoritative phase or checkpoint
  # generation may have advanced after the page was rendered. That is a phase violation, so a
  # state-changing request may halt this flow while an old flow instance can never halt its
  # replacement.
  def phase_bound_to?(ticket, binding)
    return false unless binding

    binding.phase == ticket.step.to_s && binding.generation == ticket.checkpoint_version &&
      ticket.expires_at.to_i.positive?
  end

  def unusable_ticket?(ticket)
    return true if ticket.expired? || (ticket.respond_to?(:lapsed?) && ticket.lapsed?)

    ticket.is_a?(FlowSignUp) && ticket.sign_up_terminal?
  end

  def committed_email_finalization_retry?(ticket, registry, current_step)
    return false unless mode == :update && family == "email" && step == :birthdate && current_step.nil?
    return false unless ticket.sign_up_checkpoint_pending? && ticket.pending_contact_type == "email" &&
      registry.missing_requirements(ticket.completed_requirements).empty?

    owner_model, contact_model, outbox_model, owner_key =
      case surface
      when :app then [Client, ClientEmail, ClientContactAuditOutbox, :user_id]
      when :com then [Visitor, VisitorEmail, VisitorContactAuditOutbox, :visitor_id]
      else return false
      end
    owner = owner_model.find_by(id: ticket.principal_id)
    contact = contact_model.find_by(:id => ticket.pending_contact_id, owner_key => ticket.principal_id)
    return false unless owner&.active? && contact&.binding_effective?

    # This admits reconciliation, not another checkpoint write. The controller rechecks the
    # original Source intent under owner/contact locks and skips the cleared birthdate mutation.
    outbox_model.where(
      contact_kind: "email", event_name: "finalized", owner_ref: owner.public_id,
      contact_ref: contact.public_id, operation_ref: ticket.public_id, actor_ref: nil,
    ).count == 1
  end

  def context(ticket, registry, current_step:)
    Context.new(
      status: :ok,
      surface: surface,
      family: family,
      step: step,
      ticket: ticket,
      registry: registry,
      next_step: current_step,
      current_step: current_step,
      refusal: nil,
      errors: [],
    )
  end

  def refusal(kind, ticket: nil, registry: nil, current_step: nil)
    Context.new(
      status: :refused,
      surface: surface,
      family: family,
      step: step,
      ticket: ticket,
      registry: registry,
      next_step: current_step,
      current_step: current_step,
      refusal: kind,
      errors: ["request contradicts the authoritative sign-up flow"],
    )
  end

  def failure(message)
    Context.new(
      status: :invalid,
      surface: surface,
      family: family,
      step: step,
      ticket: nil,
      registry: nil,
      next_step: nil,
      current_step: nil,
      refusal: nil,
      errors: [message],
    )
  end
end
