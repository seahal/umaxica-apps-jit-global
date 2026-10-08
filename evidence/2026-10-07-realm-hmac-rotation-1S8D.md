# Scoped HMAC rotation

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted changes affected verification.

The new rotation API's RED run contained 9 tests, 19 assertions, 1 failure and 6 errors: construction
without scope selected every model, while valid realm/channel keywords were unsupported.
After mandatory explicit scope and finite target selection, the command
`bin/rails test test/services/realm_identifier_hmac_rotation_test.rb test/services/identifier_hmac_emergency_rotation_test.rb`
passed 10 tests, 142 assertions, no failures/errors/skips. Every domain is tested separately;
unselected record attributes and result counts remain unchanged. The existing all-domain coverage
now invokes six explicit operations rather than an implicit global default.

No operational maintenance freeze or production secret rotation was performed. Those remain required
before a real emergency operation. These checks use local test records and non-secret local keys.
