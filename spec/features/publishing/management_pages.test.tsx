import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const patch = vi.fn();
const post = vi.fn();
const destroy = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: {
    patch: (...args: unknown[]) => {
      patch(...args);
    },
    post: (...args: unknown[]) => {
      post(...args);
    },
    delete: (...args: unknown[]) => {
      destroy(...args);
    },
  },
}));

const { default: ManagementIndex } = await import("@/features/publishing/ManagementIndex");
const { default: ManagementShow } = await import("@/features/publishing/ManagementShow");
const { default: ManagementEdit } = await import("@/features/publishing/ManagementEdit");
const { default: ManagementNew } = await import("@/features/publishing/ManagementNew");

describe("publishing management pages", () => {
  it("renders index rows and show links", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        new_href="/publishing/docs/app/entries/new"
        page={{ number: 1, per_page: 25, total: 1, previous_href: null, next_href: null }}
        entries={[
          {
            public_id: "pubidabcdefghijklmnop",
            title: "Guide",
            locale: "ja",
            canonical_slug: "guide",
            archive_state: "active",
            publication_state: "draft",
            revision_sequence: 1,
            updated_at: "2026-09-04T00:00:00Z",
            show_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
            edit_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop/edit",
          },
        ]}
      />,
    );

    expect(html).toContain("Guide");
    expect(html).toContain("guide");
    expect(html).toContain("ja");
    expect(html).toContain("/publishing/docs/app/entries/pubidabcdefghijklmnop");
  });

  it("renders show content and edit navigation", () => {
    const html = renderToStaticMarkup(
      <ManagementShow
        title="Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        edit_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/edit"
        publish_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/publications"
        archive_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/archive"
        errors={{}}
        publication={null}
        scheduled_publications={[]}
        entry={{
          public_id: "pubidabcdefghijklmnop",
          surface: "docs",
          audience: "app",
          locale: "ja",
          canonical_slug: "guide",
          current_revision_public_id: "revidabcdefghijklmnop",
          revision_sequence: 1,
          title: "Guide",
          summary: "Guide summary",
          body: { text: "Guide body" },
          archive_state: "active",
          archive_reason: null,
          publication_state: "draft",
          revision_count: 1,
          version_count: 0,
          updated_at: "2026-09-04T00:00:00Z",
        }}
      />,
    );

    expect(html).toContain("Guide summary");
    expect(html).toContain("Guide body");
    expect(html).toContain("/publishing/docs/app/entries/pubidabcdefghijklmnop/edit");
    expect(html).toContain("Edit");
  });

  it("renders current edit values and validation errors", () => {
    const html = renderToStaticMarkup(
      <ManagementEdit
        title="Edit Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        show_href="/publishing/docs/app/entries/pubidabcdefghijklmnop"
        errors={{ body: "must be valid JSON", title: "can't be blank" }}
        form={{
          action: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
          method: "patch",
          title: "Guide",
          summary: "Guide summary",
          body: '{\n  "text": "Guide body"\n}',
          lock_version: 0,
          locale: "ja",
          canonical_slug: "guide",
        }}
      />,
    );

    expect(html).toContain("Guide");
    expect(html).toContain("Guide summary");
    expect(html).toContain("Guide body");
    expect(html).toContain("must be valid JSON");
    expect(html).toContain("can&#x27;t be blank");
    expect(html).toContain('action="/publishing/docs/app/entries/pubidabcdefghijklmnop"');
    expect(html).toContain('name="_method"');
    expect(html).toContain("patch");
  });

  // Every optional field is null and the cell is archived: the row still has to name the entry and
  // say so, because a staff member reading the list has nothing else to identify it by.
  it("falls back to the public id and an em dash when a row has no revision yet", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        new_href="/publishing/docs/app/entries/new"
        page={{ number: 1, per_page: 25, total: 1, previous_href: null, next_href: null }}
        entries={[
          {
            public_id: "pubidabcdefghijklmnop",
            title: null,
            locale: "ja",
            canonical_slug: null,
            archive_state: "archived",
            publication_state: "draft",
            revision_sequence: null,
            updated_at: null,
            show_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
            edit_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop/edit",
          },
        ]}
      />,
    );

    expect(html).toContain("pubidabcdefghijklmnop");
    expect(html).toContain("draft / archived");
    expect(html.split("—")).toHaveLength(4);
  });

  it("says the cell is empty rather than rendering a headed table with no rows", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        new_href="/publishing/docs/app/entries/new"
        page={{ number: 1, per_page: 25, total: 0, previous_href: null, next_href: null }}
        entries={[]}
      />,
    );

    expect(html).toContain("No entries in this cell.");
    expect(html).not.toContain("<table");
  });

  it("shows an em dash for each unset field and omits the summary section entirely", () => {
    const html = renderToStaticMarkup(
      <ManagementShow
        title="pubidabcdefghijklmnop"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        edit_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/edit"
        publish_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/publications"
        archive_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/archive"
        errors={{}}
        publication={null}
        scheduled_publications={[]}
        entry={{
          public_id: "pubidabcdefghijklmnop",
          surface: "docs",
          audience: "app",
          locale: "ja",
          canonical_slug: null,
          current_revision_public_id: null,
          revision_sequence: null,
          title: null,
          summary: null,
          body: {},
          archive_state: "active",
          archive_reason: null,
          publication_state: "draft",
          revision_count: 0,
          version_count: 0,
          updated_at: null,
        }}
      />,
    );

    expect(html.split("—")).toHaveLength(5);
    expect(html).not.toContain("Summary");
    expect(html).toContain("Body");
  });
});

