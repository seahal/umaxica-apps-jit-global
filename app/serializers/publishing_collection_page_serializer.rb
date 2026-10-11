# typed: false
# frozen_string_literal: true

# Maps a Pagy offset paginator onto the public collection `page` envelope.
#
# The public schema is owned by UMAXICA. Only the documented page coordinates
# (`current`, `previous`, `next`, `last`) are emitted; Pagy internals such as
# offset, count, and URL templates stay off the wire.
class PublishingCollectionPageSerializer
  class << self
    public

    def call(...)
      new(...).call
    end
  end

  def initialize(pagy)
    @pagy = pagy
  end

  public

  def call
    {
      current: pagy.page,
      previous: pagy.previous,
      next: pagy.next,
      last: pagy.last,
    }
  end

  private

  attr_reader :pagy
end
