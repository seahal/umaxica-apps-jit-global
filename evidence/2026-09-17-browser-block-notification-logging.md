# Browser block notification logging

Added `app/subscribers/browser_block_notification_subscriber.rb` and
`config/initializers/browser_block_notifications.rb` to log Rails' `browser_block.action_controller`
notification (fired by `allow_browser versions: :modern`) as a structured `security.browser_block.blocked`
event, following the existing `CsrfNotificationSubscriber` pattern. Logs the parsed browser name and
version (via the `useragent` gem, same approach `allow_browser` itself uses) instead of the raw
User-Agent string, plus controller, action, host, and path.

## Verification

- `scripts/test-isolated bin/rails test test/subscribers/browser_block_notification_subscriber_test.rb test/subscribers/csrf_notification_subscriber_test.rb`
  → 8 runs, 19 assertions, 0 failures, 0 errors.
- `bundle exec rubocop app/subscribers/browser_block_notification_subscriber.rb config/initializers/browser_block_notifications.rb test/subscribers/browser_block_notification_subscriber_test.rb`
  → no offenses.
- `scripts/test-isolated bin/rails test test/subscribers/` also run; the 12 pre-existing failures are
  all in `jwt_anomaly_subscriber_test.rb` (fixture/schema-cache errors unrelated to these changes,
  present before this work) — not caused by this change.
- Ran pending test-database migrations (`bin/rails db:migrate` via `scripts/test-isolated`) that were
  required just to boot the test suite; unrelated to this change but necessary environment setup,
  recorded here per the environment-construction rule.
