import { render, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import SignUpCheckpoint from "@/features/auth/signup/SignUpCheckpoint";

const checkpoint = {
  title: "Registration",
  birthdate: null,
  passkey: null,
  complete_message: null,
  cancellation: null,
};

describe("signup Secret distribution result", () => {
  it.each([
    "Secret は最大20個まで保有できます。今回は1個を配布しました。",
    "有効な Secret が上限の20個あるため、今回は新しい Secret を配布していません。",
  ])("renders the server's result as an inline accessible notice: %s", (notice) => {
    const screen = render(
      <SignUpCheckpoint
        {...checkpoint}
        notice={notice}
      />,
    );
    expect(within(screen.container).getByRole("status").textContent).toBe(notice);
    expect(screen.container.querySelector("form")).toBeNull();
  });

  it.each([undefined, null, ""])("adds no notice for a regular checkpoint: %s", (notice) => {
    const screen = render(
      <SignUpCheckpoint
        {...checkpoint}
        notice={notice}
      />,
    );
    expect(within(screen.container).queryByRole("status")).toBeNull();
    expect(
      within(screen.container).getByRole("heading", { name: "Registration" }).textContent,
    ).toBe("Registration");
  });
});
