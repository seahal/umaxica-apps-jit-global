# typed: false
# frozen_string_literal: true

module Webauthn
  # Closed enumeration of the WebAuthn surfaces. Each surface owns its own
  # relying party, credential store, and actor model; credentials never cross
  # surfaces. Surface resolution is always an explicit declaration
  # (WebauthnSurfaceDeclarable) -- never inferred from class names or hosts.
  class Surface
    class UnknownSurfaceError < StandardError; end

    attr_reader :key, :env_prefix, :passkey_class_name, :passkey_status_class_name,
                :ceremony_transaction_class_name, :actor_foreign_key, :actor_association_name

    def initialize(key, env_prefix:, passkey_class_name:, passkey_status_class_name:,
                   ceremony_transaction_class_name:, actor_foreign_key:, actor_association_name:)
      @key = key
      @env_prefix = env_prefix
      @passkey_class_name = passkey_class_name
      @passkey_status_class_name = passkey_status_class_name
      @ceremony_transaction_class_name = ceremony_transaction_class_name
      @actor_foreign_key = actor_foreign_key
      @actor_association_name = actor_association_name
      freeze
    end

    def passkey_class = passkey_class_name.constantize

    def passkey_status_class = passkey_status_class_name.constantize

    def ceremony_transaction_class = ceremony_transaction_class_name.constantize

    delegate :to_s, to: :key

    REGISTRY = {
      app: new(
        :app,
        env_prefix: "APP",
        passkey_class_name: "ClientPasskey",
        passkey_status_class_name: "ClientPasskeyStatus",
        ceremony_transaction_class_name: "ClientPasskeyCeremonyTransaction",
        actor_foreign_key: "user_id",
        actor_association_name: :user,
      ),
      com: new(
        :com,
        env_prefix: "COM",
        passkey_class_name: "VisitorPasskey",
        passkey_status_class_name: "VisitorPasskeyStatus",
        ceremony_transaction_class_name: "VisitorPasskeyCeremonyTransaction",
        actor_foreign_key: "visitor_id",
        actor_association_name: :visitor,
      ),
      org: new(
        :org,
        env_prefix: "ORG",
        passkey_class_name: "OperatorPasskey",
        passkey_status_class_name: "OperatorPasskeyStatus",
        ceremony_transaction_class_name: "OperatorPasskeyCeremonyTransaction",
        actor_foreign_key: "staff_id",
        actor_association_name: :staff,
      ),
    }.freeze

    def self.for(key)
      return key if key.is_a?(Surface)

      REGISTRY.fetch(key.to_sym) do
        raise UnknownSurfaceError, "Unknown WebAuthn surface: #{key.inspect} (expected one of #{REGISTRY.keys.inspect})"
      end
    end

    def self.all = REGISTRY.values
  end
end
