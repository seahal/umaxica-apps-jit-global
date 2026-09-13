import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The identity pages read `router` and `Link` from a booted Inertia application, and
// TurnstileWidget talks to the Cloudflare API script the surface layout loads. Both are stubbed so
// the server-rendered markup stays assertable.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: {} }),
}));

const { default: ActivityIndex } = await import("@/features/base_com/identity/ActivityIndex");
const { default: BirthdateShow } = await import("@/features/base_com/identity/BirthdateShow");
const { default: EmailsIndex } = await import("@/features/base_com/identity/EmailsIndex");
const { default: EmailEdit } = await import("@/features/base_com/identity/EmailEdit");
const { default: EmailRegistrationNew } =
  await import("@/features/base_com/identity/EmailRegistrationNew");
const { default: OtpCodeForm } = await import("@/features/base_com/identity/OtpCodeForm");
const { default: OtpReentryNew } = await import("@/features/base_com/identity/OtpReentryNew");
const { default: ErrorList } = await import("@/components/ui/ErrorList");
const { default: PrivacyErasureNew } =
  await import("@/features/base_com/identity/PrivacyErasureNew");
const { default: PrivacyErasureStatusShow } =
  await import("@/features/base_com/identity/PrivacyErasureStatusShow");
const { default: EnforcementRecoveryShow } =
  await import("@/features/base_com/identity/EnforcementRecoveryShow");
const { default: SecretCredentialsIndex } =
  await import("@/features/base_com/identity/SecretCredentialsIndex");
const { default: SecretCredentialShow } =
  await import("@/features/base_com/identity/SecretCredentialShow");
const { default: SecretCredentialForm } =
  await import("@/features/base_com/identity/SecretCredentialForm");
const { default: RecoveryPasscodesShow } =
  await import("@/features/base_com/identity/RecoveryPasscodesShow");
const { default: SessionsIndex } = await import("@/features/base_com/identity/SessionsIndex");
const { default: SessionShow } = await import("@/features/base_com/identity/SessionShow");
const { default: TelephonesIndex } = await import("@/features/base_com/identity/TelephonesIndex");
const { default: TelephoneEdit } = await import("@/features/base_com/identity/TelephoneEdit");
const { default: TelephoneRegistrationNew } =
  await import("@/features/base_com/identity/TelephoneRegistrationNew");
const { default: WithdrawalNew } = await import("@/features/base_com/identity/WithdrawalNew");
const { default: WithdrawalEdit } = await import("@/features/base_com/identity/WithdrawalEdit");

const backLink = { label: "Back", href: "/identity?ri=jp" };
const turnstile = { site_key: "site-key", mode: "execute" as const, action: null, cdata: null };

describe("ActivityIndex", () => {
  const columns = {
    occurred_at: "Occurred",
    event: "Event",
    ip_address: "IP",
    device: "Device",
    login_method: "Login method",
    context: "Context",
  };

  it("renders one row per activity", () => {
    const html = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent activity."
        back_link={backLink}
        empty_message="No activity."
        columns={columns}
        activities={[
          {
            id: "1",
            occurred_at: "2026-01-01",
            event_label: "Signed in",
            event_id: "my-login-event",
            ip_address: "203.0.113.1",
            device: "Chrome",
            login_method: "passkey",
            context: "{}",
          },
        ]}
      />,
    );

    expect(html).toContain("Signed in");
    expect(html).toContain("my-login-event");
    expect(html).toContain("203.0.113.1");
    expect(html).not.toContain("No activity.");
  });

  it("renders the empty message when there is nothing to show", () => {
    const html = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent activity."
        back_link={backLink}
        empty_message="No activity."
        columns={columns}
        activities={[]}
      />,
    );

    expect(html).toContain("No activity.");
    expect(html).not.toContain("<table>");
  });
});

describe("BirthdateShow", () => {
  const props = {
    title: "Birthdate",
    description: "Your birthdate.",
    back_link: backLink,
    birthdate_label: "Birthdate",
    not_set: "Not set",
    change_unavailable: "Cannot be changed.",
  };

  it("shows the stored birthdate", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...props}
        birthdate="2000-01-01"
      />,
    );

    expect(html).toContain("2000-01-01");
    expect(html).not.toContain("Not set");
  });

  it("shows the not-set wording when there is no birthdate", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...props}
        birthdate={null}
      />,
    );

    expect(html).toContain("Not set");
  });
});

