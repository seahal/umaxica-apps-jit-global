# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Publishing
      module News
        module Com
          module Entries
            class PublicationsController < Edit::Org::ApplicationController
              include ::PublishingManagementPublicationsActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "news"
              PUBLISHING_AUDIENCE = "com"
              ENTRY_CLASS = ::Publishing::News::Com::Entry

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
