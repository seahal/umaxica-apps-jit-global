# typed: false
# frozen_string_literal: true

# Mock notification settings screen shared by the app, com, and org preference surfaces (five.md).
# It follows the scaffold shape (edit renders the form, update redirects), but it has no fields and
# stores nothing yet. No form object is used (five.md section 2-2); the real save is split into Guest
# and User controllers. The including controller defines notification_back_link_path,
# notification_form_action_path, and notification_return_path with its own static route helpers.
module BasePreferenceNotificationScreen
  extend ActiveSupport::Concern

  FORM_SCOPE = "preference_notification"

  public

  def edit
    render_notification_edit
  end

  # The displayed choices are not editable state yet. Ignore the submitted mock payload and return
  # to the screen without parsing or persisting any of it.
  def update
    redirect_to(notification_return_path, status: :see_other)
  end

  private

  def render_notification_edit
    render inertia: "#{controller_path}/edit", props: {
      title: t(preference_base_i18n_key(:preferences, :notification, :title)),
      description: t(preference_base_i18n_key(:preferences, :notification, :description)),
      placeholder: t(preference_base_i18n_key(:preferences, :notification, :placeholder)),
      back_link: {
        label: t(preference_base_i18n_key(:preferences, :title)),
        href: notification_back_link_path,
      },
      form: {
        action: notification_form_action_path,
        method: "patch",
        scope: FORM_SCOPE,
        submit_label: t(preference_acme_i18n_key(:preferences, :update_settings)),
        submitting_label: t(preference_acme_i18n_key(:preferences, :submitting)),
      },
      # Display only: the field is shown for layout review and is not submitted or stored yet.
      web_push: {
        label: t(preference_base_i18n_key(:preferences, :notification, :web_push, :label)),
        value: "disabled",
        choices: %w(enabled disabled).map do |value|
          { value: value, label: t(preference_base_i18n_key(:preferences, :notification, :web_push, value)) }
        end,
      },
    }
  end
end
