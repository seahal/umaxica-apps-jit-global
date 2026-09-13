# frozen_string_literal: true

require "test_helper"

class EditOrgPublishingManagementRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOST = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
  PUBLIC_ID = "abcdefghijklmnopqrstu"

  CELLS = %w(info docs news help).product(%w(app com org)).freeze

  test "all twelve cells expose the entry pages on public_id" do
    CELLS.each do |surface, audience|
      controller = "edit/org/publishing/#{surface}/#{audience}/entries"

      index = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries",
        method: :get,
      )
      new_entry = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/new",
        method: :get,
      )
      create = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries",
        method: :post,
      )
      show = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
        method: :get,
      )
      edit = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/edit",
        method: :get,
      )
      update = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
        method: :patch,
      )

      assert_equal controller, index.fetch(:controller), "#{surface}/#{audience} index"
      assert_equal "index", index.fetch(:action)
      assert_equal controller, new_entry.fetch(:controller), "#{surface}/#{audience} new"
      assert_equal "new", new_entry.fetch(:action)
      assert_equal controller, create.fetch(:controller), "#{surface}/#{audience} create"
      assert_equal "create", create.fetch(:action)
      assert_equal controller, show.fetch(:controller), "#{surface}/#{audience} show"
      assert_equal "show", show.fetch(:action)
      assert_equal PUBLIC_ID, show.fetch(:id)
      assert_equal controller, edit.fetch(:controller), "#{surface}/#{audience} edit"
      assert_equal "edit", edit.fetch(:action)
      assert_equal PUBLIC_ID, edit.fetch(:id)
      assert_equal controller, update.fetch(:controller), "#{surface}/#{audience} update"
      assert_equal "update", update.fetch(:action)
      assert_equal PUBLIC_ID, update.fetch(:id)
    end
  end

  test "publication windows are a nested resource of the entry in every cell" do
    CELLS.each do |surface, audience|
      controller = "edit/org/publishing/#{surface}/#{audience}/entries/publications"

      create = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/publications",
        method: :post,
      )
      destroy = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/publications/vwxyzabcdefghijklmnop",
        method: :delete,
      )

      assert_equal controller, create.fetch(:controller), "#{surface}/#{audience} publication create"
      assert_equal "create", create.fetch(:action)
      assert_equal PUBLIC_ID, create.fetch(:entry_id)
      assert_equal controller, destroy.fetch(:controller), "#{surface}/#{audience} publication destroy"
      assert_equal "destroy", destroy.fetch(:action)
      assert_equal PUBLIC_ID, destroy.fetch(:entry_id)
      assert_equal "vwxyzabcdefghijklmnop", destroy.fetch(:id)
    end
  end

  test "the archive state is a singular nested resource of the entry in every cell" do
    CELLS.each do |surface, audience|
      controller = "edit/org/publishing/#{surface}/#{audience}/entries/archives"

      create = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/archive",
        method: :post,
      )
      destroy = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/archive",
        method: :delete,
      )

      assert_equal controller, create.fetch(:controller), "#{surface}/#{audience} archive create"
      assert_equal "create", create.fetch(:action)
      assert_equal PUBLIC_ID, create.fetch(:entry_id)
      assert_equal controller, destroy.fetch(:controller), "#{surface}/#{audience} archive destroy"
      assert_equal "destroy", destroy.fetch(:action)
      assert_equal PUBLIC_ID, destroy.fetch(:entry_id)
    end
  end

  # An entry is never deleted: every association off it is
  # `dependent: :restrict_with_exception`, and its revisions, versions, and
  # publications are the record of what was published. Archiving is the
  # removal this schema has.
  test "publishing management routes do not expose entry destroy" do
    CELLS.each do |surface, audience|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
          method: :delete,
        )
      end
    end
  end

  test "named helpers use params id as the public identifier" do
    path = Rails.application.routes.url_helpers.edit_org_publishing_docs_app_entry_path(PUBLIC_ID)

    assert_equal "/publishing/docs/app/entries/#{PUBLIC_ID}", path
    assert_not_includes path, "/1"
  end

  test "the edit Publishing routes do not recognize on the Base staff host" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")}/publishing/docs/app/entries",
        method: :get,
      )
    end
  end
end
