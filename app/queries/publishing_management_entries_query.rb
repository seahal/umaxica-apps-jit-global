# typed: false
# frozen_string_literal: true

# Reads one publishing cell for the staff CMS: every entry in the family,
# across locales and both archive states, newest first.
#
# The index is paginated. The public read path
# (`PublishingPublishedEntriesQuery`) has always clamped its page size, while
# this one ordered the whole family and built two URLs per row; a cell is
# unbounded in principle, so the page size is bounded here too.
#
# Offset paging rather than the public path's cursor: this list is ordered by
# `updated_at`, which changes under the reader as entries are edited, so a
# cursor would claim a stability the ordering does not have. A staff operator
# paging through a working list is the case offset paging fits.
class PublishingManagementEntriesQuery
  def self.call(...)
    new(...).call
  end

  DEFAULT_PER_PAGE = 25
  MIN_PER_PAGE = 1
  MAX_PER_PAGE = 100

  Page = Data.define(:entries, :number, :per_page, :has_more, :total)

  def self.clamp_per_page(value)
    value.clamp(MIN_PER_PAGE, MAX_PER_PAGE)
  end

  def initialize(entry_class:)
    @entry_class = entry_class
  end

  def call
    scoped.includes(:current_revision, :canonical_slug, :active_publication)
      .order(updated_at: :desc, id: :desc)
  end

  # `number` is 1-based. One row beyond the page decides `has_more` without a
  # second count query for the common "is there a next page" question; `total`
  # is counted separately because the page header states it.
  def page(number: 1, per_page: DEFAULT_PER_PAGE)
    per_page = self.class.clamp_per_page(per_page)
    number = [number.to_i, 1].max
    rows = call.offset((number - 1) * per_page).limit(per_page + 1).to_a

    Page.new(
      entries: rows.first(per_page),
      number: number,
      per_page: per_page,
      has_more: rows.length > per_page,
      total: scoped.count,
    )
  end

  def find!(public_id:)
    scoped.includes(
      :canonical_slug,
      { active_publication: :entry_version },
      current_revision: %i(media_usages single_taxonomy_assignments multiple_taxonomy_assignments),
    ).find_by!(public_id: public_id)
  end

  private

  attr_reader :entry_class

  def scoped
    entry_class.all
  end
end
