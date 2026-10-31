# Historical A19-3: region and language on the Base COM entry

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including Base COM and its integration tests; the result applies to that worktree.

The anonymous Base COM entry now has a request test using separate browser sessions for `ri=jp` and `ri=us` in each of English and Japanese. The test compares the rendered description and preference-link label across regions and confirms the description matches the requested locale. The focused final run passed: `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/com/roots_controller_test.rb -n '/region_does_not_change/'` returned 1 run, 8 assertions. Before the final locale assertion, the complete file passed 8 runs, 35 assertions.

This checks one page and two copy fields, not every page or deployed translation bundle. A19-3 remains a focused local disposition.
