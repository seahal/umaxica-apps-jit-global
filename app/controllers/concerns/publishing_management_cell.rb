# typed: false
# frozen_string_literal: true

# Everything the staff Publishing CMS controllers of one surface/audience cell
# share: the cell's identity, the authenticated operator credential, the
# Publishing authority client, and the props every page is built from.
#
# Contract: the including controller declares PUBLISHING_AUDIENCE and
# PUBLISHING_SURFACE as explicit constants. Those values are
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

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    # The CMS is staff-only. Every action writes or reads unpublished content,
    # including drafts that were never published and the bodies of archived
    # entries, so there is no action here that an anonymous request may reach.
    #
    # The surface web rate limit comes from the staff ApplicationController
    # these controllers inherit (Edit::Org::ApplicationController).
    before_action :authenticate_browser_rp!
  end

  private

  def publishing_audience
    self.class.publishing_audience
  end

  def publishing_surface
    self.class.publishing_surface
  end

  # Staff CMS Inertia/controller prefix comes from the surface
  # ApplicationController (Edit::Org::ApplicationController#publishing_management_namespace).
  # Do not define a stub here: included modules sit ahead of the superclass in
  # the ancestor chain and would shadow that implementation for every cell.

  # R5-WU13: every read and write goes to the Publishing authority over HTTPS with this request's
  # Operator Access JWT; the RP holds no publishing data and makes no policy decision itself.
  def publishing_authority
    @publishing_authority ||= PublishingAuthorityClient.new(
      surface: publishing_surface, audience: publishing_audience,
      access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
    )
  end

  # Records the authority's decision for verify_authorized, then answers not-found or dependency
  # failures the same way the pages always have. Returns the result for :ok and :unprocessable.
  def authority_result!(result)
    authorize!(result, to: :show?, with: PublishingRemoteResultPolicy)
    raise ActiveRecord::RecordNotFound, "publishing entry not found" if result.status == :not_found

    if result.status == :dependency
      head :service_unavailable
      return
    end

    result
  end

  def fetch_management_entry!(ref)
    result = authority_result!(publishing_authority.entry(ref))
    result&.data&.fetch("entry")
  end

  def find_management_entry!
    fetch_management_entry!(params.expect(:id))
  end

  def find_nested_management_entry!
    fetch_management_entry!(params.expect(:entry_id))
  end

  # Absolute controller paths, so a nested controller addresses the entries
  # pages of its own cell rather than its own.
  def entries_controller_path
    "/#{publishing_management_namespace}/#{publishing_surface}/#{publishing_audience}/entries"
  end

  # Every cell (four content families x three audiences) shares the same four ERB templates; the
  # cell's identity travels as locals (surface/audience-derived hrefs), not as a per-cell view.
  def entries_template(name)
    "edit/org/publishing/entries/#{name}"
  end

  def entry_path(entry, action:)
    url_for(controller: entries_controller_path, action: action, id: entry.fetch("public_id"), only_path: true)
  end

  def entries_index_path(**)
    url_for(controller: entries_controller_path, action: :index, only_path: true, **)
  end

  def entry_publications_path(entry)
    url_for(
      controller: "#{entries_controller_path}/publications",
      action: :create, entry_id: entry.fetch("public_id"), only_path: true,
    )
  end

  def entry_publication_path(entry, publication)
    url_for(
      controller: "#{entries_controller_path}/publications",
      action: :destroy, entry_id: entry.fetch("public_id"), id: publication.fetch("public_id"), only_path: true,
    )
  end

  def entry_archive_path(entry)
    url_for(
      controller: "#{entries_controller_path}/archives",
      action: :create, entry_id: entry.fetch("public_id"), only_path: true,
    )
  end

  def management_title
    "Publishing #{publishing_surface}/#{publishing_audience}"
  end

  def index_page_props(page)
    number = page.fetch("number")
    {
      title: management_title,
      description: "Entries for #{publishing_surface}/#{publishing_audience} across locales.",
      surface: publishing_surface,
      audience: publishing_audience,
      new_href: url_for(controller: entries_controller_path, action: :new, only_path: true),
      entries: page.fetch("entries").map { |entry| index_entry_props(entry) },
      page: {
        number:,
        per_page: page.fetch("per_page"),
        total: page.fetch("total"),
        previous_href: (entries_index_path(page: number - 1) if number > 1),
        next_href: (entries_index_path(page: number + 1) if page.fetch("has_more")),
      },
    }
  end

  def index_entry_props(entry)
    entry.slice(
      "public_id", "title", "locale", "canonical_slug", "archive_state", "publication_state", "revision_sequence",
      "updated_at",
    ).symbolize_keys.merge(show_href: entry_path(entry, action: :show), edit_href: entry_path(entry, action: :edit))
  end

  def show_entry_props(entry, errors: {})
    active = entry["active_publication"]
    {
      title: entry["title"].presence || management_title,
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: entries_index_path,
      edit_href: entry_path(entry, action: :edit),
      publish_href: entry_publications_path(entry),
      archive_href: entry_archive_path(entry),
      errors: stringify_error_keys(errors),
      publication: (publication_props(entry, active) if active),
      scheduled_publications: entry.fetch("scheduled_publications").map { |row| publication_props(entry, row) },
      entry: {
        public_id: entry.fetch("public_id"),
        surface: publishing_surface,
        audience: publishing_audience,
        locale: entry["locale"],
        canonical_slug: entry["canonical_slug"],
        current_revision_public_id: entry["current_revision_public_id"],
        revision_sequence: entry["revision_sequence"],
        title: entry["title"],
        summary: entry["summary"],
        body: entry["body"],
        archive_state: entry["archive_state"],
        archive_reason: entry["archive_reason"],
        publication_state: entry["publication_state"],
        revision_count: entry["revision_count"],
        version_count: entry["version_count"],
        updated_at: entry["updated_at"],
      },
    }
  end

  def publication_props(entry, publication)
    {
      public_id: publication.fetch("public_id"),
      effective_from: publication.fetch("effective_from"),
      version_public_id: publication.fetch("version_public_id"),
      end_href: entry_publication_path(entry, publication),
    }
  end

  def edit_entry_props(entry, errors:, form: nil)
    body_source = form&.body_text
    body_source ||= pretty_body_json(entry["body"])
    {
      title: "Edit #{entry["title"].presence || entry.fetch("public_id")}",
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: entries_index_path,
      show_href: entry_path(entry, action: :show),
      errors: stringify_error_keys(errors),
      form: {
        action: entry_path(entry, action: :update),
        method: "patch",
        title: form&.title || entry["title"],
        summary: form&.summary || entry["summary"],
        body: body_source,
        lock_version: entry["lock_version"],
        locale: entry["locale"],
        canonical_slug: entry["canonical_slug"],
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
    render entries_template("show"),
           locals: show_entry_props(entry, errors: errors),
           status: :unprocessable_content
  end

  def pretty_body_json(body)
    JSON.pretty_generate(body || {})
  end

  def stringify_error_keys(errors)
    errors.to_h { |key, value| [key.to_s, value] }
  end
end
