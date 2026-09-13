import { act, useState } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { present } from "../../support/present";

// The base/app self-service pages moved out of ERB, so the markup and the form handlers are now
// covered here. Inertia is mocked because these specs exercise the components, not the transport.
const post = vi.fn();
const patch = vi.fn();
const deleteRequest = vi.fn();
let formErrors: Record<string, string> = {};

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: deleteRequest },
  usePage: () => ({ props: {} }),
  useForm: (initial: Record<string, unknown>) => {
    const [data, setDataState] = useState(initial);

    return {
      data,
      setData: (key: string, value: unknown) =>
        setDataState((current) => ({ ...current, [key]: value })),
      errors: formErrors,
      processing: false,
      post,
      patch,
    };
  },
}));

const { default: SelfServiceShell } = await import("@/features/self_service/Shell");
const { default: EntityList } = await import("@/features/self_service/EntityList");
const { default: AvatarForm } = await import("@/features/self_service/AvatarForm");
const { default: BillingsIndex } = await import("@/pages/base/app/billings/index");
const { default: AvatarShow } = await import("@/pages/base/app/avatars/show");
const { default: SwitcherShow } = await import("@/pages/base/app/switchers/show");
const { default: SignInLimitationShow } = await import("@/pages/base/app/sign/in/limitations/show");

let container: HTMLDivElement | null = null;
let root: Root | null = null;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root?.render(element);
  });

  return container;
};

beforeEach(() => {
  formErrors = {};
});

afterEach(() => {
  if (root) {
    act(() => {
      root?.unmount();
    });
  }
  container?.remove();
  container = null;
  root = null;
  post.mockClear();
  patch.mockClear();
  deleteRequest.mockClear();
});

describe("SelfServiceShell", () => {
  it("renders the title and the body the server resolved", () => {
    const html = renderToStaticMarkup(
      <SelfServiceShell
        title="Account"
        body="account"
      />,
    );

    expect(html).toMatch(/<h1[^>]*>Account<\/h1>/u);
    expect(html).toContain("account");
    expect(html).toContain("Signed in");
    expect(html).not.toContain('href="/dashboard?ri=jp"');
  });

  it("renders the dashboard up link above the title when the server sent one", () => {
    const html = renderToStaticMarkup(
      <SelfServiceShell
        title="Account"
        body="account"
        up_link={{ label: "上へ", href: "/dashboard?ri=jp" }}
      />,
    );
    const upIndex = html.indexOf('href="/dashboard?ri=jp"');
    const titleIndex = html.search(/<h1[^>]*>Account<\/h1>/u);

    expect(html).toContain("上へ");
    expect(upIndex).toBeGreaterThan(-1);
    expect(upIndex).toBeLessThan(titleIndex);
  });
});

describe("EntityList", () => {
  const entries = [
    { public_id: "acc_1", label: "acc_1", href: "/accounts/acc_1?ri=jp" },
    { public_id: "acc_2", label: "acc_2", href: "/accounts/acc_2?ri=jp" },
  ];

  it("lists every entry with the href the server generated", () => {
    const html = renderToStaticMarkup(
      <EntityList
        title="Accounts"
        body="account"
        empty="None available"
        entries={entries}
      />,
    );

    expect(html).toMatch(/<h1[^>]*>Accounts<\/h1>/u);
    expect(html).toContain('href="/accounts/acc_1?ri=jp"');
    expect(html).toContain("acc_2");
    expect(html).not.toContain("None available");
  });

  it("renders the empty message when nothing is available", () => {
    const html = renderToStaticMarkup(
      <EntityList
        title="Accounts"
        body="account"
        empty="None available"
        entries={[]}
      />,
    );

    expect(html).toContain("None available");
    expect(html).not.toContain("<ul>");
  });

  it("renders the dashboard up link above the title when the server sent one", () => {
    const html = renderToStaticMarkup(
      <EntityList
        title="Accounts"
        body="account"
        empty="None available"
        entries={[]}
        up_link={{ label: "上へ", href: "/dashboard?ri=jp" }}
      />,
    );
    const upIndex = html.indexOf('href="/dashboard?ri=jp"');
    const titleIndex = html.search(/<h1[^>]*>Accounts<\/h1>/u);

    expect(html).toContain("上へ");
    expect(upIndex).toBeGreaterThan(-1);
    expect(upIndex).toBeLessThan(titleIndex);
  });
});

