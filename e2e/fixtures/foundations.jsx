import React from "react";
import { createRoot } from "react-dom/client";

import EmailPreferenceEdit from "../../src/features/identity/EmailPreferenceEdit";
import InfoPage from "../../src/features/identity/InfoPage";

import "../../src/styles/surfaces/auth_app.css";

// Japanese paragraphs are locale/reflow fixtures, not repository-authored guidance.
const query = new URLSearchParams(location.search);
document.documentElement.lang = query.get("lang") === "ja" ? "ja" : "en";
const root = document.querySelector("#fixture");
if (!root) {
  throw new Error("Foundation fixture root is missing");
}
createRoot(root).render(
  query.get("screen") === "preferences" ? (
    <EmailPreferenceEdit
      title="Email preferences"
      address="synthetic@example.invalid"
      form={{
        action: "/synthetic/preferences",
        scope: "email",
        promotional: false,
        notifiable: true,
        always_on_label: "Essential notices",
        always_on_description: "These notices remain enabled.",
        promotional_label: "Promotional notices",
        promotional_description: "Choose whether to receive promotional notices.",
        notifiable_label: "Account notices",
        notifiable_description: "Choose whether to receive account notices.",
        submit: "Save",
        turnstile: { site_key: "synthetic", action: "test", mode: "render", cdata: null },
      }}
      delete={{
        href: "/synthetic/delete",
        label: "Delete",
        confirm: "Delete this synthetic address?",
      }}
      cancel_link={{ href: "/synthetic/back", label: "Back" }}
      error_messages={[]}
    />
  ) : (
    <InfoPage
      title="Information"
      paragraphs={
        document.documentElement.lang === "ja"
          ? [
              "これは読みやすさを確認するための合成文章です。情報の内容と段落の関係がわかるように表示します。".repeat(
                5,
              ),
              "次の段落では、別の情報を説明します。文字を拡大しても文章と操作が欠けないことを確認します。".repeat(
                4,
              ),
            ]
          : [
              "This synthetic paragraph checks readable line length and spacing when text is enlarged. ".repeat(
                8,
              ),
              "The next paragraph explains another point without crowding the preceding text. ".repeat(
                8,
              ),
            ]
      }
      back_link={{ href: "/synthetic/back", label: "Back" }}
    />
  ),
);
