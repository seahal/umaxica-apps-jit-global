# Required Associations That the Parent Nullifies on Delete

Recorded 2026-10-20. Status: backlog, design decision required.

## Problem

These models require their parent on every save (required `belongs_to`), but deleting the parent
sets the column to NULL:

| Model                      | Column          | Parent side                                                                                   |
| -------------------------- | --------------- | --------------------------------------------------------------------------------------------- |
| `ClientProfile`            | `user_id`       | `fk_client_profiles_on_user_id ON DELETE SET NULL`                                            |
| `Member`                   | `user_id`       | `Client has_many :owned_members, dependent: :nullify`                                         |
| `OperatorWorkspaceAccount` | `department_id` | `Department has_many :operator_workspace_accounts, dependent: :nullify`, `ON DELETE SET NULL` |

`database_consistency` reports each as
`ColumnPresenceChecker ... association foreign key column should be NOT NULL`. Making the columns
NOT NULL would make deleting the parent fail, so the 2026-10-20 NOT NULL migrations left them out,
and `test/models/required_attribute_not_null_contract_test.rb` lists them in
`NULLIFIED_ON_PARENT_DELETE`.

## Decision needed

Per row, choose one:

- The child cannot exist without the parent: delete the child with the parent (`ON DELETE CASCADE`
  and `dependent: :delete_all` or `:destroy`), then make the column NOT NULL.
- The child outlives the parent: make the association optional and keep the column nullable.

Record the choice for each row, remove that row from `NULLIFIED_ON_PARENT_DELETE`, and keep audit
and retention rules in mind for `Member`.