describe("EmailsIndex", () => {
  const base = {
    title: "Emails",
    back_link: backLink,
    new_link: { label: "Add", href: "/identity/emails/registration/new" },
    columns: { address: "Address", status: "Status", actions: "Actions" },
    empty_message: "No emails.",
  };

  it("lists every email with its server-resolved status", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...base}
        emails={[
          {
            public_id: "e1",
            address: "person@example.com",
            status_label: "Verified",
            edit_link: { label: "Edit", href: "/identity/emails/e1/edit" },
          },
        ]}
      />,
    );

    expect(html).toContain("person@example.com");
    expect(html).toContain("Verified");
    expect(html).toContain("/identity/emails/e1/edit");
    expect(html).not.toContain("No emails.");
  });

  it("renders the empty row when the visitor has no email", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...base}
        emails={[]}
      />,
    );

    expect(html).toContain("No emails.");
  });
});

describe("TelephonesIndex", () => {
  const base = {
    title: "Telephones",
    back_link: backLink,
    new_link: { label: "Add", href: "/identity/telephones/registration/new" },
    columns: { number: "Number", status: "Status", actions: "Actions" },
    empty_message: "No telephones.",
  };

  it("lists every telephone", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        {...base}
        telephones={[
          {
            public_id: "t1",
            number: "+819012345678",
            status_label: "Unverified",
            edit_link: { label: "Edit", href: "/identity/telephones/t1/edit" },
          },
        ]}
      />,
    );

    expect(html).toContain("+819012345678");
    expect(html).toContain("Unverified");
  });

  it("renders the empty row", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        {...base}
        telephones={[]}
      />,
    );

    expect(html).toContain("No telephones.");
  });
});

describe("EmailEdit", () => {
  it("renders the preference checkboxes at their saved state", () => {
    const html = renderToStaticMarkup(
      <EmailEdit
        title="Email"
        address="person@example.com"
        errors={["Address is invalid"]}
        always_on={{ label: "Always on", description: "Transactional email." }}
        promotional={{ label: "Promotional", description: "Offers.", checked: true }}
        notifiable={{ label: "Notifiable", description: "Alerts.", checked: false }}
        form={{ url: "/identity/emails/e1", scope: "visitor_email", submit_label: "Save" }}
        destroy={{ label: "Delete", url: "/identity/emails/e1", confirm: "Sure?" }}
        cancel_link={{ label: "Cancel", href: "/identity/emails" }}
        turnstile={turnstile}
      />,
    );

    expect(html).toContain('name="visitor_email[promotional]"');
    expect(html).toContain("Address is invalid");
    expect(html).toContain('name="cf-turnstile-response"');
  });
});

