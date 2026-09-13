# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module News
        module Org
          module Entries
            class PublicationsController < Edit::Org::ApplicationController
              include ::PublishingManagementPublicationsActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "news"
              PUBLISHING_AUDIENCE = "org"
              ENTRY_CLASS = ::Publishing::News::Org::Entry

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
