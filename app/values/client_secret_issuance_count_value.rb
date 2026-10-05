# typed: false
# frozen_string_literal: true

class ClientSecretIssuanceCountValue
  MAXIMUM = 20

  class ReservationConflict < StandardError; end

  public

  attr_reader :active_count, :reserved_count

  def initialize(active_count:, reserved_count:)
    unless active_count.is_a?(Integer) && active_count.between?(0, MAXIMUM)
      raise ArgumentError, "active Secret count must be an integer from zero through twenty"
    end
    unless reserved_count.is_a?(Integer) && reserved_count.between?(0, MAXIMUM)
      raise ArgumentError, "reserved Secret count must be an integer from zero through twenty"
    end
    if active_count + reserved_count > MAXIMUM
      raise ArgumentError, "active and reserved Secret counts exceed capacity"
    end

    @active_count = active_count
    @reserved_count = reserved_count
    freeze
  end

  def passkey_count
    raise ReservationConflict, "another Secret issuance holds capacity" if @reserved_count.positive?

    case @active_count
    when 0..18 then 2
    when 19 then 1
    when 20 then 0
    else raise ArgumentError, "unsupported active Secret count"
    end
  end

  def manual_count
    raise ReservationConflict, "another Secret issuance holds capacity" if @reserved_count.positive?

    case @active_count
    when 0..19 then 1
    when 20 then 0
    else raise ArgumentError, "unsupported active Secret count"
    end
  end
end
