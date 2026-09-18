import type { router as inertiaRouter } from "@inertiajs/react";
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { acceptConfirmation, confirmationButtons } from "../../support/confirmation";
import { present } from "../../support/present";
import { finishVisit, startVisit } from "../../support/visit";

// Unlike the static markup spec, these tests mount the components and fire real DOM events, which
// is the only way to reach the submit handlers, the confirmation branches and the verb each form
// chooses.
// Typed from the adapter's own signatures, so an assertion on a recorded call is checked against
// the arguments Inertia actually passes rather than against `any`.
const get = vi.fn<typeof inertiaRouter.get>();
const post = vi.fn<typeof inertiaRouter.post>();
const patch = vi.fn<typeof inertiaRouter.patch>();
const destroy = vi.fn<typeof inertiaRouter.delete>();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get, post, patch, delete: destroy },
  usePage: () => ({ props: {} }),
}));

// The real widget talks to the Cloudflare API script the surface layout loads, which does not exist
// in jsdom. The stub publishes a token so the submitted payload can be asserted.
vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ onToken }: { onToken?: (token: string) => void }) => (
    <button
      type="button"
      data-testid="solve-turnstile"
      onClick={() => onToken?.("turnstile-token")}
    >
      solve
    </button>
  ),
}));

const { default: DestructiveButton } =
  await import("@/features/base_com/identity/DestructiveButton");
const { default: SessionsIndex } = await import("@/features/base_com/identity/SessionsIndex");
const { default: SecretCredentialsIndex } =
  await import("@/features/base_com/identity/SecretCredentialsIndex");
const { default: SecretCredentialForm } =
  await import("@/features/base_com/identity/SecretCredentialForm");
const { default: EmailEdit } = await import("@/features/base_com/identity/EmailEdit");
const { default: EmailRegistrationNew } =
  await import("@/features/base_com/identity/EmailRegistrationNew");
const { default: OtpCodeForm } = await import("@/features/base_com/identity/OtpCodeForm");
const { default: OtpReentryNew } = await import("@/features/base_com/identity/OtpReentryNew");
const { default: TelephoneRegistrationNew } =
  await import("@/features/base_com/identity/TelephoneRegistrationNew");
const { default: PrivacyErasureNew } =
  await import("@/features/base_com/identity/PrivacyErasureNew");
const { default: EnforcementRecoveryShow } =
  await import("@/features/base_com/identity/EnforcementRecoveryShow");
