import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The identity pages submit through `router` and render `Link`, neither of which exists outside a
// booted Inertia application. `Link` is stubbed to the anchor it renders so the static markup stays
// assertable.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: { errors: {} } }),
}));

const { default: ActivitiesIndex } = await import("@/pages/base/app/identity/activities/index");
const { default: BirthdateShow } = await import("@/pages/base/app/identity/birthdates/show");
const { default: EmailsIndex } = await import("@/pages/base/app/identity/emails/index");
const { default: EmailEdit } = await import("@/pages/base/app/identity/emails/edit");
const { default: EmailRegistrationNew } =
  await import("@/pages/base/app/identity/emails/registrations/new");
const { default: EmailRegistrationEdit } =
  await import("@/pages/base/app/identity/emails/registrations/edit");
const { default: MfaChallengeShow } = await import("@/pages/base/app/identity/mfa/challenges/show");
const { default: MfaResetShow } = await import("@/pages/base/app/identity/mfa/resets/show");
const { default: PrivacyErasureNew } =
  await import("@/pages/base/app/identity/privacy/erasures/new");
const { default: PrivacyErasureStatusShow } =
  await import("@/pages/base/app/identity/privacy/erasure/statuses/show");
const { default: RecoveryShow } = await import("@/pages/base/app/identity/recoveries/show");
const { default: RecoverySessionNew } =
  await import("@/pages/base/app/identity/recovery/sessions/new");
const { default: SecretsIndex } = await import("@/pages/base/app/identity/secrets/index");
const { default: SecretShow } = await import("@/pages/base/app/identity/secrets/show");
const { default: SecretNew } = await import("@/pages/base/app/identity/secrets/new");
const { default: SecretEdit } = await import("@/pages/base/app/identity/secrets/edit");
const { default: SessionsIndex } = await import("@/pages/base/app/identity/sessions/index");
const { default: SessionShow } = await import("@/pages/base/app/identity/sessions/show");
const { default: TelephonesIndex } = await import("@/pages/base/app/identity/telephones/index");
const { default: TelephoneNew } = await import("@/pages/base/app/identity/telephones/new");
const { default: TelephoneEdit } = await import("@/pages/base/app/identity/telephones/edit");
const { default: TelephoneRegistrationNew } =
  await import("@/pages/base/app/identity/telephones/registrations/new");
const { default: TelephoneRegistrationEdit } =
  await import("@/pages/base/app/identity/telephones/registrations/edit");
const { default: WithdrawalSessionNew } =
  await import("@/pages/base/app/identity/withdrawal/sessions/new");
const { default: WithdrawalNew } = await import("@/pages/base/app/identity/withdrawals/new");
const { default: WithdrawalEdit } = await import("@/pages/base/app/identity/withdrawals/edit");

const backLink = { label: "Back", href: "/identity" };

describe("identity activities index", () => {
  const headings = {
    occurred_at: "Occurred",
    event: "Event",
    ip_address: "IP",
    device: "Device",
    login_method: "Login method",
    context: "Context",
  };

  it("renders one row per activity", () => {
    const html = renderToStaticMarkup(
      <ActivitiesIndex
        title="Activity"
        description="Recent activity."
        empty_message="No activity."
        back_link={backLink}
        table_headings={headings}
        activities={[
          {
            event_id: 12,
            occurred_at: "1 January 2026",
            event_label: "Signed in",
            ip_address: "203.0.113.4",
            user_agent_summary: "Firefox",
            login_method: "passkey",
            context_text: "{}",
          },
        ]}
      />,
    );

    expect(html).toContain("Signed in");
    expect(html).toContain("203.0.113.4");
    // The context travels as code, not as prose. Matched as an element rather than as exact
    // markup so styling it is not a change to what the row reports.
    expect(html).toMatch(/<code[^>]*>\{\}<\/code>/u);
    expect(html).not.toContain("No activity.");
  });

  it("renders the empty message with no activity", () => {
    const html = renderToStaticMarkup(
      <ActivitiesIndex
        title="Activity"
        description="Recent activity."
        empty_message="No activity."
        back_link={backLink}
        table_headings={headings}
        activities={[]}
      />,
    );

    expect(html).toContain("No activity.");
    expect(html).not.toContain("<table>");
  });
});

