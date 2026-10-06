# frozen_string_literal: true

class Base::App::Identity::PasskeysController < Base::App::Identity::BaseController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  private

  def registration_surface = "app"

  def identity_actor = current_client

  def passkey_class = ClientPasskey

  def passkey_association = :client_passkeys
end
