// Answering `fetch` from a spec, and reading back what the code under test sent.
//
// `RequestInit["body"]` is a union that includes streams and form data, so reading it needs a
// narrowing step rather than a `String(...)` that would quietly answer "[object Object]" for the
// shapes this application never sends. Doing that once here keeps every spec's assertion honest.
import { vi } from "vitest";

export type FetchMock = { mock: { calls: Parameters<typeof fetch>[] } };

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/**
 * The empty answer a Rails `head :no_content` sends. Calling `.json()` on it rejects, exactly as it
 * does in a browser, so a spec using this catches code that assumes a body it never gets.
 */
export function noContentResponse(): Response {
  return new Response(null, { status: 204 });
}

/**
 * A response the code under test must handle without parsing it as JSON. `contentType` is optional
 * because a server behind a proxy can answer with none at all, and that path needs covering too.
 */
export function textResponse(body: string, status: number, contentType = "text/html"): Response {
  return new Response(body, {
    status,
    ...(contentType === "" ? {} : { headers: { "content-type": contentType } }),
  });
}

function urlOf(target: Parameters<typeof fetch>[0]): string {
  if (typeof target === "string") {
    return target;
  }

  return target instanceof URL ? target.href : target.url;
}

export function jsonBody(init: RequestInit | undefined): unknown {
  const { body } = init ?? {};

  if (typeof body !== "string") {
    throw new TypeError(`Expected the request body to be a JSON string, got ${typeof body}.`);
  }

  return JSON.parse(body);
}

/** The parsed JSON body of the nth request, in the order the code under test made them. */
export function requestBody(fetchMock: FetchMock, index = 0): unknown {
  return jsonBody(fetchMock.mock.calls[index]?.[1]);
}

/** The url of the nth request. */
export function requestUrl(fetchMock: FetchMock, index = 0): string {
  const call = fetchMock.mock.calls[index];

  if (!call) {
    throw new Error(`No request was made at index ${index}.`);
  }

  return urlOf(call[0]);
}

/** The first request made with `method`, for the specs whose subject also reads on connect. */
export function requestWithMethod(fetchMock: FetchMock, method: string) {
  const call = fetchMock.mock.calls.find(([, init]) => init?.method === method);

  return call ? { url: urlOf(call[0]), body: jsonBody(call[1]) } : undefined;
}

/** Installs a `fetch` that answers the queued responses in order, then repeats the last one. */
export function stubFetchQueue(...responses: Response[]) {
  const fetchMock = vi.fn<typeof fetch>();
  responses.forEach((response) => fetchMock.mockResolvedValueOnce(response));
  const last = responses.at(-1);
  if (last) {
    fetchMock.mockResolvedValue(last);
  }
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

/**
 * Installs a `fetch` that answers by request method, for the specs whose subject both reads and
 * writes. `pending` is left unresolved so a spec can decide when the read lands.
 */
export function stubFetchByMethod(answers: Record<string, Response>) {
  // The resolver is collected rather than reassigned into a closure variable, so nothing in here
  // is a function that exists only to be overwritten later.
  const settlers: ((response: Response) => void)[] = [];
  const pending = new Promise<Response>((resolve) => {
    settlers.push(resolve);
  });

  const fetchMock = vi.fn<typeof fetch>((_input, init) => {
    const answer = answers[init?.method ?? "GET"];

    return answer ? Promise.resolve(answer) : pending;
  });

  vi.stubGlobal("fetch", fetchMock);

  return {
    fetchMock,
    settlePending: (response: Response) => {
      settlers.forEach((settle) => settle(response));
    },
  };
}

/**
 * Installs a `fetch` that builds a fresh answer per request method. A `Response` body can be read
 * once, so a subject that reads more than once (connect, then an explicit sync) needs a new one each
 * time. Keeping the method dispatch here keeps the specs themselves free of branches.
 */
export function stubFetchAnswering(
  answers: Record<string, (init: RequestInit | undefined) => Response | Promise<Response>>,
) {
  const fetchMock = vi.fn<typeof fetch>((_input, init) => {
    const method = init?.method ?? "GET";
    const answer = answers[method];

    if (!answer) {
      throw new Error(`No answer was stubbed for ${method}.`);
    }

    return Promise.resolve(answer(init));
  });

  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}
