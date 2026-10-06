# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class TelephonesController < ::Base::Org::ApplicationController
        include SignOperatorTelephoneRegistrable
        include ::SignSettingsAuthorityRedirect

        include ::VerificationOperator

        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          authorize!(OperatorTelephone, to: :index?)
          @staff_telephones = current_operator.staff_telephones.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def new
          @staff_telephone = OperatorTelephone.new
          render inertia: true, props: new_page_props
        end

        def edit
          @staff_telephone = current_operator.staff_telephones.find(params.expect(:id))
          authorize!(@staff_telephone)
          render inertia: true, props: edit_page_props
        end

        def create
          tel_params = params.slice(:staff_telephone).permit(staff_telephone: [:raw_number, :number]).fetch(
            :staff_telephone, {},
          )
          number = tel_params[:raw_number] || tel_params[:number]

          unless initiate_staff_telephone_verification(current_operator, number)
            render_new_failure
            return
          end

          redirect_to(edit_base_org_identity_telephones_registration_path(ri: params[:ri]))
        end

        def destroy
          telephone = current_operator.staff_telephones.find(params.expect(:id))
          authorize!(telephone)

          current_operator.with_lock do
            telephone = OperatorTelephone.lock.find_by!(id: telephone.id, staff_id: current_operator.id)
            telephone.destroy! if AuthMethodGuard.can_remove_telephone?(current_operator, telephone)
          end
          redirect_to(
            base_org_identity_telephones_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def render_new_failure
          render inertia: "base/org/identity/telephones/new",
                 props: new_page_props,
                 status: :unprocessable_content
        end

        def index_page_props
          {
            title: t("controller.sign.app.setting.index.telephone"),
            back_link: { label: t("sign.org.settings.show.back"), href: base_org_identity_path },
            new_link: {
              label: t("sign.org.settings.telephone.index.new_link"),
              href: new_base_org_identity_telephones_registration_path,
            },
            columns: {
              value: t("activerecord.attributes.staff_telephone.number"),
              status: t("activerecord.attributes.staff_telephone.status"),
              actions: "Actions",
            },
            empty_message: t("sign.org.settings.telephone.index.empty"),
            entries: @staff_telephones.map { |telephone| serialize_telephone(telephone) },
          }
        end

        def serialize_telephone(telephone)
          verified = [OperatorTelephoneStatus::ACTIVE, OperatorTelephoneStatus::VERIFIED]
            .include?(telephone.staff_telephone_status_id)

          {
            public_id: telephone.id.to_s,
            value: telephone.number,
            status: verified ? t("views.sign.org.settings.telephones.index.verified") :
              t("views.sign.org.settings.telephones.index.unverified"),
            edit_link: {
              label: t("sign.org.settings.telephone.index.edit"),
              href: edit_base_org_identity_telephone_path(telephone),
            },
          }
        end

        def new_page_props
          {
            title: t("sign.org.settings.telephone.new.title"),
            form: {
              action: base_org_identity_telephones_path,
              scope: "staff_telephone",
              number_label: t("activerecord.attributes.staff_telephone.number"),
              number_placeholder: "+819012345678",
              submit: t("actions.submit"),
            },
            cancel_link: {
              label: t("actions.cancel"),
              href: base_org_identity_telephones_path(ri: params[:ri]),
            },
            error_messages: @staff_telephone.errors.full_messages,
          }
        end

        def edit_page_props
          {
            title: t("sign.org.settings.telephone.edit.title"),
            number: @staff_telephone.number,
            delete: {
              label: t("sign.org.settings.telephone.index.delete"),
              href: base_org_identity_telephone_path(@staff_telephone.id, ri: params[:ri]),
              confirm: t("sign.org.settings.telephone.index.delete_confirm"),
            },
            cancel_link: {
              label: t("sign.common.cancel"),
              href: base_org_identity_telephones_path(ri: params[:ri]),
            },
          }
        end

        def authorize_telephone_registration!
          authorize!(OperatorTelephone, to: :create?)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end
      end
    end
  end
end