describe("identity birthdate show", () => {
  const base = {
    title: "Birthdate",
    description: "Your birthdate.",
    change_unavailable: "It cannot be changed.",
    birthdate_label: "Birthdate",
    not_set_label: "Not set",
    back_link: backLink,
  };

  it("renders the stored birthdate", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...base}
        birthdate="2000-01-01"
      />,
    );

    expect(html).toContain("2000-01-01");
    expect(html).not.toContain("Not set");
  });

  it("renders the placeholder when no birthdate is stored", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...base}
        birthdate={null}
      />,
    );

    expect(html).toContain("Not set");
  });
});

describe("identity emails index", () => {
  const shared = {
    title: "Emails",
    empty_message: "No email addresses.",
    back_link: backLink,
    new_link: { label: "Add", href: "/identity/emails/registration/new" },
    table_headings: { address: "Address", status: "Status", actions: "Actions" },
  };

  it("lists the addresses", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...shared}
        emails={[
          {
            public_id: "eml_1",
            address: "someone@example.com",
            status_label: "Verified",
            edit_link: { label: "Edit", href: "/identity/emails/eml_1/edit" },
          },
        ]}
      />,
    );

    expect(html).toContain("someone@example.com");
    expect(html).toContain("Verified");
    expect(html).not.toContain("No email addresses.");
  });

  it("renders the empty row", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...shared}
        emails={[]}
      />,
    );

    expect(html).toContain("No email addresses.");
  });
});

describe("identity email edit", () => {
  const props = {
    title: "Email settings",
    address: "someone@example.com",
    form: {
      action: "/identity/emails/eml_1",
      submit_label: "Save",
      locked: false,
      always_on_label: "Always on",
      always_on_description: "Security mail is always sent.",
      promotional: { checked: true, label: "Promotional", description: "Offers." },
      notifiable: { checked: false, label: "Notifiable", description: "Notices." },
    },
    delete: { label: "Delete", confirm: "Sure?", url: "/identity/emails/eml_1" },
    cancel_link: { label: "Cancel", href: "/identity/emails" },
  };

  it("renders the preference form", () => {
    const html = renderToStaticMarkup(
      <EmailEdit
        {...props}
        error={null}
      />,
    );

    expect(html).toContain("someone@example.com");
    expect(html).toContain("Promotional");
    expect(html).not.toContain('role="alert"');
  });

  it("renders the failure message and the locked state", () => {
    const html = renderToStaticMarkup(
      <EmailEdit
        {...props}
        form={{ ...props.form, locked: true }}
        error="That did not work."
      />,
    );

    expect(html).toContain("That did not work.");
    expect(html).toContain("disabled");
  });
});

describe("identity email registration screens", () => {
  const newProps = {
    title: "Add an email address",
    back_link: backLink,
    cancel_link: { label: "Cancel", href: "https://base.example/preference" },
    form: {
      action: "/identity/emails/registration",
      address_label: "Address",
      address: "",
      submit_label: "Submit",
      promotional: { checked: false, label: "Promotional", description: "Offers." },
      notifiable: { checked: true, label: "Notifiable", description: "Notices." },
    },
  };

  it("renders the address form without errors", () => {
    const html = renderToStaticMarkup(
      <EmailRegistrationNew
        {...newProps}
        errors={[]}
      />,
    );

    expect(html).toContain("Address");
    expect(html).not.toContain("<ul");
  });

  it("renders validation errors", () => {
    const html = renderToStaticMarkup(
      <EmailRegistrationNew
        {...newProps}
        errors={["Address is invalid"]}
      />,
    );

    expect(html).toContain("Address is invalid");
  });

  const editProps = {
    title: "Verify your email address",
    description: "Enter the code.",
    cancel_link: { label: "Cancel", href: "https://base.example/preference" },
    form: {
      action: "/identity/emails/registration",
      code_label: "Verification code",
      code_placeholder: "123456",
      delivery_help: "It expires soon.",
      submit_label: "Verify",
      verification_token: "tok_1",
    },
    resend: { label: "Resend", url: "/identity/emails/registration/redelivery" },
  };

  it("renders the verification form", () => {
    const html = renderToStaticMarkup(
      <EmailRegistrationEdit
        {...editProps}
        errors={[]}
      />,
    );

    expect(html).toContain("Verification code");
    expect(html).toContain("Resend");
  });

  it("renders verification errors without a token", () => {
    const html = renderToStaticMarkup(
      <EmailRegistrationEdit
        {...editProps}
        form={{ ...editProps.form, verification_token: null }}
        errors={["Code is invalid"]}
      />,
    );

    expect(html).toContain("Code is invalid");
  });
});

