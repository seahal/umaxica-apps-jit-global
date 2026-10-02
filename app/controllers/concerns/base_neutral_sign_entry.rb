# typed: false
# frozen_string_literal: true

# Base's neutral browser entry. GET only renders one form; POST issues the Base-owned local
# admission and starts Auth at /sign/in, where any allowed switch to registration happens. Base is
# not its own RP, and there is no Sign in / Sign up choice here
# (adr/sign-neutral-entry-and-logout-target-authorization.md).
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
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: base_sign_surface, intent: "sign_in")
    redirect_to_jump_url(auth_sign_in_url_for(admission), status: :see_other)
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
