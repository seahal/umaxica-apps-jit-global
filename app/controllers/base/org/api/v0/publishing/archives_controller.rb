# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Publishing
          # Publishing-owned archive commands for the Edit RP (R5-WU13).
          class ArchivesController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include PublishingAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open

            before_action :authenticate_publishing_caller!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def create
              entry = find_publishing_entry!(:entry_entry_ref)
              authorize_publishing_entry!(entry, to: :update?)
              attributes = params[:archive].present? ? { reason: params.expect(archive: %i(reason))[:reason] } : {}
              form = ::Publishing::ArchiveEntryForm.new(attributes)
              return render_publishing_errors(form.message_hash, entry:) unless form.valid?

              result = ::Publishing::ArchiveEntryOperation.call(
                entry:, reason: form.reason, operator_public_id: publishing_operator.public_id,
              )
              return render_publishing_errors(result.errors, entry:) unless result.ok?

              render_entry(entry.reload, status: :created)
            end

            def destroy
              entry = find_publishing_entry!(:entry_entry_ref)
              authorize_publishing_entry!(entry, to: :update?)
              result = ::Publishing::UnarchiveEntryOperation.call(
                entry:,
                operator_public_id: publishing_operator.public_id,
              )
              return render_publishing_errors(result.errors, entry:) unless result.ok?

              render_entry(entry.reload)
            end
          end
        end
      end
    end
  end
end