describe("identity multi factor screens", () => {
  it("renders the challenge state", () => {
    const html = renderToStaticMarkup(
      <MfaChallengeShow
        title="Multi factor"
        reset_unavailable="Reset is unavailable."
        toggle_title="Status"
        state_label="Enabled"
        back_link={backLink}
        error={null}
      />,
    );

    expect(html).toContain("Enabled");
    expect(html).not.toContain('role="alert"');
  });

  it("renders the challenge failure", () => {
    const html = renderToStaticMarkup(
      <MfaChallengeShow
        title="Multi factor"
        reset_unavailable="Reset is unavailable."
        toggle_title="Status"
        state_label="Disabled"
        back_link={backLink}
        error="It could not be changed."
      />,
    );

    expect(html).toContain("It could not be changed.");
  });

  it("renders the reset screen", () => {
    const html = renderToStaticMarkup(
      <MfaResetShow
        title="Multi factor reset"
        reset_unavailable="Reset is unavailable."
        back_link={backLink}
      />,
    );

    expect(html).toContain("Multi factor reset");
  });
});

describe("identity privacy erasure screens", () => {
  it("renders the request form", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureNew
        title="Early personal data erasure"
        notices={["It is separate from withdrawal."]}
        form={{
          action: "/identity/privacy/erasure",
          jurisdiction: "unknown",
          submit_label: "Request early erasure",
        }}
      />,
    );

    expect(html).toContain("It is separate from withdrawal.");
    expect(html).toContain("Request early erasure");
  });

  it("renders an active request", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Privacy erasure status"
        empty_message="No privacy erasure request is active."
        privacy_request={{
          status_label: "Status: received",
          received_label: "Received: 2026-01-01",
          response_due_label: "Response due: 2026-02-01",
        }}
      />,
    );

    expect(html).toContain("Status: received");
    expect(html).not.toContain("No privacy erasure request is active.");
  });

  it("renders the empty status", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Privacy erasure status"
        empty_message="No privacy erasure request is active."
        privacy_request={null}
      />,
    );

    expect(html).toContain("No privacy erasure request is active.");
  });
});

