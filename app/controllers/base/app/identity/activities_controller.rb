# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class ActivitiesController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_activity_log!

        def index
          activities = activity_log.activities(activity_scope).limit(100)
          render inertia: true, props: activities_page_props(activities)
        rescue ActiveRecord::ActiveRecordError
          render inertia: true, props: activities_page_props(ClientChronicle.none)
        end

        private

        def authorize_activity_log! = authorize!(ClientChronicle, to: :index?)

        def activity_scope
          subject = ClientChronicle.where(subject_type: "Client", subject_id: current_client.id.to_s)
          actor = ClientChronicle.where(actor_type: "Client", actor_id: current_client.id)
          subject.or(actor)
        end

        def activity_log = @activity_log ||= ::Base::Identity::ActivityLogPresenter.new(surface: :app)

        def activities_page_props(activities)
          {
            title: t("base.shared.identity.activities.title"),
            description: t("base.shared.identity.activities.description"),
            empty_message: t("base.shared.identity.activities.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
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
