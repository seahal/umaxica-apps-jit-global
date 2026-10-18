# typed: false
# frozen_string_literal: true

module SessionOidcConnection
  extend ActiveSupport::Concern

  FIRST_PARTY_CLIENT_ID = "first_party_session"

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_validation :ensure_session_oidc_connection, on: :create
    validates :oidc_client_id, length: { maximum: 64 }, allow_blank: true
  end

  private

  def ensure_session_oidc_connection
    return if oidc_connection.present?

    actor = public_send(self.class.session_oidc_actor_name)
    return if actor.blank?

    operation =
      lambda do
        attributes = {
          self.class.session_oidc_actor_key => actor.id,
          :client_id => FIRST_PARTY_CLIENT_ID,
        }

        self.class.session_oidc_connection_class.find_or_create_by!(
          attributes,
        )
      end

    self.oidc_connection = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  class_methods do
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def session_oidc_connection_config(actor_name:, connection_class:)
      @session_oidc_actor_name = actor_name
      @session_oidc_connection_class = connection_class
    end

    def session_oidc_actor_name = @session_oidc_actor_name

    def session_oidc_connection_class = @session_oidc_connection_class
    # rubocop:enable ThreadSafety/ClassInstanceVariable

    def session_oidc_actor_key = session_oidc_connection_class.actor_foreign_key
  end
end
