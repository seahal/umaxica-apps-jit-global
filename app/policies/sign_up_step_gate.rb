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

  def call
    return failure("unsupported sign-up route") unless route_known?

    ticket = current_ticket
    return refusal(:no_active_flow) unless ticket
    return refusal(:flow_binding) unless mode == :entry || bound_to?(ticket)

    registry = SignUpRequirementRegistry.for_ticket(ticket, surface: surface)
    return failure("family does not match ticket") unless registry.entry_method == family
    return context(ticket, registry, current_step: nil) if mode == :destroy
    return failure("ticket is not usable") if unusable_ticket?(ticket)

    current_step = self.class.current_step_for(ticket, registry)
    return context(ticket, registry, current_step: current_step) if mode == :entry
    return failure("step does not belong to ticket") unless registry.requirement?(step)
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

  def current_ticket
    if controller.respond_to?(:current_sign_up_flow_ticket, true)
      ticket = controller.send(:current_sign_up_flow_ticket)
      return ticket if ticket
    end

    locator = SignUpCycleLocator.new(controller.session, surface: surface, cycle_class: cycle_class)
    locator.current || ticket_from_sequence_id
  end

  def ticket_from_sequence_id
    public_id = controller.send(:sign_up_ticket_public_id) if controller.respond_to?(:sign_up_ticket_public_id, true)
    return if public_id.blank?

    cycle = cycle_class.find_by(public_id: public_id)
    return unless cycle
    return if cycle.expired? || (cycle.respond_to?(:lapsed?) && cycle.lapsed?)
    return if cycle.respond_to?(:sign_up_terminal?) && cycle.sign_up_terminal?

    cycle
  end

  def cycle_class
    case surface
    when :app then ClientSignUpFlow
    when :com then VisitorSignUpFlow
    else
      raise ArgumentError, "unsupported sign-up surface"
    end
  end

  # The request must name the flow instance the session locator resolves. A page rendered for an
  # earlier flow, a request with no binding, and a binding minted for another surface all fail
  # here, before any phase comparison, so they can never be attributed to the current flow.
  def bound_to?(ticket)
    binding = SignFlowBindingCodec.decode(controller.params[AuthIoKeys::Params::FLOW_BINDING])
    return false unless binding

    binding.kind == "sign_up" && binding.surface == surface.to_s &&
      ActiveSupport::SecurityUtils.secure_compare(binding.flow_public_id, ticket.public_id.to_s)
  end

  def unusable_ticket?(ticket)
    return true if ticket.expired? || (ticket.respond_to?(:lapsed?) && ticket.lapsed?)

    ticket.respond_to?(:sign_up_terminal?) && ticket.sign_up_terminal?
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