describe("ManagementEdit", () => {
  const form = {
    action: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
    method: "patch",
    title: "Guide",
    summary: "Guide summary",
    body: '{\n  "text": "Guide body"\n}',
    lock_version: 3,
    locale: "ja",
    canonical_slug: "guide",
  };

  const renderEdit = (overrides: Partial<Parameters<typeof ManagementEdit>[0]> = {}) =>
    render(
      <ManagementEdit
        title="Edit Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        show_href="/publishing/docs/app/entries/pubidabcdefghijklmnop"
        errors={{}}
        form={form}
        {...overrides}
      />,
    );

  beforeEach(() => {
    patch.mockClear();
  });

  // The form posts through Inertia, not the browser, so the request the server sees is whatever
  // this handler builds. It has to carry the edited values and the lock_version the page was
  // rendered with -- that version is the whole of the concurrent-edit check on the server.
  it("submits the edited values with the lock_version the page was rendered with", async () => {
    const user = userEvent.setup();
    renderEdit();

    await user.clear(screen.getByRole("textbox", { name: "Title" }));
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Guide v2");
    await user.clear(screen.getByRole("textbox", { name: "Summary" }));
    await user.type(screen.getByRole("textbox", { name: "Summary" }), "Second summary");
    await user.clear(screen.getByRole("textbox", { name: "Body (JSON)" }));
    await user.type(screen.getByRole("textbox", { name: "Body (JSON)" }), '{{"text":"v2"}');
    await user.click(screen.getByRole("button", { name: "Save revision" }));

    expect(patch).toHaveBeenCalledTimes(1);
    expect(patch).toHaveBeenCalledWith(form.action, {
      entry: {
        title: "Guide v2",
        summary: "Second summary",
        body: '{"text":"v2"}',
        lock_version: 3,
      },
    });
  });

  it("renders a stale lock_version and a base failure as alerts", () => {
    renderEdit({ errors: { lock_version: "is stale", base: "entry has no current revision" } });

    const alerts = screen.getAllByRole("alert").map((node) => node.textContent);

    expect(alerts).toContain("is stale");
    expect(alerts).toContain("entry has no current revision");
  });

  it("names a summary failure under the summary field", () => {
    renderEdit({ errors: { summary: "is too long" } });

    expect(screen.getAllByRole("alert").map((node) => node.textContent)).toContain("is too long");
  });

  it("renders no alert when there is nothing wrong with the submission", () => {
    renderEdit();

    expect(screen.queryAllByRole("alert")).toHaveLength(0);
  });

  // A revision that was never given a title or summary still has to open in the editor, with empty
  // fields rather than the string "null", and with the slug line reduced to the locale.
  it("opens an untitled revision with empty fields and no slug suffix", () => {
    renderEdit({ form: { ...form, title: null, summary: null, canonical_slug: null } });

    expect(screen.getByRole<HTMLInputElement>("textbox", { name: "Title" }).value).toBe("");
    expect(screen.getByRole<HTMLTextAreaElement>("textbox", { name: "Summary" }).value).toBe("");
    expect(screen.getByText("Locale ja").textContent).toBe("Locale ja");
  });
});

