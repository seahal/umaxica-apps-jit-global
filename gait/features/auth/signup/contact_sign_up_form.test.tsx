import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import ContactSignUpForm, {
  type ContactSignUpFormProps,
} from "@/features/auth/signup/ContactSignUpForm";

const props: ContactSignUpFormProps = {
  title: "Register",
  action: "/sign/up/email",
  scope: "client_email",
  field: { name: "raw_address", label: "Email", type: "email", autocomplete: "email" },
  checkboxes: [],
  error_heading: null,
  errors: [],
  turnstile: { site_key: "test-site-key", mode: "render" },
  submit_label: "Send",
  links: [{ key: "back", label: "Back", href: "/sign/up?ri=jp" }],
  cancel: { label: "Cancel", action: "/sign/cancellation?ri=jp", method: "post" },
};

describe("ContactSignUpForm", () => {
  it("renders Back as a link and Cancel as a form the server decides", () => {
    const markup = renderToStaticMarkup(<ContactSignUpForm {...props} />);

    const document = new DOMParser().parseFromString(markup, "text/html");
    const back = document.querySelector('header a[href="/sign/up?ri=jp"]');
    expect(back?.textContent).toContain("Back");
    expect(document.querySelectorAll('a[href="/sign/up?ri=jp"]')).toHaveLength(1);
    expect(markup).toContain('action="/sign/cancellation?ri=jp"');
    expect(markup).toContain("Cancel");
  });

  it("omits Cancel when the ceremony has no cancellable parent", () => {
    const markup = renderToStaticMarkup(
      <ContactSignUpForm
        {...props}
        cancel={null}
      />,
    );

    expect(markup).not.toContain("/sign/cancellation");
    expect(markup).toContain('href="/sign/up?ri=jp"');
  });
});
