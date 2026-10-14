# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: departments
# Database name: org_principal
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  department_status_id :bigint           default(0), not null
#  parent_id            :bigint
#  workspace_id         :bigint
#
# Indexes
#
#  index_departments_on_department_status_id_and_parent_id  (department_status_id,parent_id) UNIQUE
#  index_departments_on_parent_id                           (parent_id)
#  index_departments_on_workspace_id                        (workspace_id)
#
# Foreign Keys
#
#  fk_departments_on_department_status_id  (department_status_id => department_statuses.id)
#  fk_rails_...                            (parent_id => departments.id)
#  fk_rails_...                            (workspace_id => organizations.id) ON DELETE => nullify
#


require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  fixtures :organizations, :organization_statuses, :department_statuses

  setup do
    I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
    @workspace = organizations(:one)
  end

  test "should be valid" do
    department = Department.new(
      name: "Test Dept",
      department_status_id: DepartmentStatus::NOTHING,
      workspace: @workspace,
    )

    assert_predicate department, :valid?, department.errors.full_messages.to_sentence
  end

  test "requires name" do
    department = Department.new(department_status_id: DepartmentStatus::NOTHING)

    assert_not department.valid?
    assert_includes department.errors[:name], "を入力してください"
  end

  test "links parent and children" do
    parent = Department.create!(
      name: "Parent Dept",
      department_status_id: DepartmentStatus::ACTIVE,
      workspace: @workspace,
    )
    child = Department.create!(
      name: "Child Dept",
      department_status_id: DepartmentStatus::NOTHING,
      workspace: @workspace,
      parent: parent,
    )

    assert_equal parent, child.parent
    assert_includes parent.children, child
  end

  test "validates status uniqueness within the same parent" do
    validator = Department.validators_on(:department_status_id).grep(ActiveRecord::Validations::UniquenessValidator).first

    assert_equal :parent_id, validator.options[:scope]
  end
end
