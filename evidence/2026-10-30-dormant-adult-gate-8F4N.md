# Dormant adult content gate

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these checks.
- Before this change the controller registry created and reconciled adult gate children, and legacy preference adoption forced an underage gate despite the accepted sign-up ADR and two.md requiring the gate to remain dormant. Removed those registry entries and the age-based writer, and excluded the gate from legacy token child rotation. Existing gate models, associations, tables and rows were retained.
- With automatic schema maintenance disabled to avoid applying the pending binding migration, the dormant-gate guard, anonymous com initialization, Web Push API and sign-up policy tests passed: 15 runs, 106 assertions. The com HTTP case verifies that a new preference does not create a gate row.
- `bundle exec rubocop app/controllers/concerns/preference_class_registry.rb app/controllers/concerns/preference_adoption.rb app/controllers/concerns/preference_sign_out_rotation.rb app/models/concerns/single_use_token.rb test/unit/security/preference_dormant_adult_gate_test.rb test/integration/anonymous_com_web_push_initialization_test.rb`: no offenses.
- The legacy app/org adoption path has not been exercised end-to-end in this check. Its consent copying behavior still differs from two.md, and the full implementation remains incomplete.