describe("identity recovery screens", () => {
  const appeal = {
    url: "/identity/recovery/appeals",
    reason_label: "Appeal reason",
    reason_codes: [
      { label: "incorrect_decision", value: "incorrect_decision" },
      { label: "other", value: "other" },
    ],
    statement_label: "Appeal statement",
    statement_max_length: 4000,
    submit_label: "Submit appeal",
  };

  it("renders an appealable case", () => {
    const html = renderToStaticMarkup(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal,
          },
        ]}
      />,
    );

    expect(html).toContain("Security lock");
    expect(html).toContain("Submit appeal");
    expect(html).toContain("Appeal statement");
  });

  it("renders a case without an appeal form and the appeal error", () => {
    const html = renderToStaticMarkup(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error="An appeal already exists."
        enforcement_cases={[
          {
            public_id: "case_2",
            kind_label: "Method protection",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: null,
          },
        ]}
      />,
    );

    expect(html).toContain("An appeal already exists.");
    expect(html).not.toContain("Submit appeal");
  });

  it("renders the recovery entry screen with the code form", () => {
    const html = renderToStaticMarkup(
      <RecoverySessionNew
        title="Account recovery"
        description="A code will be sent."
        address_form={{
          action: "/identity/recovery/session",
          label: "Email address",
          address: "someone@example.com",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/recovery/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    expect(html).toContain("Verification code");
    expect(html).toContain("someone@example.com");
  });

  it("renders the recovery entry screen without the code form", () => {
    const html = renderToStaticMarkup(
      <RecoverySessionNew
        title="Account recovery"
        description="A code will be sent."
        address_form={{
          action: "/identity/recovery/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={null}
      />,
    );

    expect(html).not.toContain("Verification code");
  });
});

describe("identity secret screens", () => {
  it("renders the secret list", () => {
    const html = renderToStaticMarkup(
      <SecretsIndex
        title="Secrets"
        back_link={backLink}
        new_link={{ label: "New secret", href: "/identity/secrets/new" }}
        table_headings={{
          name: "Name",
          created_at: "Created",
          last_used_at: "Last used",
          actions: "Actions",
        }}
        edit_label="Edit"
        destroy_label="Delete"
        destroy_confirm="Sure?"
        secret_credentials={[
          {
            public_id: "sec_1",
            name: "deploy",
            created_at: "1 Jan",
            last_used_at: "-",
            edit_url: "/identity/secrets/sec_1/edit",
            destroy_url: "/identity/secrets/sec_1",
          },
        ]}
      />,
    );

    expect(html).toContain("deploy");
    expect(html).toContain("Delete");
  });

  it("renders the secret detail", () => {
    const html = renderToStaticMarkup(
      <SecretShow
        title="Secret"
        description="The details."
        name="deploy"
        created_at_label="Created"
        created_at="1 January 2026"
        last_used_at_label="Last used"
        last_used_at="Never"
        back_link={{ label: "Back", href: "/identity/secrets" }}
        edit_link={{ label: "Edit", href: "/identity/secrets/sec_1/edit" }}
      />,
    );

    expect(html).toContain("Never");
    expect(html).toContain("deploy");
  });

  const newSecretProps = {
    title: "New secret",
    description: "Save it now.",
    back_link: backLink,
    cancel_link: { label: "Cancel", href: "/identity/secrets" },
    form: {
      action: "/identity/secrets",
      name_label: "Name",
      name: "abcd",
      enabled_label: "I saved it",
      submit_label: "Save",
    },
    raw_secret_credential: "abcd-efgh",
    raw_secret_label: "Secret",
    one_time_notice: "Shown once only.",
  };

  it("renders the one time secret", () => {
    const html = renderToStaticMarkup(
      <SecretNew
        {...newSecretProps}
        errors={[]}
      />,
    );

    expect(html).toContain("abcd-efgh");
    expect(html).toContain("Shown once only.");
  });

  it("renders new secret errors", () => {
    const html = renderToStaticMarkup(
      <SecretNew
        {...newSecretProps}
        errors={["Name is invalid"]}
      />,
    );

    expect(html).toContain("Name is invalid");
  });

  const editSecretProps = {
    title: "Edit secret",
    description: "Rename it.",
    back_link: backLink,
    cancel_link: { label: "Cancel", href: "/identity/secrets" },
    form: {
      action: "/identity/secrets/sec_1",
      name_label: "Name",
      name: "deploy",
      enabled_label: "Enabled",
      enabled: true,
      submit_label: "Update",
    },
  };

  it("renders the edit form", () => {
    const html = renderToStaticMarkup(
      <SecretEdit
        {...editSecretProps}
        errors={[]}
      />,
    );

    expect(html).toContain("deploy");
    expect(html).toContain("checked");
  });

  it("renders edit errors", () => {
    const html = renderToStaticMarkup(
      <SecretEdit
        {...editSecretProps}
        errors={["Name is invalid"]}
      />,
    );

    expect(html).toContain("Name is invalid");
  });
});

describe("identity session screens", () => {
  const sessionRow = {
    public_id: "tok_1",
    status: "1",
    kind: "2",
    binding: "DBSC",
    last_activity: "1 Jan",
    created: "1 Jan",
    refresh_expires: "1 Feb",
    current: false,
    revoke_url: "/identity/sessions/tok_1",
  };
  const headings = {
    session: "Session",
    kind: "Kind",
    binding: "Binding",
    last_activity: "Last activity",
    created: "Created",
    refresh_expires: "Refresh expires",
  };

  it("renders the revocable inventory", () => {
    const html = renderToStaticMarkup(
      <SessionsIndex
        title="Sessions"
        empty_message="No active sessions were found."
        back_link={backLink}
        table_headings={headings}
        current_label="current"
        revoke_label="Revoke"
        revoke_confirm="Revoke this session?"
        bulk_revocation={{
          others_label: "Sign out other sessions",
          others_confirm: "Sure?",
          others_url: "/identity/other_sessions",
        }}
        sessions={[sessionRow, { ...sessionRow, public_id: "tok_2", current: true }]}
      />,
    );

    expect(html).toContain("Sign out other sessions");
    expect(html).not.toContain("Sign out everywhere");
    expect(html).toContain("tok_2");
    expect(html).toContain("current");
  });

  it("renders the empty inventory", () => {
    const html = renderToStaticMarkup(
      <SessionsIndex
        title="Sessions"
        empty_message="No active sessions were found."
        back_link={backLink}
        table_headings={headings}
        current_label="current"
        revoke_label="Revoke"
        revoke_confirm="Revoke this session?"
        bulk_revocation={null}
        sessions={[]}
      />,
    );

    expect(html).toContain("No active sessions were found.");
    expect(html).not.toContain("Sign out everywhere");
  });

  it("renders one session", () => {
    const html = renderToStaticMarkup(
      <SessionShow
        title="Session"
        session={sessionRow}
        back_link={{ label: "Back", href: "/identity/sessions" }}
      />,
    );

    expect(html).toContain("tok_1");
    expect(html).toContain("DBSC");
  });
});

describe("identity telephone screens", () => {
  const headings = { number: "Number", status: "Status", actions: "Actions" };

  it("lists the telephones", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        title="Telephones"
        empty_message="No telephone numbers."
        back_link={backLink}
        new_link={{ label: "Add", href: "/identity/telephones/registration/new" }}
        table_headings={headings}
        telephones={[
          {
            public_id: "tel_1",
            number: "+819012345678",
            status_label: "Verified",
            edit_link: { label: "Edit", href: "/identity/telephones/tel_1/edit" },
          },
        ]}
      />,
    );

    expect(html).toContain("+819012345678");
  });

  it("renders the empty telephone row", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        title="Telephones"
        empty_message="No telephone numbers."
        back_link={backLink}
        new_link={{ label: "Add", href: "/identity/telephones/registration/new" }}
        table_headings={headings}
        telephones={[]}
      />,
    );

    expect(html).toContain("No telephone numbers.");
  });

  const telephoneFormProps = {
    title: "Add a telephone number",
    description: "It is used for verification.",
    help_text: "Use the international format.",
    number_label: "Number",
    number_placeholder: "+819012345678",
    form: { action: "/identity/telephones", submit_label: "Submit" },
    cancel_link: { label: "Cancel", href: "/identity/telephones" },
  };

  it("renders the telephone form", () => {
    const html = renderToStaticMarkup(
      <TelephoneNew
        {...telephoneFormProps}
        errors={[]}
      />,
    );

    expect(html).toContain("Use the international format.");
    expect(html).not.toContain("<ul");
  });

  it("renders telephone form errors", () => {
    const html = renderToStaticMarkup(
      <TelephoneNew
        {...telephoneFormProps}
        errors={["Number is invalid"]}
      />,
    );

    expect(html).toContain("Number is invalid");
  });

  it("renders the telephone removal screen", () => {
    const html = renderToStaticMarkup(
      <TelephoneEdit
        title="Telephone"
        number="+819012345678"
        delete={{ label: "Delete", confirm: "Sure?", url: "/identity/telephones/tel_1" }}
        cancel_link={{ label: "Cancel", href: "/identity/telephones" }}
      />,
    );

    expect(html).toContain("Delete");
  });

  it("renders the registration form and its errors", () => {
    const html = renderToStaticMarkup(
      <TelephoneRegistrationNew
        {...telephoneFormProps}
        form={{ action: "/identity/telephones/registration", submit_label: "Submit" }}
        errors={["Number is invalid"]}
      />,
    );

    expect(html).toContain("Number is invalid");
  });

  it("renders the registration form without errors", () => {
    const html = renderToStaticMarkup(
      <TelephoneRegistrationNew
        {...telephoneFormProps}
        form={{ action: "/identity/telephones/registration", submit_label: "Submit" }}
        errors={[]}
      />,
    );

    expect(html).toContain("Submit");
  });

  const registrationEditProps = {
    title: "Verify your telephone number",
    description: "A code was sent.",
    code_label: "Verification code",
    code_placeholder: "123456",
    delivery_help: "It expires soon.",
    form: { action: "/identity/telephones/registration", submit_label: "Verify" },
    cancel_link: { label: "Cancel", href: "/identity/telephones" },
  };

  it("renders the telephone verification form", () => {
    const html = renderToStaticMarkup(
      <TelephoneRegistrationEdit
        {...registrationEditProps}
        errors={[]}
      />,
    );

    expect(html).toContain("Verification code");
  });

  it("renders telephone verification errors", () => {
    const html = renderToStaticMarkup(
      <TelephoneRegistrationEdit
        {...registrationEditProps}
        errors={["Code is invalid"]}
      />,
    );

    expect(html).toContain("Code is invalid");
  });
});

