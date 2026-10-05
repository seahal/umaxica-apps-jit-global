import { render, screen } from "@testing-library/react";
import { expect, it } from "vitest";

import TotpsIndex from "@/pages/auth/app/settings/totps/index";

it("shows the supplied task title, named table and document creation action in the empty state", () => {
  render(
    <TotpsIndex
      title="Authenticator apps"
      back_link={{ label: "Settings", href: "/settings" }}
      new_link={{ label: "Add authenticator", href: "/settings/totps/new" }}
      columns={{ title: "Name", last_otp_at: "Last used", status: "Status", actions: "Actions" }}
      empty_message="No authenticator apps"
      edit_label="Edit"
      totps={[]}
    />,
  );
  expect(screen.getByRole("heading", { name: "Authenticator apps", level: 1 })).toBeTruthy();
  expect(screen.getByRole("region", { name: "Authenticator apps" })).toBeTruthy();
  expect(screen.getByRole("link", { name: "Add authenticator" }).getAttribute("href")).toBe(
    "/settings/totps/new",
  );
  expect(screen.getByText("No authenticator apps")).toBeTruthy();
});
