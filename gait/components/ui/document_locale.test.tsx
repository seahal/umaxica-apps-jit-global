import { render, screen, waitFor } from "@testing-library/react";
import { useLocale } from "react-aria-components";
import { afterEach, expect, it } from "vitest";

import DocumentLocale from "@/components/ui/DocumentLocale";

// Probe the public context that React Aria controls consume.
function LocaleConsumer() {
  const { locale } = useLocale();
  return <output>{locale}</output>;
}
afterEach(() => {
  document.documentElement.lang = "en";
});
it("uses the server document language instead of the browser language and follows document changes", async () => {
  document.documentElement.lang = "ja";
  render(
    <DocumentLocale>
      <LocaleConsumer />
    </DocumentLocale>,
  );
  expect(screen.getByRole("status").textContent).toBe("ja");
  document.documentElement.lang = "en";
  await waitFor(() => expect(screen.getByRole("status").textContent).toBe("en"));
});
