// User-facing strings shared by the React passkey ceremonies.
//
// They were string literals in the controllers rather than i18n lookups, so the React port keeps
// them literal: inventing translation keys here would change what an operator reads mid-ceremony.
export const PASSKEY_MESSAGES = {
  unsupported: "このブラウザはPasskeyに対応していません",
  fetchingOptions: "認証オプションを取得中...",
  optionsFailed: "オプションの取得に失敗しました",
  optionsMissing: "認証オプションの取得に失敗しました",
  confirming: "認証器でPasskeyを確認中...",
  creating: "認証器でPasskeyを作成中...",
  verifying: "サーバーで検証中...",
  verificationFailed: "認証に失敗しました",
  registrationFailed: "登録に失敗しました",
  registrationComplete: "登録完了！リダイレクト中...",
  loginComplete: "ログイン成功！リダイレクト中...",
  totpRequired: "二段階認証が必要です...",
  unexpectedResponse: "予期しない応答です",
  cancelled: "認証がキャンセルされました",
  securityError: "セキュリティエラーが発生しました",
  alreadyRegistered: "このPasskeyは既に登録されています",
  authenticationError: "認証中にエラーが発生しました",
  registrationError: "登録中にエラーが発生しました",
} as const;

export const TURNSTILE_DEFAULT_ERROR =
  "Security verification failed. Please refresh and try again.";

/** Mirrors the `error.name` branches the Stimulus controllers used. */
export function authenticationErrorMessage(error: unknown): string {
  if (error instanceof DOMException || error instanceof Error) {
    if (error.name === "NotAllowedError") {
      return PASSKEY_MESSAGES.cancelled;
    }
    if (error.name === "SecurityError") {
      return PASSKEY_MESSAGES.securityError;
    }
    return error.message || PASSKEY_MESSAGES.authenticationError;
  }
  return PASSKEY_MESSAGES.authenticationError;
}

/** Mirrors the `error.name` branches of the registration controller. */
export function registrationErrorMessage(error: unknown): string {
  if (error instanceof DOMException || error instanceof Error) {
    if (error.name === "NotAllowedError") {
      return PASSKEY_MESSAGES.cancelled;
    }
    if (error.name === "InvalidStateError") {
      return PASSKEY_MESSAGES.alreadyRegistered;
    }
    return error.message || PASSKEY_MESSAGES.registrationError;
  }
  return PASSKEY_MESSAGES.registrationError;
}
