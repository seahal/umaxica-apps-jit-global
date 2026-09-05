# frozen_string_literal: true

require "minitest/autorun"

# Pins the 3 x 4 content matrix document so the twelve cells stay explicit.
class ContentSurfaceMatrixDocTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)
  DOC = File.join(REPOSITORY_ROOT, "docs/architecture/content-surface-matrix.md")

  CELLS = [
    "app × info",
    "com × info",
    "org × info",
    "app × docs",
    "com × docs",
    "org × docs",
    "app × news",
    "com × news",
    "org × news",
    "app × help",
    "com × help",
    "org × help",
  ].freeze

  def test_matrix_document_lists_every_cell_and_does_not_claim_edge_cms_is_deployed
    assert File.file?(DOC), "expected #{DOC}"

    body = File.read(DOC)

    CELLS.each do |cell|
      assert_includes body, "### #{cell}", "missing cell heading #{cell}"
    end

    assert_includes body, "Edge does not consume it yet"
  end
end
