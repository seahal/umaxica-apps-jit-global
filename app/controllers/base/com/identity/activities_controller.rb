# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class ActivitiesController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :authorize_activity_log!

        def index
          activities = activity_log.activities(activity_scope).limit(100)
          render inertia: "base/com/identity/activities/index", props: activities_page_props(activities)
        rescue ActiveRecord::ActiveRecordError
          render inertia: "base/com/identity/activities/index", props: activities_page_props(ClientChronicle.none)
        end

        private

        # ClientChronicle stores both Clients and Visitors; this page is limited to this Visitor's rows.
        def authorize_activity_log! = authorize!(ClientChronicle, to: :index?)

        def activity_scope
          ClientChronicle.where(subject_type: "Visitor", subject_id: current_visitor.id.to_s)
        end

        def activity_log = @activity_log ||= ::Base::Identity::ActivityLogPresenter.new(surface: :com)

        def activities_page_props(activities)
          {
            title: t("base.shared.identity.activities.title"),
            description: t("base.shared.identity.activities.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_com_identity_path(ri: params[:ri]),
            },
            empty_message: t("base.shared.identity.activities.empty"),
            columns: activity_columns,
            activities: activities.map { |activity| activity_log.present(activity) }.compact,
          }
        end

        def activity_columns
          %i(occurred_at activity device source risk).index_with do |column|
            t("base.shared.identity.activities.columns.#{column}")
          end
        end
      end
    end
  end
end
