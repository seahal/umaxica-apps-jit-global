# typed: false
# frozen_string_literal: true

# D-59 (two.md section 3.5): the closed Sign Entry classification every Auth entry-boundary
# controller declares statically. The four values, and nothing else:
#
# - `sign_in` / `sign_up` - the realm's interactive entry flows; the Sign Entry Sentry governs them
#   and the resolved flow decides which flag the sentry reads.
# - `parent_intent` - continuations whose effective intent comes from the *verified parent*
#   (provider callbacks, OIDC handoffs); request parameters never decide the classification.
# - `excluded` - reachable actions the Sign Entry Sentry does not govern, always with a stated
#   reason: neither a sign entry at all (settings, re-verification, Sign Out, ticket ceremonies,
#   health/API endpoints). A bare "excluded" is a guard failure. The confirmed standby-only
#   Emergency entry is classified as sign_in and declares its fixed exception separately.
#
# An undeclared reachable action is never silently treated as `excluded`: the static guard test
# (`test/unit/security/sign_entry_classification_guard_test.rb`) holds the reachable-action set
# against the declarations, so a missing declaration is a failing guard, not a bypass.
module SignEntryClassification
  extend ActiveSupport::Concern

  CLASSIFICATIONS = %i(sign_in sign_up parent_intent excluded).freeze
  STANDBY_ONLY_CONTROLLERS = %w(
    Auth::Org::Sign::In::Emergency::PasskeysController
    Auth::Org::Sign::In::Emergency::Passkey::OptionsController
    Auth::Org::Sign::In::Emergency::Passkey::VerificationsController
  ).freeze

  class UnsupportedClassificationError < StandardError; end

  class MissingExcludedReasonError < StandardError; end

  class InvalidStandbyExceptionError < StandardError; end

  # Raised at request time when a reachable action arrives without a declaration. The static guard
  # keeps this unreachable; it exists so the failure is loud if the guard is ever bypassed.
  class UndeclaredClassificationError < StandardError; end

  # One declaration per class, inherited by subclasses that declare nothing and replaced by the
  # subclass that declares its own. The declaration installs its readers on the declaring class
  # explicitly; inclusion alone changes nothing.
  class_methods do
    public

    # Static declaration. `actions:` names the controller actions that override the class-wide
    # value (the fixed override table); `reason:` is mandatory for `excluded`.
    def sign_entry_classification!(classification, reason: nil, actions: {}, standby_only: false)
      classification = classification.to_sym
      unless CLASSIFICATIONS.include?(classification)
        raise UnsupportedClassificationError, classification.inspect
      end
      unless [true, false].include?(standby_only)
        raise InvalidStandbyExceptionError, "standby exception must be boolean"
      end
      if standby_only && (classification != :sign_in || STANDBY_ONLY_CONTROLLERS.exclude?(name) ||
          reason.to_s.blank? || actions.any?)
        raise InvalidStandbyExceptionError, "invalid standby-only sign-in declaration"
      end
      if classification == :excluded && reason.to_s.blank?
        raise MissingExcludedReasonError, "#{name} declared excluded without a reason"
      end

      overrides =
        actions.transform_keys(&:to_sym).transform_values do |value|
          symbolized = value.to_sym
          unless CLASSIFICATIONS.include?(symbolized)
            raise UnsupportedClassificationError, symbolized.inspect
          end

          symbolized
        end.freeze
      declared_reason = reason.to_s.presence&.freeze
      if overrides.value?(:excluded) && declared_reason.nil?
        raise MissingExcludedReasonError, "#{name} declared an excluded action without a reason"
      end

      # Controller declarations run while classes load; these frozen values are never request state.
      # rubocop:disable ThreadSafety/ClassAndModuleAttributes
      class_attribute(
        :sign_entry_classification_value, :sign_entry_classification_reason,
        :sign_entry_classification_overrides, :sign_entry_standby_only, instance_accessor: false,
      )
      # rubocop:enable ThreadSafety/ClassAndModuleAttributes
      self.sign_entry_classification_value = classification
      self.sign_entry_classification_reason = declared_reason
      self.sign_entry_classification_overrides = overrides
      self.sign_entry_standby_only = standby_only
    end

    def sign_entry_standby_only?
      respond_to?(:sign_entry_standby_only) && sign_entry_standby_only == true
    end

    def sign_entry_classification_value
      return superclass.sign_entry_classification_value if superclass.respond_to?(:sign_entry_classification_value)

      nil
    end

    def sign_entry_classification_reason
      return superclass.sign_entry_classification_reason if superclass.respond_to?(:sign_entry_classification_reason)

      nil
    end

    # Action overrides belong to the class that owns the fixed table; a subclass that declares
    # nothing inherits the class-wide value without inheriting actions it may not implement.
    def sign_entry_classification_overrides
      if superclass.respond_to?(:sign_entry_classification_overrides)
        return superclass.sign_entry_classification_overrides
      end

      {}.freeze
    end
  end

  private

  # The classification for *this request*: the action override table first, then the class
  # declaration. Nil when the controller declared nothing (the guard's gap, not an exclusion).
  def resolved_sign_entry_classification
    override = self.class.sign_entry_classification_overrides[action_name.to_sym]
    return override if override

    self.class.sign_entry_classification_value
  end

  def sign_entry_classification_reason
    self.class.sign_entry_classification_reason
  end
end
