# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module Docs
        module App
          module Entries
            class ArchivesController < Edit::Org::ApplicationController
              include ::PublishingManagementArchivesActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "docs"
              PUBLISHING_AUDIENCE = "app"
              ENTRY_CLASS = ::Publishing::Docs::App::Entry

              public

              def create
                super
              end

              def destroy
                super
              end
            end
          end
        end
      end
    end
  end
end
