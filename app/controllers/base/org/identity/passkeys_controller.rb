# frozen_string_literal: true

class Base::Org::Identity::PasskeysController < Base::Org::ApplicationController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  private

  def registration_surface = "org"

  def identity_actor = current_operator

  def passkey_class = OperatorPasskey

  def passkey_association = :staff_passkeys

  def passkey_reference_attribute = :external_id
end
