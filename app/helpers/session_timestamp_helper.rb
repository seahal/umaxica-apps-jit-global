# typed: false
# frozen_string_literal: true

module SessionTimestampHelper
  DATE_FORMATS = {
    "iso" => "%Y-%m-%d",
    "ymd" => "%Y-%m-%d",
    "uk" => "%d/%m/%Y",
    "dmy" => "%d/%m/%Y",
    "us" => "%m/%d/%Y",
    "mdy" => "%m/%d/%Y",
  }.freeze

  TIME_FORMATS = {
    "24" => "%H:%M",
    "hour_24" => "%H:%M",
    "12" => "%I:%M",
    "hour_12" => "%I:%M",
  }.freeze

  public

  def localized_session_timestamp(time)
    return nil if time.nil?

    preference = Actor.preferences
    # Preference JWTs may carry a canonical IANA name or a downcased transport value.
    localized_time = time.in_time_zone(TimezoneIdentifier.resolve(preference.timezone))
    date = localized_time.strftime(date_format_for(preference.date_format))
    clock = localized_time.strftime(time_format_for(preference.time_format))

    return "#{date} #{clock}" unless twelve_hour_time_format?(preference.time_format)

    period =
      if localized_time.hour < 12
        I18n.t("time.am")
      else
        I18n.t("time.pm")
      end
    "#{date} #{clock} #{period}"
  end

  private

  def date_format_for(value)
    DATE_FORMATS.fetch(value.to_s.downcase, DATE_FORMATS.fetch("iso"))
  end

  def time_format_for(value)
    TIME_FORMATS.fetch(value.to_s.downcase, TIME_FORMATS.fetch("24"))
  end

  def twelve_hour_time_format?(value)
    %w(12 hour_12).include?(value.to_s.downcase)
  end
end