describe("ManagementIndex paging", () => {
  it("names the total, the current page, and only the neighbours that exist", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        new_href="/publishing/docs/app/entries/new"
        page={{
          number: 2,
          per_page: 25,
          total: 60,
          previous_href: "/publishing/docs/app/entries?page=1",
          next_href: "/publishing/docs/app/entries?page=3",
        }}
        entries={[]}
      />,
    );

    expect(html).toContain("60 entries");
    expect(html).toContain("page 2");
    expect(html).toContain("/publishing/docs/app/entries?page=1");
    expect(html).toContain("/publishing/docs/app/entries?page=3");
  });

  it("offers no previous link on the first page and no next link on the last", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        new_href="/publishing/docs/app/entries/new"
        page={{ number: 1, per_page: 25, total: 3, previous_href: null, next_href: null }}
        entries={[]}
      />,
    );

    expect(html).not.toContain("Previous");
    expect(html).not.toContain("Next");
    expect(html).toContain("/publishing/docs/app/entries/new");
  });
});

describe("ManagementNew", () => {
  const form = {
    action: "/publishing/docs/app/entries",
    method: "post",
    title: null,
    summary: null,
    body: "{}",
    locale: "ja",
    slug: null,
  };

  const renderNew = (overrides: Partial<Parameters<typeof ManagementNew>[0]> = {}) =>
    render(
      <ManagementNew
        title="New docs/app entry"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        errors={{}}
        locales={["ja", "en"]}
        form={form}
        {...overrides}
      />,
    );

  beforeEach(() => {
    post.mockClear();
  });

  it("submits the locale and slug that only exist at creation together with the content", async () => {
    const user = userEvent.setup();
    renderNew();

    await user.selectOptions(screen.getByRole("combobox", { name: "Locale" }), "en");
    await user.type(screen.getByRole("textbox", { name: "Slug" }), "new-guide");
    await user.type(screen.getByRole("textbox", { name: "Title" }), "New Guide");
    await user.type(screen.getByRole("textbox", { name: "Summary" }), "Summary");
    await user.clear(screen.getByRole("textbox", { name: "Body (JSON)" }));
    await user.type(screen.getByRole("textbox", { name: "Body (JSON)" }), '{{"text":"body"}');
    await user.click(screen.getByRole("button", { name: "Create entry" }));

    expect(post).toHaveBeenCalledTimes(1);
    expect(post).toHaveBeenCalledWith("/publishing/docs/app/entries", {
      entry: {
        title: "New Guide",
        summary: "Summary",
        body: '{"text":"body"}',
        locale: "en",
        slug: "new-guide",
      },
    });
  });

  it("keeps the rejected values on the form and names what was wrong with them", () => {
    renderNew({
      errors: { slug: "is already used by another entry in this locale", title: "can't be blank" },
      form: { ...form, slug: "taken", title: "" },
    });

    const alerts = screen.getAllByRole("alert").map((node) => node.textContent);

    expect(alerts).toContain("is already used by another entry in this locale");
    expect(alerts).toContain("can't be blank");
    // With an error rendered inside the label, the field's accessible name carries the message
    // too, so the value is what identifies it here.
    expect(screen.getByDisplayValue("taken")).toBeTruthy();
  });

  it("names locale, body, and base failures on the create form", () => {
    renderNew({
      errors: {
        locale: "is not available in this cell",
        body: "must be valid JSON",
        base: "the cell cannot accept another entry",
      },
    });

    const alerts = screen.getAllByRole("alert").map((node) => node.textContent);

    expect(alerts).toContain("is not available in this cell");
    expect(alerts).toContain("must be valid JSON");
    expect(alerts).toContain("the cell cannot accept another entry");
  });
});

