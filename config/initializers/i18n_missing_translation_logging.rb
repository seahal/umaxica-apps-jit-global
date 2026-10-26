# typed: false
# frozen_string_literal: true

require "jit_log_event"

Rails.application.config.after_initialize do
  previous_exception_handler = I18n.exception_handler

  I18n.exception_handler =
    lambda do |exception, locale, key, options|
      missing_translation =
        exception.is_a?(I18n::MissingTranslation) || exception.is_a?(I18n::MissingTranslationData)

      if Rails.env.production? && missing_translation
        translation_key = I18n.normalize_keys(locale, key, options[:scope]).drop(1).join(".")
        Rails.logger.warn(
          JitLogEvent.format("i18n.missing_translation", key: translation_key, locale: locale.to_s),
        )
      end

      previous_exception_handler.call(exception, locale, key, options)
    end
end
