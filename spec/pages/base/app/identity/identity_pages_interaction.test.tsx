import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { answerConfirmation } from "../../../../support/confirmation";
import { present } from "../../../../support/present";

// These tests mount the identity pages and fire real DOM events, so the submit and confirm
// branches the static markup cannot reach are covered.
const get = vi.fn();
const post = vi.fn();
const patch = vi.fn();
const destroy = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get, post, patch, delete: destroy },
  usePage: () => ({ props: { errors: {} } }),
}));

const { default: EmailEdit } = await import("@/pages/base/app/identity/emails/edit");
const { default: EmailRegistrationNew } =
  await import("@/pages/base/app/identity/emails/registrations/new");
const { default: EmailRegistrationEdit } =
  await import("@/pages/base/app/identity/emails/registrations/edit");
const { default: PrivacyErasureNew } =
  await import("@/pages/base/app/identity/privacy/erasures/new");
const { default: RecoveryShow } = await import("@/pages/base/app/identity/recoveries/show");
const { default: RecoverySessionNew } =
  await import("@/pages/base/app/identity/recovery/sessions/new");
const { default: SecretsIndex } = await import("@/pages/base/app/identity/secrets/index");
const { default: SecretNew } = await import("@/pages/base/app/identity/secrets/new");
const { default: SecretEdit } = await import("@/pages/base/app/identity/secrets/edit");
const { default: SessionsIndex } = await import("@/pages/base/app/identity/sessions/index");
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

const fireVisitCallbacks = (mocked: { mock: { calls: unknown[][] } }) => {
  const call = mocked.mock.calls.at(-1);
  const options = call?.at(-1);
  if (typeof options === "object" && options !== null) {
    const visit = options as { onStart?: () => void; onFinish?: () => void };
    act(() => {
      visit.onStart?.();
      visit.onFinish?.();
    });
  }
};

const clickButton = (label: string) => {
  const button = [...container.querySelectorAll("button")].find(
    (candidate) => candidate.textContent === label,
  );
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

// The confirmation is a rendered dialog now: its cancel button is first and its confirm button
// second, so answering it is a click rather than a stubbed `window.confirm`.

const setInput = (selector: string, value: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  if (!input) {
    throw new Error(`no input for ${selector}`);
  }
  act(() => {
    const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
    descriptor?.set?.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
  });
};

const toggleCheckbox = (selector: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  if (!input) {
    throw new Error(`no checkbox for ${selector}`);
  }
  act(() => {
    input.click();
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
  vi.unstubAllGlobals();
});

const backLink = { label: "Back", href: "/identity" };

describe("email edit interaction", () => {
  const props = {
    title: "Email settings",
    address: "someone@example.com",
    form: {
      action: "/identity/emails/eml_1",
      submit_label: "Save",
      locked: false,
      always_on_label: "Always on",
      always_on_description: "Security mail is always sent.",
      promotional: { checked: false, label: "Promotional", description: "Offers." },
      notifiable: { checked: false, label: "Notifiable", description: "Notices." },
    },
    delete: { label: "Delete", confirm: "Sure?", url: "/identity/emails/eml_1" },
    cancel_link: { label: "Cancel", href: "/identity/emails" },
    error: null,
  };

  it("keeps unchecked preferences as off", () => {
    mount(<EmailEdit {...props} />);
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/eml_1",
      { user_email: { promotional: "0", notifiable: "0" } },
      expect.anything(),
    );
  });

  it("patches the subscription preferences", () => {
    mount(<EmailEdit {...props} />);
    toggleCheckbox("#user_email_promotional");
    toggleCheckbox("#user_email_notifiable");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/eml_1",
      { user_email: { promotional: "1", notifiable: "1" } },
      expect.anything(),
    );

    fireVisitCallbacks(patch);
  });

  it("deletes only after confirmation", () => {
    mount(<EmailEdit {...props} />);
    clickButton("Delete");
    answerConfirmation(false);
    expect(destroy).not.toHaveBeenCalled();

    clickButton("Delete");
    answerConfirmation(true);
    expect(destroy).toHaveBeenCalledWith("/identity/emails/eml_1");
  });
});

