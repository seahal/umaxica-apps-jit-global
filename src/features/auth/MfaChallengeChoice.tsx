// The second-factor screen of a sign-in ceremony.
//
// Which factors the actor may use is decided on the server from the credentials they actually hold,
// so a factor the actor cannot use is absent from `methods` rather than rendered and hidden. When
// no factor is available the server sends the notice, and cancellation is the only way out: the
// first factor has already been consumed, so the sign-in form is not a step back.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

export type MfaMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type MfaChallengeChoiceProps = {
  title: string;
  description: string;
  methods: MfaMethodLink[];
  no_methods_notice: string | null;
  cancel: CeremonyCancellationProps;
};

export default function MfaChallengeChoice({
  title,
  description,
  methods,
  no_methods_notice: noMethodsNotice,
  cancel,
}: MfaChallengeChoiceProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      {/* Document visits: each factor ceremony has its own guards. */}
      <NavList items={methods} />

      {noMethodsNotice ? <p className="text-sm text-fg-muted">{noMethodsNotice}</p> : null}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
