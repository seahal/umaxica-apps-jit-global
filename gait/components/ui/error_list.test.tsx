import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

// The one error treatment. Three near-identical components used to render validation failures, and
// the screen a message appeared on decided whether it was a bulleted danger panel or a comma-joined
// muted one. These cases pin the single treatment that replaced them.
const { default: ErrorList } = await import("@/components/ui/ErrorList");

describe("ErrorList", () => {
  it("renders nothing when the server reported no failure", () => {
    const { container } = render(<ErrorList errors={[]} />);

    expect(container.innerHTML).toBe("");
  });

  it("renders initial errors without an unsolicited live announcement", () => {
    render(<ErrorList errors={["メールアドレスを入力してください", "確認が未完了です"]} />);

    expect(screen.queryByRole("alert")).toBeNull();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(screen.getByText("確認が未完了です")).toBeTruthy();
  });

  it("renders the header only when the server sent one", () => {
    const { rerender } = render(<ErrorList errors={["Boom"]} />);

    expect(screen.queryByRole("heading")).toBeNull();

    rerender(
      <ErrorList
        errors={["Boom"]}
        header="The server rejected this form."
      />,
    );

    expect(screen.getByText("The server rejected this form.")).toBeTruthy();
    expect(screen.queryByRole("heading")).toBeNull();
  });
});

// These are summary announcements, never live regions on field errors.
it("announces an asynchronous failure only when the caller opts in", () => {
  const { rerender } = render(
    <ErrorList
      errors={[]}
      announce
    />,
  );
  expect(screen.queryByRole("alert")).toBeNull();
  rerender(
    <ErrorList
      errors={["Try again."]}
      announce
    />,
  );
  expect(screen.getByRole("alert").textContent).toContain("Try again.");
});
it("preserves repeated and empty server messages without inventing validation", () => {
  render(<ErrorList errors={["", "Failed", "Failed"]} />);
  expect(screen.getAllByRole("listitem")).toHaveLength(3);
});
