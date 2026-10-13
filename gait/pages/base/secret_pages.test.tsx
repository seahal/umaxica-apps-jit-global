import { fireEvent, render, screen } from "@testing-library/react";
import { expect, it } from "vitest";

import Issuance from "@/pages/base/app/secret_issuances/show";
import SecretIndex from "@/pages/base/app/secrets/index";
import SecretNew from "@/pages/base/app/secrets/new";
import SecretShow from "@/pages/base/app/secrets/show";

it("lists only server-provided credentials and their destinations", () => {
  render(
    <SecretIndex
      title="Secrets"
      count={1}
      secrets={[{ id: "one", name: "Laptop", href: "/secrets/one" }]}
      add={{ href: "/secrets/new", label: "Add" }}
    />,
  );
  expect(screen.getByRole("link", { name: "Laptop" }).getAttribute("href")).toBe("/secrets/one");
  expect(screen.getByRole("link", { name: "Add" }).getAttribute("href")).toBe("/secrets/new");
  expect(screen.getByText("1")).toBeTruthy();
});

it("posts the issuance operation and CSRF token", () => {
  const { container } = render(
    <SecretNew
      title="New secret"
      action="/secrets"
      authenticity_token="csrf"
      operation_id="operation"
      submit="Create"
    />,
  );
  const form = container.querySelector("form")!;
  expect(form.method).toBe("post");
  expect(form.getAttribute("action")).toBe("/secrets");
  expect(Object.fromEntries(new FormData(form))).toEqual({
    authenticity_token: "csrf",
    operation_id: "operation",
  });
  expect(screen.getByRole("button", { name: "Create" }).getAttribute("type")).toBe("submit");
});

it("keeps rename and revocation in separate document forms", () => {
  const { container } = render(
    <SecretShow
      title="Secret"
      name="Laptop"
      id="one"
      action="/secrets/one"
      authenticity_token="csrf"
      rename="Rename"
      revoke="Revoke"
    />,
  );
  fireEvent.change(screen.getByLabelText("Rename"), { target: { value: "Desktop" } });
  const [rename, revoke] = container.querySelectorAll("form");
  expect(Object.fromEntries(new FormData(rename))).toEqual({
    authenticity_token: "csrf",
    _method: "patch",
    name: "Desktop",
  });
  expect(Object.fromEntries(new FormData(revoke))).toEqual({
    authenticity_token: "csrf",
    _method: "delete",
  });
  expect(rename!.getAttribute("action")).toBe("/secrets/one");
  expect(revoke!.getAttribute("action")).toBe("/secrets/one");
  expect(screen.getByLabelText("Rename").getAttribute("maxlength")).toBe("255");
});

it("offers presentation and cancellation before displaying a secret", () => {
  render(
    <Issuance
      title="Issue secret"
      presentation="/present"
      confirmation="/confirm"
      authenticity_token="csrf"
      present_label="Present"
      confirm_label="Stored"
      cancel_label="Cancel"
      notice={null}
      continue_href="/identity"
      continue_label="Continue"
      state="pending_presentation"
    />,
  );
  expect(
    screen.getByRole("button", { name: "Present" }).closest("form")?.getAttribute("action"),
  ).toBe("/present");
  expect(
    Object.fromEntries(
      new FormData(screen.getByRole("button", { name: "Cancel" }).closest("form")!),
    ),
  ).toEqual({ authenticity_token: "csrf", _method: "delete" });
  expect(screen.queryByRole("link", { name: "Continue" })).toBeNull();
});
it("requires storage acknowledgement before confirming a secret", () => {
  render(
    <Issuance
      title="Issue secret"
      presentation="/present"
      confirmation="/confirm"
      authenticity_token="csrf"
      present_label="Present"
      confirm_label="Stored"
      cancel_label="Cancel"
      notice={null}
      continue_href="/identity"
      continue_label="Continue"
      state="pending_confirmation"
    />,
  );
  const checkbox = screen.getByRole<HTMLInputElement>("checkbox", { name: "Stored" });
  expect(checkbox.required).toBe(true);
  expect(checkbox.checkValidity()).toBe(false);
  fireEvent.click(checkbox);
  expect(checkbox.checkValidity()).toBe(true);
  expect(Object.fromEntries(new FormData(checkbox.closest("form")!))).toEqual({
    authenticity_token: "csrf",
    _method: "patch",
    stored: "1",
  });
  expect(
    Object.fromEntries(
      new FormData(screen.getByRole("button", { name: "Cancel" }).closest("form")!),
    ),
  ).toEqual({ authenticity_token: "csrf", _method: "delete" });
});
it.each(["omitted", "confirmed"])("continues from %s to the supplied destination", (state) => {
  const { container } = render(
    <Issuance
      title="Issue secret"
      presentation="/present"
      confirmation="/confirm"
      authenticity_token="csrf"
      present_label="Present"
      confirm_label="Stored"
      cancel_label="Cancel"
      notice={null}
      continue_href="/identity"
      continue_label="Continue"
      state={state}
    />,
  );
  expect(screen.getByRole("link", { name: "Continue" }).getAttribute("href")).toBe("/identity");
  expect(container.querySelector("form")).toBeNull();
});

it.each(["omitted", "confirmed"])("completes %s through the server checkpoint", (state) => {
  render(
    <Issuance
      title="Issue secret"
      state={state}
      presentation="/present"
      confirmation="/confirm"
      authenticity_token="csrf"
      present_label="Present"
      confirm_label="Stored"
      cancel_label="Cancel"
      notice="Ready"
      continue_href="/identity"
      continue_label="Continue"
      completion_action="/complete"
      checkpoint_version={0}
    />,
  );
  const form = screen.getByRole("button", { name: "Continue" }).closest("form")!;
  expect(form.getAttribute("action")).toBe("/complete");
  expect(Object.fromEntries(new FormData(form))).toEqual({
    authenticity_token: "csrf",
    _method: "patch",
    checkpoint_version: "0",
  });
  expect(screen.getByRole("status").textContent).toBe("Ready");
  expect(screen.queryByRole("link", { name: "Continue" })).toBeNull();
});

it.each([
  { checkpoint: {}, expected: null },
  { checkpoint: { checkpoint_version: 0 }, expected: "0" },
  { checkpoint: { checkpoint_version: 1 }, expected: "1" },
])("carries the supplied checkpoint when reattempting: %s", ({ checkpoint, expected }) => {
  render(
    <Issuance
      title="Issue secret"
      state="pending_confirmation"
      presentation="/present"
      confirmation="/confirm"
      authenticity_token="csrf"
      present_label="Present"
      confirm_label="Stored"
      cancel_label="Cancel"
      notice={null}
      continue_href="/identity"
      continue_label="Continue"
      reattempt_action="/retry"
      reattempt_of="previous"
      reattempt_label="Retry"
      {...checkpoint}
    />,
  );
  const retry = screen.getByRole("button", { name: "Retry" }).closest("form")!;
  expect(retry.getAttribute("action")).toBe("/retry");
  expect(new FormData(retry).get("reattempt_of")).toBe("previous");
  expect(new FormData(retry).get("checkpoint_version")).toBe(expected);
  expect(
    new FormData(screen.getByRole("checkbox").closest("form")!).get("checkpoint_version"),
  ).toBe(expected);
});
