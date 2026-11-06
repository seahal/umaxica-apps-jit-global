# typed: false
# frozen_string_literal: true

# Replaces the offline Worker on an origin that no longer uses one. The old Worker re-fetched every
# navigation, which the browser reports as `Sec-Fetch-Dest: empty`, and Auth admission refuses that.
# This script has no fetch handler, deletes only the Worker's own cache, and unregisters itself.
# Exit condition: remove this and its routes once installed Workers have aged out.
module ServiceWorkerRetirement
  extend ActiveSupport::Concern

  SCRIPT = <<~JAVASCRIPT
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => {
      event.waitUntil(caches.delete("offline").then(() => self.registration.unregister()));
    });
  JAVASCRIPT

  public

  def show
    render plain: SCRIPT, content_type: "text/javascript"
  end
end
