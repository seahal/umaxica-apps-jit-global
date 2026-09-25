// Registers the offline fallback service worker for this origin.
//
// Unlike the base and auth entrypoints, this one does not import ../application: the Warp
// layouts ship no JavaScript bundle today, and pulling Turbo, Stimulus, and Inertia into them would
// be an unrelated behaviour change. See adr/pwa-offline-route-exception.md.

import { registerOfflineServiceWorker } from "../../pwa/register";

void registerOfflineServiceWorker();
