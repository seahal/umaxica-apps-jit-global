# frozen_string_literal: true

class RemoveRedundantPublishingLocaleUniqueIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # (id, entry_id) is already unique, so (id, entry_id, locale) adds no constraint. No foreign key
  # references the three-column set; (id, entry_id) and (id, locale) stay as composite FK targets.
  INDEXES = [
    [:publishing_help_org_entry_versions, "uidx_help_org_ver_id_entry_locale"],
    [:publishing_help_org_entry_revisions, "uidx_help_org_rev_id_entry_locale"],
    [:publishing_help_com_entry_versions, "uidx_help_com_ver_id_entry_locale"],
    [:publishing_help_com_entry_revisions, "uidx_help_com_rev_id_entry_locale"],
    [:publishing_help_app_entry_versions, "uidx_help_app_ver_id_entry_locale"],
    [:publishing_help_app_entry_revisions, "uidx_help_app_rev_id_entry_locale"],
    [:publishing_news_org_entry_versions, "uidx_news_org_ver_id_entry_locale"],
    [:publishing_news_org_entry_revisions, "uidx_news_org_rev_id_entry_locale"],
    [:publishing_news_com_entry_versions, "uidx_news_com_ver_id_entry_locale"],
    [:publishing_news_com_entry_revisions, "uidx_news_com_rev_id_entry_locale"],
    [:publishing_news_app_entry_versions, "uidx_news_app_ver_id_entry_locale"],
    [:publishing_news_app_entry_revisions, "uidx_news_app_rev_id_entry_locale"],
    [:publishing_docs_org_entry_versions, "uidx_docs_org_ver_id_entry_locale"],
    [:publishing_docs_org_entry_revisions, "uidx_docs_org_rev_id_entry_locale"],
    [:publishing_docs_com_entry_versions, "uidx_docs_com_ver_id_entry_locale"],
    [:publishing_docs_com_entry_revisions, "uidx_docs_com_rev_id_entry_locale"],
    [:publishing_docs_app_entry_versions, "uidx_docs_app_ver_id_entry_locale"],
    [:publishing_docs_app_entry_revisions, "uidx_docs_app_rev_id_entry_locale"],
    [:publishing_info_org_entry_versions, "uidx_info_org_ver_id_entry_locale"],
    [:publishing_info_org_entry_revisions, "uidx_info_org_rev_id_entry_locale"],
    [:publishing_info_com_entry_versions, "uidx_info_com_ver_id_entry_locale"],
    [:publishing_info_com_entry_revisions, "uidx_info_com_rev_id_entry_locale"],
    [:publishing_info_app_entry_versions, "uidx_info_app_ver_id_entry_locale"],
    [:publishing_info_app_entry_revisions, "uidx_info_app_rev_id_entry_locale"],
  ].freeze

  def change
    INDEXES.each do |table, name|
      remove_index(table, %i(id entry_id locale), unique: true, name:, algorithm: :concurrently)
    end
  end
end
