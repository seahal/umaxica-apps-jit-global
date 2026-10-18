# Test Repair Batch 1

Date: 2026-06-19

## Cluster

- `sign/app` telephone signup param-key mismatch between the `ClientTelephone` form and the
  controller

## Evidence

- `app/views/sign/app/sign/up/telephones/new.html.erb` and `edit.html.erb` use
  `form_with model: @user_telephone`, which emits `client_telephone[...]` params.
- `app/controllers/sign/app/sign/up/telephones_controller.rb` now reads `client_telephone` for both
  create and OTP submit flows, with `user_telephone` retained as a compatibility fallback.
- The error summary text in the `app` telephone views still said `sample`; it now says `telephone`.

## Files Changed

- `app/controllers/sign/app/sign/up/telephones_controller.rb`
- `app/views/sign/app/sign/up/telephones/new.html.erb`
- `app/views/sign/app/sign/up/telephones/edit.html.erb`
- `test/controllers/sign/app/up/telephones_controller_test.rb`

## Verification

- `ruby -c app/controllers/sign/app/sign/up/telephones_controller.rb`
- `ruby -c test/controllers/sign/app/up/telephones_controller_test.rb`
- `bin/rails test test/controllers/sign/app/up/telephones_controller_test.rb` could not run because
  the local test database `test_com_principal_db` is missing.

## Result

- Fixed
