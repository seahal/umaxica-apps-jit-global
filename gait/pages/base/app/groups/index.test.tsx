import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import GroupsIndex from "@/pages/base/app/groups/index";

describe("base app groups page", () => {
  it("renders the visible groups screen and title", () => {
    const html = renderToStaticMarkup(
      <GroupsIndex
        title="Groups"
        empty_message="No groups"
        groups={[]}
      />,
    );

    expect(html).toContain("<h1");
    expect(html).toContain("Groups");
    expect(html).toContain("No groups");
  });
  it("links each authorized group to its GET detail without an Inertia visit", () => {
    const html = renderToStaticMarkup(
      <GroupsIndex
        title="Groups"
        empty_message="No groups"
        groups={[{ public_id: "group-1", name: "My group", href: "/groups/group-1?ri=jp" }]}
      />,
    );
    expect(html).toContain('href="/groups/group-1?ri=jp"');
    expect(html).toContain("My group");
    expect(html).not.toContain("No groups");
  });
});
