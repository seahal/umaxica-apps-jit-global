import ButtonLink from "@/components/ui/ButtonLink";
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";

type Props = {
  title: string;
  count: number;
  secrets: { id: string; name: string; href: string }[];
  add: { href: string; label: string };
};

export default function SecretIndex({ title, count, secrets, add }: Props) {
  return (
    <Page
      title={title}
      actions={<ButtonLink href={add.href}>{add.label}</ButtonLink>}
    >
      <p className="text-base text-fg-muted">{count}</p>
      <NavList items={secrets.map((secret) => ({ label: secret.name, href: secret.href }))} />
    </Page>
  );
}
