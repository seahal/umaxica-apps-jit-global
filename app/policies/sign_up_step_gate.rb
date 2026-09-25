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
      :redirect_to,
      :errors,
    ) do
      def success?
        status == :ok || status == :redirect
      end

      def redirect?
        status == :redirect
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
    return failure("ticket is required") unless ticket

    registry = SignUpRequirementRegistry.for_ticket(ticket, surface: surface)
    return failure("family does not match ticket") unless registry.entry_method == family
    return destroy_context(ticket, registry) if mode == :destroy
    return failure("ticket is not usable") if unsafe_ticket?(ticket)
    return failure("step does not belong to ticket") unless registry.requirement?(step)
    if mode == :create && CREATE_STEPS.exclude?(step)
      return failure("challenge issuance is not allowed for this step")
    end
    return failure("prior requirement is not clear") unless registry.prior_requirements_cleared?(
      ticket.completed_requirements,
      step,
    )

    next_step = registry.next_requirement(ticket.completed_requirements)
    if mode == :show && next_step && next_step != step
      return redirect_context(ticket, registry, next_step)
    end

    Context.new(
      status: :ok,
      surface: surface,
      family: family,
      step: step,
      ticket: ticket,
      registry: registry,
      next_step: next_step,
      redirect_to: nil,
      errors: [],
    )
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

  def unsafe_ticket?(ticket)
    return true if ticket.expired? || (ticket.respond_to?(:lapsed?) && ticket.lapsed?)
    return true if ticket.respond_to?(:sign_up_terminal?) && ticket.sign_up_terminal?
    return false if step == :otp && ticket.step.in?(%w(contact contact_verified checkpoint))

    !ticket.respond_to?(:sign_up_checkpoint_pending?) || !ticket.sign_up_checkpoint_pending?
  end

  def destroy_context(ticket, registry)
    Context.new(
      status: :ok,
      surface: surface,
      family: family,
      step: step,
      ticket: ticket,
      registry: registry,
      next_step: nil,
      redirect_to: nil,
      errors: [],
    )
  end

  def redirect_context(ticket, registry, next_step)
    Context.new(
      status: :redirect,
      surface: surface,
      family: family,
      step: step,
      ticket: ticket,
      registry: registry,
      next_step: next_step,
      redirect_to: path_for(next_step),
      errors: [],
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
      redirect_to: nil,
      errors: [message],
    )
  end

  def path_for(target_step)
    helper = STEP_ROUTES.fetch(surface).fetch(family).fetch(target_step)
    controller.public_send(helper, ri: controller.params[:ri], pt: signed_pt)
  end

  def signed_pt
    return controller.send(:signed_pt_param) if controller.respond_to?(:signed_pt_param, true)

    controller.params[:pt]
  end
end
