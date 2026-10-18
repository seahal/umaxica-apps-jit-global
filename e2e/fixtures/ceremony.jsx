import { createRoot } from "react-dom/client";

import OtpVerificationForm from "../../src/features/auth/signup/OtpVerificationForm";
import SignUpCheckpoint from "../../src/features/auth/signup/SignUpCheckpoint";
import SignUpMethodChoice from "../../src/features/auth/signup/SignUpMethodChoice";
import SecretSignIn from "../../src/pages/auth/app/sign/in/secrets/new";

import "../../src/styles/surfaces/auth_app.css";

// Synthetic display data; this fixture has no admitted ceremony, credential or backend state.
const params = new URLSearchParams(window.location.search);
const screen = params.get("screen");
const root = document.querySelector("#fixture");
if (!root) {
  throw new Error("The ceremony fixture root is missing.");
}

let content;
switch (screen) {
  case "methods":
    content = (
      <SignUpMethodChoice
        title="Choose a registration method"
        suspended_notice={null}
        methods={[
          { key: "email", label: "Email registration", href: "/synthetic/email" },
          { key: "telephone", label: "Telephone registration", href: "/synthetic/telephone" },
        ]}
        social_providers={[]}
        links={[{ key: "sign_in", label: "Sign in", href: "/synthetic/sign-in" }]}
      />
    );
    break;
  case "checkpoint":
    content = (
      <SignUpCheckpoint
        title="Complete registration"
        notice={null}
        birthdate={null}
        passkey={{
          title: "Register a passkey",
          description: "A passkey is required for this synthetic example.",
          label: "Continue with a passkey",
          href: "/synthetic/passkey",
        }}
        complete_message={null}
        cancellation={{ label: "Cancel registration", action: "/synthetic/cancel" }}
      />
    );
    break;
  case "otp":
    content = (
      <OtpVerificationForm
        title="Verify the code"
        description="Enter the code sent to your contact."
        action="/synthetic/otp"
        scope="client_email"
        code_label="Verification code"
        code_placeholder="123456"
        submit_label="Verify"
        delivery_help="Check the message delivery."
        error_heading="Check the code"
        errors={["The synthetic code was not accepted."]}
        cancel={{ label: "Cancel registration", action: "/synthetic/cancel", method: "delete" }}
      />
    );
    break;
  case "secret":
    content = (
      <SecretSignIn
        title="Sign in with a Secret"
        label="Secret"
        submit="Continue"
        error={null}
        action="/synthetic/secret"
        authenticity_token="synthetic"
        turnstile={{ site_key: "synthetic", action: "sign_in", mode: "render", cdata: null }}
      />
    );
    break;
  default:
    throw new Error("An explicit supported fixture screen is required.");
}
createRoot(root).render(content);
