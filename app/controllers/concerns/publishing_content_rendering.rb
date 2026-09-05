# typed: false
# frozen_string_literal: true

# Renders read-only entries from the central publishing DB. This is one
# cohesive public-content read contract: resolve the edition, run the published
# entries query, serialize, apply short shared-cache validators, and render
# Problem Details on malformed input. Splitting those steps would hide the
# HTTP contract behind several modules that always run together.
#
# Contract: the including controller declares PUBLISHING_AUDIENCE and
# PUBLISHING_SURFACE as explicit constants. Those values are never inferred
# from the class name or request path. See adr/publishing-db-content-authority.md
# and docs/architecture/publishing-persistence.md.
#
# This concern installs no callbacks of its own. ApiContentNegotiation, included
# below, registers before_action filters because content negotiation must run
# before every JSON action on these endpoints; duplicating those filters on
# twelve controllers would hide the same contract.
module PublishingContentRendering
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation

  class_methods do
    def publishing_audience
      unless const_defined?(:PUBLISHING_AUDIENCE, false)
        raise(NameError, "#{name} must declare PUBLISHING_AUDIENCE")
      end

      const_get(:PUBLISHING_AUDIENCE, false)
    end

    def publishing_surface
      unless const_defined?(:PUBLISHING_SURFACE, false)
        raise(NameError, "#{name} must declare PUBLISHING_SURFACE")
      end

      const_get(:PUBLISHING_SURFACE, false)
    end
  end

  # Published content is public and identical for every caller on a given host, so it is shared-
  # cacheable. The window is short because a publication is expected to become visible promptly;
  # conditional requests, not a long TTL, are what remove the repeated transfer.
  PUBLISHING_CACHE_MAX_AGE = 60

  private

  # The validator is computed over the rendered payload rather than over row timestamps. It therefore
  # cannot drift from what is actually sent -- a taxonomy rename or a vocabulary change alters the
  # payload and the validator together. This saves transfer, not query work; the rows are still read.
  def render_publishing_entries_index
    cursor = publishing_page_cursor
    return if performed?

    limit = publishing_page_limit
    return if performed?

    page = publishing_entries_query.page(limit:, cursor:)
    entries = page.entries.filter_map { |entry| publishing_entry_json(entry) }
    payload = { data: entries, page: { next_cursor: page.next_cursor, has_more: page.has_more } }

    expires_in(PUBLISHING_CACHE_MAX_AGE.seconds, public: true)
    # The validator covers the whole envelope, so it is page-specific: two pages of the same
    # collection never share an ETag, and a cursor change invalidates the cached representation.
    return unless stale?(etag: payload, last_modified: publishing_entries_last_modified(entries), public: true)

    render json: payload
  end

  # adr/api-collection-contract.md: a single resource is returned at the top level, with no wrapper
  # key.
  def render_publishing_entry_show
    entry = publishing_entries_query.find_published(public_id: params.expect(:public_id))
    return render_problem(:not_found) unless entry

    payload = publishing_entry_json(entry)
    expires_in(PUBLISHING_CACHE_MAX_AGE.seconds, public: true)
    return unless stale?(etag: payload, last_modified: publishing_timestamp(payload[:published_at]), public: true)

    render json: payload
  end

  # A `limit` outside the bounds is clamped, per the ADR: a tuning mistake must not become an error.
  # A `limit` that is not a whole number is a different thing -- a malformed request -- and is
  # refused rather than quietly treated as the default.
  def publishing_page_limit
    raw = params[:limit]
    return PublishingPublishedEntriesQuery::DEFAULT_LIMIT if raw.blank?

    Integer(raw.to_s, 10)
  rescue ArgumentError, TypeError
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_problem(:bad_request, detail: "limit must be a whole number.")
    # rubocop:enable I18n/RailsI18n/DecorateString
    nil
  end

  # Returns nil when no cursor was sent. A cursor that does not verify is refused: serving page one
  # instead would return the wrong rows while looking successful.
  def publishing_page_cursor
    raw = params[:cursor]
    return nil if raw.blank?

    PublishingEntriesCursor.decode(raw)
  rescue PublishingEntriesCursor::InvalidCursor
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_problem(:bad_request, detail: "cursor is not valid.")
    # rubocop:enable I18n/RailsI18n/DecorateString
    nil
  end

  # `published_at` is the only instant in the contract, so the newest one is the collection's
  # last-modified. Nil when nothing is published: `stale?` then relies on the ETag alone rather than
  # inventing a timestamp.
  def publishing_entries_last_modified(entries)
    entries.filter_map { |entry| publishing_timestamp(entry[:published_at]) }.max
  end

  def publishing_timestamp(value)
    Time.zone.parse(value.to_s) if value.present?
  end

  def publishing_entries_json
    publishing_entries_query.call.filter_map { |entry| publishing_entry_json(entry) }
  end

  # JSON contract preserved from the legacy ReadOnlyContentRendering: the
  # "namespace" field is the content surface (docs/news/help/info) and the
  # "surface" field is the audience (app/com/org).
  def publishing_entry_json(entry)
    PublishingEntrySerializer.call(
      entry:, namespace: self.class.publishing_surface, surface: self.class.publishing_audience,
      vocabularies: publishing_vocabularies,
    )
  end

  # Loaded once per request: the taxonomy keys are a property of the surface,
  # not of an individual entry, so an index of N entries still costs one query.
  def publishing_vocabularies
    @publishing_vocabularies ||=
      Publishing::Vocabulary
        .available
        .for_scope(audience: self.class.publishing_audience, surface: self.class.publishing_surface)
        .order(:key)
        .to_a
  end

  def publishing_entries_query
    @publishing_entries_query ||=
      PublishingPublishedEntriesQuery.new(
        edition: publishing_edition, category: params[:category], tag: params[:tag],
      )
  end

  def publishing_edition
    @publishing_edition ||=
      PublishingEditionResolver.call(
        audience: self.class.publishing_audience, surface: self.class.publishing_surface, locale: publishing_locale,
      )
  end

  def publishing_locale
    params[:locale].presence || locale_from_request_region(params[:ri]) || I18n.locale.to_s
  end

  def locale_from_request_region(region)
    return if region.blank?

    {
      "jp" => "ja",
      "us" => "en",
    }[region.to_s.downcase]
  end
end
