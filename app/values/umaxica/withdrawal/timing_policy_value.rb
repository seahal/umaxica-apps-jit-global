# typed: false
# frozen_string_literal: true

module Umaxica
  module Withdrawal
    # Immutable app/com withdrawal timing configuration. The policy is intentionally separate
    # from Withdrawable because Operator withdrawal keeps its existing contract.
    class TimingPolicyValue
      STANDARD_RECOVERY_DELAY_SECONDS = 1.hour.to_i
      STANDARD_EARLY_TERMINATION_DELAY_SECONDS = 7.days.to_i
      STANDARD_RETENTION_PERIOD_SECONDS = 31.days.to_i

      ENV_KEYS = {
        recovery_delay: "UMAXICA_APP_COM_WITHDRAWAL_RECOVERY_DELAY_SECONDS",
        early_termination_delay: "UMAXICA_APP_COM_WITHDRAWAL_EARLY_TERMINATION_DELAY_SECONDS",
        retention_period: "UMAXICA_APP_COM_WITHDRAWAL_RETENTION_PERIOD_SECONDS",
      }.freeze

      attr_reader :recovery_delay, :early_termination_delay, :retention_period

      class << self
        public

        def current(environment: Rails.env.to_s, environment_variables: ENV)
          validate_environment!(environment:, environment_variables:)
        end

        def validate_environment!(environment:, environment_variables:)
          configured_keys = ENV_KEYS.values.select { |key| environment_variables.key?(key) }

          if environment == "production" && configured_keys.any?
            raise ArgumentError,
                  "app/com withdrawal timing overrides are forbidden in production: #{configured_keys.join(", ")}"
          end

          if configured_keys.any? && %w(development test).exclude?(environment)
            raise ArgumentError, "app/com withdrawal timing overrides are only allowed in development or test"
          end

          values =
            ENV_KEYS.to_h do |name, key|
              raw = environment_variables[key]
              [name, raw.nil? ? standard_seconds_for(name) : parse_seconds!(key, raw)]
            end
          new(**values)
        end

        private

        def standard_seconds_for(name)
          {
            recovery_delay: STANDARD_RECOVERY_DELAY_SECONDS,
            early_termination_delay: STANDARD_EARLY_TERMINATION_DELAY_SECONDS,
            retention_period: STANDARD_RETENTION_PERIOD_SECONDS,
          }.fetch(name)
        end

        def parse_seconds!(key, raw)
          value = raw.to_s
          raise ArgumentError, "#{key} must be a positive integer number of seconds" unless value.match?(/\A[0-9]+\z/)

          seconds = Integer(value, 10)
          raise ArgumentError, "#{key} must be a positive integer number of seconds" unless seconds.positive?

          seconds
        end
      end

      def initialize(recovery_delay:, early_termination_delay:, retention_period:)
        @recovery_delay = positive_duration(recovery_delay, :recovery_delay)
        @early_termination_delay = positive_duration(early_termination_delay, :early_termination_delay)
        @retention_period = positive_duration(retention_period, :retention_period)

        unless @recovery_delay < @early_termination_delay && @early_termination_delay < @retention_period
          raise ArgumentError, "withdrawal timing must satisfy recovery < early termination < retention"
        end

        freeze
      end

      public

      def recovery_delay_seconds = recovery_delay.to_i

      def early_termination_delay_seconds = early_termination_delay.to_i

      def retention_period_seconds = retention_period.to_i

      private

      def positive_duration(value, name)
        seconds = value.is_a?(ActiveSupport::Duration) ? value.to_i : value
        unless seconds.is_a?(Integer) && seconds.positive?
          raise ArgumentError, "#{name} must be a positive integer number of seconds"
        end

        seconds.seconds.freeze
      end
    end
  end
end
