# frozen_string_literal: true

require "test_helper"
require "prism"

class RootTokenCreationInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ROOT_TOKEN_WRITES = %i(create create! insert insert! insert_all insert_all!).freeze
  ROOT_TOKEN_RECEIVERS = /\A(?:ClientToken|VisitorToken|OperatorToken|token_class)\z/.freeze
  ROOT_TOKEN_ASSOCIATIONS = /\.(?:client_tokens|visitor_tokens|staff_tokens)\z/.freeze
  ROOT_TOKEN_TABLE_INSERTS = /\bINSERT\s+INTO\s+(?:client_tokens|visitor_tokens|operator_tokens)\b/i.freeze
  ISSUANCE_PATH = "app/controllers/concerns/authentication_base.rb"

  test "A44-7 root-token creation stays inside the final issuance method" do
    violations = []

    (Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")).each do |path|
      source = File.read(path)
      pending = [[Prism.parse(source).value, false]]

      until pending.empty?
        node, inside_final_issuance = pending.pop
        inside_final_issuance ||= node.is_a?(Prism::DefNode) && node.name == :create_login_token_record

        if node.is_a?(Prism::CallNode) && ROOT_TOKEN_WRITES.include?(node.name)
          receiver = node.receiver&.location&.slice.to_s
          root_token_write = ROOT_TOKEN_RECEIVERS.match?(receiver) || ROOT_TOKEN_ASSOCIATIONS.match?(receiver)
          allowed = path.relative_path_from(Rails.root).to_s == ISSUANCE_PATH && inside_final_issuance
          if root_token_write && !allowed
            violations << "#{path.relative_path_from(Rails.root)}:#{node.location.start_line}"
          end
        elsif (node.is_a?(Prism::StringNode) || node.is_a?(Prism::InterpolatedStringNode)) &&
            ROOT_TOKEN_TABLE_INSERTS.match?(node.location.slice)
          violations << "#{path.relative_path_from(Rails.root)}:#{node.location.start_line}"
        end

        node.child_nodes.compact.each { |child| pending << [child, inside_final_issuance] }
      end
    end

    assert_empty violations.uniq, "Root tokens may be created only in AuthenticationBase#create_login_token_record"
  end
end
