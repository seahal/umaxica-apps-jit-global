import { afterEach, describe, expect, test, vi } from "vitest";

import { handleStepUpChallenge } from "@/lib/step_up_challenge";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("handleStepUpChallenge", () => {
  test("routes a canonical Bearer challenge to the same-origin entry and carries only the page path and region", () => {
    const location = {
      href: "https://base.example.test/identity/passkeys/passkey-1?ri=jp&private=omitted",
      origin: "https://base.example.test",
      assign: vi.fn<(target: string) => void>(),
    };
    vi.stubGlobal("window", { location });

    expect(
      handleStepUpChallenge({
        status: 401,
        headers: {
          "www-authenticate":
            'Bearer error="insufficient_user_authentication", error_description="step-up authentication is required", acr_values="https://visa.umaxica.app/acr/reauthentication", max_age="300"',
        },
      }),
    ).toBe(true);

    expect(location.assign).toHaveBeenCalledOnce();
    expect(location.assign).toHaveBeenCalledWith(
      "https://base.example.test/verification?return_target=%2Fidentity%2Fpasskeys%2Fpasskey-1&ri=jp",
    );
  });

  test("recognizes the same challenge from an Inertia response header record", () => {
    const location = {
      href: "https://base.example.test/identity/passkeys/passkey-1",
      origin: "https://base.example.test",
      assign: vi.fn<(target: string) => void>(),
    };
    vi.stubGlobal("window", { location });

    expect(
      handleStepUpChallenge({
        status: 401,
        headers: { "WWW-Authenticate": 'Bearer error="insufficient_user_authentication"' },
      }),
    ).toBe(true);
    expect(location.assign).toHaveBeenCalledTimes(1);
  });

  test.each([
    { status: 403, challenge: 'Bearer error="insufficient_user_authentication"' },
    { status: 401, challenge: 'Bearer error="invalid_token"' },
    { status: 401, challenge: 'Basic error="insufficient_user_authentication"' },
    { status: 302, challenge: 'Bearer error="insufficient_user_authentication"' },
  ])("does not handle status $status with $challenge", ({ status, challenge }) => {
    const location = {
      href: "https://base.example.test/identity/passkeys/passkey-1",
      origin: "https://base.example.test",
      assign: vi.fn<(target: string) => void>(),
    };
    vi.stubGlobal("window", { location });

    expect(
      handleStepUpChallenge({
        status,
        headers: new Headers({ "WWW-Authenticate": challenge }),
      }),
    ).toBe(false);
    expect(location.assign).not.toHaveBeenCalled();
  });
});