describe("identity withdrawal screens", () => {
  it("renders the withdrawal re-entry screen with both forms", () => {
    const html = renderToStaticMarkup(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "someone@example.com",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/withdrawal/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    expect(html).toContain("Verification code");
  });

  it("renders the withdrawal re-entry screen without the code form", () => {
    const html = renderToStaticMarkup(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={null}
      />,
    );

    expect(html).not.toContain("Verification code");
  });

  const schedule = {
    title: "Schedule withdrawal",
    ack_label: "I understand",
    submit_label: "Continue",
    acknowledged: false,
    action: "/identity/withdrawal",
    errors: [] as string[],
  };

  it("renders the schedule step alone", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("Schedule withdrawal");
    expect(html).not.toContain("Deactivate today");
  });

  it("renders both steps and their errors", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={{ ...schedule, acknowledged: true, errors: ["Acknowledgement is required"] }}
        deactivate={{
          title: "Deactivate today",
          ack_label: "I understand",
          submit_label: "Deactivate",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          errors: ["Acknowledgement is required"],
        }}
      />,
    );

    expect(html).toContain("Deactivate today");
    expect(html).toContain("Acknowledgement is required");
  });

  it("renders the deactivated notice instead of the steps", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("Already deactivated.");
    expect(html).not.toContain("Schedule withdrawal");
  });

  const signOut = { label: "Sign out", url: "/identity/withdrawal/session" };
  const erasureLink = { label: "Request early erasure", href: "/identity/privacy/erasure/new" };

  it("renders the recoverable status", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message="Recoverable until 1 February 2026."
        recovery={{
          available_message: "Recovery is available.",
          submit_label: "Recover",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          unavailable_message: null,
        }}
        termination={{
          submit_label: "Terminate now",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          available_at_message: null,
        }}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Recovery is available.");
    expect(html).toContain("Terminate now");
  });

  it("renders the pending status", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message="Recoverable until 1 February 2026."
        recovery={{
          available_message: null,
          submit_label: null,
          confirm: null,
          action: null,
          unavailable_message: "Recovery is unavailable.",
        }}
        termination={{
          submit_label: null,
          confirm: null,
          action: null,
          available_at_message: "Termination becomes available on 1 February 2026.",
        }}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Termination becomes available on 1 February 2026.");
    expect(html).not.toContain("Terminate now");
  });

  it("renders termination without a recovery section", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={{
          submit_label: "Terminate now",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          available_at_message: null,
        }}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Terminate now");
    expect(html).not.toContain("Recover");
  });

  it("renders the terminated status", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={null}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Recovery is unavailable.");
    expect(html).not.toContain("Request early erasure");
  });
});
