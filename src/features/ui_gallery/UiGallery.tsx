// Every shared primitive on one page, for the dev surface only.
//
// This replaces the old "React Aria probe", which demonstrated a shim that only looked like React
// Aria: it exported a hand-written `Button` and a `TextField` that was a bare `<div>`, so the page
// proved nothing about the library it was named after.
//
// What it is for now: rendering each primitive in one place is how the visual states that no unit
// test can assert — the focus ring, the dark palette, contrast, the overlay's position — get
// checked in a real browser. It ships only on `core/dev`.
import { useState } from "react";

import Button, { type ButtonVariant } from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import DescriptionList from "@/components/ui/DescriptionList";
import Dialog from "@/components/ui/Dialog";
import DocumentLocale from "@/components/ui/DocumentLocale";
import ErrorList from "@/components/ui/ErrorList";
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";
import RadioGroup from "@/components/ui/RadioGroup";
import Select from "@/components/ui/Select";
import Table from "@/components/ui/Table";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";

const VARIANTS: ButtonVariant[] = ["primary", "secondary", "danger", "ghost"];

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return <Card heading={title}>{children}</Card>;
}

export function UiGallery(_props: Record<string, unknown>) {
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <DocumentLocale>
      <Page
        title="UI primitives"
        description="Each primitive below is the one the application uses. Switch the theme control in
        the footer to check the dark palette, and tab through the page to check the focus ring."
        width="wide"
      >
        <p className="text-sm font-medium tracking-wide text-fg-muted uppercase">
          Internal, dev surface only
        </p>

        <Section title="Button">
          <div className="flex flex-wrap items-center gap-2">
            {VARIANTS.map((variant) => (
              <Button
                key={variant}
                variant={variant}
              >
                {variant}
              </Button>
            ))}
            <Button isDisabled>disabled</Button>
          </div>

          {/* The link that wears the button. Its appearance comes from the same source. */}
          <div className="flex flex-wrap items-center gap-2">
            <ButtonLink href="#gallery">primary link</ButtonLink>
            <ButtonLink
              href="#gallery"
              variant="secondary"
              size="sm"
            >
              secondary, small
            </ButtonLink>
            <TextLink href="#gallery">inline link</TextLink>
            <TextLink
              href="#gallery"
              tone="muted"
            >
              muted inline link
            </TextLink>
          </div>
        </Section>

        <Section title="TextField">
          <TextField
            label="Address"
            description="Bound to its description through aria-describedby."
            placeholder="you@example.com"
            type="email"
          />
          <TextField
            label="Rejected address"
            errorMessage="The server rejected this address."
            defaultValue="not-an-address"
            type="email"
          />
          <TextField
            label="Disabled"
            isDisabled
            defaultValue="unavailable"
          />
        </Section>

        <Section title="Select">
          <Select
            label="Theme"
            defaultValue="system"
            options={[
              { value: "system", label: "Follow the system" },
              { value: "light", label: "Light" },
              { value: "dark", label: "Dark" },
            ]}
          />
        </Section>

        <Section title="Checkbox and RadioGroup">
          <Checkbox defaultSelected>Functional cookies</Checkbox>
          <Checkbox>Performance cookies</Checkbox>
          <Checkbox isDisabled>Unavailable</Checkbox>

          <RadioGroup
            label="Delivery"
            defaultValue="email"
            options={[
              { value: "email", label: "Email", description: "The address on the account." },
              { value: "sms", label: "SMS" },
              { value: "none", label: "Nothing", isDisabled: true },
            ]}
          />
        </Section>

        <Section title="Dialog">
          <div>
            <Button onPress={() => setDialogOpen(true)}>Open the dialog</Button>
          </div>
          <Dialog
            title="Is the overlay positioned and trapped?"
            isOpen={dialogOpen}
            onOpenChange={setDialogOpen}
          >
            <p className="text-sm text-fg-muted">
              Tab should stay inside this dialog, Escape should close it, and focus should return to
              the control that opened it.
            </p>
            <div className="flex justify-end">
              <Button
                autoFocus
                variant="secondary"
                onPress={() => setDialogOpen(false)}
              >
                Close
              </Button>
            </div>
          </Dialog>
        </Section>

        <Section title="ErrorList">
          <ErrorList
            header="The server rejected this form."
            errors={["The address is already registered.", "The code has expired."]}
          />
        </Section>

        <Section title="NavList">
          <NavList
            items={[
              { label: "Passkey", href: "#gallery" },
              { label: "Authenticator app", href: "#gallery", description: "A six-digit code." },
              { label: "Recovery code", href: null, description: "No entry point from here." },
            ]}
          />
        </Section>

        <Section title="DescriptionList">
          <DescriptionList
            items={[
              { term: "Created", description: "1 January 2026" },
              { term: "Last used", description: "Never" },
            ]}
          />
        </Section>

        <Section title="Table">
          <Table label="Sessions">
            <thead>
              <tr>
                <th scope="col">Session</th>
                <th scope="col">Kind</th>
                <th scope="col">Last activity</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="font-mono">ses_01</td>
                <td>Browser</td>
                <td className="whitespace-nowrap text-fg-muted">1 January 2026</td>
              </tr>
              <tr>
                <td className="font-mono">ses_02</td>
                <td>Mobile</td>
                <td className="whitespace-nowrap text-fg-muted">2 January 2026</td>
              </tr>
            </tbody>
          </Table>
        </Section>
      </Page>
    </DocumentLocale>
  );
}
