# typed: false
# frozen_string_literal: true

# Staff Publishing CMS entry pages for one surface/audience cell: the list,
# one entry, the new-entry form, and the two writes that produce a revision.
#
# Publishing and archiving are not actions here. They are their own nested
# resources (`Entries::PublicationsController`,
# `Entries::ArchivesController`), because they change a different row than a
# revision does.
module PublishingManagementEntriesActions
  extend ActiveSupport::Concern

  include ::PublishingManagementCell

  def index
    result = authority_result!(publishing_authority.entries(page: page_number))
    return unless result

    render entries_template("index"), locals: index_page_props(result.data)
  end

  def show
    entry = find_management_entry!
    return unless entry

    render entries_template("show"), locals: show_entry_props(entry)
  end

  def new
    # The authority answers the Operator's create permission on the collection read.
    return unless authority_result!(publishing_authority.entries(page: 1))

    render entries_template("new"), locals: new_entry_props
  end

  def create
    form = Publishing::CreateEntryForm.new(create_entry_form_attributes)
    unless form.valid?
      return unless authority_result!(publishing_authority.entries(page: 1))

      render_new_failure(errors: form.message_hash, form: form)
      return
    end

    result = authority_result!(
      publishing_authority.create_entry(
        locale: form.locale, slug: form.slug, title: form.title, summary: form.summary, body: form.body_text,
      ),
    )
    return unless result
    return render_new_failure(errors: result.errors, form: form) if result.status == :unprocessable

    redirect_to(entry_path(result.data.fetch("entry"), action: :show), status: :see_other)
  end

  def edit
    entry = find_management_entry!
    return unless entry

    render entries_template("edit"), locals: edit_entry_props(entry, errors: {})
  end

  def update
    form = Publishing::ReviseEntryForm.new(revise_entry_form_attributes)
    unless form.valid?
      entry = find_management_entry!
      return unless entry

      render_edit_failure(entry, errors: form.message_hash, form: form)
      return
    end

    result = authority_result!(
      publishing_authority.revise_entry(
        params.expect(:id),
        title: form.title, summary: form.summary, body: form.body_text, lock_version: form.lock_version,
      ),
    )
    return unless result
    return render_edit_failure(result.data.fetch("entry"), errors: result.errors, form: form) if
      result.status == :unprocessable

    redirect_to(entry_path(result.data.fetch("entry"), action: :show), status: :see_other)
  end

  private

  # A page outside the list is an empty page, not an error, but a page that is
  # not a number is a malformed request and is answered as one rather than
  # quietly read as page 1.
  def page_number
    value = params[:page]
    return 1 if value.blank?

    number = Integer(value, exception: false)
    raise ActionController::BadRequest, "page must be an integer" if number.nil?

    number
  end

  def revise_entry_form_attributes
    permitted = params.expect(entry: %i(title summary body lock_version))
    {
      title: permitted[:title],
      summary: permitted[:summary],
      body_text: permitted[:body],
      lock_version: permitted[:lock_version],
    }
  end

  def create_entry_form_attributes
    permitted = params.expect(entry: %i(title summary body locale slug))
    {
      title: permitted[:title],
      summary: permitted[:summary],
      body_text: permitted[:body],
      locale: permitted[:locale],
      slug: permitted[:slug],
    }
  end

  def render_edit_failure(entry, errors:, form:)
    render entries_template("edit"),
           locals: edit_entry_props(entry, errors: errors, form: form),
           status: :unprocessable_content
  end

  def render_new_failure(errors:, form:)
    render entries_template("new"),
           locals: new_entry_props(errors: errors, form: form),
           status: :unprocessable_content
  end
end