describe("EmailRegistrationNew", () => {
  it("renders the address field and the challenge", () => {
    const html = renderToStaticMarkup(
      <EmailRegistrationNew
        title="Add email"
        back_link={backLink}
        errors={[]}
        form={{
          url: "/identity/emails/registration",
          method: "post",
          scope: "visitor_email",
          submit_label: "Create",
        }}
        address_label="Address"
        address_value=""
        notifiable={{ label: "Notifiable", description: "Alerts.", checked: true }}
        cancel_link={{ label: "Cancel", href: "/identity/emails" }}
        turnstile={turnstile}
      />,
    );

    expect(html).toContain('name="visitor_email[address]"');
    expect(html).toContain('type="email"');
    expect(html).toContain('name="cf-turnstile-response"');
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

  it("marks the code field as a one-time code", () => {
    const html = renderToStaticMarkup(<OtpCodeForm {...base} />);

    expect(html).toContain('name="visitor_email[pass_code]"');
    expect(html).toContain("one-time-code");
    expect(html).not.toContain('name="visitor_email[token]"');
  });

  it("echoes the verification token back when the server sent one", () => {
    const html = renderToStaticMarkup(
      <OtpCodeForm
        {...base}
        verification_token="tok"
      />,
    );

    expect(html).toContain('name="visitor_email[token]"');
    expect(html).toContain('value="tok"');
  });
});

describe("TelephoneRegistrationNew", () => {
  it("renders the number field with the server placeholder", () => {
    const html = renderToStaticMarkup(
      <TelephoneRegistrationNew
        title="Add telephone"
        description="Enter a number."
        errors={["Number is invalid"]}
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

    expect(html).toContain('name="visitor_telephone[raw_number]"');
    expect(html).toContain("+819012345678");
    expect(html).toContain("Number is invalid");
  });
});

describe("TelephoneEdit", () => {
  it("offers removal only", () => {
    const html = renderToStaticMarkup(
      <TelephoneEdit
        title="Telephone"
        number="+819012345678"
        destroy={{ label: "Delete", url: "/identity/telephones/t1", confirm: "Sure?" }}
        cancel_link={{ label: "Cancel", href: "/identity/telephones" }}
      />,
    );

    expect(html).toContain("Delete");
    expect(html).toContain("+819012345678");
  });
});

describe("ErrorList", () => {
  it("renders nothing when there is no error", () => {
    expect(renderToStaticMarkup(<ErrorList errors={[]} />)).toBe("");
  });

  it("renders the header when one is given", () => {
    const html = renderToStaticMarkup(
      <ErrorList
        errors={["Name is required"]}
        header="1 error"
      />,
    );

    expect(html).toContain("1 error");
    expect(html).toContain("Name is required");
  });
});

describe("SecretCredentialsIndex", () => {
  it("renders one destroy form per credential", () => {
    const html = renderToStaticMarkup(
      <SecretCredentialsIndex
        title="Secrets"
        back_link={backLink}
        new_link={{ label: "New", href: "/identity/secrets/new" }}
        columns={{ name: "Name", created: "Created", last_used: "Last used", actions: "Actions" }}
        destroy_confirm="Sure?"
        destroy_label="Destroy"
        turnstile={turnstile}
        credentials={[
          {
            public_id: "s1",
            name: "laptop",
            created_at: "2026-01-01",
            last_used_at: "-",
            show_link: { label: "Show", href: "/identity/secrets/s1" },
            edit_link: { label: "Edit", href: "/identity/secrets/s1/edit" },
            destroy_url: "/identity/secrets/s1",
          },
        ]}
      />,
    );

    expect(html).toContain("laptop");
    expect(html).toContain("Destroy");
    expect(html).toContain('name="cf-turnstile-response"');
  });
});

describe("SecretCredentialShow", () => {
  it("renders the credential metadata", () => {
    const html = renderToStaticMarkup(
      <SecretCredentialShow
        title="Secret"
        name="laptop"
        created_term="Created"
        created_at="2026-01-01"
        last_used_term="Last used"
        last_used_at="Never"
        back_link={{ label: "Back", href: "/identity/secrets" }}
        edit_link={{ label: "Edit", href: "/identity/secrets/s1/edit" }}
      />,
    );

    expect(html).toContain("laptop");
    expect(html).toContain("Never");
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
    enabled: true,
    cancel_link: { label: "Cancel", href: "/identity/secrets" },
    turnstile,
  };

  it("reveals the one-time secret on the create page", () => {
    const html = renderToStaticMarkup(
      <SecretCredentialForm
        {...base}
        form={{
          url: "/identity/secrets",
          method: "post",
          scope: "visitor_secret_credential",
          submit_label: "Save",
        }}
        secret={{ label: "Secret", value: "raw-secret", one_time_notice: "Shown once." }}
      />,
    );

    expect(html).toContain("raw-secret");
    expect(html).toContain("Shown once.");
  });

  it("omits the secret and shows the error header on the edit page", () => {
    const html = renderToStaticMarkup(
      <SecretCredentialForm
        {...base}
        errors={{ header: "1 error", messages: ["Name is required"] }}
        form={{
          url: "/identity/secrets/s1",
          method: "patch",
          scope: "visitor_secret_credential",
          submit_label: "Update",
        }}
      />,
    );

    expect(html).not.toContain("raw-secret");
    expect(html).toContain("1 error");
    expect(html).toContain("Name is required");
  });
});

describe("RecoveryPasscodesShow", () => {
  const base = {
    title: "Recovery codes",
    description: "Keep them safe.",
    one_time_notice: "Shown once.",
    inventory_notice: "Ten codes.",
    missing_message: "Nothing to show.",
    back_link: { label: "Back", href: "https://example.test/identity" },
  };

  it("lists the revealed passcodes", () => {
    const html = renderToStaticMarkup(
      <RecoveryPasscodesShow
        {...base}
        passcodes={["aaa-bbb", "ccc-ddd"]}
      />,
    );

    expect(html).toContain("aaa-bbb");
    expect(html).toContain("Shown once.");
    expect(html).not.toContain("Nothing to show.");
  });

  it("explains when the reveal is gone", () => {
    const html = renderToStaticMarkup(
      <RecoveryPasscodesShow
        {...base}
        passcodes={[]}
      />,
    );

    expect(html).toContain("Nothing to show.");
  });
});

describe("SessionsIndex", () => {
  const base = {
    title: "Sessions",
    back_link: backLink,
    columns: ["Session", "Kind", "Binding", "Last activity", "Created", "Refresh expires", ""],
    empty_message: "No active sessions were found.",
    current_label: "current",
  };

  const row = {
    public_id: "sess-1",
    current: true,
    status: "1",
    kind: "2",
    binding: "DBSC",
    last_activity: "2026-01-01",
    created: "2026-01-01",
    refresh_expires: "2026-02-01",
    revoke: null,
  };

  it("offers no bulk revocation when only the current session exists", () => {
    const html = renderToStaticMarkup(
      <SessionsIndex
        {...base}
        bulk_actions={null}
        sessions={[row]}
      />,
    );

    expect(html).toContain("sess-1");
    expect(html).toContain("current");
    expect(html).not.toContain("Revoke other sessions");
  });

  it("offers bulk and per-row revocation when the server sent them", () => {
    const html = renderToStaticMarkup(
      <SessionsIndex
        {...base}
        bulk_actions={{
          revoke_others: {
            label: "Revoke other sessions",
            url: "/identity/other_sessions",
            confirm: "Sure?",
          },
        }}
        sessions={[
          row,
          {
            ...row,
            public_id: "sess-2",
            current: false,
            revoke: { label: "Revoke", url: "/identity/sessions/sess-2", confirm: "Sure?" },
          },
        ]}
      />,
    );

    expect(html).toContain("Revoke other sessions");
    expect(html).not.toContain("Revoke all sessions");
    expect(html).toContain("sess-2");
  });

  it("reports an empty inventory", () => {
    const html = renderToStaticMarkup(
      <SessionsIndex
        {...base}
        bulk_actions={null}
        sessions={[]}
      />,
    );

    expect(html).toContain("No active sessions were found.");
  });
});

describe("SessionShow", () => {
  it("renders each detail as a definition", () => {
    const html = renderToStaticMarkup(
      <SessionShow
        title="Session"
        back_link={{ label: "Back", href: "/identity/sessions" }}
        items={[
          { term: "Session", description: "sess-1" },
          { term: "Binding", description: "NORMAL" },
        ]}
      />,
    );

    expect(html).toContain("sess-1");
    expect(html).toContain("NORMAL");
  });
});

describe("PrivacyErasureNew", () => {
  it("renders the retention notices and the jurisdiction the server chose", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureNew
        title="Early erasure"
        paragraphs={["Separate from withdrawal.", "Some data is retained."]}
        form={{
          url: "/identity/privacy/erasure",
          jurisdiction: "unknown",
          submit_label: "Request",
        }}
      />,
    );

    expect(html).toContain("Separate from withdrawal.");
    expect(html).toContain('name="jurisdiction"');
    expect(html).toContain('value="unknown"');
  });
});

describe("PrivacyErasureStatusShow", () => {
  it("renders the active request", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Status"
        empty_message="No privacy erasure request is active."
        privacy_request={{
          status_term: "Status",
          status_label: "received",
          received_term: "Received",
          received_at: "2026-01-01T00:00:00Z",
          response_due_term: "Response due",
          response_due_at: "2026-02-01T00:00:00Z",
        }}
      />,
    );

    expect(html).toContain("received");
    expect(html).toContain("2026-02-01T00:00:00Z");
  });

  it("reports when nothing is active", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Status"
        empty_message="No privacy erasure request is active."
        privacy_request={null}
      />,
    );

    expect(html).toContain("No privacy erasure request is active.");
  });
});

