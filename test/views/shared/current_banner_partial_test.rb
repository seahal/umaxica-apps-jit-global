# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CurrentBannerPartialTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :operator_banners, :visitor_banners, :clients, :client_statuses, :operators,
           :operator_statuses, :visitors, :visitor_statuses, :visitor_visibilities, :visitor_security_modes,
           :visitor_mfa_statuses

  test "renders the current banner for a surface" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :jp, domain: :news }

      assert_includes rendered, "Client newer banner"
      assert_includes rendered, "Client newer banner body"
    end
  end

  test "renders the current banner for sign domain with ww region" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :ww, domain: :sign }

      assert_includes rendered, "Staff current banner"
      assert_includes rendered, "Staff current banner body"
    end
  end

  test "renders the current banner for sign domain with global region (normalized to ww)" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :global, domain: :sign }

      assert_includes rendered, "Staff current banner"
      assert_includes rendered, "Staff current banner body"
    end
  end

  test "renders the current banner for help domain with jp region" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      render partial: "layouts/shared/current_banner", locals: { tld: :com, region: :jp, domain: :help }

      assert_includes rendered, "Visitor current banner"
      assert_includes rendered, "Visitor current banner body"
    end
  end

  test "raises error when mandatory arguments are missing" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app } # region and domain are missing
    end
  end

  test "raises error when invalid tld is provided" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :net, region: :jp, domain: :news }
    end
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: nil, region: :jp, domain: :news }
    end
  end

  test "raises error when invalid domain is provided" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :jp, domain: :fake }
    end
  end

  test "raises error when invalid region is provided" do
    # 'nk' or nil are always invalid
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :nk, domain: :news }
    end
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: nil, domain: :news }
    end
  end

  test "raises error when invalid region for domain is provided" do
    # For news domain, ww region is invalid (only jp, us are allowed)
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :ww, domain: :news }
    end
    # For sign domain, jp region is invalid (only global, ww are allowed)
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :jp, domain: :sign }
    end
    # ww is no longer allowed (changed to ww)
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :www, domain: :sign }
    end
  end

  test "renders nothing when the current banner is missing" do
    VisitorBanner.stub(:current, VisitorBanner.none) do
      render partial: "layouts/shared/current_banner", locals: { tld: :com, region: :jp, domain: :news }

      assert_empty rendered.strip
    end
  end
end
