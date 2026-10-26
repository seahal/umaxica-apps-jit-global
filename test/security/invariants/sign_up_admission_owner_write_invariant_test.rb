# frozen_string_literal: true

require "test_helper"
require "prism"

class SignUpAdmissionOwnerWriteInvariantTest < ActiveSupport::TestCase
  test "bulk writes and SQL cannot reassign an existing sign-up Admission owner" do
    offenders = []
    (Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")).each do |path|
      source = File.read(path)
      next unless source.include?("auth_admission_binding_id")

      pending = [Prism.parse(source).value]
      until pending.empty?
        node = pending.pop
        pending.concat(node.child_nodes.compact)
        bulk_assignment = node.is_a?(Prism::CallNode) &&
          %i(update_all update_columns update_column).include?(node.name) &&
          node.arguments&.location&.slice&.include?("auth_admission_binding_id")
        sql_assignment = (node.is_a?(Prism::StringNode) || node.is_a?(Prism::InterpolatedStringNode)) &&
          /\bUPDATE\b.*?\bSET\b.*?\bauth_admission_binding_id\b/im.match?(node.location.slice)
        next unless bulk_assignment || sql_assignment

        offenders << "#{path.relative_path_from(Rails.root)}:#{node.location.start_line}"
      end
    end

    assert_empty offenders.uniq,
                 "sign-up Admission ownership escaped immutable construction: #{offenders.uniq.join(", ")}"
  end
end