describe("BillingsIndex", () => {
  it("renders the heading and the translated description", () => {
    const html = renderToStaticMarkup(
      <BillingsIndex
        title="Billings"
        description="Sign in required."
      />,
    );

    // Matched as a heading rather than as exact markup: the class list is styling, and a
    // refresh of it is not a change to what this page says.
    expect(html).toMatch(/<h1[^>]*>Billings<\/h1>/u);
    expect(html).toContain("Sign in required.");
  });
});

describe("AvatarShow", () => {
  it("renders the moniker, the handle and the edit link", () => {
    const html = renderToStaticMarkup(
      <AvatarShow
        title="Avatar"
        moniker="First Avatar"
        handle="first"
        edit={{ label: "Edit", href: "/avatars/av_1/edit?ri=jp" }}
      />,
    );

    expect(html).toMatch(/<h1[^>]*>First Avatar<\/h1>/u);
    expect(html).toContain("first");
    expect(html).toContain('href="/avatars/av_1/edit?ri=jp"');
  });

  it("omits the handle and the edit link the server withheld", () => {
    const html = renderToStaticMarkup(
      <AvatarShow
        title="Avatar"
        moniker="First Avatar"
        handle={null}
        edit={null}
      />,
    );

    expect(html).not.toContain("<a");
    expect(html).toContain("First Avatar");
  });
});

describe("SwitcherShow", () => {
  const candidates = [
    { account_public_id: "acc_1", organization_public_id: "org_1", avatar_public_id: "av_1" },
  ];

  it("renders the current context, the candidates and a rejection", () => {
    const html = renderToStaticMarkup(
      <SwitcherShow
        title="Switcher"
        current={{
          account_public_id: "acc_1",
          organization_public_id: "org_1",
          organization_unit_public_id: "unit_1",
          avatar_public_id: "av_1",
        }}
        candidates={candidates}
        error="invalid switch"
      />,
    );

    expect(html).toMatch(/<h1[^>]*>Switcher<\/h1>/u);
    expect(html).toContain("unit_1");
    expect(html).toContain("invalid switch");
    expect(html).toContain('role="alert"');
  });

  it("reports an absent context without an error region", () => {
    const html = renderToStaticMarkup(
      <SwitcherShow
        title="Switcher"
        current={null}
        candidates={[]}
        error={null}
      />,
    );

    expect(html).toContain("No current context.");
    expect(html).not.toContain('role="alert"');
  });

  it("renders the dashboard up link above the title when the server sent one", () => {
    const html = renderToStaticMarkup(
      <SwitcherShow
        title="Switcher"
        current={null}
        candidates={[]}
        error={null}
        up_link={{ label: "上へ", href: "/dashboard?ri=jp" }}
      />,
    );
    const upIndex = html.indexOf('href="/dashboard?ri=jp"');
    const titleIndex = html.search(/<h1[^>]*>Switcher<\/h1>/u);

    expect(html).toContain("上へ");
    expect(upIndex).toBeGreaterThan(-1);
    expect(upIndex).toBeLessThan(titleIndex);
  });
});