describe("email registration interaction", () => {
  it("posts unchecked preferences as off", () => {
    mount(
      <EmailRegistrationNew
        title="Add an email address"
        back_link={backLink}
        cancel_link={{ label: "Cancel", href: "/preference" }}
        form={{
          action: "/identity/emails/registration",
          address_label: "Address",
          address: "",
          submit_label: "Submit",
          promotional: { checked: false, label: "Promotional", description: "Offers." },
          notifiable: { checked: false, label: "Notifiable", description: "Notices." },
        }}
        errors={[]}
      />,
    );
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/emails/registration",
      {
        user_email: { address: "", promotional: "0", notifiable: "0" },
      },
      expect.anything(),
    );
  });

  it("posts the address and the preferences", () => {
    mount(
      <EmailRegistrationNew
        title="Add an email address"
        back_link={backLink}
        cancel_link={{ label: "Cancel", href: "/preference" }}
        form={{
          action: "/identity/emails/registration",
          address_label: "Address",
          address: "",
          submit_label: "Submit",
          promotional: { checked: false, label: "Promotional", description: "Offers." },
          notifiable: { checked: false, label: "Notifiable", description: "Notices." },
        }}
        errors={[]}
      />,
    );
    setInput("#user_email_address", "someone@example.com");
    toggleCheckbox("#user_email_promotional");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/emails/registration",
      {
        user_email: { address: "someone@example.com", promotional: "1", notifiable: "0" },
      },
      expect.anything(),
    );

    fireVisitCallbacks(post);
  });

  const editProps = {
    title: "Verify your email address",
    description: "Enter the code.",
    cancel_link: { label: "Cancel", href: "/preference" },
    resend: { label: "Resend", url: "/identity/emails/registration/redelivery" },
    errors: [],
  };

  it("patches the code with the verification token", () => {
    mount(
      <EmailRegistrationEdit
        {...editProps}
        form={{
          action: "/identity/emails/registration",
          code_label: "Verification code",
          code_placeholder: "123456",
          delivery_help: "It expires soon.",
          submit_label: "Verify",
          verification_token: "tok_1",
        }}
      />,
    );
    setInput("#user_email_pass_code", "123456");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/registration",
      { user_email: { pass_code: "123456", token: "tok_1" } },
      expect.anything(),
    );
  });

  it("patches the code without a token and posts a redelivery", () => {
    mount(
      <EmailRegistrationEdit
        {...editProps}
        form={{
          action: "/identity/emails/registration",
          code_label: "Verification code",
          code_placeholder: "123456",
          delivery_help: "It expires soon.",
          submit_label: "Verify",
          verification_token: null,
        }}
      />,
    );
    submitForm();
    expect(patch).toHaveBeenCalledWith(
      "/identity/emails/registration",
      { user_email: { pass_code: "" } },
      expect.anything(),
    );

    clickButton("Resend");
    expect(post).toHaveBeenCalledWith("/identity/emails/registration/redelivery");
    fireVisitCallbacks(patch);
  });
});

describe("privacy erasure interaction", () => {
  it("posts the jurisdiction", () => {
    mount(
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
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/privacy/erasure",
      { jurisdiction: "unknown" },
      expect.anything(),
    );
    fireVisitCallbacks(post);
  });
});

