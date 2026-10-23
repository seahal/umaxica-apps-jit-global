# frozen_string_literal: true

# Only persisted OP request/Binding facts select the ceremony. A route or browser parameter
# cannot broaden an ordinary authentication admission into registration (D-72, WU-24b).
class AuthEntryIntentResolver < ApplicationService
  public

  def initialize(prompt:, entry_intent:)
    super()
    @prompt = prompt
    @entry_intent = entry_intent
  end

  def call
    unless entry_intent.nil?
      return entry_intent if %w(sign_in sign_up).include?(entry_intent)

      raise ArgumentError, "authentication entry intent must be sign_in or sign_up"
    end

    (OidcAuthorizeRequestResolver.normalize_prompt(prompt) == "create") ? "sign_up" : "sign_in"
  end

  private

  attr_reader :prompt, :entry_intent
end
