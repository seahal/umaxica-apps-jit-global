# typed: false
# frozen_string_literal: true

module Edit
  module Org
    class DashboardsController < Edit::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
      before_action :authenticate_operator!

      public

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: show_page_props
      end

      private

      def show_page_props
        {
          title: "Publishing",
          # Staff-only dashboard copy is intentionally inline until the Edit surface has its own
          # translation catalog.
          # rubocop:disable I18n/RailsI18n/DecorateString
          description: "Staff Publishing management for info, docs, news, and help.",
          # rubocop:enable I18n/RailsI18n/DecorateString
          sections: [publishing_section],
        }
      end

      def publishing_section
        {
          heading: "Publishing",
          groups: [
            {
              heading: "info",
              items: [
                { label: "app", href: edit_org_publishing_info_app_entries_path(ri: params[:ri]) },
                { label: "com", href: edit_org_publishing_info_com_entries_path(ri: params[:ri]) },
                { label: "org", href: edit_org_publishing_info_org_entries_path(ri: params[:ri]) },
              ],
            },
            {
              heading: "docs",
              items: [
                { label: "app", href: edit_org_publishing_docs_app_entries_path(ri: params[:ri]) },
                { label: "com", href: edit_org_publishing_docs_com_entries_path(ri: params[:ri]) },
                { label: "org", href: edit_org_publishing_docs_org_entries_path(ri: params[:ri]) },
              ],
            },
            {
              heading: "news",
              items: [
                { label: "app", href: edit_org_publishing_news_app_entries_path(ri: params[:ri]) },
                { label: "com", href: edit_org_publishing_news_com_entries_path(ri: params[:ri]) },
                { label: "org", href: edit_org_publishing_news_org_entries_path(ri: params[:ri]) },
              ],
            },
            {
              heading: "help",
              items: [
                { label: "app", href: edit_org_publishing_help_app_entries_path(ri: params[:ri]) },
                { label: "com", href: edit_org_publishing_help_com_entries_path(ri: params[:ri]) },
                { label: "org", href: edit_org_publishing_help_org_entries_path(ri: params[:ri]) },
              ],
            },
          ],
        }
      end
    end
  end
end
