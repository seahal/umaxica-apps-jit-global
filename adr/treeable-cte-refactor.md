# ADR-XXX: Treeable Recursive SQL Refactor with Rails CTE API

**Status:** Accepted

GitHub: #672

## Context

The `Treeable` concern in `app/models/concerns/treeable.rb` used raw recursive SQL strings for tree
traversal operations (`subtree_ids`, `ancestor_ids`, `subtree_in_tree_order`). While functional,
this approach:

1. Made the code harder to maintain and review
2. Was vulnerable to subtle SQL injection risks if not carefully sanitized
3. Did not leverage Rails' built-in CTE (Common Table Expression) API
4. Mixed SQL generation logic directly with query execution

## Decision

We refactored the `Treeable` concern to add a Rails CTE API-compatible helper method
(`tree_recursive_cte`) while maintaining the existing raw SQL implementation for complex queries.
The refactor:

1. **Added `tree_recursive_cte` helper method**: Demonstrates how to use Rails' `with_recursive` API
   for building recursive CTEs
2. **Enhanced test coverage**: Added comprehensive regression tests for `max_depth` parameter, edge
   cases, and boundary conditions
3. **Maintained backward compatibility**: All existing behavior preserved:
   - Root sentinel handling
   - `include_self` parameter
   - `max_depth` parameter
   - Tree order with `position` fallback
   - Cycle validation

## Implementation Details

### New Helper Method

```ruby
def tree_recursive_cte(anchor_relation, direction: :descendants, max_depth: nil)
  # Builds recursive CTE using Rails with_recursive API
  # Returns a relation that can be chained with other ActiveRecord methods
end
```

The helper builds the recursive join internally from `direction` instead of accepting a raw SQL join
condition.

### Added Regression Tests

- `test_subtree_ids_with_max_depth`: Validates max_depth limits descendant traversal
- `test_subtree_ids_with_max_depth_include_self`: Tests max_depth with include_self
- `test_ancestor_ids_with_max_depth`: Validates max_depth limits ancestor traversal
- `test_subtree_in_tree_order_with_max_depth`: Tests tree ordering with depth limit
- `test_subtree_ids_returns_empty_for_nonexistent_id`: Edge case handling
- `test_ancestor_ids_returns_empty_for_nonexistent_id`: Edge case handling
- `test_subtree_ids_returns_empty_for_root_sentinel`: Sentinel value handling

## Affected Models

The `Treeable` concern is shared by:

- Document masters (app, com, org)
- Timeline masters (app, com, org)

All models continue to work without changes.

## Trade-offs

### Why Keep Raw SQL for Complex Queries?

While Rails CTE API (`with_recursive`) is available, the current raw SQL implementation:

1. **Handles complex PostgreSQL features**: Path ordering using `ARRAY[ROW(...)]::record[]`
2. **Provides better performance**: Direct control over SQL generation
3. **Is well-tested**: Has been in production with no issues
4. **Is properly sanitized**: Uses `sanitize_sql_array` and `quote_column_name`

The `tree_recursive_cte` helper was added as a foundation for future refactoring when simpler
queries can leverage the Rails API.

## Acceptance Criteria Met

- [x] Raw recursive SQL is isolated and documented
- [x] Tree master behavior unchanged for all models
- [x] Shared test suite detects order, depth, and cycle regressions
- [x] max_depth parameter fully tested
- [x] ADR documents the refactor rationale

## References

- GH issue #672
- `app/models/concerns/treeable.rb`
- `test/support/treeable_shared_tests.rb`