describe("AvatarForm", () => {
  const createProps = {
    title: "New Avatar",
    heading: "New Avatar",
    action: "/avatars?ri=jp",
    method: "post" as const,
    submit_label: "Create Avatar",
    moniker: { label: "Name", value: "", maxlength: 120 },
    handle: { label: "Handle", value: "", maxlength: 80 },
  };
  const editProps = {
    ...createProps,
    title: "Avatar",
    heading: "Avatar",
    action: "/avatars/av_1?ri=jp",
    method: "patch" as const,
    submit_label: "Update Avatar",
    moniker: { label: "Name", value: "First Avatar", maxlength: 120 },
    handle: null,
  };

  it("renders the handle field only when the server sent one", () => {
    expect(renderToStaticMarkup(<AvatarForm {...createProps} />)).toContain("avatar_handle");
    expect(renderToStaticMarkup(<AvatarForm {...editProps} />)).not.toContain("avatar_handle");
  });

  it("renders the validation errors the server returned", () => {
    formErrors = { "avatar.moniker": "can't be blank", "avatar.handle": "is taken" };

    const html = renderToStaticMarkup(<AvatarForm {...createProps} />);

    expect(html).toContain("can&#x27;t be blank");
    expect(html).toContain("is taken");
  });

  it("edits both fields and posts to the create action", () => {
    const element = mount(<AvatarForm {...createProps} />);
    const moniker = present(
      element.querySelector<HTMLInputElement>("#avatar_moniker"),
      "the moniker field",
    );
    const handle = present(
      element.querySelector<HTMLInputElement>("#avatar_handle"),
      "the handle field",
    );
    const descriptor = present(
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")?.set,
      "the input value setter",
    );

    act(() => {
      descriptor.call(moniker, "Ada");
      moniker.dispatchEvent(new Event("input", { bubbles: true }));
    });
    act(() => {
      descriptor.call(handle, "ada");
      handle.dispatchEvent(new Event("input", { bubbles: true }));
    });
    act(() => {
      element
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/avatars?ri=jp");
    expect(patch).not.toHaveBeenCalled();
  });

  it("patches the update action", () => {
    const element = mount(<AvatarForm {...editProps} />);

    act(() => {
      element
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith("/avatars/av_1?ri=jp");
    expect(post).not.toHaveBeenCalled();
  });
});

describe("SignInLimitationShow", () => {
  const props = {
    title: "Session limit",
    heading: "Session limit",
    description: "Revoke one existing session to continue signing in.",
    session_label: "Session",
    error: null as string | null,
    notice: null as string | null,
    action: "/sign/in/limitation",
    cancel_action: "/sign/in/limitation?resolution_challenge=ch_1",
    submit_label: "Revoke and continue",
    cancel_label: "Cancel sign-in",
    resolution: { field: "resolution_challenge", value: "ch_1" },
    sessions: [
      {
        session_ref: "ref_1",
        restriction_label: "Restricted",
        created_label: "Created 01/02",
        last_used_label: "Last used 01/03",
        revoke_label: "Revoke this session",
      },
      {
        session_ref: "ref_2",
        restriction_label: "Normal",
        created_label: "Created 01/04",
        last_used_label: null,
        revoke_label: "Revoke this session",
      },
    ],
  };

  it("renders every session, with the never-used one lacking a last-used line", () => {
    const html = renderToStaticMarkup(<SignInLimitationShow {...props} />);

    expect(html).toContain("Restricted");
    expect(html).toContain("Normal");
    expect(html).toContain("Last used 01/03");
    expect(html).toContain('value="ref_2"');
    expect(html).not.toContain('role="alert"');
  });

  it("renders the error, the notice and the field error", () => {
    formErrors = { session_ref: "select a session" };

    const html = renderToStaticMarkup(
      <SignInLimitationShow
        {...props}
        error="revoke failed"
        notice="still full"
      />,
    );

    expect(html).toContain("revoke failed");
    expect(html).toContain("still full");
    expect(html).toContain("select a session");
  });

  it("selects a session, submits the patch and cancels with a delete", () => {
    const element = mount(<SignInLimitationShow {...props} />);
    const radio = element.querySelector<HTMLInputElement>('input[value="ref_1"]');

    act(() => {
      radio?.click();
    });

    expect(element.querySelector<HTMLInputElement>('input[value="ref_1"]')?.checked).toBe(true);

    act(() => {
      element
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith("/sign/in/limitation");

    act(() => {
      element.querySelector<HTMLButtonElement>('button[type="button"]')?.click();
    });

    expect(deleteRequest).toHaveBeenCalledWith("/sign/in/limitation?resolution_challenge=ch_1");
  });
});
