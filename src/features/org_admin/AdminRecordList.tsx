import Button from "@/components/ui/Button";
// A bounded, paginated list of administration records with an optional exact-identifier search.
// A failed load is its own state: it is never shown as an empty list.
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

import AdminContextPanel, { AdminNotices } from "./AdminContextPanel";
import type { AdminBaseProps, AdminLink } from "./types";

export type AdminRecordRow = {
  key: string;
  cells: string[];
  href: string | null;
};

export type AdminRecordListProps = AdminBaseProps & {
  columns: string[];
  rows: AdminRecordRow[];
  empty_message: string;
  search: {
    action: string;
    label: string;
    name: string;
    value: string;
    submit_label: string;
    maxlength: number;
  } | null;
  pagination: { previous: AdminLink | null; next: AdminLink | null };
  actions: AdminLink[];
};

export default function AdminRecordList({
  title,
  description,
  up_link: upLink = null,
  context,
  notices = [],
  columns,
  rows,
  empty_message: emptyMessage,
  search,
  pagination,
  actions,
}: AdminRecordListProps) {
  const paginationLabel =
    typeof document === "undefined"
      ? undefined
      : document.querySelector<HTMLMetaElement>('meta[name="ui-pagination"]')?.content;
  return (
    <Page
      title={title}
      {...(description ? { description } : {})}
      up={upLink}
      upVisit="document"
      width="wide"
    >
      <AdminContextPanel context={context} />
      <AdminNotices notices={notices} />

      {search ? (
        <form
          method="get"
          action={search.action}
          className="flex flex-wrap items-end gap-2"
        >
          <label className="flex flex-col gap-1 text-base font-medium text-fg">
            {search.label}
            <input
              type="search"
              name={search.name}
              defaultValue={search.value}
              maxLength={search.maxlength}
              className="min-h-12 rounded-md border border-control bg-surface px-3 py-2 text-base text-fg"
            />
          </label>
          <Button type="submit">{search.submit_label}</Button>
        </form>
      ) : null}

      {actions.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          {actions.map((action) => (
            <ButtonLink
              key={action.href}
              href={action.href}
              variant="secondary"
            >
              {action.label}
            </ButtonLink>
          ))}
        </div>
      ) : null}

      <div>
        {rows.length === 0 ? (
          <p className="text-base text-fg-muted">{emptyMessage}</p>
        ) : (
          <Table
            label={title}
            density="dense"
          >
            <thead>
              <tr>
                {columns.map((column) => (
                  <th
                    key={column}
                    scope="col"
                  >
                    {column}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.key}>
                  {row.cells.map((cell, index) => (
                    // Cells are positional within a row and never reorder.
                    <td key={index}>
                      {index === 0 && row.href ? (
                        <a
                          href={row.href}
                          className="ui-text-link underline underline-offset-4 hover:underline"
                        >
                          {cell}
                        </a>
                      ) : (
                        cell
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </div>

      <nav
        aria-label={paginationLabel}
        className="flex flex-wrap justify-between gap-4 text-base"
      >
        {pagination.previous ? (
          <a
            className="ui-text-link text-link underline underline-offset-4"
            href={pagination.previous.href}
          >
            {pagination.previous.label}
          </a>
        ) : (
          <span />
        )}
        {pagination.next ? (
          <a
            className="ui-text-link text-link underline underline-offset-4"
            href={pagination.next.href}
          >
            {pagination.next.label}
          </a>
        ) : (
          <span />
        )}
      </nav>
    </Page>
  );
}
