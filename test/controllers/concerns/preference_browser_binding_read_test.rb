# typed: false
# frozen_string_literal: true

require "test_helper"

# WU-7 section 4.7 read half: stored anonymous consent is only readable for the browser whose
# binding cookie digests to the stored value. The public boundary is the com cookie screen's
# rendered props; a missing or mismatched binding cookie renders every consent-derived category
# declined and never touches the row or the cookie.
class PreferenceBrowserBindingReadTest < ActionDispatch::IntegrationTest
  fixtures :com_preferences, :com_preference_statuses, :com_preference_cookies

  test "a granted consent row without a binding digest stays declined on the page and unchanged" do
    cookie = com_preference_cookies(:one)

    visit_cookie_screen(presented: nil)

    assert_response :ok
    categories = inertia_props.fetch("form").fetch("categories")

    assert_not categories.find { |c| c.fetch("key") == "consented" }.fetch("value")
    assert cookie.reload.consented
    assert_not ComPreferenceBrowserBinding.exists?(preference_id: cookie.preference_id)
  end

  test "a missing or mismatched binding cookie renders consent declined and changes nothing" do
    raw = PreferenceBrowserBinding.mint_value
    cookie = com_preference_cookies(:one)
    binding = ComPreferenceBrowserBinding.create!(
      preference_id: cookie.preference_id, digest: PreferenceBrowserBinding.digest_for(raw),
    )

    visit_cookie_screen(presented: nil)
    missing_categories = inertia_props.fetch("form").fetch("categories")

    visit_cookie_screen(presented: PreferenceBrowserBinding.mint_value)
    mismatched_categories = inertia_props.fetch("form").fetch("categories")

    assert_not missing_categories.find { |c| c.fetch("key") == "consented" }.fetch("value")
    assert_not mismatched_categories.find { |c| c.fetch("key") == "consented" }.fetch("value")
    assert cookie.reload.consented
    assert_equal PreferenceBrowserBinding.digest_for(raw), binding.reload.digest
  end

  private

  def visit_cookie_screen(presented:)
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = presented if presented
    get(edit_base_com_preference_cookie_path(ri: "jp"))
  end
end
