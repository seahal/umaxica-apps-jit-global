# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authentication
  class CurrentResourceResolverTest < ActiveSupport::TestCase
    FakeResource =
      Struct.new(:id, :admin_locked, :token_valid_after_at, keyword_init: true) do
        def admin_locked?
          admin_locked
        end

        def access_token_stale_for_administrative_lock?(payload)
          return false if token_valid_after_at.blank?

          Time.zone.at(payload["iat"].to_i) < token_valid_after_at
        end
      end

    class FakeTokenScope
      FakeToken =
        Struct.new(
          :public_id, :oidc_jti, :last_used_at, :created_at, :user_id,
          :device_session_id, :device_session, :visitor_id, :staff_id,
        ) do
          def has_attribute?(attribute)
            %i(public_id oidc_jti last_used_at created_at user_id device_session_id visitor_id staff_id)
              .include?(attribute.to_sym)
          end

          # Records the throttled activity write so tests can assert when a
          # per-request last_used_at touch did (or did not) happen.
          def update_columns(attrs)
            FakeTokenScope.touches << attrs
            attrs.each { |key, value| self[key] = value }
            true
          end
        end

      class << self
        attr_accessor :token_oidc_jti, :token_last_used_at, :token_created_at,
                      :token_user_id, :token_device_session_id, :token_device_session,
                      :token_visitor_id, :token_staff_id # rubocop:disable ThreadSafety/ClassAndModuleAttributes

        def touches
          @touches ||= []
        end

        def reset_touches!
          @touches = []
        end
      end

      def where(*)
        self
      end

      def includes(*)
        self
      end

      def or(_other)
        self
      end

      def exists?
        true
      end

      def first
        FakeToken.new(
          "token_public_id", self.class.token_oidc_jti,
          self.class.token_last_used_at, self.class.token_created_at,
          self.class.token_user_id || 123, self.class.token_device_session_id,
          self.class.token_device_session, self.class.token_visitor_id || 123,
          self.class.token_staff_id || 123,
        )
      end
    end

    class FakeTokenClass
      # The resolver reads only ACTIVE sessions (TokenStatusManagement.active_status).
      def self.active_status
        FakeTokenScope.new
      end

      def self.where(*)
        FakeTokenScope.new
      end

      def self.column_names
        %w(id public_id discard_at oidc_sid)
      end

      def self.arel_table
        Arel::Table.new("tokens")
      end
    end

    class FakeResourceClass
      class << self
        def resource
          @resource
        end

        def resource=(value)
          @resource = value
        end
      end

      def self.find_by(id:)
        return resource || FakeResource.new(id: id) if id == 123

        nil
      end
    end

    test "returns failure when access token is blank" do
      result = AuthenticationCurrentResourceResolver.new(
        access_token: nil,
        request_host: "app.localhost",
        resource_type: "client",
        resource_class: FakeResourceClass,
        token_class: FakeTokenClass,
      ).call

      assert_equal :blank_access_token, result.failure_reason
      assert_nil result.resource
    end

    test "returns resource and session id when token is valid" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          connection_calls = []
          OrgTicketRecord.stub(:connected_to, ->(**options, &block) { connection_calls << options; block.call }) do
            result = AuthenticationCurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.localhost",
              resource_type: "client",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_nil result.failure_reason
            assert_equal "token_public_id", result.session_public_id
            assert_equal "token_public_id", result.token_public_id
            assert_equal 123, result.resource.id
            assert connection_calls.any? { |opts| opts[:role] == :writing }
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
    end

    test "returns token_jti_mismatch when access token jti is stale" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "stale-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = AuthenticationCurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.localhost",
              resource_type: "client",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_equal :token_jti_mismatch, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
    end

    test "returns administrative_access_locked when resource is admin locked" do
      payload = {
        "sub" => "123",
        "sid" => "sess_1",
        "scope" => "domain:client",
        "jti" => "current-jti",
        "iat" => Time.current.to_i,
      }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeResourceClass.resource = FakeResource.new(id: 123, admin_locked: true)

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :administrative_access_locked, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeResourceClass.resource = nil
    end

    test "returns administrative_access_token_stale when token predates access state change" do
      payload = {
        "sub" => "123",
        "sid" => "sess_1",
        "scope" => "domain:client",
        "jti" => "current-jti",
        "iat" => 10.minutes.ago.to_i,
      }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeResourceClass.resource = FakeResource.new(
        id: 123,
        admin_locked: false,
        token_valid_after_at: 1.minute.ago,
      )

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :administrative_access_token_stale, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeResourceClass.resource = nil
    end

    test "returns actor_mismatch failure when actor claim differs" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:operator" }

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, false) do
          result = AuthenticationCurrentResourceResolver.new(
            access_token: "token",
            request_host: "app.localhost",
            resource_type: "client",
            resource_class: FakeResourceClass,
            token_class: FakeTokenClass,
          ).call

          assert_equal :actor_mismatch, result.failure_reason
          assert_equal payload, result.payload
        end
      end
    end

    test "rejects an existing token whose actor differs from the access token subject" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_user_id = 999

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :actor_mismatch, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_user_id = nil
    end

    test "rejects visitor and operator tokens whose actor differs from the access token subject" do
      FakeTokenScope.token_oidc_jti = "current-jti"

      { "visitor" => :token_visitor_id, "operator" => :token_staff_id }.each do |surface, actor_slot|
        payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:#{surface}", "jti" => "current-jti" }
        FakeTokenScope.public_send("#{actor_slot}=", 999)

        AuthenticationToken.stub(:decode, payload) do
          AuthenticationToken.stub(:resource_type_scope_matches?, true) do
            OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
              result = AuthenticationCurrentResourceResolver.new(
                access_token: "token",
                request_host: "#{surface}.localhost",
                resource_type: surface,
                resource_class: FakeResourceClass,
                token_class: FakeTokenClass,
              ).call

              assert_equal :actor_mismatch, result.failure_reason
              assert_nil result.resource
            end
          end
        end
        FakeTokenScope.public_send("#{actor_slot}=", nil)
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_visitor_id = nil
      FakeTokenScope.token_staff_id = nil
    end

    test "rejects a bound token when its device session is missing" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_device_session_id = 42

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :token_session_not_found, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_device_session_id = nil
    end

    test "rejects a bound token when its device session belongs to another actor" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_device_session_id = 42
      FakeTokenScope.token_device_session = Struct.new(:user_id, :public_id, :dpop_jkt, :status_id, :revoked_at)
        .new(999, "session_1", nil, DeviceSessionable::STATUS_ACTIVE, nil)

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :actor_mismatch, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_device_session_id = nil
      FakeTokenScope.token_device_session = nil
    end

    test "accepts a bound token when its device session belongs to the same actor" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_device_session_id = 42
      FakeTokenScope.token_device_session = Struct.new(:user_id, :public_id, :dpop_jkt, :status_id, :revoked_at)
        .new(123, "session_1", nil, DeviceSessionable::STATUS_ACTIVE, nil)

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_nil result.failure_reason
            assert_equal 123, result.resource.id
            assert_equal "session_1", result.session_public_id
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_device_session_id = nil
      FakeTokenScope.token_device_session = nil
    end

    test "rejects a bound token when its device session is revoked by time or status" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_device_session_id = 42
      session_class = Struct.new(:user_id, :public_id, :dpop_jkt, :status_id, :revoked_at)

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            [
              session_class.new(123, "session_1", nil, DeviceSessionable::STATUS_REVOKED, nil),
              session_class.new(123, "session_1", nil, DeviceSessionable::STATUS_ACTIVE, Time.current),
            ].each do |session|
              FakeTokenScope.token_device_session = session
              result = resolve_client_resource

              assert_equal :token_session_not_found, result.failure_reason
              assert_nil result.resource
            end
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_device_session_id = nil
      FakeTokenScope.token_device_session = nil
    end

    test "returns idle_timeout when the session has been inactive beyond the window" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"
      FakeTokenScope.token_last_used_at = 9.hours.ago # client idle window is 8h

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = resolve_client_resource

            assert_equal :idle_timeout, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_last_used_at = nil
    end

    test "writes last_used_at only when activity is past the throttle window" do
      payload = { "sub" => "123", "sid" => "sess_1", "scope" => "domain:client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"

      AuthenticationToken.stub(:decode, payload) do
        AuthenticationToken.stub(:resource_type_scope_matches?, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            # Within the throttle window: no activity write.
            FakeTokenScope.token_last_used_at = 10.seconds.ago
            FakeTokenScope.reset_touches!
            resolve_client_resource

            assert_empty FakeTokenScope.touches

            # Past the throttle window (still within the idle window): one write.
            FakeTokenScope.token_last_used_at = 5.minutes.ago
            FakeTokenScope.reset_touches!
            result = resolve_client_resource

            assert_equal 123, result.resource.id
            assert_equal 1, FakeTokenScope.touches.size
            assert FakeTokenScope.touches.first.key?(:last_used_at)
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
      FakeTokenScope.token_last_used_at = nil
    end

    private

    def resolve_client_resource
      AuthenticationCurrentResourceResolver.new(
        access_token: "token",
        request_host: "app.localhost",
        resource_type: "client",
        resource_class: FakeResourceClass,
        token_class: FakeTokenClass,
      ).call
    end
  end
end
