# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class ActivitiesController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :authorize_activity_log!, only: %i(index)

        def index
          activities = activity_log.activities(activity_scope).limit(100)
          render inertia: "base/org/identity/activities/index", props: activities_page_props(activities)
        rescue ActiveRecord::ActiveRecordError
          render inertia: "base/org/identity/activities/index", props: activities_page_props(OperatorChronicle.none)
        end

        private

        def authorize_activity_log! = authorize!(OperatorChronicle, to: :index?)

        def activity_scope
          OperatorChronicle.where(subject_type: "Operator", subject_id: current_operator.id.to_s)
        end

        def activity_log = @activity_log ||= ::Base::Identity::ActivityLogPresenter.new(surface: :org)

        def activities_page_props(activities)
          {
            title: t("base.shared.identity.activities.title"),
            description: t("base.shared.identity.activities.description"),
            empty_message: t("base.shared.identity.activities.empty"),
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path(ri: params[:ri]),
            },
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
