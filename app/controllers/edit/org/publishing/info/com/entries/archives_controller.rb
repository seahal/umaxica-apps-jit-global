# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module Info
        module Com
          module Entries
            class ArchivesController < Edit::Org::ApplicationController
              include ::PublishingManagementArchivesActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "info"
              PUBLISHING_AUDIENCE = "com"
              ENTRY_CLASS = ::Publishing::Info::Com::Entry

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
