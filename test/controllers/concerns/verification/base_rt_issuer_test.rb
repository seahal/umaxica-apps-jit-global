# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class VerificationBaseRtIssuerTest < ActiveSupport::TestCase
  Request =
    Struct.new(:parameters, :host, :fullpath, :request_id, keyword_init: true) do
      def parameters
        self[:parameters] || {}
      end
    end

  TokenStub = Struct.new(:public_id)

  module Sign
    module App
      class RtHarness
        class << self
          def before_action(*) = nil

          def helper_method(*) = nil
        end

        include CommonRedirect
        include VerificationBase

        attr_accessor :rt_param, :session_token, :request_fullpath

        def request
          Request.new(
            parameters: { "pt" => rt_param.to_s },
            host: "id.app.localhost",
            fullpath: request_fullpath || "/settings/passkeys",
            request_id: "req-1",
          )
        end

        def params
          { pt: rt_param }.with_indifferent_access
        end

        def current_session_token = session_token

        # mirrors authentication_base: returns the stable session identifier
        def current_session_public_id = session_token&.public_id.to_s

        def actor_verification_path = "/sign/app/verification"
      end
    end

    module Com
      class RtHarness < Sign::App::RtHarness
        def actor_verification_path = "/sign/com/verification"
      end
    end

    module Org
      class RtHarness < Sign::App::RtHarness
        def actor_verification_path = "/sign/org/verification"
      end
    end
  end

  module NoSurface
    class RtHarness < Sign::App::RtHarness
    end
  end

  # The cookie-backed verification record is the fallback when a step-up carries no
  # scope. It has to refuse a missing cookie and a cookie that matches no live record,
  # and it must still answer true when the freshness stamp cannot be written because
  # the request is on a reading connection.
  class VerificationRecordStub
    attr_reader :updates

    def initialize(read_only: false)
      @read_only = read_only
      @updates = []
    end

    def update!(attributes)
      raise ActiveRecord::ReadOnlyError if @read_only

      @updates << attributes
    end
  end

  def self.verification_model_stub(record, conditions_sink)
    Class.new do
      define_singleton_method(:cookie_name) { "verification_cookie" }
      define_singleton_method(:digest_token) { |raw| "digest:#{raw}" }
      define_singleton_method(:active) { self }
      define_singleton_method(:find_by) do |**conditions|
        conditions_sink << conditions
        record
      end
    end
  end

  test "verification_record_satisfied? refuses a missing cookie and an unmatched record" do
    conditions = []
    model = self.class.verification_model_stub(nil, conditions)
    h = Sign::App::RtHarness.new
    h.define_singleton_method(:verification_model) { model }
    h.define_singleton_method(:verification_token_foreign_key) { :user_token_id }
    h.define_singleton_method(:cookies) { @fake_cookies ||= {} }

    assert_not h.send(:verification_record_satisfied?, TokenStub.new("t-1"))
    assert_empty conditions, "a missing cookie must not reach the database"

    h.cookies["verification_cookie"] = "raw-token"

    assert_not h.send(:verification_record_satisfied?, Struct.new(:id).new(7))
    assert_equal({ user_token_id: 7, token_digest: "digest:raw-token" }, conditions.last)
  end

  test "verification_record_satisfied? stamps the record and tolerates a read-only connection" do
    writable = VerificationRecordStub.new
    writable_model = self.class.verification_model_stub(writable, [])
    h = Sign::App::RtHarness.new
    h.define_singleton_method(:verification_model) { writable_model }
    h.define_singleton_method(:verification_token_foreign_key) { :user_token_id }
    h.define_singleton_method(:cookies) { @fake_cookies ||= {} }
    h.cookies["verification_cookie"] = "raw-token"

    assert h.send(:verification_record_satisfied?, Struct.new(:id).new(7))
    assert_equal 1, writable.updates.size

    read_only_model = self.class.verification_model_stub(VerificationRecordStub.new(read_only: true), [])
    h.define_singleton_method(:verification_model) { read_only_model }

    assert h.send(:verification_record_satisfied?, Struct.new(:id).new(7))
  end
end
