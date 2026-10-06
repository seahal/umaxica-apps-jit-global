# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TelephonesController < BaseController
        include ::SurfaceInertiaPage
        include CommonRedirect
        include CommonOtp
        include SignTelephoneRegistrable
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          authorize!(ClientTelephone, to: :index?)
          telephones = current_client.client_telephones.order(created_at: :asc)
          render inertia: true, props: telephones_index_props(telephones)
        end

        def new
          @user_telephone = ClientTelephone.new
          render inertia: true, props: telephone_new_props(@user_telephone)
        end

        def edit
          @user_telephone = current_client.client_telephones.find_by!(public_id: params.expect(:id))
          authorize!(@user_telephone)
          render inertia: true, props: telephone_edit_props(@user_telephone)
        end

        def create
          user = current_client
          tel_params = params.expect(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_telephone_verification(user, number, auto_accept_confirmations: true)
            redirect_to(edit_base_app_identity_telephones_registration_path(ri: params[:ri]), status: :see_other)
          else
            render inertia: "base/app/identity/telephones/new",
                   props: telephone_new_props(@user_telephone || ClientTelephone.new),
                   status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_client.client_telephones.find_by!(public_id: params.expect(:id))
          authorize!(telephone)
          return redirect_to(
            base_app_identity_telephones_path(ri: params[:ri]),
            status: :see_other,
          ) unless AuthMethodGuard.can_remove_telephone?(
            current_client, telephone,
          )

          IdentityCredentialRemovalCommitter.call!(
            actor: current_client, credential: telephone, current_session: current_session, request: request,
          )
          redirect_to(base_app_identity_telephones_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_telephone_registration! = authorize!(ClientTelephone, to: :create?)

        def verification_required_action? = true

        def verification_scope = "settings_telephone"

        def telephones_index_props(telephones)
          {
            title: "Telephones",
            empty_message: t("views.sign.app.settings.telephones.index.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            new_link: {
              label: t("sign.app.settings.telephone.index.new_link"),
              href: new_base_app_identity_telephone_path(ri: params[:ri]),
            },
            registration_link: {
              label: t("base.app.navigation.telephone_registration"),
              href: new_base_app_identity_telephones_registration_path(ri: params[:ri]),
            },
            table_headings: {
              number: "Number",
              status: "Status",
              actions: t("views.sign.app.settings.telephones.index.actions"),
            },
            telephones: telephones.map { |telephone| serialize_telephone(telephone) },
          }
        end

        def serialize_telephone(telephone)
          {
            public_id: telephone.public_id,
            number: telephone.number.to_s,
            status_label: verified_telephone?(telephone) ?
              t("views.sign.app.settings.telephones.index.verified") :
              t("views.sign.app.settings.telephones.index.unverified"),
            edit_link: {
              label: t("sign.app.settings.telephone.index.edit"),
              href: edit_base_app_identity_telephone_path(telephone.public_id),
            },
          }
        end

        def verified_telephone?(telephone)
          [
            ClientTelephoneStatus::VERIFIED,
            ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
          ].include?(telephone.user_telephone_status_id)
        end

        def telephone_new_props(telephone)
          {
            title: t("sign.app.settings.telephone.new.title"),
            description: t("views.sign.app.settings.telephones.new.description"),
            help_text: t("views.sign.app.settings.telephones.new.help_text"),
            number_label: "Number",
            number_placeholder: "+819012345678",
            form: { action: base_app_identity_telephones_path, submit_label: "Submit" },
            cancel_link: { label: "Cancel", href: base_app_identity_telephones_path(ri: params[:ri]) },
            errors: telephone.errors.full_messages,
          }
        end

        def telephone_edit_props(telephone)
          {
            title: t("sign.app.settings.telephone.edit.title"),
            number: telephone.number.to_s,
            delete: {
              label: t("sign.app.settings.telephone.index.delete"),
              confirm: t("sign.app.settings.telephone.index.delete_confirm"),
              url: base_app_identity_telephone_path(telephone.public_id, ri: params[:ri]),
            },
            cancel_link: { label: "Cancel", href: base_app_identity_telephones_path(ri: params[:ri]) },
          }
        end
      end
    end
  end
end
