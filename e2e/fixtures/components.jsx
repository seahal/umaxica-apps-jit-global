import { useState } from "react";
import { useLocale } from "react-aria-components";
import { createRoot } from "react-dom/client";

import Card from "../../src/components/ui/Card";
import DocumentLocale from "../../src/components/ui/DocumentLocale";
import Select from "../../src/components/ui/Select";
import Table from "../../src/components/ui/Table";
import TextField from "../../src/components/ui/TextField";
import BirthdateFieldset from "../../src/features/auth/signup/BirthdateFieldset";
import { AdminNotices } from "../../src/features/org_admin/AdminContextPanel";

const query = new URLSearchParams(location.search);
document.documentElement.lang = query.get("lang") === "ja" ? "ja" : "en";
// Edition styles remain independently delivered, including in this isolated display fixture.
switch (query.get("edition") ?? "app") {
  case "app":
    await import("../../src/styles/surfaces/auth_app.css");
    break;
  case "com":
    await import("../../src/styles/surfaces/auth_com.css");
    break;
  case "org":
    await import("../../src/styles/surfaces/auth_org.css");
    break;
  default:
    throw new Error("Unsupported fixture edition");
}
function Content() {
  const { locale } = useLocale();
  const [value, setValue] = useState("0");
  return (
    <div className="mx-auto flex max-w-4xl flex-col gap-8 px-4 py-8">
      <h1 className="text-2xl font-semibold">Component acceptance</h1>
      <p data-locale>{locale}</p>
      <Card heading="Input conditions">
        <form
          aria-label="Synthetic choice"
          onSubmit={(event) => event.preventDefault()}
        >
          <Select
            name="preference[option_id]"
            label="Choice"
            value={value}
            onChange={setValue}
            description="Choose an available option."
            options={[
              { value: "0", label: "Stored", isDisabled: true },
              { value: "1", label: "Available" },
            ]}
          />
          <TextField
            label="Public name"
            description="Use the existing public name limit."
            errorMessage="Check this synthetic name."
          />
        </form>
      </Card>
      <Card>
        <h2
          id="birthdate"
          className="text-xl font-semibold"
        >
          Birthdate
        </h2>
        <form aria-label="Synthetic birthdate">
          <BirthdateFieldset
            labelledby="birthdate"
            format="YYYY-MM-DD"
            separator="-"
            parts={[
              { part: "year", label: "Year", placeholder: "1990", value: "", min: 1900, max: 2026 },
              { part: "month", label: "Month", placeholder: "01", value: "", min: 1, max: 12 },
              { part: "day", label: "Day", placeholder: "01", value: "", min: 1, max: 31 },
            ]}
          />
        </form>
      </Card>
      <Card heading="Records">
        <Table label="Ordinary records">
          <thead>
            <tr>
              <th scope="col">Record</th>
              <th scope="col">State</th>
              <th scope="col">Description</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Example</td>
              <td>Available</td>
              <td className="whitespace-nowrap">
                A synthetic record with several visible attributes
              </td>
            </tr>
          </tbody>
        </Table>
        <Table
          label="Administration records"
          density="dense"
        >
          <thead>
            <tr>
              <th scope="col">Record</th>
              <th scope="col">State</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Example</td>
              <td>Available</td>
            </tr>
          </tbody>
        </Table>
      </Card>
      <AdminNotices
        notices={[
          { tone: "info", message: "Result information" },
          { tone: "warning", message: "Review this synthetic operation before continuing" },
        ]}
      />
    </div>
  );
}
const root = document.querySelector("#fixture");
if (!root) {
  throw new Error("Missing component fixture root");
}
createRoot(root).render(
  <DocumentLocale>
    <Content />
  </DocumentLocale>,
);