describe("recovery interaction", () => {
  it("posts the restore request and the appeal", () => {
    mount(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              reason_label: "Appeal reason",
              reason_codes: [
                { label: "other", value: "other" },
                { label: "mistake", value: "mistake" },
              ],
              statement_label: "Appeal statement",
              statement_max_length: 4000,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    submitForm(0);
    expect(post).toHaveBeenCalledWith("/identity/recovery/completion", {
      data: { enforcement_case_id: "case_1" },
    });

    submitForm(1);
    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      {
        appeal: { enforcement_case_id: "case_1", reason_code: "other", statement: "" },
      },
      expect.anything(),
    );

    fireVisitCallbacks(post);
  });

  it("restores a case that has no appeal form", () => {
    mount(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_2",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: null,
          },
        ]}
      />,
    );

    expect(container.querySelectorAll("form")).toHaveLength(1);
    submitForm(0);
    expect(post).toHaveBeenCalledWith("/identity/recovery/completion", {
      data: { enforcement_case_id: "case_2" },
    });
  });

  it("updates the appeal reason when the visitor chooses another code", () => {
    mount(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_1",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              reason_label: "Appeal reason",
              reason_codes: [
                { label: "other", value: "other" },
                { label: "mistake", value: "mistake" },
              ],
              statement_label: "Appeal statement",
              statement_max_length: 4000,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    const select = container.querySelector<HTMLSelectElement>("select")!;
    act(() => {
      select.value = "mistake";
      select.dispatchEvent(new Event("change", { bubbles: true }));
    });
    submitForm(1);

    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      {
        appeal: { enforcement_case_id: "case_1", reason_code: "mistake", statement: "" },
      },
      expect.anything(),
    );
  });

  it("appeals with an empty reason when the server sent no codes", () => {
    mount(
      <RecoveryShow
        title="Account recovery"
        description="Complete verification."
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_3",
            kind_label: "Security lock",
            restore: { url: "/identity/recovery/completion", submit_label: "Restore access" },
            appeal: {
              url: "/identity/recovery/appeals",
              reason_label: "Appeal reason",
              reason_codes: [],
              statement_label: "Appeal statement",
              statement_max_length: 4000,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    submitForm(1);
    expect(post).toHaveBeenCalledWith(
      "/identity/recovery/appeals",
      {
        appeal: { enforcement_case_id: "case_3", reason_code: "", statement: "" },
      },
      expect.anything(),
    );
  });

  it("posts the recovery address and the code", () => {
    mount(
      <RecoverySessionNew
        title="Account recovery"
        description="A code will be sent."
        address_form={{
          action: "/identity/recovery/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/recovery/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    setInput("#recovery_reentry_address", "someone@example.com");
    submitForm(0);
    expect(post).toHaveBeenCalledWith("/identity/recovery/session", {
      data: { recovery_reentry: { address: "someone@example.com" } },
    });

    setInput("#recovery_pass_code", "123456");
    submitForm(1);
    expect(post).toHaveBeenCalledWith("/identity/recovery/session", {
      data: { pass_code: "123456" },
    });
  });
});

describe("secret interaction", () => {
  it("deletes a secret only after confirmation", () => {
    mount(
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

    clickButton("Delete");
    answerConfirmation(false);
    expect(destroy).not.toHaveBeenCalled();

    clickButton("Delete");
    answerConfirmation(true);
    expect(destroy).toHaveBeenCalledWith("/identity/secrets/sec_1");
  });

  it("posts a new secret", () => {
    mount(
      <SecretNew
        title="New secret"
        description="Save it now."
        back_link={backLink}
        cancel_link={{ label: "Cancel", href: "/identity/secrets" }}
        form={{
          action: "/identity/secrets",
          name_label: "Name",
          name: "abcd",
          enabled_label: "I saved it",
          submit_label: "Save",
        }}
        raw_secret_credential="abcd-efgh"
        raw_secret_label="Secret"
        one_time_notice="Shown once only."
        errors={[]}
      />,
    );

    setInput("#user_secret_credential_name", "deploy");
    submitForm();
    expect(post).toHaveBeenCalledWith(
      "/identity/secrets",
      { user_secret_credential: { name: "deploy", enabled: "0" } },
      expect.anything(),
    );
    post.mockClear();
    toggleCheckbox("#user_secret_credential_enabled");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/secrets",
      { user_secret_credential: { name: "deploy", enabled: "1" } },
      expect.anything(),
    );

    fireVisitCallbacks(post);
  });

  it("patches an existing secret", () => {
    mount(
      <SecretEdit
        title="Edit secret"
        description="Rename it."
        back_link={backLink}
        cancel_link={{ label: "Cancel", href: "/identity/secrets" }}
        form={{
          action: "/identity/secrets/sec_1",
          name_label: "Name",
          name: "deploy",
          enabled_label: "Enabled",
          enabled: true,
          submit_label: "Update",
        }}
        errors={[]}
      />,
    );

    submitForm();
    expect(patch).toHaveBeenCalledWith(
      "/identity/secrets/sec_1",
      { user_secret_credential: { name: "deploy", enabled: "1" } },
      expect.anything(),
    );
    patch.mockClear();
    toggleCheckbox("#user_secret_credential_enabled");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/secrets/sec_1",
      { user_secret_credential: { name: "deploy", enabled: "0" } },
      expect.anything(),
    );

    fireVisitCallbacks(patch);
  });
});

describe("session revocation interaction", () => {
  it("revokes one session and the whole inventory after confirmation", () => {
    const nativeSubmit = vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(() => {});
    mount(
      <SessionsIndex
        title="Sessions"
        empty_message="No active sessions were found."
        back_link={backLink}
        expires_at_description="This session ends at its expiry and cannot be extended."
        columns={{
          device: "Device",
          last_activity: "Last activity",
          created: "Created",
          expires_at: "Expires at",
          status: "Status",
          action: "Action",
        }}
        bulk_revocations={{
          others: {
            label: "Sign out other sessions",
            confirm: "Sure?",
            href: "/identity/other_sessions",
          },
        }}
        sessions={[
          {
            device: "Firefox / Linux",
            status: "Active",
            last_activity: "1 Jan",
            created: "1 Jan",
            expires_at: "1 Feb",
            revoke: {
              label: "Revoke",
              href: "/identity/sessions/tok_1",
              confirm: "Revoke this session?",
            },
          },
        ]}
      />,
    );

    clickButton("Revoke");
    answerConfirmation(false);
    expect(nativeSubmit).not.toHaveBeenCalled();

    clickButton("Revoke");
    answerConfirmation(true);
    expect(nativeSubmit).toHaveBeenCalledTimes(1);

    clickButton("Sign out other sessions");
    answerConfirmation(true);
    expect(nativeSubmit).toHaveBeenCalledTimes(2);
    expect(container.textContent).not.toContain("Sign out everywhere");
  });
});

describe("telephone interaction", () => {
  const formProps = {
    title: "Add a telephone number",
    description: "It is used for verification.",
    help_text: "Use the international format.",
    number_label: "Number",
    number_placeholder: "+819012345678",
    cancel_link: { label: "Cancel", href: "/identity/telephones" },
    errors: [],
  };

  it("posts the number from the settings form", () => {
    mount(
      <TelephoneNew
        {...formProps}
        form={{ action: "/identity/telephones", submit_label: "Submit" }}
      />,
    );
    setInput("#user_telephone_raw_number", "+819012345678");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/telephones",
      { user_telephone: { raw_number: "+819012345678" } },
      expect.anything(),
    );
    fireVisitCallbacks(post);
  });

  it("posts the number from the registration form", () => {
    mount(
      <TelephoneRegistrationNew
        {...formProps}
        form={{ action: "/identity/telephones/registration", submit_label: "Submit" }}
      />,
    );
    setInput("#user_telephone_raw_number", "+819012345678");
    submitForm();

    expect(post).toHaveBeenCalledWith(
      "/identity/telephones/registration",
      { user_telephone: { raw_number: "+819012345678" } },
      expect.anything(),
    );
    fireVisitCallbacks(post);
  });

  it("patches the verification code", () => {
    mount(
      <TelephoneRegistrationEdit
        title="Verify your telephone number"
        description="A code was sent."
        code_label="Verification code"
        code_placeholder="123456"
        delivery_help="It expires soon."
        form={{ action: "/identity/telephones/registration", submit_label: "Verify" }}
        cancel_link={{ label: "Cancel", href: "/identity/telephones" }}
        errors={[]}
      />,
    );
    setInput("#user_telephone_pass_code", "123456");
    submitForm();

    expect(patch).toHaveBeenCalledWith(
      "/identity/telephones/registration",
      { user_telephone: { pass_code: "123456" } },
      expect.anything(),
    );
    fireVisitCallbacks(patch);
  });

  it("deletes a telephone only after confirmation", () => {
    mount(
      <TelephoneEdit
        title="Telephone"
        number="+819012345678"
        delete={{ label: "Delete", confirm: "Sure?", url: "/identity/telephones/tel_1" }}
        cancel_link={{ label: "Cancel", href: "/identity/telephones" }}
      />,
    );

    clickButton("Delete");
    answerConfirmation(false);
    expect(destroy).not.toHaveBeenCalled();

    clickButton("Delete");
    answerConfirmation(true);
    expect(destroy).toHaveBeenCalledWith("/identity/telephones/tel_1");
  });
});

describe("withdrawal interaction", () => {
  it("posts the re-entry address and the code", () => {
    mount(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/withdrawal/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    setInput("#withdrawal_reentry_address", "someone@example.com");
    submitForm(0);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal/session", {
      data: { withdrawal_reentry: { address: "someone@example.com" } },
    });

    setInput("#withdrawal_pass_code", "123456");
    submitForm(1);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal/session", {
      data: { pass_code: "123456" },
    });
  });

  it("submits the schedule step and the deactivation step", () => {
    mount(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={{
          title: "Schedule withdrawal",
          ack_label: "I understand",
          submit_label: "Continue",
          acknowledged: false,
          action: "/identity/withdrawal",
          errors: [],
        }}
        deactivate={{
          title: "Deactivate today",
          ack_label: "I understand",
          submit_label: "Deactivate",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          errors: [],
        }}
      />,
    );

    submitForm(0);
    expect(get).toHaveBeenCalledWith("/identity/withdrawal", { ack_schedule_purge: "0" });
    get.mockClear();

    toggleCheckbox("#ack_schedule_purge");
    submitForm(0);
    expect(get).toHaveBeenCalledWith("/identity/withdrawal", { ack_schedule_purge: "1" });

    submitForm(1);
    answerConfirmation(false);
    expect(patch).not.toHaveBeenCalled();

    submitForm(1);
    answerConfirmation(true);
    expect(patch).toHaveBeenCalledWith("/identity/withdrawal", {
      data: { ack_deactivate_today: "0" },
    });
    patch.mockClear();
    toggleCheckbox("#ack_deactivate_today");
    submitForm(1);
    answerConfirmation(true);
    expect(patch).toHaveBeenCalledWith("/identity/withdrawal", {
      data: { ack_deactivate_today: "1" },
    });
  });

  it("recovers and terminates only after confirmation", () => {
    mount(
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
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    clickButton("Recover");
    answerConfirmation(false);
    clickButton("Terminate now");
    answerConfirmation(false);
    expect(post).not.toHaveBeenCalled();
    expect(destroy).not.toHaveBeenCalled();

    clickButton("Recover");
    answerConfirmation(true);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal");

    clickButton("Terminate now");
    answerConfirmation(true);
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal");

    clickButton("Sign out");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal/session");
  });

  it("renders without a termination section when the server sent none", () => {
    mount(
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
        termination={null}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    expect(container.textContent).toContain("Recover");
    expect(container.textContent).not.toContain("Terminate now");
  });

  it("signs out from the terminated status", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={null}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    clickButton("Sign out");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal/session");
  });

  it("recovers without a confirmation when the server sent none", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={{
          available_message: null,
          submit_label: "Recover",
          confirm: null,
          action: "/identity/withdrawal",
          unavailable_message: "Not now.",
        }}
        termination={{
          submit_label: "Terminate now",
          confirm: null,
          action: "/identity/withdrawal",
          available_at_message: "Available later.",
        }}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    expect(container.textContent).toContain("Not now.");
    expect(container.textContent).toContain("Available later.");
    clickButton("Recover");
    expect(post).toHaveBeenCalledWith("/identity/withdrawal");
    clickButton("Terminate now");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal");
  });
});