describe("EnforcementRecoveryShow", () => {
  const appeal = {
    url: "/identity/recovery/appeals",
    scope: "appeal",
    reason_label: "Appeal reason",
    reason_codes: [{ label: "mistake", value: "mistake" }],
    statement_label: "Appeal statement",
    statement_max_length: 500,
    submit_label: "Submit appeal",
  };

  it("renders the appeal form only for an appealable case", () => {
    const html = renderToStaticMarkup(
      <EnforcementRecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "c1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal,
          },
          {
            public_id: "c2",
            kind_label: "Method protection",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: null,
          },
        ]}
      />,
    );

    expect(html).toContain("Security lock");
    expect(html).toContain("Method protection");
    expect(html.match(/Submit appeal/gu)).toHaveLength(1);
  });

  it("shows the appeal error the server reported", () => {
    const html = renderToStaticMarkup(
      <EnforcementRecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error="Appeal already submitted"
        enforcement_cases={[]}
      />,
    );

    expect(html).toContain("Appeal already submitted");
  });
});

describe("OtpReentryNew", () => {
  const addressForm = {
    url: "/identity/withdrawal/session",
    scope: "withdrawal_reentry",
    field: "address",
    label: "Email address",
    value: "person@example.com",
    submit_label: "Send verification code",
  };

  it("shows only the address form before a code is issued", () => {
    const html = renderToStaticMarkup(
      <OtpReentryNew
        title="Withdrawal session"
        generic_message="If an account matches, a code is sent."
        address_form={addressForm}
        pass_code_form={null}
      />,
    );

    expect(html).toContain("If an account matches, a code is sent.");
    expect(html).not.toContain('name="pass_code"');
  });

  it("shows the code form once the server issued one", () => {
    const html = renderToStaticMarkup(
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

    expect(html).toContain('name="pass_code"');
    expect(html).toContain("one-time-code");
    expect(html).toContain("A code will be sent.");
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
    checked: true,
    submit_label: "Continue",
  };

  it("sends a deactivated visitor to the recovery page", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recover", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("Already deactivated.");
    expect(html).not.toContain("ack_schedule_purge");
  });

  it("schedules without a deactivation step while that gate is closed", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recover", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("ack_schedule_purge");
    expect(html).not.toContain("ack_deactivate_today");
  });

  it("adds the deactivation step once the schedule is acknowledged", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recover", href: "/identity/withdrawal/edit" }}
        schedule={{ ...schedule, errors: ["Acknowledgement is required"] }}
        deactivate={{
          title: "Deactivate",
          errors: [],
          url: "/identity/withdrawal",
          method: "patch",
          field: "ack_deactivate_today",
          ack_label: "Deactivate today",
          submit_label: "Deactivate",
          confirm: "Sure?",
        }}
      />,
    );

    expect(html).toContain("ack_schedule_purge");
    expect(html).toContain("ack_deactivate_today");
    expect(html).toContain("Acknowledgement is required");
  });
});

