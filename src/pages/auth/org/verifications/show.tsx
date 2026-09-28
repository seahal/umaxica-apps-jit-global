// The step-up entry screen: pick a verification method.
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

export type OrgVerificationEntryProps = {
  title: string;
  section_title: string;
  section_description: string;
  notice: string | null;
  no_methods: string | null;
  methods: { key: string; label: string; href: string }[];
  cancel: CeremonyCancellationProps;
};

export default function OrgVerificationEntry({
  title,
  section_title: sectionTitle,
  section_description: sectionDescription,
  notice,
  cancel,
  no_methods: noMethods,
  methods,
}: OrgVerificationEntryProps) {
  return (
    <Page title={title}>
      {notice ? (
        <output className="rounded-lg border border-line bg-surface-muted px-4 py-3 text-sm text-fg">
          {notice}
        </output>
      ) : null}

      <Card heading={sectionTitle}>
        <p className="text-sm text-fg-muted">{sectionDescription}</p>

        {noMethods ? <p className="text-sm text-fg-muted">{noMethods}</p> : null}

        {methods.length > 0 ? (
          <ul className="flex flex-col gap-2">
            {methods.map((method) => (
              <li key={method.key}>
                <a
                  href={method.href}
                  className="flex items-center justify-between gap-3 rounded-lg border border-line
                    px-4 py-3 text-sm font-medium text-fg hover:bg-surface-muted"
                >
                  <span>{method.label}</span>
                  <span
                    aria-hidden="true"
                    className="text-fg-muted"
                  >
                    &rarr;
                  </span>
                </a>
              </li>
            ))}
          </ul>
        ) : null}
      </Card>
      {/* Ends the whole Step-Up ceremony; the server decides where the actor lands. */}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
