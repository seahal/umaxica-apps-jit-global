// Driving the two JSON requests a Stimulus passkey ceremony makes.
//
// Both controllers POST to a begin url, call the credential API, then POST to a finish url. A spec
// cares which url got which payload and how each response was read, so `fetch` is queued rather
// than pattern-matched: the order is the ceremony's own, and asserting on it is asserting that the
// steps ran in it.
import { expect, vi } from "vitest";

import { type FetchMock, jsonResponse, requestBody, requestUrl, textResponse } from "./http";

export { jsonResponse, textResponse };

export type CeremonyFetch = FetchMock;

/** Installs a `fetch` that answers the queued responses in order and refuses anything beyond. */
export function stubCeremonyFetch(...responses: Response[]) {
  const queue = [...responses];
  const fetchMock = vi.fn<typeof fetch>(() => {
    const next = queue.shift();

    if (!next) {
      return Promise.reject(new Error("The ceremony made more requests than the spec queued."));
    }

    return Promise.resolve(next);
  });

  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

/** The url and parsed JSON body of the nth request the ceremony made. */
export function requestAt(fetchMock: CeremonyFetch, index: number) {
  const call = fetchMock.mock.calls[index];

  if (!call) {
    throw new Error(`The ceremony made no request at index ${index}.`);
  }

  expect(call[1]?.method).toBe("POST");

  return { url: requestUrl(fetchMock, index), body: requestBody(fetchMock, index) };
}