const { default: WithdrawalNew } = await import("@/features/base_com/identity/WithdrawalNew");
const { default: WithdrawalEdit } = await import("@/features/base_com/identity/WithdrawalEdit");

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const submitForm = (index = 0) => {
  const form = present(container.querySelectorAll("form")[index], `form ${index}`);
  act(() => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
};

const click = (selector: string) => {
  const element = container.querySelector<HTMLElement>(selector);
  act(() => {
    element?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

// The confirmation is a rendered dialog now, so accepting it is a click on its confirm button
// rather than a stubbed `window.confirm`.

const declineConfirmation = () => {
  const [button] = confirmationButtons();
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

const setInput = (selector: string, value: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
  act(() => {
    descriptor?.set?.call(input, value);
    input?.dispatchEvent(new Event("input", { bubbles: true }));
  });
};

const toggle = (selector: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  act(() => {
    input?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  get.mockClear();
  post.mockClear();
  patch.mockClear();
  destroy.mockClear();
  vi.restoreAllMocks();
});

const turnstile = { site_key: "site-key", mode: "execute" as const, action: null, cdata: null };

describe("DestructiveButton", () => {
  const action = { label: "Delete", url: "/identity/emails/e1", confirm: "Sure?" };

  it("issues the DELETE the route expects once the confirmation is accepted", () => {
    mount(<DestructiveButton action={action} />);
    submitForm();
    acceptConfirmation();

    expect(destroy).toHaveBeenCalledWith("/identity/emails/e1", expect.objectContaining({}));
  });

  it("forwards extra payload when the server named some", () => {
    mount(
      <DestructiveButton
        action={action}
        data={{ challenge: "tok" }}
      />,
    );
    submitForm();
    acceptConfirmation();

    expect(destroy).toHaveBeenCalledWith(
      "/identity/emails/e1",
      expect.objectContaining({ data: { challenge: "tok" } }),
    );
  });

  it("does nothing when the confirmation is declined", () => {
    mount(<DestructiveButton action={action} />);
    submitForm();
    declineConfirmation();

    expect(destroy).not.toHaveBeenCalled();
  });

  it("toggles the processing state around the request", () => {
    mount(<DestructiveButton action={action} />);
    submitForm();
    acceptConfirmation();

    const [, options] = present(destroy.mock.calls[0], "the first router.delete call");
    act(() => {
      startVisit(options);
    });
    expect(container.querySelector("button")?.disabled).toBe(true);
    act(() => {
      finishVisit(options);
    });
    expect(container.querySelector("button")?.disabled).toBe(false);
  });
});

describe("SessionsIndex", () => {
  const props = {
    title: "Sessions",
    back_link: { label: "Back", href: "/identity" },
    expires_at_description: "This session ends at its expiry and cannot be extended.",
    columns: {
      device: "Device",
      last_activity: "Last activity",
      created: "Created",
      expires_at: "Expires at",
      status: "Status",
      action: "Action",
    },
    empty_message: "No active sessions were found.",
    bulk_revocations: {
      others: { label: "Revoke others", href: "/identity/other_sessions", confirm: "Sure?" },
    },
    sessions: [
      {
        device: "Firefox / Linux",
        last_activity: "2026-01-01",
        created: "2026-01-01",
        expires_at: "2026-02-01",
        status: "Active",
        revoke: { label: "Revoke", href: "/identity/sessions/sess-2", confirm: "Sure?" },
      },
    ],
  };

  it("revokes the selected session with DELETE", () => {
    const submit = vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(() => {});
    mount(<SessionsIndex {...props} />);
    submitForm(1);
    acceptConfirmation();

    expect(submit).toHaveBeenCalledTimes(1);
    expect(container.querySelectorAll("form")[1]?.getAttribute("action")).toBe(
      "/identity/sessions/sess-2",
    );
  });

  it("keeps the bulk revocations behind their confirmation", () => {
    const submit = vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(() => {});
    mount(<SessionsIndex {...props} />);
    submitForm(0);
    declineConfirmation();

    expect(submit).not.toHaveBeenCalled();
  });

  it("posts the server-provided bulk revocation action", () => {
    const submit = vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(() => {});
    mount(<SessionsIndex {...props} />);
    submitForm(0);
    acceptConfirmation();

    expect(submit).toHaveBeenCalledTimes(1);
    expect(container.querySelectorAll("form")[0]?.getAttribute("action")).toBe(
      "/identity/other_sessions",
    );
  });
});

describe("SecretCredentialsIndex", () => {
  const props = {
    title: "Secrets",
    back_link: { label: "Back", href: "/identity" },
    new_link: { label: "New", href: "/identity/secrets/new" },
    columns: { name: "Name", created: "Created", last_used: "Last used", actions: "Actions" },
    destroy_confirm: "Sure?",
    destroy_label: "Destroy",
    turnstile,
    credentials: [
      {
        public_id: "s1",
        name: "laptop",
        created_at: "2026-01-01",
        last_used_at: "-",
        show_link: { label: "Show", href: "/identity/secrets/s1" },
        edit_link: { label: "Edit", href: "/identity/secrets/s1/edit" },
        destroy_url: "/identity/secrets/s1",
      },
    ],
  };

  it("sends the challenge token with the removal", () => {
    mount(<SecretCredentialsIndex {...props} />);
    click("[data-testid='solve-turnstile']");
    submitForm();
    acceptConfirmation();

    expect(destroy).toHaveBeenCalledWith(
      "/identity/secrets/s1",
      expect.objectContaining({ data: { "cf-turnstile-response": "turnstile-token" } }),
    );
    const [, options] = present(destroy.mock.calls[0], "the first router.delete call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });

  it("does not remove when the confirmation is declined", () => {
    mount(<SecretCredentialsIndex {...props} />);
    submitForm();
    declineConfirmation();

    expect(destroy).not.toHaveBeenCalled();
  });
});

describe("SecretCredentialForm", () => {
  const base = {
    title: "Secret",
    description: "Store it now.",
    errors: null,
    name_label: "Name",
    name_value: "abcd",
    enabled_label: "Enabled",
    enabled: false,
    cancel_link: { label: "Cancel", href: "/identity/secrets" },
    turnstile,
  };

  it("creates with POST and carries the challenge token", () => {
    mount(
      <SecretCredentialForm
        {...base}
        form={{
          url: "/identity/secrets",
          method: "post",
          scope: "visitor_secret_credential",
          submit_label: "Save",
        }}
      />,
    );
    click("[data-testid='solve-turnstile']");
    setInput("#visitor_secret_credential_name", "office");
    toggle("#visitor_secret_credential_enabled");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/secrets",
      {
        visitor_secret_credential: { name: "office", enabled: "1" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });

  it("renames with PATCH", () => {
    mount(
      <SecretCredentialForm
        {...base}
        form={{
          url: "/identity/secrets/s1",
          method: "patch",
          scope: "visitor_secret_credential",
          submit_label: "Update",
        }}
      />,
    );
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/secrets/s1",
      expect.objectContaining({ visitor_secret_credential: { name: "abcd", enabled: "0" } }),
      expect.objectContaining({}),
    );
  });
});

describe("EmailEdit", () => {
  it("submits both preference toggles and the challenge token as a PATCH", () => {
    mount(
      <EmailEdit
        title="Email"
        address="person@example.com"
        errors={[]}
        always_on={{ label: "Always on", description: "Transactional." }}
        promotional={{ label: "Promotional", description: "Offers.", checked: false }}
        notifiable={{ label: "Notifiable", description: "Alerts.", checked: true }}
        form={{ url: "/identity/emails/e1", scope: "visitor_email", submit_label: "Save" }}
        destroy={{ label: "Delete", url: "/identity/emails/e1", confirm: "Sure?" }}
        cancel_link={{ label: "Cancel", href: "/identity/emails" }}
        turnstile={turnstile}
      />,
    );
    click("[data-testid='solve-turnstile']");
    submitForm();
    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/e1",
      {
        visitor_email: { promotional: "0", notifiable: "1" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    patch.mockClear();
    click("[data-testid='solve-turnstile']");
    toggle("#visitor_email_promotional");
    toggle("#visitor_email_notifiable");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/e1",
      {
        visitor_email: { promotional: "1", notifiable: "0" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    const [, , options] = present(patch.mock.calls[0], "the first router.patch call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });
});

describe("EmailRegistrationNew", () => {
  it("posts the address, the preference and the token", () => {
    mount(
      <EmailRegistrationNew
        title="Add email"
        back_link={{ label: "Back", href: "/identity/emails" }}
        errors={[]}
        form={{
          url: "/identity/emails/registration",
          method: "post",
          scope: "visitor_email",
          submit_label: "Create",
        }}
        address_label="Address"
        address_value=""
        notifiable={{ label: "Notifiable", description: "Alerts.", checked: false }}
        cancel_link={{ label: "Cancel", href: "/identity/emails" }}
        turnstile={turnstile}
      />,
    );
    click("[data-testid='solve-turnstile']");
    setInput("#visitor_email_address", "person@example.com");
    submitForm();
    expect(post).toHaveBeenCalledWith(
      "/identity/emails/registration",
      {
        visitor_email: { address: "person@example.com", notifiable: "0" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    post.mockClear();
    click("[data-testid='solve-turnstile']");
    toggle("#visitor_email_notifiable");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/emails/registration",
      {
        visitor_email: { address: "person@example.com", notifiable: "1" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });
});

describe("OtpCodeForm", () => {
  const base = {
    title: "Verify",
    description: "A code was sent.",
    errors: [],
    form: {
      url: "/identity/emails/registration",
      method: "patch" as const,
      scope: "visitor_email",
      submit_label: "Continue",
    },
    code_label: "Code",
    code_placeholder: "123456",
    delivery_help: "Check your inbox.",
    cancel_link: { label: "Cancel", href: "/identity/emails" },
    turnstile,
  };

  it("patches the code without a token when the server sent none", () => {
    mount(<OtpCodeForm {...base} />);
    click("[data-testid='solve-turnstile']");
    setInput("#visitor_email_pass_code", "123456");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/registration",
      {
        visitor_email: { pass_code: "123456" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    const [, , options] = present(patch.mock.calls[0], "the first router.patch call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });

  it("carries the verification token back when the server sent one", () => {
    mount(
      <OtpCodeForm
        {...base}
        verification_token="tok"
      />,
    );
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/registration",
      expect.objectContaining({
        visitor_email: { pass_code: "", token: "tok" },
      }),
      expect.objectContaining({}),
    );
  });
});

describe("TelephoneRegistrationNew", () => {
  it("posts the raw number and the token", () => {
    mount(
      <TelephoneRegistrationNew
        title="Add telephone"
        description="Enter a number."
        errors={[]}
        form={{
          url: "/identity/telephones/registration",
          method: "post",
          scope: "visitor_telephone",
          submit_label: "Submit",
        }}
        number_label="Number"
        number_placeholder="+819012345678"
        help_text="Use E.164."
        cancel_link={{ label: "Cancel", href: "/identity/telephones" }}
        turnstile={turnstile}
      />,
    );
    click("[data-testid='solve-turnstile']");
    setInput("#visitor_telephone_raw_number", "+819012345678");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/telephones/registration",
      {
        visitor_telephone: { raw_number: "+819012345678" },
        "cf-turnstile-response": "turnstile-token",
      },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });
});

describe("OtpReentryNew", () => {
  const addressForm = {
    url: "/identity/recovery/session",
    scope: "recovery_reentry",
    field: "address",
    label: "Email address",
    value: "",
    submit_label: "Send verification code",
  };

  it("posts the address", () => {
    mount(
      <OtpReentryNew
        title="Account recovery"
        description=""
        address_form={addressForm}
        pass_code_form={null}
      />,
    );
    setInput("#recovery_reentry_address", "person@example.com");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/session",
      { recovery_reentry: { address: "person@example.com" } },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });

  it("posts the delivered code on the second form", () => {
    mount(
      <OtpReentryNew
        title="Account recovery"
        description="A code will be sent."
        address_form={addressForm}
        pass_code_form={{
          url: "/identity/recovery/session",
          field: "pass_code",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );
    setInput("#pass_code", "654321");
    submitForm(1);

    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/session",
      { pass_code: "654321" },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the pass-code router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });
});

describe("PrivacyErasureNew", () => {
  it("posts the jurisdiction the server chose", () => {
    mount(
      <PrivacyErasureNew
        title="Early erasure"
        paragraphs={["Separate from withdrawal."]}
        form={{
          url: "/identity/privacy/erasure",
          jurisdiction: "unknown",
          submit_label: "Request",
        }}
      />,
    );
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/privacy/erasure",
      { jurisdiction: "unknown" },
      expect.objectContaining({}),
    );
    const [, , options] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });
});

describe("EnforcementRecoveryShow", () => {
  it("posts the restore request and the appeal for the case they belong to", () => {
    mount(
      <EnforcementRecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "c1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              scope: "appeal",
              reason_label: "Appeal reason",
              reason_codes: [
                { label: "mistake", value: "mistake" },
                { label: "other", value: "other" },
              ],
              statement_label: "Appeal statement",
              statement_max_length: 500,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    submitForm(0);
    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/completion",
      { enforcement_case_id: "c1" },
      expect.objectContaining({}),
    );
    const [, , restoreOptions] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(restoreOptions);
    });
    act(() => {
      finishVisit(restoreOptions);
    });

    submitForm(1);
    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      {
        appeal: { enforcement_case_id: "c1", reason_code: "mistake", statement: "" },
      },
      expect.objectContaining({}),
    );
    const [, , appealOptions] = present(post.mock.calls[1], "the second router.post call");
    act(() => {
      startVisit(appealOptions);
    });
    act(() => {
      finishVisit(appealOptions);
    });
  });

  it("updates the appeal reason when the visitor chooses another code", () => {
    mount(
      <EnforcementRecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "c1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              scope: "appeal",
              reason_label: "Appeal reason",
              reason_codes: [
                { label: "mistake", value: "mistake" },
                { label: "other", value: "other" },
              ],
              statement_label: "Appeal statement",
              statement_max_length: 500,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    const select = container.querySelector<HTMLSelectElement>("select")!;
    act(() => {
      select.value = "other";
      select.dispatchEvent(new Event("change", { bubbles: true }));
    });
    submitForm(1);

    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      {
        appeal: { enforcement_case_id: "c1", reason_code: "other", statement: "" },
      },
      expect.objectContaining({}),
    );
  });

  it("falls back to an empty reason when the server offered no choices", () => {
    mount(
      <EnforcementRecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "c2",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              scope: "appeal",
              reason_label: "Appeal reason",
              reason_codes: [],
              statement_label: "Appeal statement",
              statement_max_length: 500,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );
    submitForm(1);

    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      { appeal: { enforcement_case_id: "c2", reason_code: "", statement: "" } },
      expect.objectContaining({}),
    );
  });
});

describe("WithdrawalNew", () => {
  const schedule = {
    title: "Schedule",
    errors: [],
    url: "/identity/withdrawal/new",
    method: "get" as const,
    field: "ack_schedule_purge",
    ack_label: "I understand",
    checked: false,
    submit_label: "Continue",
  };

  const deactivate = {
    title: "Deactivate",
    errors: [],
    url: "/identity/withdrawal",
    method: "patch" as const,
    field: "ack_deactivate_today",
    ack_label: "Deactivate today",
    submit_label: "Deactivate",
    confirm: "Sure?",
  };

  const props = {
    title: "Withdrawal",
    already_deactivated: false,
    already_deactivated_message: "Already deactivated.",
    recovery_link: { label: "Recover", href: "/identity/withdrawal/edit" },
    schedule,
    deactivate,
  };

  it("acknowledges the schedule with the GET the route expects", () => {
    mount(<WithdrawalNew {...props} />);
    toggle("#ack_schedule_purge");
    submitForm(0);

    expect(get).toHaveBeenCalledWith(
      "/identity/withdrawal/new",
      { ack_schedule_purge: "1" },
      expect.objectContaining({}),
    );
    const [, , options] = present(get.mock.calls[0], "the first router.get call");
    act(() => {
      startVisit(options);
    });
    act(() => {
      finishVisit(options);
    });
  });

  it("deactivates with PATCH behind its confirmation", () => {
    mount(<WithdrawalNew {...props} />);
    submitForm(1);
    acceptConfirmation();

    expect(patch).toHaveBeenCalledWith(
      "/identity/withdrawal",
      { ack_deactivate_today: "0" },
      expect.objectContaining({}),
    );
  });

  it("does not deactivate when the confirmation is declined", () => {
    mount(<WithdrawalNew {...props} />);
    submitForm(1);
    declineConfirmation();

    expect(patch).not.toHaveBeenCalled();
  });
});

describe("WithdrawalEdit", () => {
  const props = {
    title: "Recovery",
    terminated: false,
    unavailable_message: "Recovery is unavailable.",
    deadline_message: "Recoverable until 2026-03-01",
    privacy_erasure_link: { label: "Erase", href: "/identity/privacy/erasure/new" },
    sign_out: { label: "Sign out", url: "/identity/withdrawal/session" },
    recovery: {
      available_message: "Recovery is available.",
      url: "/identity/withdrawal",
      submit_label: "Restore",
      confirm: "Sure?",
    },
    termination: {
      url: "/identity/withdrawal",
      submit_label: "Terminate now",
      confirm: "Sure?",
    },
  };

  it("restores with POST and terminates with DELETE", () => {
    mount(<WithdrawalEdit {...props} />);

    submitForm(0);
    acceptConfirmation();
    expect(post).toHaveBeenCalledWith("/identity/withdrawal", {}, expect.objectContaining({}));
    const [, , postOptions] = present(post.mock.calls[0], "the first router.post call");
    act(() => {
      startVisit(postOptions);
    });
    act(() => {
      finishVisit(postOptions);
    });

    submitForm(1);
    acceptConfirmation();
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal", expect.objectContaining({}));
    const [, deleteOptions] = present(destroy.mock.calls[0], "the first router.delete call");
    act(() => {
      startVisit(deleteOptions);
    });
    act(() => {
      finishVisit(deleteOptions);
    });
  });

  it("signs out of the ceremony with DELETE and no confirmation", () => {
    mount(<WithdrawalEdit {...props} />);
    submitForm(2);

    expect(destroy).toHaveBeenCalledWith(
      "/identity/withdrawal/session",
      expect.objectContaining({}),
    );
  });

  it("keeps the restore behind its confirmation", () => {
    mount(<WithdrawalEdit {...props} />);
    submitForm(0);
    declineConfirmation();

    expect(post).not.toHaveBeenCalled();
  });
});
