# Testing Patterns

## Contents

- Test state, not interactions
- DAMP over DRY in tests
- Prefer real implementations over mocks
- Arrange-Act-Assert
- One assertion per concept
- Naming tests
- Anti-patterns

## Test state, not interactions

Assert on the outcome of an operation, not on which methods were called internally. Tests that
verify call sequences break during refactoring even when behavior is unchanged.

```typescript
// Good: tests what the function does (state-based)
it("returns tasks sorted by creation date, newest first", async () => {
  const tasks = await listTasks({ sortBy: "createdAt", sortOrder: "desc" });
  expect(tasks[0].createdAt.getTime()).toBeGreaterThan(tasks[1].createdAt.getTime());
});

// Bad: tests how the function works internally (interaction-based)
it("calls db.query with ORDER BY created_at DESC", async () => {
  await listTasks({ sortBy: "createdAt", sortOrder: "desc" });
  expect(db.query).toHaveBeenCalledWith(expect.stringContaining("ORDER BY created_at DESC"));
});
```

## DAMP over DRY in tests

In production code, DRY is usually right. In tests, DAMP — Descriptive And Meaningful Phrases — is
better. A test should read like a specification and tell a complete story without the reader tracing
through shared helpers.

```typescript
it("rejects tasks with empty titles", () => {
  const input = { title: "", assignee: "user-1" };
  expect(() => createTask(input)).toThrow("Title is required");
});

it("trims whitespace from titles", () => {
  const input = { title: "  Buy groceries  ", assignee: "user-1" };
  const task = createTask(input);
  expect(task.title).toBe("Buy groceries");
});
```

Duplication in tests is acceptable when it makes each test independently understandable.

## Prefer real implementations over mocks

Use the simplest test double that does the job. The more real code a test exercises, the more
confidence it provides.

```
Preference order (most to least preferred):
1. Real implementation  → highest confidence, catches real bugs
2. Fake                 → in-memory version of a dependency (e.g. fake DB)
3. Stub                 → returns canned data, no behavior
4. Mock (interaction)   → verifies method calls; use sparingly
```

Use mocks only where the real implementation is too slow, non-deterministic, or has side effects
that cannot be controlled — external APIs, email sending. Over-mocking produces tests that pass
while production breaks.

## Arrange-Act-Assert

```typescript
it("marks overdue tasks when deadline has passed", () => {
  // Arrange
  const task = createTask({ title: "Test", deadline: new Date("2025-01-01") });

  // Act
  const result = checkOverdue(task, new Date("2025-01-02"));

  // Assert
  expect(result.isOverdue).toBe(true);
});
```

## One assertion per concept

```typescript
// Good: each test verifies one behavior
it('rejects empty titles', () => { ... });
it('trims whitespace from titles', () => { ... });
it('enforces maximum title length', () => { ... });

// Bad: everything in one test
it('validates titles correctly', () => {
  expect(() => createTask({ title: '' })).toThrow();
  expect(createTask({ title: '  hello  ' }).title).toBe('hello');
  expect(() => createTask({ title: 'a'.repeat(256) })).toThrow();
});
```

## Naming tests

```typescript
// Good: reads like a specification
describe('TaskService.completeTask', () => {
  it('sets status to completed and records timestamp', ...);
  it('throws NotFoundError for non-existent task', ...);
  it('is idempotent — completing an already-completed task is a no-op', ...);
  it('sends notification to task assignee', ...);
});

// Bad: vague names
describe('TaskService', () => {
  it('works', ...);
  it('handles errors', ...);
  it('test 3', ...);
});
```

## Anti-patterns

| Anti-pattern                          | Problem                                                 | Fix                                                                     |
| ------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------- |
| Testing implementation details        | Tests break on refactor even when behavior is unchanged | Test inputs and outputs, not internal structure                         |
| Flaky tests (timing, order-dependent) | Erode trust in the whole suite                          | Deterministic assertions, isolated test state                           |
| Testing framework code                | Spends effort on third-party behavior                   | Test only project code                                                  |
| Snapshot abuse                        | Large snapshots nobody reviews, break on any change     | Use sparingly and review every change                                   |
| No test isolation                     | Tests pass individually but fail together               | Each test sets up and tears down its own state                          |
| Mocking everything                    | Tests pass while production breaks                      | Real > fake > stub > mock; mock only at slow or non-deterministic edges |
