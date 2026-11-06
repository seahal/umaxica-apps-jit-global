import { expect, test, type Route } from "playwright/test";

type InertiaPage = Record<string, unknown> & {
  props: Record<string, unknown>;
};

type PreferenceChoice = {
  value: number;
  disabled?: boolean;
};

type PreferenceForm = Record<string, unknown> & {
  value: number;
  choices: PreferenceChoice[];
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isInertiaPage(value: unknown): value is InertiaPage {
  return isRecord(value) && isRecord(value["props"]);
}

function isPreferenceChoice(value: unknown): value is PreferenceChoice {
  return (
    isRecord(value) &&
    typeof value["value"] === "number" &&
    (value["disabled"] === undefined || typeof value["disabled"] === "boolean")
  );
}

function isPreferenceForm(value: unknown): value is PreferenceForm {
  return (
    isRecord(value) &&
    typeof value["value"] === "number" &&
    Array.isArray(value["choices"]) &&
    value["choices"].every(isPreferenceChoice)
  );
}

function readInertiaPage(value: unknown): InertiaPage {
  if (!isInertiaPage(value)) {
    throw new Error("Rails response did not contain valid Inertia props");
  }
  return value;
}

function parseInitialPage(serialized: string | null): InertiaPage {
  if (serialized === null) {
    throw new Error("Rails page did not include its Inertia payload");
  }
  return readInertiaPage(JSON.parse(serialized));
}

function readPreferenceForm(page: InertiaPage): PreferenceForm {
  const { form } = page.props;
  if (!isPreferenceForm(form)) {
    throw new Error("Rails page did not provide preference form props");
  }
  return form;
}

function alternateChoice(form: PreferenceForm): PreferenceChoice {
  const choice = form.choices.find(
    (candidate) => !candidate.disabled && candidate.value !== form.value,
  );
  if (choice === undefined) {
    throw new Error("Rails theme page had no alternate choice");
  }
  return choice;
}

function twoAlternateChoices(form: PreferenceForm): [PreferenceChoice, PreferenceChoice] {
  const choices = form.choices.filter(
    (candidate) => !candidate.disabled && candidate.value !== form.value,
  );
  const submitted = choices.at(0);
  const newer = choices.at(1);
  if (submitted === undefined || newer === undefined) {
    throw new Error("Rails theme page did not provide two choices for the edit race");
  }
  return [submitted, newer];
}

function isInertiaPatchResponse(response: {
  request(): { method(): string };
  headers(): Record<string, string>;
}) {
  return response.request().method() === "PATCH" && response.headers()["x-inertia"] === "true";
}

async function fulfillPatchWithPage(
  route: Route,
  page: () => InertiaPage,
  beforeFulfill: () => Promise<void> = async () => {},
): Promise<void> {
  if (route.request().method() !== "PATCH") {
    await route.continue();
    return;
  }

  await beforeFulfill();
  await route.fulfill({
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "x-inertia": "true",
      vary: "X-Inertia",
    },
    body: JSON.stringify(page()),
  });
}

test("same-page server update replaces a clean preference selection", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.name));
  await page.setViewportSize({ width: 320, height: 900 });
  const response = await page.goto(
    "http://base.com.localhost:3198/preference/theme/edit?ri=jp&lx=ja",
  );
  expect(response?.status()).toBe(200);

  const select = page.getByRole("combobox");
  await expect(select).toBeVisible();

  const pageElement = page.locator('script[type="application/json"][data-page="app"]');
  const initialPage = parseInitialPage(await pageElement.textContent());
  const initialForm = readPreferenceForm(initialPage);
  const nextChoice = alternateChoice(initialForm);
  await expect(select).toHaveValue(String(initialForm.value));

  await page.route("**/preference/theme**", (route) =>
    fulfillPatchWithPage(route, () => ({
      ...initialPage,
      props: {
        ...initialPage.props,
        form: { ...initialForm, value: nextChoice.value },
      },
    })),
  );

  await select.focus();
  await page.keyboard.press("Tab");
  const submit = page.getByRole("button", { name: "更新" });
  await expect(submit).toBeFocused();
  const patchResponse = page.waitForResponse(isInertiaPatchResponse);
  await page.keyboard.press("Enter");
  const updated = await patchResponse;
  const updatedForm = readPreferenceForm(readInertiaPage(await updated.json()));

  expect(updatedForm.value).toBe(nextChoice.value);
  await expect(select).toHaveValue(String(nextChoice.value));
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
  expect(pageErrors).toEqual([]);
});

test("same-page server update preserves a newer selection made during submission", async ({
  page,
}) => {
  const pageErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.name));
  const response = await page.goto(
    "http://base.com.localhost:3198/preference/theme/edit?ri=jp&lx=ja",
  );
  expect(response?.status()).toBe(200);

  const select = page.getByRole("combobox");
  const pageElement = page.locator('script[type="application/json"][data-page="app"]');
  const initialPage = parseInitialPage(await pageElement.textContent());
  const initialForm = readPreferenceForm(initialPage);
  const [submittedChoice, newerChoice] = twoAlternateChoices(initialForm);
  await expect(select).toHaveValue(String(initialForm.value));

  let markPatchArrived!: () => void;
  const patchArrived = new Promise<void>((resolve) => {
    markPatchArrived = resolve;
  });
  let releaseResponse!: () => void;
  const responseGate = new Promise<void>((resolve) => {
    releaseResponse = resolve;
  });
  await page.route("**/preference/theme**", (route) =>
    fulfillPatchWithPage(
      route,
      () => ({
        ...initialPage,
        props: {
          ...initialPage.props,
          form: { ...initialForm, value: submittedChoice.value },
        },
      }),
      async () => {
        markPatchArrived();
        await responseGate;
      },
    ),
  );

  await select.selectOption(String(submittedChoice.value));
  const patchResponse = page.waitForResponse(isInertiaPatchResponse);
  await page.getByRole("button", { name: "更新" }).click();
  await patchArrived;
  await select.selectOption(String(newerChoice.value));
  releaseResponse();
  const updated = await patchResponse;
  const updatedForm = readPreferenceForm(readInertiaPage(await updated.json()));

  expect(updatedForm.value).toBe(submittedChoice.value);
  await expect(select).toHaveValue(String(newerChoice.value));
  expect(pageErrors).toEqual([]);
});
