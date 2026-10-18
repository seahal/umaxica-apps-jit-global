# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Publishing
          # Publishing-owned publication window commands for the Edit RP (R5-WU13).
          class PublicationsController < ActionController::API
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
              attributes = {}
              if params[:publication].present?
                attributes[:effective_from_text] = params.expect(publication: %i(effective_from))[:effective_from]
              end
              form = ::Publishing::PublishEntryForm.new(attributes)
              return render_publishing_errors(form.message_hash, entry:) unless form.valid?

              result = ::Publishing::PublishEntryOperation.call(
                entry:, operator_public_id: publishing_operator.public_id, effective_from: form.effective_from,
              )
              return render_publishing_errors(result.errors, entry:) unless result.ok?

              render_entry(entry.reload, status: :created)
            end

            def destroy
              entry = find_publishing_entry!(:entry_entry_ref)
              authorize_publishing_entry!(entry, to: :update?)
              publication = entry.publications.find_by!(public_id: params.expect(:publication_ref))
              attributes = {}
              attributes[:reason] = params.expect(publication: %i(reason))[:reason] if params[:publication].present?
              form = ::Publishing::EndPublicationForm.new(attributes)
              return render_publishing_errors(form.message_hash, entry:) unless form.valid?

              result = ::Publishing::EndPublicationOperation.call(
                publication:, reason: form.reason, operator_public_id: publishing_operator.public_id,
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
