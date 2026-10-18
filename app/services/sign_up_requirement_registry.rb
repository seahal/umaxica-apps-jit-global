# typed: false
# frozen_string_literal: true

class SignUpRequirementRegistry
  Definition =
    Data.define(:surface, :entry_method, :requirements, :social) do
      def social?
        social
      end
    end

  DEFINITIONS = {
    app: {
      "email" => Definition.new(surface: :app, entry_method: "email", requirements: %i(otp birthdate), social: false),
      "telephone" => Definition.new(
        surface: :app,
        entry_method: "telephone",
        requirements: %i(otp passkey birthdate),
        social: false,
      ),
      "google" => Definition.new(
        surface: :app,
        entry_method: "google",
        requirements: %i(confirmation birthdate),
        social: true,
      ),
      "apple" => Definition.new(
        surface: :app,
        entry_method: "apple",
        requirements: %i(confirmation birthdate),
        social: true,
      ),
    },
    com: {
      "email" => Definition.new(surface: :com, entry_method: "email", requirements: %i(otp birthdate), social: false),
      "telephone" => Definition.new(
        surface: :com,
        entry_method: "telephone",
        requirements: %i(otp passkey birthdate),
        social: false,
      ),
    },
  }.freeze

  attr_reader :definition

  def self.for_ticket(ticket, surface: surface_for_ticket(ticket))
    for_entry(surface: surface, entry_method: ticket.entry_method)
  end

  def self.for_entry(surface:, entry_method:)
    normalized_surface = surface.to_sym
    definition = DEFINITIONS.fetch(normalized_surface).fetch(entry_method.to_s)

    new(definition)
  rescue KeyError
    raise ArgumentError, "unsupported sign-up entry method: #{surface.inspect}/#{entry_method.inspect}"
  end

  def self.surface_for_ticket(ticket)
    case ticket
    when ClientSignUpFlow
      :app
    when VisitorSignUpFlow
      :com
    else
      raise ArgumentError, "unsupported sign-up ticket class: #{ticket.class.name}"
    end
  end

  def initialize(definition)
    @definition = definition
  end

  delegate :surface, :entry_method, :requirements, :social?, to: :definition

  def requirement?(requirement)
    requirements.include?(requirement.to_sym)
  end

  def missing_requirements(completed_requirements)
    requirements.reject { |requirement| requirement_cleared?(completed_requirements, requirement) }
  end

  def prior_requirements(requirement)
    index = requirements.index(requirement.to_sym)
    return [] unless index

    requirements.first(index)
  end

  def prior_requirements_cleared?(completed_requirements, requirement)
    prior_requirements(requirement).all? { |prior| requirement_cleared?(completed_requirements, prior) }
  end

  def next_requirement(completed_requirements)
    missing_requirements(completed_requirements).first
  end

  def requirement_cleared?(completed_requirements, requirement)
    return false unless completed_requirements.is_a?(Hash)

    requirement_state = completed_requirements.fetch(requirement.to_s, {})

    requirement_state.is_a?(Hash) && requirement_state["cleared"] == true
  end
end
