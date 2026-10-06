# typed: false
# frozen_string_literal: true

# Promotional email one-click / confirmation unsubscribe actions.
#
# Surface-neutral: the including controller supplies the surface-specific
# `promotional_email_model`, `promotional_email_scope`, and
# `redirect_after_unsubscribe_path`. Used by the acme bare email controllers,
# which own the promotional unsubscribe boundary (preference authority lives on
# acme/www per adr/identity-authority-boundary.md).
module PromotionalEmailUnsubscribeActions
  extend ActiveSupport::Concern
  include ::CloudflareTurnstile

  def edit
  end

  def destroy
    return unless verified_turnstile_for_destroy?

    unsubscribe_promotional_email!
    redirect_to(redirect_after_unsubscribe_path(token: params[:token]))
  end

  def create
    unsubscribe_promotional_email!
    head :ok
  end

  private

  def verified_turnstile_for_destroy?
    return true if cloudflare_turnstile_validation["success"]

    redirect_to(
      redirect_after_unsubscribe_path(token: params[:token]),
      status: :see_other,
    )
    false
  end

  def promotional_unsubscribe_create_request?
    return false unless action_name == "create"

    email = promotional_email_model.find_by(public_id: params[:id])
    return false unless email

    PromotionalEmailUnsubscribeToken.valid?(email, params[:token], scope: promotional_email_scope)
  end

  def set_promotional_email
    @email = promotional_email_model.find_by(public_id: params[:id])
    return head :not_found unless @email
    return if PromotionalEmailUnsubscribeToken.valid?(@email, params[:token], scope: promotional_email_scope)

    head :not_found
  end

  def unsubscribe_promotional_email!
    @email.unsubscribe_promotional!
  end
end
