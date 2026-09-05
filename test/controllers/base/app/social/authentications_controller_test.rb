# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::Social::AuthenticationsControllerTest < ActionController::TestCase
  counts_rate_limits!
  tests Base::App::Social::Authentication::CompletionsController

  setup do
    @request.host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @commit_user = Client.create!(
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      birthdate: "2000-01-01",
    )
  end

  test "completion provisions the graph before session issuance" do
    graph_provisioned = false
    sign_up_flow_completed = false

    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      raise RuntimeError, "graph was not provisioned" unless graph_provisioned

      { status: :success, redirect_path: "/dashboard" }
    end
    @controller.define_singleton_method(:complete_base_social_signup_flow!) do |_commit, _sign_in_result|
      raise RuntimeError, "graph was not provisioned" unless graph_provisioned

      sign_up_flow_completed = true
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "signup", "actor_ref" => "flow-1" },
      nil,
      Struct.new(:provider).new("google"),
      false,
    )

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "signup", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(*_args, **_kwargs) { graph_provisioned = true }) do
            AuthenticationSessionCommitter.stub(:call, { status: :success, redirect_path: "/dashboard" }) do
              post :create, params: { id: "google", ri: "jp", social_ceremony_result: "signed-token" }
            end
          end
        end
      end
    end

    assert_response :redirect
    assert_match %r{/dashboard\z}, response.location
    assert_predicate graph_provisioned, :itself
    assert_predicate sign_up_flow_completed, :itself
  end

  test "completion does not establish a session when graph provisioning fails" do
    session_started = false

    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      session_started = true
      { status: :success, redirect_path: "/dashboard" }
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "signup", "actor_ref" => "flow-1" },
      nil,
      Struct.new(:provider).new("google"),
      false,
    )
    error = RuntimeError.new("graph boom")

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "signup", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(*_args, **_kwargs) { raise error }) do
            raised =
              assert_raises(RuntimeError) do
                post(:create, params: { id: "google", ri: "jp", social_ceremony_result: "signed-token" })
              end

            assert_same error, raised
          end
        end
      end
    end

    assert_not session_started
  end

  test "completion redirects without notice for signup flows" do
    redirects = []
    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      { status: :success, redirect_path: "/dashboard" }
    end
    @controller.define_singleton_method(:complete_base_social_signup_flow!) do |_commit, _sign_in_result|
      true
    end
    @controller.define_singleton_method(:redirect_to) do |*args, **kwargs|
      redirects << [args, kwargs]
    end
    @controller.define_singleton_method(:base_social_login_redirect_to) do |_sign_in_result|
      "/dashboard"
    end
    @controller.define_singleton_method(:base_social_login_redirect_allows_other_host?) do |_redirect_url|
      false
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "signup", "actor_ref" => "flow-1" },
      nil,
      Struct.new(:provider).new("apple"),
      false,
    )

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "apple", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "signup", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(*_args, **_kwargs) { true }) do
            AuthenticationSessionCommitter.stub(:call, { status: :success, redirect_path: "/dashboard" }) do
              post :create, params: { id: "apple", ri: "jp", social_ceremony_result: "signed-token" }
            end
          end
        end
      end
    end

    assert_equal({ allow_other_host: false }, redirects.last.last)
  end

  test "completion renders terminal failure for sign in result failures" do
    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      { status: :login_forbidden, message: "login blocked" }
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "login" },
      nil,
      Struct.new(:provider).new("google"),
      true,
    )

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "login", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(*_args, **_kwargs) { true }) do
            AuthenticationSessionCommitter.stub(:call, { status: :login_forbidden, message: "login blocked" }) do
              post :create, params: { id: "google", ri: "jp", social_ceremony_result: "signed-token" }
            end
          end
        end
      end
    end

    assert_response :forbidden
    assert_nil response.location
    assert_equal "login blocked", response.body
  end

  test "completion cooldown is not converted to a fresh sign in redirect" do
    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      raise AuthenticationBase::LoginCooldownError
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "login" },
      nil,
      Struct.new(:provider).new("google"),
      true,
    )

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "login", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(*_args, **_kwargs) { true }) do
            AuthenticationSessionCommitter.stub(:call, ->(**) { raise AuthenticationBase::LoginCooldownError }) do
              post :create, params: { id: "google", ri: "jp", social_ceremony_result: "signed-token" }
            end
          end
        end
      end
    end

    assert_response :too_many_requests
    assert_nil response.location
    assert_includes response.body, I18n.t("errors.messages.login_cooldown")
  end
end
