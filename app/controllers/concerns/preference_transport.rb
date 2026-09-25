# typed: false
# frozen_string_literal: true

module PreferenceTransport
  extend ActiveSupport::Concern

  private

  def set_preferences_cookie
    if request.get? || request.head?
      load_access_token_preference_record!(clear_invalid_cookie: false)
      if @preferences.blank? && refresh_token_value.present?
        load_read_only_preference_record_from_refresh_token!
        return render_preference_refresh_error! if preference_refresh_failed?
      end
      return
    end

    clear_preference_refresh_failure!
    return if load_access_token_payload

    preference, created = load_preference_record_from_refresh_token!(create_if_missing: true)
    return render_preference_refresh_error! if preference_refresh_failed?
    return if preference.blank?

    @preferences = preference
    restore_preference_from_resource!(preference) if created && respond_to?(:current_resource, true)

    refresh_refresh_token_lifetime(preference)
    return render_preference_refresh_error! if preference_refresh_failed?

    issue_access_token_from(@preferences || preference)
    nil
  end

  def refresh_preference_token_from_db_for_edit_entry!
    return if @preferences.blank?
    return unless respond_to?(:current_resource, true)
    return unless respond_to?(:copy_preference_values!, true)

    resource = preference_current_resource
    return if resource.blank?

    resource_preference = resolved_resource_preference(resource) if respond_to?(:resolved_resource_preference, true)
    return if resource_preference.blank?

    copy_preference_values!(resource_preference, @preferences, preference_prefix)
    reload_preference_for_token!(@preferences)
    issue_access_token_from(@preferences)
  end

  def restore_preference_from_resource!(_preference)
    resource = preference_current_resource
    return if resource.blank?
    return unless respond_to?(:adopt_preference_for!, true)

    adopt_preference_for!(resource)
  rescue PreferenceBase::ResolutionError
    raise
  rescue StandardError => e
    Rails.logger.info(
      JitLogEvent.format(
        "preference.restore_from_resource.error", error: e.class.name,
                                                  message: e.message,
      ),
    )
    nil
  end

  def reload_preference_for_token!(preference)
    preference.reload
    preference_associations_to_preload.each do |association_name|
      next unless preference.respond_to?(association_name)

      preference.association(association_name).reload
    end
    preference
  end
end
