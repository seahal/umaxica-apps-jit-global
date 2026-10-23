# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_banners
# Database name: com_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_banners_on_visitor_id  (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#
require "test_helper"

class VisitorBannerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :visitor_banners, :visitors, :visitor_statuses, :visitor_visibilities, :visitor_security_modes,
           :visitor_mfa_statuses

  test "inherits from principal record" do
    assert_operator VisitorBanner, :<, ComPrincipalRecord
  end

  test "visitor is required" do
    banner = VisitorBanner.new(body: "Banner body")

    assert_not banner.valid?
    assert_includes banner.errors[:visitor], "を入力してください"
  end

  test "actor returns visitor" do
    assert_equal visitors(:reserved_visitor), visitor_banners(:current_visitor_banner).actor
  end

  test "banner concern default actor returns nil" do
    klass =
      Class.new do
        define_singleton_method(:attribute) { |*| nil }
        define_singleton_method(:validates) { |*| nil }
        define_singleton_method(:validate) { |*| nil }
        define_singleton_method(:scope) { |*| nil }

        include BannerModel
      end

    assert_nil klass.new.actor
  end

  test "default values are applied" do
    banner = VisitorBanner.create!(
      visitor: visitors(:reserved_visitor),
      body: "Default banner body",
    ).reload

    assert_not banner.published
    assert_not_nil banner.starts_at
    assert_equal 9999, banner.ends_at.year
    assert_equal "", banner.title
  end

  test "current scope orders same starts_at by id desc" do
    starts_at = Time.zone.parse("2026-03-18 00:00:00 UTC")
    older = VisitorBanner.create!(
      visitor: visitors(:reserved_visitor),
      body: "Older",
      published: true,
      starts_at: starts_at,
      ends_at: starts_at + 1.day,
    )
    newer = VisitorBanner.create!(
      visitor: visitors(:reserved_visitor),
      body: "Newer",
      published: true,
      starts_at: starts_at,
      ends_at: starts_at + 1.day,
    )

    travel_to starts_at + 1.hour do
      assert_equal [newer, older], VisitorBanner.where(id: [older.id, newer.id]).current.to_a
    end
  end

  test "database columns keep expected defaults and null constraints" do
    published_column = VisitorBanner.columns_hash["published"]
    title_column = VisitorBanner.columns_hash["title"]
    body_column = VisitorBanner.columns_hash["body"]
    starts_at_column = VisitorBanner.columns_hash["starts_at"]
    ends_at_column = VisitorBanner.columns_hash["ends_at"]
    visitor_id_column = VisitorBanner.columns_hash["visitor_id"]

    # `Column#default` carries the raw database default, so a boolean reads back as "false".
    assert_equal "false", published_column.default
    assert_equal "", title_column.default
    assert_not body_column.null
    assert_not starts_at_column.null
    assert_not ends_at_column.null
    assert_not visitor_id_column.null
  end

  test "database rejects null body when validations are bypassed" do
    banner = VisitorBanner.new(visitor: visitors(:reserved_visitor), body: nil)

    assert_raises(ActiveRecord::NotNullViolation) do
      ActiveRecord::Base.logger.silence { banner.save!(validate: false) }
    end
  end

  test "database check constraint rejects ends_at equal to starts_at when validations are bypassed" do
    banner = VisitorBanner.new(
      visitor: visitors(:reserved_visitor),
      body: "Invalid window",
      starts_at: Time.zone.parse("2026-03-18 00:00:00 UTC"),
      ends_at: Time.zone.parse("2026-03-18 00:00:00 UTC"),
    )
    exception_classes = [ActiveRecord::StatementInvalid]
    exception_classes << ActiveRecord::CheckConstraintViolation if defined?(ActiveRecord::CheckConstraintViolation)

    assert_raises(*exception_classes) do
      ActiveRecord::Base.logger.silence { banner.save!(validate: false) }
    end
  end
end
