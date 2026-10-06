# frozen_string_literal: true

class Base::Com::Identity::PasskeysController < Base::Com::ApplicationController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  private

  def registration_surface = "com"

  def identity_actor = current_visitor

  def passkey_class = VisitorPasskey

  def passkey_association = :visitor_passkeys
end
