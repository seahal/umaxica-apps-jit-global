# frozen_string_literal: true

class RemoveRedundantPublishingIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # [table, column, index name]; each is covered by a composite index that leads with the same column.
  INDEXES = [
    [:publishing_help_org_version_media_usages, :entry_version_id, "idx_on_entry_version_id_5047b8eaae"],
    [:publishing_help_org_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_c4b49013a6"],
    [:publishing_help_org_taxonomy_terms, :vocabulary_id, "index_publishing_help_org_taxonomy_terms_on_vocabulary_id"],
    [:publishing_help_org_entry_versions, :entry_id, "index_publishing_help_org_entry_versions_on_entry_id"],
    [:publishing_help_org_entry_revisions, :entry_id, "index_publishing_help_org_entry_revisions_on_entry_id"],
    [:publishing_help_com_version_media_usages, :entry_version_id, "idx_on_entry_version_id_de9d71656a"],
    [:publishing_help_com_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_e430280ab1"],
    [:publishing_help_com_taxonomy_terms, :vocabulary_id, "index_publishing_help_com_taxonomy_terms_on_vocabulary_id"],
    [:publishing_help_com_entry_versions, :entry_id, "index_publishing_help_com_entry_versions_on_entry_id"],
    [:publishing_help_com_entry_revisions, :entry_id, "index_publishing_help_com_entry_revisions_on_entry_id"],
    [:publishing_help_app_version_media_usages, :entry_version_id, "idx_on_entry_version_id_0ee210b2b5"],
    [:publishing_help_app_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_f987c52794"],
    [:publishing_help_app_taxonomy_terms, :vocabulary_id, "index_publishing_help_app_taxonomy_terms_on_vocabulary_id"],
    [:publishing_help_app_entry_versions, :entry_id, "index_publishing_help_app_entry_versions_on_entry_id"],
    [:publishing_help_app_entry_revisions, :entry_id, "index_publishing_help_app_entry_revisions_on_entry_id"],
    [:publishing_news_org_version_media_usages, :entry_version_id, "idx_on_entry_version_id_85c8b1949a"],
    [:publishing_news_org_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_af519933a0"],
    [:publishing_news_org_taxonomy_terms, :vocabulary_id, "index_publishing_news_org_taxonomy_terms_on_vocabulary_id"],
    [:publishing_news_org_entry_versions, :entry_id, "index_publishing_news_org_entry_versions_on_entry_id"],
    [:publishing_news_org_entry_revisions, :entry_id, "index_publishing_news_org_entry_revisions_on_entry_id"],
    [:publishing_news_com_version_media_usages, :entry_version_id, "idx_on_entry_version_id_2cc4568c50"],
    [:publishing_news_com_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_936880ceca"],
    [:publishing_news_com_taxonomy_terms, :vocabulary_id, "index_publishing_news_com_taxonomy_terms_on_vocabulary_id"],
    [:publishing_news_com_entry_versions, :entry_id, "index_publishing_news_com_entry_versions_on_entry_id"],
    [:publishing_news_com_entry_revisions, :entry_id, "index_publishing_news_com_entry_revisions_on_entry_id"],
    [:publishing_news_app_version_media_usages, :entry_version_id, "idx_on_entry_version_id_45404796f4"],
    [:publishing_news_app_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_943136696e"],
    [:publishing_news_app_taxonomy_terms, :vocabulary_id, "index_publishing_news_app_taxonomy_terms_on_vocabulary_id"],
    [:publishing_news_app_entry_versions, :entry_id, "index_publishing_news_app_entry_versions_on_entry_id"],
    [:publishing_news_app_entry_revisions, :entry_id, "index_publishing_news_app_entry_revisions_on_entry_id"],
    [:publishing_docs_org_version_media_usages, :entry_version_id, "idx_on_entry_version_id_4cd943f55f"],
    [:publishing_docs_org_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_f220c8f97e"],
    [:publishing_docs_org_taxonomy_terms, :vocabulary_id, "index_publishing_docs_org_taxonomy_terms_on_vocabulary_id"],
    [:publishing_docs_org_entry_versions, :entry_id, "index_publishing_docs_org_entry_versions_on_entry_id"],
    [:publishing_docs_org_entry_revisions, :entry_id, "index_publishing_docs_org_entry_revisions_on_entry_id"],
    [:publishing_docs_com_version_media_usages, :entry_version_id, "idx_on_entry_version_id_d451e876f4"],
    [:publishing_docs_com_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_335482b5b7"],
    [:publishing_docs_com_taxonomy_terms, :vocabulary_id, "index_publishing_docs_com_taxonomy_terms_on_vocabulary_id"],
    [:publishing_docs_com_entry_versions, :entry_id, "index_publishing_docs_com_entry_versions_on_entry_id"],
    [:publishing_docs_com_entry_revisions, :entry_id, "index_publishing_docs_com_entry_revisions_on_entry_id"],
    [:publishing_docs_app_version_media_usages, :entry_version_id, "idx_on_entry_version_id_c7a3fd4207"],
    [:publishing_docs_app_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_ae3645a48c"],
    [:publishing_docs_app_taxonomy_terms, :vocabulary_id, "index_publishing_docs_app_taxonomy_terms_on_vocabulary_id"],
    [:publishing_docs_app_entry_versions, :entry_id, "index_publishing_docs_app_entry_versions_on_entry_id"],
    [:publishing_docs_app_entry_revisions, :entry_id, "index_publishing_docs_app_entry_revisions_on_entry_id"],
    [:publishing_info_org_version_media_usages, :entry_version_id, "idx_on_entry_version_id_d7a15f73b8"],
    [:publishing_info_org_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_0e042ce215"],
    [:publishing_info_org_taxonomy_terms, :vocabulary_id, "index_publishing_info_org_taxonomy_terms_on_vocabulary_id"],
    [:publishing_info_org_entry_versions, :entry_id, "index_publishing_info_org_entry_versions_on_entry_id"],
    [:publishing_info_org_entry_revisions, :entry_id, "index_publishing_info_org_entry_revisions_on_entry_id"],
    [:publishing_info_com_version_media_usages, :entry_version_id, "idx_on_entry_version_id_2a922bfe07"],
    [:publishing_info_com_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_dadda0980d"],
    [:publishing_info_com_taxonomy_terms, :vocabulary_id, "index_publishing_info_com_taxonomy_terms_on_vocabulary_id"],
    [:publishing_info_com_entry_versions, :entry_id, "index_publishing_info_com_entry_versions_on_entry_id"],
    [:publishing_info_com_entry_revisions, :entry_id, "index_publishing_info_com_entry_revisions_on_entry_id"],
    [:publishing_info_app_version_media_usages, :entry_version_id, "idx_on_entry_version_id_d118d04df1"],
    [:publishing_info_app_revision_media_usages, :entry_revision_id, "idx_on_entry_revision_id_89d55e3ea8"],
    [:publishing_info_app_taxonomy_terms, :vocabulary_id, "index_publishing_info_app_taxonomy_terms_on_vocabulary_id"],
    [:publishing_info_app_entry_versions, :entry_id, "index_publishing_info_app_entry_versions_on_entry_id"],
    [:publishing_info_app_entry_revisions, :entry_id, "index_publishing_info_app_entry_revisions_on_entry_id"],
  ].freeze

  def change
    INDEXES.each do |table, column, name|
      remove_index(table, column, name:, algorithm: :concurrently)
    end
  end
end
