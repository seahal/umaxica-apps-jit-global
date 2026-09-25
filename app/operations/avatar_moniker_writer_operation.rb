# typed: false
# frozen_string_literal: true

class AvatarMonikerWriterOperation < ApplicationService
  Result =
    Data.define(:avatar_moniker, :errors) do
      def success? = errors.empty?
    end

  EXPECTED_CURRENT_STATES = %i(absent present).freeze
  VALIDATION_TIMESTAMP = Time.utc(2000, 1, 1).freeze

  def initialize(avatar:, moniker:, expected_current:)
    super()
    raise ArgumentError, "avatar must be persisted" unless avatar.is_a?(Avatar) && avatar.persisted?
    raise ArgumentError, "unsupported expected_current: #{expected_current.inspect}" unless
      EXPECTED_CURRENT_STATES.include?(expected_current)

    @avatar = avatar
    @moniker = moniker
    @expected_current = expected_current
  end

  def call
    avatar_moniker = nil
    errors = {}

    Avatar.transaction do
      avatar.with_lock do
        current = avatar.current_avatar_moniker
        assert_expected_current_state!(current)

        # A finite interval lets the full model validation check the moniker without treating
        # this unsaved preflight object as a second current row.
        candidate = AvatarMoniker.new(
          avatar: avatar,
          moniker: moniker,
          valid_from: VALIDATION_TIMESTAMP,
          valid_to: VALIDATION_TIMESTAMP,
        )
        candidate.valid?
        moniker_errors = candidate.errors[:moniker]
        unless moniker_errors.empty?
          avatar_moniker = candidate
          errors = { moniker: moniker_errors }
          next
        end

        if current&.moniker == candidate.moniker
          avatar_moniker = current
          next
        end

        effective_at = Time.current
        current&.update!(valid_to: effective_at)

        avatar_moniker = avatar.avatar_monikers.build(
          moniker: candidate.moniker,
          valid_from: effective_at,
        )
        avatar_moniker.save!
      end
    end

    avatar.association(:current_avatar_moniker).reset if errors.empty?
    Result.new(avatar_moniker: avatar_moniker, errors: errors)
  rescue ActiveRecord::RecordInvalid => e
    moniker_errors = e.record.errors[:moniker]
    raise if moniker_errors.empty?

    Result.new(avatar_moniker: e.record, errors: { moniker: moniker_errors })
  end

  private

  attr_reader :avatar, :moniker, :expected_current

  def assert_expected_current_state!(current)
    if expected_current == :absent && current.present?
      raise ActiveRecord::RecordNotSaved, "Avatar already has a current AvatarMoniker"
    elsif expected_current == :present && current.nil?
      raise ActiveRecord::RecordNotFound, "Avatar has no current AvatarMoniker"
    end
  end
end
