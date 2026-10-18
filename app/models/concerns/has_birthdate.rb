# typed: false
# frozen_string_literal: true

module HasBirthdate
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    encrypts :birthdate

    validates :birthdate, length: { maximum: 10 }, allow_blank: true

    validate :birthdate_format
    validate :birthdate_not_future
  end

  def parsed_birthdate
    return nil if birthdate.blank?

    Date.iso8601(birthdate)
  rescue Date::Error
    nil
  end

  def birthdate_for_age
    AgeEligibility.birthdate_for_age(birthdate)
  end

  def calendar_valid_birthdate?
    parsed_birthdate.present?
  end

  def age_on(date = Time.zone.today)
    date = date.to_date
    bday = birthdate_for_age
    return nil unless bday

    age = date.year - bday.year
    before_birthday = ([date.month, date.day] <=> [bday.month, bday.day]).negative?

    before_birthday ? age - 1 : age
  end

  def minimum_age_reached?(minimum_age, today: Time.zone.today)
    AgeEligibility.minimum_age_reached?(birthdate, minimum_age: minimum_age, today: today)
  end

  def adult_for_nsfw?(minimum_age: 18, today: Time.zone.today)
    minimum_age_reached?(minimum_age, today: today)
  end

  def nsfw_unlockable?
    birthdate_for_age.present? && adult_for_nsfw?
  end

  private

  def birthdate_format
    return if birthdate.blank?
    return if birthdate.match?(JitUtilsBirthdateFormat::PATTERN)

    errors.add(:birthdate, :birthdate_format)
  end

  def birthdate_not_future
    return if birthdate.blank?
    return unless birthdate.match?(JitUtilsBirthdateFormat::PATTERN)

    today = Time.zone.today.strftime("%Y-%m-%d")
    errors.add(:birthdate, :birthdate_before_today) if birthdate >= today
  end
end
