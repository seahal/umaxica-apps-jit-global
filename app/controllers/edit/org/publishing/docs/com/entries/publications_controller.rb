# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module Docs
        module Com
          module Entries
            class PublicationsController < Edit::Org::ApplicationController
              include ::PublishingManagementPublicationsActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "docs"
              PUBLISHING_AUDIENCE = "com"
              ENTRY_CLASS = ::Publishing::Docs::Com::Entry

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
