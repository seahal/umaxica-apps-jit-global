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
    entry = find_nested_management_entry!
    authorize_publishing!(entry, to: :update?)
    form = Publishing::ArchiveEntryForm.new(archive_form_attributes)

    unless form.valid?
      render_show_failure(entry, errors: form.message_hash)
      return
    end

    result = Publishing::ArchiveEntryOperation.call(
      entry: entry,
      reason: form.reason,
      operator_public_id: operator_public_id,
    )

    unless result.ok?
      render_show_failure(publishing_entries_query.find!(public_id: entry.public_id), errors: result.errors)
      return
    end

    redirect_to(entry_path(entry, action: :show), status: :see_other)
  end

  def destroy
    entry = find_nested_management_entry!
    authorize_publishing!(entry, to: :update?)

    result = Publishing::UnarchiveEntryOperation.call(entry: entry, operator_public_id: operator_public_id)

    unless result.ok?
      render_show_failure(publishing_entries_query.find!(public_id: entry.public_id), errors: result.errors)
      return
    end

    redirect_to(entry_path(entry, action: :show), status: :see_other)
  end

  private

  def archive_form_attributes
    return {} if params[:archive].blank?

    { reason: params.expect(archive: %i(reason))[:reason] }
  end
end
