// States who is acting and on which realm, in text, at the top of every administration screen.
import DescriptionList from "@/components/ui/DescriptionList";

import type { AdminContext, AdminNotice } from "./types";

const NOTICE_CLASS: Record<AdminNotice["tone"], string> = {
  info: "border-line bg-surface-muted text-fg",
  warning: "border-warning bg-surface-muted text-fg",
  danger: "border-danger bg-surface-muted text-danger",
};

export function AdminNotices({ notices }: { notices: AdminNotice[] }) {
  if (notices.length === 0) {
    return null;
  }

  return (
    <ul className="flex flex-col gap-2">
      {notices.map((notice) => (
        <li
          key={notice.message}
          role={notice.tone === "info" ? "status" : "alert"}
          className={`rounded-md border px-3 py-2 text-sm ${NOTICE_CLASS[notice.tone]}`}
        >
          {notice.message}
        </li>
      ))}
    </ul>
  );
}

export default function AdminContextPanel({ context }: { context: AdminContext }) {
  const items = [{ term: context.operator_label, description: context.operator_public_id }];
  if (context.realm_label !== null && context.realm !== null) {
    items.push({ term: context.realm_label, description: context.realm });
  }

  return <DescriptionList items={items} />;
}
