import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import PalmSignOutShow, { type PalmSignOutShowProps } from "@/pages/palm/app/sign_outs/show";

const props: PalmSignOutShowProps = {
  title: "Signed out",
  heading: "Signed out",
  description: "Your Palm session was revoked and the browser logout flow completed.",
  state: "client-state",
};

describe("palm app sign-out page", () => {
  it("labels the section with the heading it renders", () => {
    const markup = renderToStaticMarkup(<PalmSignOutShow {...props} />);

    expect(markup).toContain('aria-labelledby="palm-sign-out-title"');
    expect(markup).toContain('<h1 id="palm-sign-out-title"');
    expect(markup).toContain("Signed out");
  });

  it("renders the validated state the server confirmed", () => {
    const markup = renderToStaticMarkup(<PalmSignOutShow {...props} />);

    expect(markup).toContain("Your Palm session was revoked");
    expect(markup).toContain("<code");
    expect(markup).toContain("client-state");
  });

  it("omits the state paragraph when the server validated none", () => {
    const markup = renderToStaticMarkup(
      <PalmSignOutShow
        {...props}
        description="There is no active Palm logout transaction to display."
        state={null}
      />,
    );

    expect(markup).toContain("There is no active Palm logout transaction to display.");
    expect(markup).not.toContain("<code");
  });
});
