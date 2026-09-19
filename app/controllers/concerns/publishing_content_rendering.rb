# typed: false
# frozen_string_literal: true

# Renders read-only entries from the central publishing DB. This is one
# cohesive public-content read contract: resolve the edition, run the published
# entries query, serialize, apply short shared-cache validators, and render
# Problem Details on malformed input. Splitting those steps would hide the
# HTTP contract behind several modules that always run together.
#
# Contract: the including controller declares PUBLISHING_AUDIENCE,
# PUBLISHING_SURFACE, and ENTRY_CLASS as explicit constants. Those values are
# never inferred from the class name or request path.
#
# This concern installs no callbacks of its own. ApiContentNegotiation, included
# below, registers before_action filters because content negotiation must run
# before every JSON action on these endpoints; duplicating those filters on
# twelve controllers would hide the same contract.
#
# Pagination uses Pagy's offset paginator (Pagy 43 `pagy(:offset, ...)`).
# Source: https://ddnexus.github.io/pagy/toolbox/paginators/offset/
module PublishingContentRendering
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation
  include Pagy::Method

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

    def publishing_entry_class
      unless const_defined?(:ENTRY_CLASS, false)
        raise(NameError, "#{name} must declare ENTRY_CLASS")
      end

      const_get(:ENTRY_CLASS, false)
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
    page_number = publishing_page_number
    return if performed?

    paginator, records = paginate_published_entries(page_number)
    return if performed?

    entries = records.filter_map { |entry| publishing_entry_json(entry) }
    payload = { data: entries, page: PublishingCollectionPageSerializer.call(paginator) }

    expires_in(PUBLISHING_CACHE_MAX_AGE.seconds, public: true)
    # The validator covers the whole envelope, so it is page-specific: two pages of the same
    # collection never share an ETag.
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

  # Pagy 43 reads `page` from the request when it is not passed, and `Request#resolve_page` coerces
  # non-numeric values to page 1 (`[page.to_s.to_i, 1].max`). That would answer with the first page
  # for invalid input. The application therefore parses `page` itself and passes the integer in.
  # Out-of-range pages use Pagy's `raise_range_error` rather than the default empty-page rescue.
  # Source: https://ddnexus.github.io/pagy/toolbox/paginators/offset/ (`raise_range_error`, `page`)
  def publishing_page_number
    raw = params[:page]
    return 1 if raw.blank?

    Integer(raw.to_s, 10).tap { |value| raise ArgumentError if value < 1 }
  rescue ArgumentError, TypeError
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_problem(:bad_request, detail: "page must be a whole number greater than or equal to 1.")
    # rubocop:enable I18n/RailsI18n/DecorateString
    nil
  end

  def paginate_published_entries(page_number)
    pagy(
      :offset,
      publishing_entries_query.call,
      limit: PublishingPublishedEntriesQuery::PAGE_SIZE,
      page: page_number,
      raise_range_error: true,
    )
  rescue Pagy::RangeError
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_problem(:bad_request, detail: "page is outside the available range.")
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
      self.class.publishing_entry_class.module_parent::Vocabulary.available.order(:key).to_a
  end

  def publishing_entries_query
    @publishing_entries_query ||=
      PublishingPublishedEntriesQuery.new(
        entry_class: self.class.publishing_entry_class,
        locale: publishing_locale,
        category: params[:category],
        tag: params[:tag],
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
