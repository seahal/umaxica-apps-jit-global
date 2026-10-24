# typed: false
# frozen_string_literal: true

# The effect strings below describe operator-facing switches in the Flipper UI,
# not product copy shown to users, so they are not localized.
# rubocop:disable I18n/RailsI18n/DecorateString

# The single registry of every Flipper feature this application reads.
#
# Two problems motivate it, both observed in this codebase:
#
#   1. A misspelled feature name is not an error. `Flipper.enabled?(:outbund_push_suspended)`
#      returns false forever, so a suspension switch silently never fires and a
#      fail-closed gate silently never opens. Going through `enabled?` here turns
#      an unregistered name into an ArgumentError at the call site.
#   2. Polarity was documented only in prose next to each call site, so "what does
#      unset mean here" had to be rediscovered per feature. It is declared once,
#      per flag, below.
#
# Adding a flag means adding a row here. `Security::Invariants::FeatureFlagRegistryInvariantTest`
# fails if any other file calls `Flipper.enabled?` directly.
module FeatureFlags
  # polarity:
  #   :suspension   ON = the effect is stopped. Unset = normal operation (fail-open).
  #                 A flag store that has never been written must not take the
  #                 product down.
  #   :availability ON = the ceremony is permitted. Unset = closed (fail-closed).
  #                 A lost flag must not let an authentication ceremony through.
  Flag = Data.define(:name, :polarity, :effect)

  POLARITIES = %i(suspension availability).freeze

  REGISTRY =
    [
      Flag.new(
        name: :outbound_sms_suspended, polarity: :suspension,
        effect: "Stops SMS delivery through the SNS provider.",
      ),
      Flag.new(
        name: :outbound_email_suspended, polarity: :suspension,
        effect: "Stops all mail at the delivery interceptor, transactional and promotional.",
      ),
      Flag.new(
        name: :outbound_promotional_email_suspended, polarity: :suspension,
        effect: "Stops promotional mail only; transactional mail keeps delivering.",
      ),
      Flag.new(
        name: :outbound_push_suspended, polarity: :suspension,
        effect: "Stops APNs/FCM delivery in ApplicationPushNotificationJob.",
      ),
      Flag.new(
        name: :retention_purge_suspended, polarity: :suspension,
        effect: "Stops the irreversible deletes and anonymization in RetentionPurgeJob.",
      ),
      Flag.new(
        name: :sign_in_available_app, polarity: :availability,
        effect: "Permits new sign-in ceremonies on the app surface.",
      ),
      Flag.new(
        name: :sign_up_available_app, polarity: :availability,
        effect: "Permits new sign-up ceremonies on the app surface.",
      ),
      Flag.new(
        name: :sign_in_available_com, polarity: :availability,
        effect: "Permits new sign-in ceremonies on the com surface.",
      ),
      Flag.new(
        name: :sign_up_available_com, polarity: :availability,
        effect: "Permits new sign-up ceremonies on the com surface.",
      ),
      Flag.new(
        name: :sign_in_available_org, polarity: :availability,
        effect: "Permits new sign-in ceremonies on the org surface.",
      ),
      Flag.new(
        name: :sign_up_available_org, polarity: :availability,
        effect: "Permits new sign-up ceremonies on the org surface.",
      ),
      Flag.new(
        name: :turnstile_degraded_mode, polarity: :suspension,
        effect: "Accepts requests that failed Turnstile verification while the provider is degraded.",
      ),
      Flag.new(
        name: :social_ceremony_app_apple, polarity: :availability,
        effect: "Permits the Apple ceremony on the app surface.",
      ),
      Flag.new(
        name: :social_ceremony_app_google, polarity: :availability,
        effect: "Permits the Google ceremony on the app surface.",
      ),
      Flag.new(
        name: :social_ceremony_org_entra, polarity: :availability,
        effect: "Permits the Entra ceremony on the org surface.",
      ),
      *FqdnAvailabilityRegistry::SLOT_NAMES.map do |slot|
        Flag.new(
          name: FqdnAvailabilityRegistry.flag_name_for(slot), polarity: :availability,
          effect: "Serves requests for the #{slot} FQDN. Off or unset returns 503 before rate " \
                  "limiting and before authentication. Health probes are unaffected.",
        )
      end,
    ].index_by(&:name).freeze

  module_function

  # @param actor [#flipper_id, nil] restricts the check to one actor gate.
  # @param flipper [#enabled?] injection point for tests.
  def enabled?(name, actor = nil, flipper: Flipper)
    fetch(name)
    return flipper.enabled?(name) if actor.nil?

    flipper.enabled?(name, actor)
  end

  def fetch(name)
    REGISTRY.fetch(name.to_sym) do
      raise ArgumentError, "unregistered feature flag: #{name}"
    end
  end

  def names = REGISTRY.keys
end
# rubocop:enable I18n/RailsI18n/DecorateString
