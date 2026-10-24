# typed: false
# frozen_string_literal: true

# Resolves the six explicit Sign Entry Sentry switches.  The request never
# supplies a feature name: surface and flow are selected by the routed
# controller and the effective Admission intent.
class SignEntrySentryResolver < ApplicationService
  ENTRY_FLAGS = {
    %w(app sign_in) => :sign_in_available_app,
    %w(app sign_up) => :sign_up_available_app,
    %w(com sign_in) => :sign_in_available_com,
    %w(com sign_up) => :sign_up_available_com,
    %w(org sign_in) => :sign_in_available_org,
    %w(org sign_up) => :sign_up_available_org,
  }.freeze

  def initialize(surface:, flow:, flipper: Flipper)
    super()
    @surface = surface.to_s
    @flow = flow.to_s
    @flipper = flipper
  end

  public

  def call
    feature =
      ENTRY_FLAGS.fetch([surface, flow]) do
        raise ArgumentError, "unsupported Sign Entry Sentry pair: #{surface.inspect}/#{flow.inspect}"
      end

    state =
      if FeatureFlags.enabled?(feature, flipper: flipper)
        SignEntrySentryStateValue::ALLOWED
      else
        SignEntrySentryStateValue::BLOCKED
      end

    SignEntrySentryStateValue.new(state:, surface:, flow:)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format(
        "sign_entry_sentry.flag_store_unavailable",
        surface: surface,
        flow: flow,
        error_class: e.class.name,
      ),
    )
    SignEntrySentryStateValue.new(
      state: SignEntrySentryStateValue::BLOCKED,
      surface: surface,
      flow: flow,
    )
  end

  private

  attr_reader :surface, :flow, :flipper
end
