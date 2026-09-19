# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module Help
        module Com
          class EntriesController < Edit::Org::ApplicationController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :private
            declare_authentication_mode! :private
            PUBLISHING_SURFACE = "help"
            PUBLISHING_AUDIENCE = "com"
            ENTRY_CLASS = ::Publishing::Help::Com::Entry

            public

            def index
              super
            end

            def show
              super
            end

            def new
              super
            end

            def edit
              super
            end

            def create
              super
            end

            def update
              super
            end
          end
        end
      end
    end
  end
end
