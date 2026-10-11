// Driving the visit lifecycle callbacks a component hands to `router.get/post/patch/delete`.
//
// The components under test flip their own processing state from `onStart` and `onFinish` and
// ignore the visit they are given. The adapter still declares those callbacks as taking one, so a
// spec that types its router mocks from the adapter -- which is what makes the recorded url and
// payload assertions meaningful -- has to supply it. Building it once here keeps every spec free
// of both a type assertion and forty lines of irrelevant fixture.
import type { router } from "@inertiajs/react";

import { present } from "./present";

const noop = () => {};

type VisitHelperOptions = NonNullable<Parameters<typeof router.delete>[1]>;
type ActiveVisit = Parameters<NonNullable<VisitHelperOptions["onFinish"]>>[0];

const ACTIVE_VISIT: ActiveVisit = {
  // Visit
  method: "get",
  data: {},
  replace: false,
  preserveScroll: false,
  preserveState: false,
  only: [],
  except: [],
  headers: {},
  errorBag: null,
  forceFormData: false,
  queryStringArrayFormat: "brackets",
  async: false,
  showProgress: false,
  prefetch: false,
  fresh: false,
  reset: [],
  preserveUrl: false,
  preserveErrors: false,
  invalidateCacheTags: [],
  viewTransition: false,
  component: null,
  pageProps: null,
  cached: false,

  // PendingVisitOptions
  id: "spec-visit",
  url: new URL("http://example.test/"),
  completed: false,
  cancelled: false,
  interrupted: false,

  // VisitCallbacks
  onCancelToken: noop,
  onBefore: noop,
  onBeforeUpdate: noop,
  onStart: noop,
  onProgress: noop,
  onFinish: noop,
  onCancel: noop,
  onSuccess: noop,
  onError: noop,
  onHttpException: noop,
  onNetworkError: noop,
  onFlash: noop,
  onPrefetched: noop,
  onPrefetching: noop,
};

/** Tells the component its request started, the way the adapter would. */
export function startVisit(options: VisitHelperOptions | undefined): void {
  const callback = present(
    present(options, "the recorded visit options").onStart,
    "an onStart callback",
  );
  callback(ACTIVE_VISIT);
}

/** Tells the component its request finished, the way the adapter would. */
export function finishVisit(options: VisitHelperOptions | undefined): void {
  const callback = present(
    present(options, "the recorded visit options").onFinish,
    "an onFinish callback",
  );
  callback(ACTIVE_VISIT);
}
