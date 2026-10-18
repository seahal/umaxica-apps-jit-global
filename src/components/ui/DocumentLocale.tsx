// Rails owns html[lang]. React Aria's built-in interaction messages follow that same language.
import { useEffect, useState, type ReactNode } from "react";
import { I18nProvider } from "react-aria-components";

export default function DocumentLocale({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState(() =>
    typeof document === "undefined" ? undefined : document.documentElement.lang || undefined,
  );
  useEffect(() => {
    const observer = new MutationObserver(() =>
      setLocale(document.documentElement.lang || undefined),
    );
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });
    return () => observer.disconnect();
  }, []);
  // An isolated render with no document language uses React Aria's own locale detection.
  return <I18nProvider {...(locale ? { locale } : {})}>{children}</I18nProvider>;
}
