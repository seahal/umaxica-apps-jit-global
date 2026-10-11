# typed: false
# frozen_string_literal: true

require "test_helper"

# Bootstrapping an actor's selector binds an avatar to whichever account kind the
# surface uses. Each kind has its own binding table and subject type; an account
# class the authority does not serve must be refused by name rather than binding
# to nothing.
class BaseSelectorBootstrapAuthorityDispatchTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @authority = BaseSelectorBootstrapAuthority.new(surface: :app, principal: clients(:one))
  end

  test "each account kind names its own subject type" do
    assert_equal :persona, @authority.send(:subject_type_for, ClientPersona.new)
    assert_equal :agent, @authority.send(:subject_type_for, Agent.new)
    assert_equal :individual, @authority.send(:subject_type_for, Individual.new)
  end

  test "an account kind the authority does not serve is refused by name" do
    %i(subject_type_for bind_avatar_account!).each do |seam|
      error =
        assert_raises(ArgumentError, seam.to_s) do
          if seam == :subject_type_for
            @authority.send(seam, clients(:one))
          else
            @authority.send(seam, avatar: nil, account: clients(:one))
          end
        end

      assert_match(/Client/, error.message, seam.to_s)
    end
  end

  test "create_unique answers the existing record when a concurrent insert wins the race" do
    existing = Object.new
    klass =
      Class.new do
        define_singleton_method(:find_or_create_by!) { |*| raise(ActiveRecord::RecordNotUnique, "duplicate key") }
        define_singleton_method(:find_by) { |*| existing }
      end

    assert_equal existing, @authority.send(:create_unique, klass, { handle: "h" })
  end

  test "create_unique re-raises when the record cannot be found after the race" do
    klass =
      Class.new do
        class << self
          def find_or_create_by!(*) = raise(ActiveRecord::RecordNotUnique, "duplicate key")

          def find_by(*) = nil
        end
      end

    assert_raises(ActiveRecord::RecordNotUnique) { @authority.send(:create_unique, klass, { handle: "h" }) }
  end
end
