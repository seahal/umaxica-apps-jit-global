import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";

const patch = vi.fn();
const deleteRequest = vi.fn();

vi.mock("@inertiajs/react", () => ({
  useForm: () => ({
    processing: false,
    patch,
    delete: deleteRequest,
    transform: (fn: () => unknown) => {
      fn();
      return { patch, delete: deleteRequest, processing: false };
    },
  }),
}));

import type { SessionLimitManagerProps } from "@/features/auth/session/SessionLimitManager";

import { answerConfirmation } from "../../../support/confirmation";

const { default: SessionLimitManager } =
  await import("@/features/auth/session/SessionLimitManager");
const { default: AuthAppSessionsShow } = await import("@/pages/auth/app/sign/in/sessions/show");

const props: SessionLimitManagerProps = {
  title: "セッション管理",
  heading: "セッション管理",
  description: "同時にログインできるセッション数の上限に達しています。",
  alert: null,
  notice: null,
  restricted_notice: "セッション枠を空けるまで、セッションは制限されています。",
  form: { action: "/sign/in/session?ri=jp", submit_label: "選択したセッションを無効化して続行" },
  cancel: {
    action: "/sign/in/session?ri=jp",
    label: "キャンセルしてログアウト",
    confirm: "キャンセルしますか？",
  },
  active_sessions: {
    heading: "アクティブなセッション",
    count_label: "(2/2)",
    revoke_label: "無効化",
    items: [
      {
        label: "セッション",
        current: false,
        current_label: null,
        created_at_label: "作成日時",
        created_at: "2026-01-01 09:00",
        last_used_at_label: "最終使用",
        last_used_at: "2026-01-02 09:00",
        ref: "signed-ref-one",
      },
      {
        label: "セッション",
        current: true,
        current_label: "現在",
        created_at_label: "作成日時",
        created_at: "2026-01-03 09:00",
        last_used_at_label: null,
        last_used_at: null,
        ref: null,
      },
    ],
  },
  restricted_sessions: {
    heading: "保留中のセッション",
    items: [
      {
        label: "保留中のセッション",
        current: true,
        current_label: "現在",
        created_at_label: "作成日時",
        created_at: "2026-01-03 09:05",
        last_used_at_label: null,
        last_used_at: null,
        ref: null,
      },
      {
        label: "他の保留",
        current: false,
        current_label: null,
        created_at_label: "作成日時",
        created_at: "2026-01-03 09:06",
        last_used_at_label: null,
        last_used_at: null,
        ref: null,
      },
    ],
  },
};

// Null until a test mounts, so the teardown guard below is a real check rather than one the type
// system already knows the answer to.
let container: HTMLDivElement | null = null;
let root: Root | null = null;

/** The container a test mounted into; reading it before mounting is the test's own mistake. */
const mounted = (): HTMLDivElement => present(container, "a mounted container");

const requireInput = (selector: string): HTMLInputElement => {
  const input = mounted().querySelector<HTMLInputElement>(selector);
  if (!input) {
    throw new Error(`no input matched ${selector}`);
  }
  return input;
};

const mount = (element: React.ReactElement) => {
  const host = document.createElement("div");
  document.body.append(host);
  const created = createRoot(host);
  container = host;
  root = created;
  act(() => {
    created.render(element);
  });
};

afterEach(() => {
  const mountedRoot = root;

  if (mountedRoot) {
    act(() => {
      mountedRoot.unmount();
    });
    container?.remove();
    root = null;
    container = null;
  }

  patch.mockClear();
  deleteRequest.mockClear();
  vi.unstubAllGlobals();
});

describe("SessionLimitManager markup", () => {
  it("offers a signed reference for every session the visitor may revoke", () => {
    const markup = renderToStaticMarkup(<SessionLimitManager {...props} />);

    expect(markup).toContain('name="ref" value="signed-ref-one"');
    // The current session is never revocable through the reference form.
    expect(markup).not.toContain('value="null"');
    expect(markup).toContain("(2/2)");
    expect(markup).toContain("現在");
    expect(markup).toContain("最終使用: 2026-01-02 09:00");
    expect(markup).toContain('<input type="hidden" name="_method" value="delete"/>');
  });

  it("shows the alert and the notice the server resolved", () => {
    const markup = renderToStaticMarkup(
      <SessionLimitManager
        {...props}
        alert="無効なセッション参照です。"
        notice="セッションを無効化しました。"
      />,
    );

    expect(markup).toContain('role="alert"');
    expect(markup).toContain("無効なセッション参照です。");
    // `<output>` carries an implicit `role="status"`, which is what the element is for.
    expect(markup).toMatch(/<output[^>]*>/u);
    expect(markup).toContain("セッションを無効化しました。");
  });

  it("renders neither group when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <SessionLimitManager
        {...props}
        restricted_notice={null}
        active_sessions={null}
        restricted_sessions={null}
      />,
    );

    expect(markup).not.toContain("<ul>");
    expect(markup).not.toContain("セッション枠を空けるまで");
  });
});

describe("SessionLimitManager interaction", () => {
  it("revokes the selected session with a PATCH", () => {
    mount(<SessionLimitManager {...props} />);

    const radio = requireInput('input[name="ref"]');

    act(() => {
      radio.click();
    });

    expect(radio.checked).toBe(true);

    act(() => {
      present(mounted().querySelectorAll("form")[0], "the limitation form").dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });

    expect(patch).toHaveBeenCalledWith("/sign/in/session?ri=jp");
  });

  it("cancels with a DELETE only after the visitor confirms", () => {
    mount(<SessionLimitManager {...props} />);

    const cancelForm = present(mounted().querySelectorAll("form")[1], "the cancel form");

    act(() => {
      cancelForm.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(document.querySelector("[role='dialog']")?.textContent).toContain(
      "キャンセルしますか？",
    );
    answerConfirmation(false);
    expect(deleteRequest).not.toHaveBeenCalled();

    act(() => {
      cancelForm.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
    answerConfirmation(true);

    expect(deleteRequest).toHaveBeenCalledWith("/sign/in/session?ri=jp");
  });
});

describe("auth/app session page", () => {
  it("re-exports the shared session manager", () => {
    expect(AuthAppSessionsShow).toBe(SessionLimitManager);
  });
});
import { present } from "../../../support/present";
