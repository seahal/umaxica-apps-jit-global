import { act } from "react";
import { createRoot } from "react-dom/client";
import { describe, expect, it } from "vitest";

import StepUpAdmission from "@/features/base/StepUpAdmission";

describe("Base step-up admission", () => {
  it("posts the selected intent and current document CSRF token without replaying the protected operation", () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "first-token";
    document.head.append(meta);
    const container = document.createElement("div");
    document.body.append(container);
    const root = createRoot(container);
    try {
      act(() => {
        root.render(
          <StepUpAdmission
            title="Verify identity"
            description="Confirm before continuing."
            form={{
              action: "/verification?ri=jp",
              scope: "settings_birthdate",
              pt: "signed-return-path",
              submit_label: "Continue",
            }}
            cancel={{ href: "/identity?ri=jp", label: "Cancel" }}
          />,
        );
      });
      const form = container.querySelector("form");
      expect(form?.getAttribute("method")).toBe("post");
      expect(form?.getAttribute("action")).toBe("/verification?ri=jp");
      expect(container.querySelector('a[href="/identity?ri=jp"]')?.textContent).toBe("Cancel");
      meta.content = "current-token";
      act(() => {
        form?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      });
      expect(form).not.toBeNull();
      expect(Object.fromEntries(new FormData(form!))).toEqual({
        authenticity_token: "current-token",
        scope: "settings_birthdate",
        pt: "signed-return-path",
      });
    } finally {
      act(() => root.unmount());
      container.remove();
      meta.remove();
    }
  });
});