describe("WithdrawalEdit", () => {
  const base = {
    title: "Recovery",
    unavailable_message: "Recovery is unavailable.",
    privacy_erasure_link: { label: "Erase", href: "/identity/privacy/erasure/new" },
    sign_out: { label: "Sign out", url: "/identity/withdrawal/session" },
  };

  it("shows only the unavailable notice for a terminated account", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        {...base}
        terminated
        deadline_message={null}
        recovery={{}}
        termination={null}
      />,
    );

    expect(html).toContain("Recovery is unavailable.");
    expect(html).not.toContain("Erase");
  });

  it("offers recovery and early termination when the server allows them", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        {...base}
        terminated={false}
        deadline_message="Recoverable until 2026-03-01"
        recovery={{
          available_message: "Recovery is available.",
          url: "/identity/withdrawal",
          submit_label: "Restore",
          confirm: "Sure?",
        }}
        termination={{
          url: "/identity/withdrawal",
          submit_label: "Terminate now",
          confirm: "Sure?",
        }}
      />,
    );

    expect(html).toContain("Recoverable until 2026-03-01");
    expect(html).toContain("Restore");
    expect(html).toContain("Terminate now");
    expect(html).toContain("Erase");
  });

  it("reports the pending windows when neither action is open yet", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        {...base}
        terminated={false}
        deadline_message="Recoverable until 2026-03-01"
        recovery={{ pending_message: "Recoverable from 2026-02-01" }}
        termination={{ pending_message: "Terminable from 2026-02-15" }}
      />,
    );

    expect(html).toContain("Recoverable from 2026-02-01");
    expect(html).toContain("Terminable from 2026-02-15");
    expect(html).not.toContain("Restore");
  });

  it("states that recovery is closed when the window has passed", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        {...base}
        terminated={false}
        deadline_message={null}
        recovery={{ unavailable_message: "Recovery is unavailable." }}
        termination={null}
      />,
    );

    expect(html).toContain("Recovery is unavailable.");
  });
});
