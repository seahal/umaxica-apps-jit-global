# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Publishing
          # Publishing-owned entry reads and revision writes for the Edit RP (R5-WU13).
          class EntriesController < ActionController::API
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

            def index
              authorize_publishing_entry!(publishing_operator, to: :index?)
              number = Integer(params.fetch(:page, 1).to_s, 10)
              render json: PublishingManagementEntrySerializer.page(publishing_entries_query.page(number:))
            rescue ArgumentError
              render json: { error: "bad_request" }, status: :bad_request
            end

            def show
              entry = find_publishing_entry!
              authorize_publishing_entry!(entry, to: :show?)
              render_entry(entry)
            end

            def create
              authorize_publishing_entry!(publishing_operator, to: :create?)
              permitted = params.expect(entry: %i(title summary body locale slug))
              form = ::Publishing::CreateEntryForm.new(
                title: permitted[:title], summary: permitted[:summary], body_text: permitted[:body],
                locale: permitted[:locale], slug: permitted[:slug],
              )
              return render_publishing_errors(form.message_hash) unless form.valid?

              result = ::Publishing::CreateEntryOperation.call(
                entry_class: publishing_entry_class, locale: form.locale, slug: form.slug, title: form.title,
                summary: form.summary, body: form.parsed_body, operator_public_id: publishing_operator.public_id,
              )
              return render_publishing_errors(result.errors) unless result.ok?

              render_entry(result.entry, status: :created)
            end

            def update
              entry = find_publishing_entry!
              authorize_publishing_entry!(entry, to: :update?)
              permitted = params.expect(entry: %i(title summary body lock_version))
              form = ::Publishing::ReviseEntryForm.new(
                title: permitted[:title], summary: permitted[:summary], body_text: permitted[:body],
                lock_version: permitted[:lock_version],
              )
              return render_publishing_errors(form.message_hash, entry:) unless form.valid?

              result = ::Publishing::ReviseEntryOperation.call(
                entry:, title: form.title, summary: form.summary, body: form.parsed_body,
                lock_version: form.lock_version, operator_public_id: publishing_operator.public_id,
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
