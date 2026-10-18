# typed: false
# frozen_string_literal: true

# The publication windows of one entry: the staff CMS "publish" and
# "unpublish".
#
# A publication is its own row with its own lifecycle, so it is its own
# resource rather than two verbs on the entry. `create` opens a window --
# immediately, or at a stated time -- and `destroy` ends one, which the
# operation resolves into a cancellation or a termination depending on
# whether the window had started.
#
# Both failures re-render the entry's own show page with the message on it.
# Feedback belongs in the response the operator is looking at, not in a
# one-shot banner carried across a redirect (`no-flash-messages`).
module PublishingManagementPublicationsActions
  extend ActiveSupport::Concern

  include ::PublishingManagementCell

  def create
    form = Publishing::PublishEntryForm.new(publish_form_attributes)
    unless form.valid?
      entry = find_nested_management_entry!
      return unless entry

      render_show_failure(entry, errors: form.message_hash)
      return
    end

    attributes = params[:publication].present? ? { publication: { effective_from: form.effective_from&.iso8601 } } : {}
    result = authority_result!(publishing_authority.publish(params.expect(:entry_id), attributes))
    finish_entry_command(result)
  end

  def destroy
    form = Publishing::EndPublicationForm.new(end_form_attributes)
    unless form.valid?
      entry = find_nested_management_entry!
      return unless entry

      render_show_failure(entry, errors: form.message_hash)
      return
    end

    result = authority_result!(
      publishing_authority.end_publication(
        params.expect(:entry_id), params.expect(:id),
        { publication: { reason: form.reason } },
      ),
    )
    finish_entry_command(result)
  end

  private

  def finish_entry_command(result)
    return unless result
    return render_show_failure(result.data.fetch("entry"), errors: result.errors) if result.status == :unprocessable

    redirect_to(entry_path(result.data.fetch("entry"), action: :show), status: :see_other)
  end

  # The Publish button sends no parameters at all -- it means "now" -- so an
  # absent `publication` key is the common case rather than a missing
  # parameter. A present key is read strictly.
  def publish_form_attributes
    return {} if params[:publication].blank?

    { effective_from_text: params.expect(publication: %i(effective_from))[:effective_from] }
  end

  # An absent reason is not a malformed request: it is the validation the
  # form states, answered on the page with the message next to the field.
  def end_form_attributes
    return {} if params[:publication].blank?

    { reason: params.expect(publication: %i(reason))[:reason] }
  end
end
