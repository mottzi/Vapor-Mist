# Release Notes

### 🌟 New Features & Improvements

**External Model Synchronization**
You can now keep Mist UI components perfectly in sync with database mutations that happen outside of standard client-initiated actions (like from background jobs, cron tasks, or CLI commands). 
- Use `app.mist.models.sync(_:id:)` to push upserts to connected clients.
- Use `app.mist.models.delete(_:id:)` to broadcast deletions and refresh observed query components.

**Static (Model-Less) Streams & Activity Hooks**
Streams are no longer strictly bound to specific model instances. You can now register global or component-level static streams.
- Create static streams via `app.mist.streams.staticStream(component:stream:retainingLines:maxBytes:onActive:onInactive:)`.
- Features `onActive` and `onInactive` lifecycle hooks. Optimize your backend resources by starting system log tailers only when the first user subscribes, and stopping them when the last user leaves.

**Client-Side & Server-Side Stream Buffering Limits**
Prevent browser memory leaks and DOM layout bloat on long-lived streaming pages.
- Add the `data-mist-stream-limit` attribute to your HTML elements to restrict the maximum number of stream lines kept in the DOM. 
- `mist.js` dynamically truncates older lines during updates.
- Server-side memory buffer usage can also be bounded via `retainingLines` and `maxBytes`.

**Smart Stream Auto-Scrolling Guard**
Improved user experience for live log streams: the browser will now only auto-scroll to the bottom of a stream element if the user is already scrolled to the bottom (within a 24px threshold). No more forceful scrolling when reading historical logs!

**State-Aware Fragment Action Rendering**
Fragment components (`LiveComponent`, `ManualComponent`, `PollingComponent`, `QueryComponent`) now inherently receive and render per-client component state (`ComponentState`) out-of-the-box, ensuring `mist-action` updates seamlessly re-render state changes for fragments exactly as they do for instance components.

**Robust Reconnection & Client Event Hooks**
- `mist.js` now dispatches browser-wide `mist:open` and `mist:close` events on the `document` during WebSocket state transitions, allowing you to easily build offline banners and loading states.
- Hardened WebSocket heartbeat operations during brief disconnect periods to trigger faster reconnects.
