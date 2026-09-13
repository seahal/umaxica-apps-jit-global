# typed: false
# frozen_string_literal: true

# Everything the staff Publishing CMS controllers of one surface/audience cell
# share: the cell's identity, the authenticated operator behind the request,
# the query that never leaves the cell, and the props every page is built
# from.
#
# Contract: the including controller declares PUBLISHING_AUDIENCE,
# PUBLISHING_SURFACE, and ENTRY_CLASS as explicit constants. Those values are
# never inferred from the class name, request path, params, or host.
#
# The nested publication and archive controllers render and redirect to the
# entries pages of their own cell, so the component names, paths, and props
# live here rather than in the entries controller they would otherwise have to
# reach into.
#
# A management URL has no locale segment. Index and show therefore cover every
# Entry whose Edition matches the declared audience and surface, across
# locales.
module PublishingManagementCell
  extend ActiveSupport::Concern

  include ::SurfaceInertiaPage

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

  included do
    # The CMS is staff-only. Every action writes or reads unpublished content,
    # including drafts that were never published and the bodies of archived
    # entries, so there is no action here that an anonymous request may reach.
    #
    # The surface web rate limit comes from the staff ApplicationController
    # these controllers inherit (Edit::Org::ApplicationController).
    before_action :authenticate_operator!
  end

  private

  def publishing_audience
    self.class.publishing_audience
  end

  def publishing_surface
    self.class.publishing_surface
  end

  def publishing_entry_class
    self.class.publishing_entry_class
  end

  # Staff CMS Inertia/controller prefix. Declared by the surface application
  # controller so cells never infer it from class names, params, or host.
  def publishing_management_namespace
    raise(NotImplementedError, "#{self.class.name} must implement #publishing_management_namespace")
  end

  # Every CMS action asks the same question of the same policy. The record
  # differs -- an entry for the member actions, the operator for the
  # collection ones -- because that is what the action is about.
  def authorize_publishing!(record, to:)
    authorize!(record, to: to, with: PublishingEntryPolicy)
  end

  # Provenance for every row this request writes. `authenticate_operator!` has
  # already run, so an absent operator here is a broken pipeline, not a
  # visitor: it raises rather than writing an anonymous revision.
  def operator_public_id
    current_operator.public_id
  end

  def publishing_entries_query
    PublishingManagementEntriesQuery.new(entry_class: publishing_entry_class)
  end

  def find_management_entry!
    publishing_entries_query.find!(public_id: params.expect(:id))
  end

  def find_nested_management_entry!
    publishing_entries_query.find!(public_id: params.expect(:entry_id))
  end

  # Absolute controller paths, so a nested controller addresses the entries
  # pages of its own cell rather than its own.
  def entries_controller_path
    "/#{publishing_management_namespace}/#{publishing_surface}/#{publishing_audience}/entries"
  end

  def entries_component(name)
    "#{publishing_management_namespace}/#{publishing_surface}/#{publishing_audience}/entries/#{name}"
  end

  def entry_path(entry, action:)
    url_for(controller: entries_controller_path, action: action, id: entry.public_id, only_path: true)
  end

  def entries_index_path(**)
    url_for(controller: entries_controller_path, action: :index, only_path: true, **)
  end

  def entry_publications_path(entry)
    url_for(
      controller: "#{entries_controller_path}/publications",
      action: :create, entry_id: entry.public_id, only_path: true,
    )
  end

  def entry_publication_path(entry, publication)
    url_for(
      controller: "#{entries_controller_path}/publications",
      action: :destroy, entry_id: entry.public_id, id: publication.public_id, only_path: true,
    )
  end

  def entry_archive_path(entry)
    url_for(
      controller: "#{entries_controller_path}/archives",
      action: :create, entry_id: entry.public_id, only_path: true,
    )
  end

  def management_title
    "Publishing #{publishing_surface}/#{publishing_audience}"
  end

  def index_page_props(page)
    {
      title: management_title,
      description: "Entries for #{publishing_surface}/#{publishing_audience} across locales.",
      surface: publishing_surface,
      audience: publishing_audience,
      new_href: url_for(controller: entries_controller_path, action: :new, only_path: true),
      entries: page.entries.map { |entry| index_entry_props(entry) },
      page: {
        number: page.number,
        per_page: page.per_page,
        total: page.total,
        previous_href: (entries_index_path(page: page.number - 1) if page.number > 1),
        next_href: (entries_index_path(page: page.number + 1) if page.has_more),
      },
    }
  end

  def index_entry_props(entry)
    revision = entry.current_revision
    {
      public_id: entry.public_id,
      title: revision&.title,
      locale: entry.locale,
      canonical_slug: entry.canonical_slug&.slug,
      archive_state: entry.archived? ? "archived" : "active",
      publication_state: entry.active_publication.present? ? "published" : "draft",
      revision_sequence: revision&.sequence,
      updated_at: entry.updated_at&.iso8601,
      show_href: entry_path(entry, action: :show),
      edit_href: entry_path(entry, action: :edit),
    }
  end

  def show_entry_props(entry, errors: {})
    revision = entry.current_revision
    active = entry.active_publication
    {
      title: revision&.title.presence || management_title,
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: entries_index_path,
      edit_href: entry_path(entry, action: :edit),
      publish_href: entry_publications_path(entry),
      archive_href: entry_archive_path(entry),
      errors: stringify_error_keys(errors),
      publication: (publication_props(entry, active) if active),
      scheduled_publications: scheduled_publications(entry).map { |row| publication_props(entry, row) },
      entry: {
        public_id: entry.public_id,
        surface: publishing_surface,
        audience: publishing_audience,
        locale: entry.locale,
        canonical_slug: entry.canonical_slug&.slug,
        current_revision_public_id: revision&.public_id,
        revision_sequence: revision&.sequence,
        title: revision&.title,
        summary: revision&.summary,
        body: revision&.body,
        archive_state: entry.archived? ? "archived" : "active",
        archive_reason: entry.archive_reason,
        publication_state: active.present? ? "published" : "draft",
        revision_count: entry.revisions.count,
        version_count: entry.versions.count,
        updated_at: entry.updated_at&.iso8601,
      },
    }
  end

  # Windows that have been recorded but have not started yet. They are not
  # part of `active_publication`, and an operator who scheduled one has no
  # other place to see or cancel it.
  def scheduled_publications(entry)
    entry.publications
      .where(cancelled_at: nil, terminated_at: nil)
      .where(effective_from: Time.current...)
      .order(:effective_from)
  end

  def publication_props(entry, publication)
    {
      public_id: publication.public_id,
      effective_from: publication.effective_from.iso8601,
      version_public_id: publication.entry_version.public_id,
      end_href: entry_publication_path(entry, publication),
    }
  end

  def edit_entry_props(entry, errors:, form: nil)
    revision = entry.current_revision
    body_source = form&.body_text
    body_source ||= pretty_body_json(revision&.body)
    {
      title: "Edit #{revision&.title.presence || entry.public_id}",
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: entries_index_path,
      show_href: entry_path(entry, action: :show),
      errors: stringify_error_keys(errors),
      form: {
        action: entry_path(entry, action: :update),
        method: "patch",
        title: form&.title || revision&.title,
        summary: form&.summary || revision&.summary,
        body: body_source,
        lock_version: entry.lock_version,
        locale: entry.locale,
        canonical_slug: entry.canonical_slug&.slug,
      },
    }
  end

  def new_entry_props(errors: {}, form: nil)
    {
      title: "New #{publishing_surface}/#{publishing_audience} entry",
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: entries_index_path,
      errors: stringify_error_keys(errors),
      locales: I18n.available_locales.map(&:to_s),
      form: {
        action: url_for(controller: entries_controller_path, action: :create, only_path: true),
        method: "post",
        title: form&.title,
        summary: form&.summary,
        body: form&.body_text || pretty_body_json(nil),
        locale: form&.locale || I18n.default_locale.to_s,
        slug: form&.slug,
      },
    }
  end

  # Publication and archive failures re-render the entry's own show page with
  # the message on it, because that is the page the operator acted from.
  def render_show_failure(entry, errors:)
    render inertia: entries_component("show"),
           props: show_entry_props(entry, errors: errors),
           status: :unprocessable_content
  end

  def pretty_body_json(body)
    JSON.pretty_generate(body || {})
  end

  def stringify_error_keys(errors)
    errors.to_h { |key, value| [key.to_s, value] }
  end
end