describe("ManagementShow lifecycle controls", () => {
  const entry = {
    public_id: "pubidabcdefghijklmnop",
    surface: "docs",
    audience: "app",
    locale: "ja",
    canonical_slug: "guide",
    current_revision_public_id: "revidabcdefghijklmnop",
    revision_sequence: 2,
    title: "Guide",
    summary: "Guide summary",
    body: { text: "Guide body" },
    archive_state: "active",
    archive_reason: null,
    publication_state: "draft",
    revision_count: 2,
    version_count: 0,
    updated_at: "2026-09-06T00:00:00Z",
  };

  const renderShow = (overrides: Partial<Parameters<typeof ManagementShow>[0]> = {}) =>
    render(
      <ManagementShow
        title="Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        edit_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/edit"
        publish_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/publications"
        archive_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/archive"
        errors={{}}
        publication={null}
        scheduled_publications={[]}
        entry={entry}
        {...overrides}
      />,
    );

  beforeEach(() => {
    post.mockClear();
    destroy.mockClear();
  });

  it("publishes now when no effective time is given", async () => {
    const user = userEvent.setup();
    renderShow();

    await user.click(screen.getByRole("button", { name: "Publish" }));

    expect(post).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications",
      { publication: { effective_from: "" } },
    );
  });

  it("sends the chosen time when the operator schedules the window instead", async () => {
    const user = userEvent.setup();
    renderShow();

    await user.type(
      screen.getByLabelText("Effective from (leave empty to publish now)"),
      "2026-09-08T15:04",
    );
    await user.click(screen.getByRole("button", { name: "Publish" }));

    expect(post).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications",
      { publication: { effective_from: "2026-09-08T15:04" } },
    );
  });

  // The reason is not decoration: both endings of a publication window are `NOT NULL` on their
  // reason column, so the request that carries no reason is the one the server rejects.
  it("carries the reason when a live window is ended", async () => {
    const user = userEvent.setup();
    renderShow({
      entry: { ...entry, publication_state: "published", version_count: 1 },
      publication: {
        public_id: "pubpubidabcdefghijklm",
        effective_from: "2026-09-05T00:00:00Z",
        version_public_id: "veridabcdefghijklmnop",
        end_href:
          "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications/pubpubidabcdefghijklm",
      },
    });

    await user.type(screen.getByRole("textbox", { name: "Reason for unpublishing" }), "withdrawn");
    await user.click(screen.getByRole("button", { name: "Unpublish" }));

    expect(destroy).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications/pubpubidabcdefghijklm",
      { data: { publication: { reason: "withdrawn" } } },
    );
    expect(screen.queryByRole("button", { name: "Publish" })).toBeNull();
  });

  it("lists a scheduled window with its own cancel control", async () => {
    const user = userEvent.setup();
    renderShow({
      scheduled_publications: [
        {
          public_id: "schedidabcdefghijklmn",
          effective_from: "2026-09-09T00:00:00Z",
          version_public_id: "veridabcdefghijklmnop",
          end_href:
            "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications/schedidabcdefghijklmn",
        },
      ],
    });

    expect(screen.getByText(/Scheduled for 2026-09-09/u)).toBeTruthy();

    await user.type(screen.getByRole("textbox", { name: "Reason for cancelling" }), "called off");
    await user.click(screen.getByRole("button", { name: "Cancel" }));

    expect(destroy).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications/schedidabcdefghijklmn",
      { data: { publication: { reason: "called off" } } },
    );
  });

  it("archives with a reason and restores without one", async () => {
    const user = userEvent.setup();
    const { unmount } = renderShow();

    await user.type(screen.getByRole("textbox", { name: "Reason for archiving" }), "duplicate");
    await user.click(screen.getByRole("button", { name: "Archive" }));

    expect(post).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/archive",
      { archive: { reason: "duplicate" } },
    );
    unmount();

    renderShow({ entry: { ...entry, archive_state: "archived", archive_reason: "duplicate" } });

    await user.click(screen.getByRole("button", { name: "Restore" }));

    expect(destroy).toHaveBeenCalledWith(
      "/publishing/docs/app/entries/pubidabcdefghijklmnop/archive",
    );
    expect(screen.queryByRole("button", { name: "Archive" })).toBeNull();
  });

  it("renders a refused lifecycle change as an alert on the entry page", () => {
    renderShow({
      errors: { base: "a published entry cannot be archived; end its publication first" },
    });

    const alerts = screen.getAllByRole("alert").map((node) => node.textContent);

    expect(alerts).toContain("a published entry cannot be archived; end its publication first");
  });

  it("names a refused effective_from and a refused unpublish reason", () => {
    const { unmount } = renderShow({ errors: { effective_from: "must be in the future" } });

    expect(screen.getAllByRole("alert").map((node) => node.textContent)).toContain(
      "must be in the future",
    );
    unmount();

    renderShow({
      entry: { ...entry, publication_state: "published", version_count: 1 },
      publication: {
        public_id: "pubpubidabcdefghijklm",
        effective_from: "2026-09-05T00:00:00Z",
        version_public_id: "veridabcdefghijklmnop",
        end_href:
          "/publishing/docs/app/entries/pubidabcdefghijklmnop/publications/pubpubidabcdefghijklm",
      },
      errors: { reason: "can't be blank" },
    });

    expect(screen.getAllByRole("alert").map((node) => node.textContent)).toContain(
      "can't be blank",
    );
  });

  it("renders an archived entry without a reason as an empty archived label", () => {
    renderShow({ entry: { ...entry, archive_state: "archived", archive_reason: null } });

    expect(screen.getByText("archived:")).toBeTruthy();
  });
});
