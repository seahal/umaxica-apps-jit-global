import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: {} }),
}));

const { default: EmailsIndex } = await import("@/features/base_com/identity/EmailsIndex");
const { default: SecretCredentialShow } =
  await import("@/features/base_com/identity/SecretCredentialShow");
const { default: EmailEdit } = await import("@/features/base_com/identity/EmailEdit");
const backLink = { label: "Back", href: "/identity?ri=jp" };

describe("identity page composition", () => {
  it("places parent navigation before the email list title and creation action in its header", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        title="Email addresses"
        back_link={backLink}
        new_link={{ label: "Register email", href: "/emails/new?ri=jp" }}
        columns={{ address: "Address", status: "Status", actions: "Actions" }}
        empty_message="No email addresses."
        emails={[]}
      />,
    );
    const document = new DOMParser().parseFromString(html, "text/html");
    const header = document.querySelector("header");
    expect(header).not.toBeNull();
    expect(header?.querySelector('a[href="/identity?ri=jp"]')).toBeInstanceOf(HTMLAnchorElement);
    expect(header?.querySelector('a[href="/emails/new?ri=jp"]')).toBeInstanceOf(HTMLAnchorElement);
    expect(header?.textContent).toMatch(/Back.*Email addresses.*Register email/su);
    expect(document.querySelector('table[aria-label="Email addresses"]')).not.toBeNull();
  });

  it("presents a credential name as detail text without skipping heading levels", () => {
    const html = renderToStaticMarkup(
      <SecretCredentialShow
        title="Credential"
        name="Example credential"
        created_term="Created"
        created_at="2026-10-05"
        last_used_term="Last used"
        last_used_at="Never"
        back_link={backLink}
        edit_link={{ label: "Edit credential", href: "/credentials/example/edit?ri=jp" }}
      />,
    );
    const document = new DOMParser().parseFromString(html, "text/html");
    expect(document.querySelector("h1")?.textContent).toBe("Credential");
    expect(document.querySelector("h3")).toBeNull();
    expect(document.querySelector("header")?.textContent).toContain("Example credential");
    expect(
      document.querySelector('header a[href="/credentials/example/edit?ri=jp"]'),
    ).not.toBeNull();
    expect(document.querySelectorAll("dt")).toHaveLength(2);
  });
});

it("connects each notification preference to its own visible explanation", () => {
  const html = renderToStaticMarkup(
    <EmailEdit
      title="Email preferences"
      address="example@example.test"
      errors={[]}
      always_on={{ label: "Account messages", description: "Always enabled." }}
      promotional={{ label: "Promotions", description: "Promotional messages.", checked: false }}
      notifiable={{ label: "Notifications", description: "Activity messages.", checked: true }}
      form={{ url: "/emails/example", scope: "email", submit_label: "Save" }}
      destroy={{
        url: "/emails/example",
        label: "Remove",
        confirm: "Remove address?",
      }}
      cancel_link={backLink}
      turnstile={{ site_key: "test", mode: "execute", action: null, cdata: null }}
    />,
  );
  const document = new DOMParser().parseFromString(html, "text/html");
  expect(
    document
      .querySelector('input[name="email[promotional]"]')
      ?.getAttribute("aria-describedby")
      ?.split(" "),
  ).toContain("email_promotional_description");
  expect(document.querySelector("#email_promotional_description")?.textContent).toBe(
    "Promotional messages.",
  );
  expect(
    document
      .querySelector('input[name="email[notifiable]"]')
      ?.getAttribute("aria-describedby")
      ?.split(" "),
  ).toContain("email_notifiable_description");
  expect(document.querySelector("#email_notifiable_description")?.textContent).toBe(
    "Activity messages.",
  );
});
