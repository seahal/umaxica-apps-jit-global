# typed: false
# frozen_string_literal: true

# The archive state of one entry.
#
# `archived_at` is the only removal this schema has: every association off an
# entry is `dependent: :restrict_with_exception`, and the revisions, versions,
# and publications are the record of what was published. So the CMS has no
# `DELETE /entries/:id`; it has an archive that can be set and cleared.
#
# A singular resource because an entry has one archive state: `create`
# archives, `destroy` restores.
module PublishingManagementArchivesActions
  extend ActiveSupport::Concern

  include ::PublishingManagementCell

  def create
    form = Publishing::ArchiveEntryForm.new(archive_form_attributes)
    unless form.valid?
      entry = find_nested_management_entry!
      return unless entry

      render_show_failure(entry, errors: form.message_hash)
      return
    end

    finish_archive_command(publishing_authority.archive(params.expect(:entry_id), { archive: { reason: form.reason } }))
  end

  def destroy
    finish_archive_command(publishing_authority.unarchive(params.expect(:entry_id)))
  end

  private

  def finish_archive_command(response)
    result = authority_result!(response)
    return unless result
    return render_show_failure(result.data.fetch("entry"), errors: result.errors) if result.status == :unprocessable

    redirect_to(entry_path(result.data.fetch("entry"), action: :show), status: :see_other)
  end

  def archive_form_attributes
    return {} if params[:archive].blank?

    { reason: params.expect(archive: %i(reason))[:reason] }
  end
end
