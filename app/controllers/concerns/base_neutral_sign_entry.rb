# typed: false
# frozen_string_literal: true

# Retained for legacy callers while the Base browser entry is migrated to the shared OIDC RP layer.
# Active Base sign routes use `OidcRpSignEntry` and do not include this concern.
#
# The including controller supplies `base_sign_surface` and `auth_sign_in_url_for(admission)`.
module BaseNeutralSignEntry
  extend ActiveSupport::Concern

  public

  def show
    response.set_header("Cache-Control", "no-store")
    render template: "shared/oidc_rp_sign_entries/show", layout: false
  end

  def create
    return render_sign_in_unavailable_while_authenticated if logged_in?

    response.set_header("Cache-Control", "no-store")
    restart_of = params[:restart_of]
    unless restart_of.nil? || restart_of.is_a?(String)
      return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    end

    model = BaseAuthAdmissionCoordinator::LOCAL_SIGN_IN_FLOW.fetch(base_sign_surface)
    locator = SignInCycleLocator.new(session, surface: base_sign_surface)
    existing = restart_of.present? ? locator.current : nil
    if restart_of.present? && existing.nil?
      return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    end

    nonce = existing ? nil : SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: base_sign_surface, intent: "sign_in",
      nonce_digest: existing ? existing.nonce_digest : model.digest_nonce(nonce),
      restart_of:, base_browser_nonce: base_admission_browser_nonce, base_token: current_session_token,
    )
    if existing
      return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request unless
        admission.transaction.id == existing.id
    else
      locator.issue!(admission.transaction, nonce: nonce)
    end
    redirect_to_jump_url(auth_sign_in_url_for(admission), status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
    Rails.logger.error(
      JitLogEvent.format(
        "base.sign_entry.admission_unavailable",
        surface: base_sign_surface,
        error_class: e.class.name,
        request_id: request.request_id,
      ),
    )
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable,
           content_type: "text/plain"
  end

  private

  def neutral_sign_form_url
    url_for(only_path: true, ri: RequestContextContract.normalize_region(params[:ri]))
  end
end
