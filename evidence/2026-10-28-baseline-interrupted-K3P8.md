# Interrupted baseline test preparation

- Baseline checkout: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`; main checkout HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The main worktree contained unrelated untracked files.
- The isolated baseline checkout used existing workspace bundle, fork dependencies, and node_modules. Running `BUNDLE_PATH=/home/global/workspace/vendor/bundle bin/rails test` reached `db:test:prepare` and began migrations against the configured test database server. The process was interrupted when this was observed, before a test result was obtained.
- Test database schemas may have been modified by the interrupted preparation. The exact completed migrations and the prior state have not been determined. No restoration was attempted; the test databases must be inspected before relying on them.
