# frozen_string_literal: true

module Publishing
  # Explicit roster of the twelve physical content cells. Request paths must
  # still name a concrete ENTRY_CLASS; this list is for seeds, architecture
  # tests, and fixtures that already know the cell.
  module ContentFamilies
    ENTRY_CLASSES = [
      Publishing::Info::App::Entry,
      Publishing::Info::Com::Entry,
      Publishing::Info::Org::Entry,
      Publishing::Docs::App::Entry,
      Publishing::Docs::Com::Entry,
      Publishing::Docs::Org::Entry,
      Publishing::News::App::Entry,
      Publishing::News::Com::Entry,
      Publishing::News::Org::Entry,
      Publishing::Help::App::Entry,
      Publishing::Help::Com::Entry,
      Publishing::Help::Org::Entry,
    ].freeze

    CELL_BY_ENTRY = {
      Publishing::Info::App::Entry => {
        entry: Publishing::Info::App::Entry,
        revision: Publishing::Info::App::EntryRevision,
        version: Publishing::Info::App::EntryVersion,
        vocabulary: Publishing::Info::App::Vocabulary,
        taxonomy_term: Publishing::Info::App::TaxonomyTerm,
        revision_single: Publishing::Info::App::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Info::App::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Info::App::RevisionMediaUsage,
        version_single: Publishing::Info::App::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Info::App::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Info::App::VersionMediaUsage,
      }.freeze,
      Publishing::Info::Com::Entry => {
        entry: Publishing::Info::Com::Entry,
        revision: Publishing::Info::Com::EntryRevision,
        version: Publishing::Info::Com::EntryVersion,
        vocabulary: Publishing::Info::Com::Vocabulary,
        taxonomy_term: Publishing::Info::Com::TaxonomyTerm,
        revision_single: Publishing::Info::Com::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Info::Com::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Info::Com::RevisionMediaUsage,
        version_single: Publishing::Info::Com::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Info::Com::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Info::Com::VersionMediaUsage,
      }.freeze,
      Publishing::Info::Org::Entry => {
        entry: Publishing::Info::Org::Entry,
        revision: Publishing::Info::Org::EntryRevision,
        version: Publishing::Info::Org::EntryVersion,
        vocabulary: Publishing::Info::Org::Vocabulary,
        taxonomy_term: Publishing::Info::Org::TaxonomyTerm,
        revision_single: Publishing::Info::Org::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Info::Org::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Info::Org::RevisionMediaUsage,
        version_single: Publishing::Info::Org::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Info::Org::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Info::Org::VersionMediaUsage,
      }.freeze,
      Publishing::Docs::App::Entry => {
        entry: Publishing::Docs::App::Entry,
        revision: Publishing::Docs::App::EntryRevision,
        version: Publishing::Docs::App::EntryVersion,
        vocabulary: Publishing::Docs::App::Vocabulary,
        taxonomy_term: Publishing::Docs::App::TaxonomyTerm,
        revision_single: Publishing::Docs::App::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Docs::App::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Docs::App::RevisionMediaUsage,
        version_single: Publishing::Docs::App::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Docs::App::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Docs::App::VersionMediaUsage,
      }.freeze,
      Publishing::Docs::Com::Entry => {
        entry: Publishing::Docs::Com::Entry,
        revision: Publishing::Docs::Com::EntryRevision,
        version: Publishing::Docs::Com::EntryVersion,
        vocabulary: Publishing::Docs::Com::Vocabulary,
        taxonomy_term: Publishing::Docs::Com::TaxonomyTerm,
        revision_single: Publishing::Docs::Com::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Docs::Com::RevisionMediaUsage,
        version_single: Publishing::Docs::Com::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Docs::Com::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Docs::Com::VersionMediaUsage,
      }.freeze,
      Publishing::Docs::Org::Entry => {
        entry: Publishing::Docs::Org::Entry,
        revision: Publishing::Docs::Org::EntryRevision,
        version: Publishing::Docs::Org::EntryVersion,
        vocabulary: Publishing::Docs::Org::Vocabulary,
        taxonomy_term: Publishing::Docs::Org::TaxonomyTerm,
        revision_single: Publishing::Docs::Org::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Docs::Org::RevisionMediaUsage,
        version_single: Publishing::Docs::Org::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Docs::Org::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Docs::Org::VersionMediaUsage,
      }.freeze,
      Publishing::News::App::Entry => {
        entry: Publishing::News::App::Entry,
        revision: Publishing::News::App::EntryRevision,
        version: Publishing::News::App::EntryVersion,
        vocabulary: Publishing::News::App::Vocabulary,
        taxonomy_term: Publishing::News::App::TaxonomyTerm,
        revision_single: Publishing::News::App::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::News::App::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::News::App::RevisionMediaUsage,
        version_single: Publishing::News::App::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::News::App::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::News::App::VersionMediaUsage,
      }.freeze,
      Publishing::News::Com::Entry => {
        entry: Publishing::News::Com::Entry,
        revision: Publishing::News::Com::EntryRevision,
        version: Publishing::News::Com::EntryVersion,
        vocabulary: Publishing::News::Com::Vocabulary,
        taxonomy_term: Publishing::News::Com::TaxonomyTerm,
        revision_single: Publishing::News::Com::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::News::Com::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::News::Com::RevisionMediaUsage,
        version_single: Publishing::News::Com::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::News::Com::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::News::Com::VersionMediaUsage,
      }.freeze,
      Publishing::News::Org::Entry => {
        entry: Publishing::News::Org::Entry,
        revision: Publishing::News::Org::EntryRevision,
        version: Publishing::News::Org::EntryVersion,
        vocabulary: Publishing::News::Org::Vocabulary,
        taxonomy_term: Publishing::News::Org::TaxonomyTerm,
        revision_single: Publishing::News::Org::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::News::Org::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::News::Org::RevisionMediaUsage,
        version_single: Publishing::News::Org::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::News::Org::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::News::Org::VersionMediaUsage,
      }.freeze,
      Publishing::Help::App::Entry => {
        entry: Publishing::Help::App::Entry,
        revision: Publishing::Help::App::EntryRevision,
        version: Publishing::Help::App::EntryVersion,
        vocabulary: Publishing::Help::App::Vocabulary,
        taxonomy_term: Publishing::Help::App::TaxonomyTerm,
        revision_single: Publishing::Help::App::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Help::App::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Help::App::RevisionMediaUsage,
        version_single: Publishing::Help::App::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Help::App::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Help::App::VersionMediaUsage,
      }.freeze,
      Publishing::Help::Com::Entry => {
        entry: Publishing::Help::Com::Entry,
        revision: Publishing::Help::Com::EntryRevision,
        version: Publishing::Help::Com::EntryVersion,
        vocabulary: Publishing::Help::Com::Vocabulary,
        taxonomy_term: Publishing::Help::Com::TaxonomyTerm,
        revision_single: Publishing::Help::Com::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Help::Com::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Help::Com::RevisionMediaUsage,
        version_single: Publishing::Help::Com::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Help::Com::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Help::Com::VersionMediaUsage,
      }.freeze,
      Publishing::Help::Org::Entry => {
        entry: Publishing::Help::Org::Entry,
        revision: Publishing::Help::Org::EntryRevision,
        version: Publishing::Help::Org::EntryVersion,
        vocabulary: Publishing::Help::Org::Vocabulary,
        taxonomy_term: Publishing::Help::Org::TaxonomyTerm,
        revision_single: Publishing::Help::Org::RevisionSingleTaxonomyAssignment,
        revision_multiple: Publishing::Help::Org::RevisionMultipleTaxonomyAssignment,
        revision_media: Publishing::Help::Org::RevisionMediaUsage,
        version_single: Publishing::Help::Org::VersionSingleTaxonomyAssignment,
        version_multiple: Publishing::Help::Org::VersionMultipleTaxonomyAssignment,
        version_media: Publishing::Help::Org::VersionMediaUsage,
      }.freeze,
    }.freeze

    CELL_BY_REVISION = {
      Publishing::Info::App::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Info::App::Entry),
      Publishing::Info::Com::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Info::Com::Entry),
      Publishing::Info::Org::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Info::Org::Entry),
      Publishing::Docs::App::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Docs::App::Entry),
      Publishing::Docs::Com::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Docs::Com::Entry),
      Publishing::Docs::Org::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Docs::Org::Entry),
      Publishing::News::App::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::News::App::Entry),
      Publishing::News::Com::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::News::Com::Entry),
      Publishing::News::Org::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::News::Org::Entry),
      Publishing::Help::App::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Help::App::Entry),
      Publishing::Help::Com::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Help::Com::Entry),
      Publishing::Help::Org::EntryRevision => CELL_BY_ENTRY.fetch(Publishing::Help::Org::Entry),
    }.freeze

    CELL_BY_VERSION = {
      Publishing::Info::App::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Info::App::Entry),
      Publishing::Info::Com::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Info::Com::Entry),
      Publishing::Info::Org::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Info::Org::Entry),
      Publishing::Docs::App::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Docs::App::Entry),
      Publishing::Docs::Com::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Docs::Com::Entry),
      Publishing::Docs::Org::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Docs::Org::Entry),
      Publishing::News::App::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::News::App::Entry),
      Publishing::News::Com::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::News::Com::Entry),
      Publishing::News::Org::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::News::Org::Entry),
      Publishing::Help::App::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Help::App::Entry),
      Publishing::Help::Com::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Help::Com::Entry),
      Publishing::Help::Org::EntryVersion => CELL_BY_ENTRY.fetch(Publishing::Help::Org::Entry),
    }.freeze

    CELL_BY_TAXONOMY_TERM = {
      Publishing::Info::App::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Info::App::Entry),
      Publishing::Info::Com::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Info::Com::Entry),
      Publishing::Info::Org::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Info::Org::Entry),
      Publishing::Docs::App::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Docs::App::Entry),
      Publishing::Docs::Com::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Docs::Com::Entry),
      Publishing::Docs::Org::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Docs::Org::Entry),
      Publishing::News::App::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::News::App::Entry),
      Publishing::News::Com::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::News::Com::Entry),
      Publishing::News::Org::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::News::Org::Entry),
      Publishing::Help::App::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Help::App::Entry),
      Publishing::Help::Com::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Help::Com::Entry),
      Publishing::Help::Org::TaxonomyTerm => CELL_BY_ENTRY.fetch(Publishing::Help::Org::Entry),
    }.freeze

    def self.cell_for_entry(entry)
      CELL_BY_ENTRY.fetch(entry.class) { raise ArgumentError, "unsupported publishing Entry class" }
    end

    def self.cell_for_revision(revision)
      CELL_BY_REVISION.fetch(revision.class) { raise ArgumentError, "unsupported publishing revision class" }
    end

    def self.entry_class_for_revision(revision)
      cell_for_revision(revision).fetch(:entry)
    end

    def self.cell_for_version(version)
      CELL_BY_VERSION.fetch(version.class) { raise ArgumentError, "unsupported publishing version class" }
    end

    def self.entry_class_for_version(version)
      cell_for_version(version).fetch(:entry)
    end

    def self.cell_for_taxonomy_term(term)
      CELL_BY_TAXONOMY_TERM.fetch(term.class) { raise ArgumentError, "unsupported publishing taxonomy term class" }
    end

    def self.entry_class(surface:, audience:)
      ENTRY_CLASSES.find { |klass| klass::SURFACE == surface.to_s && klass::AUDIENCE == audience.to_s }
    end

    public_class_method :cell_for_entry, :cell_for_revision, :entry_class_for_revision, :cell_for_version,
                        :entry_class_for_version, :cell_for_taxonomy_term, :entry_class
  end
end
