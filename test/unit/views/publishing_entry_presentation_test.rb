# frozen_string_literal: true

require "test_helper"

class PublishingEntryPresentationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "publishing field labels and server errors describe the existing submitted controls" do
    html = Edit::Org::Publishing::Info::Org::EntriesController.renderer.render(
      template: "edit/org/publishing/entries/new",
      layout: false,
      locals: {
        title: "Create entry",
        description: "Test editorial form",
        index_href: "/entries",
        locales: ["en", "ja"],
        errors: { "title" => "Enter a title." },
        form: { action: "/entries",
                method: :post,
                locale: "en",
                slug: "example",
                title: "",
                summary: "",
                body: "{}", },
      },
    )
    document = Nokogiri::HTML.fragment(html)
    form = document.at_css("form")

    assert_equal "/entries", form["action"]
    assert_equal "post", form["method"]
    assert_equal "en", form.at_css('[name="entry[locale]"] option[selected]')["value"]
    assert_equal "example", form.at_css('[name="entry[slug]"]')["value"]
    assert_equal "off", form.at_css('[name="entry[title]"]')["autocomplete"]
    %w(locale slug title summary body).each do |field|
      control = document.at_css("[name='entry[#{field}]']")

      assert document.at_css("label[for='#{control["id"]}']"), "#{field} has an explicit label"
    end
    title = form.at_css('[name="entry[title]"]')

    assert_equal "true", title["aria-invalid"]
    error = document.at_css("##{title["aria-describedby"]}")

    assert_equal "Enter a title.", error.text
    assert_nil error["role"]
    assert_nil error["aria-live"]
    assert_nil title["required"]
  end

  test "a publishing form with no server errors retains empty values without error relationships" do
    html = Edit::Org::Publishing::Info::Org::EntriesController.renderer.render(
      template: "edit/org/publishing/entries/new",
      layout: false,
      locals: {
        title: "Create entry",
        description: "Test editorial form",
        index_href: "/entries",
        locales: ["en"],
        errors: {},
        form: { action: "/entries",
                method: :post,
                locale: "en",
                slug: "",
                title: "",
                summary: "",
                body: "", },
      },
    )
    document = Nokogiri::HTML.fragment(html)
    title = document.at_css('[name="entry[title]"]')

    assert_equal "", title["value"]
    assert_equal "false", title["aria-invalid"]
    assert_nil title["aria-describedby"]
    assert_empty document.css(".text-error")
    assert_equal "Create entry", document.at_css('input[type="submit"]')["value"]
  end
  test "publishing identity conditions precede and describe locale and slug without changing payload fields" do
    html = Edit::Org::Publishing::Info::Org::EntriesController.renderer.render(
      template: "edit/org/publishing/entries/new", layout: false,
      locals: { title: "Create entry",
                description: "Editorial form",
                index_href: "/entries",
                locales: ["en", "ja"],
                errors: { "summary" => "Check the summary." },
                form: { action: "/entries",
                        method: :post,
                        locale: "en",
                        slug: "slug",
                        title: "Title",
                        summary: "Summary",
                        body: "{}", }, },
    )
    document = Nokogiri::HTML.fragment(html)
    %w(locale slug).each do |field|
      control = document.at_css("[name='entry[#{field}]']")

      assert_not_nil control["aria-describedby"]
      hint = document.at_css("##{control["aria-describedby"]}")

      assert_includes hint.text, "fixed when the entry is created"
      assert_operator html.index(hint["id"]), :<, html.index("name=\"entry[#{field}]\"")
    end
    summary = document.at_css('[name="entry[summary]"]')

    assert_equal "Summary", summary.text.delete_prefix("\n")
    assert_equal "true", summary["aria-invalid"]
    assert_equal "Check the summary.", document.at_css("##{summary["aria-describedby"]}").text
  end

  test "publishing revisions retain PATCH spoofing and the lock version when displaying field conditions" do
    html = Edit::Org::Publishing::Info::Org::EntriesController.renderer.render(
      template: "edit/org/publishing/entries/edit", layout: false,
      locals: { title: "Edit entry",
                description: "Editorial form",
                show_href: "/entries/one",
                index_href: "/entries",
                errors: { "body" => "Check the JSON." },
                form: { action: "/entries/one",
                        method: :patch,
                        lock_version: 7,
                        locale: "en",
                        canonical_slug: "slug",
                        title: "Title",
                        summary: "Summary",
                        body: "{}", }, },
    )
    document = Nokogiri::HTML.fragment(html)
    form = document.at_css("form")

    assert_equal "/entries/one", form["action"]
    assert_equal "post", form["method"]
    assert_equal "patch", form.at_css('[name="_method"]')["value"]
    assert_equal "7", form.at_css('[name="entry[lock_version]"]')["value"]
    body = form.at_css('[name="entry[body]"]')
    ids = body["aria-describedby"].split

    assert_equal 2, ids.size
    assert_includes document.at_css("##{ids.first}").text, "JSON"
    assert_equal "Check the JSON.", document.at_css("##{ids.last}").text
    assert_equal "{}", body.text.delete_prefix("\n")
    assert_nil body["required"]
    assert_nil body["maxlength"]
  end
end
