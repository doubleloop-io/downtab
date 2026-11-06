# Private macOS APIs on a native, non-sandboxed stack

Downtab is written in Swift and AppKit, runs outside the App Sandbox and is distributed outside the Mac App Store (Developer ID signing and notarization). It relies on private macOS APIs, because the public ones cannot raise a single window or tell which Space a window is in. A feasibility spike on macOS 27.0.1 (arm64) ended with "go, with reservations": every check passed with the private APIs, none of the hard ones with public APIs alone.

## Considered options

- **Public APIs only.** Tried first in the spike for every need; see the table below. Rejected: it loses the core of the product.
- **Electron or Tauri.** Rejected: they would simplify only the UI, which is the easy part; the hard parts are native APIs that any stack has to call anyway.
- **Forking an existing open-source switcher.** Kept only as the fallback for a no-go verdict, which did not happen.

## What failed with public APIs

| Need | Public attempt | Result |
| --- | --- | --- |
| Raise one window | `activate()`, `kAXFrontmost`, `kAXMain`, `AXRaise` | Focus arrives, but the app's other windows come forward too: VS Code 10 times out of 10, Chrome 4, Finder 1. |
| Recognize apps living only in other Spaces | Level-0 windows of at least 100×50, off screen in `CGWindowList` | False positives: Zoom and iTerm2 have off-screen utility windows and would be hidden. |
| Drop fake windows | AX role and subrole | cmux exposes `AXDialog` elements titled `Item-0` and `Item-1` with no real window behind them. |

## Private APIs in use

All are resolved at runtime with `dlsym` (`PrivateSymbol`): a missing symbol logs a line and degrades the feature instead of failing at launch.

| API | Used for | If it stops working |
| --- | --- | --- |
| `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`, `GetProcessForPID` | Bringing one window forward and making it key | Falls back to `activate()`, which raises the whole app and loses the point of the product. |
| `_AXUIElementGetWindow` | Window id of an Accessibility element; dropping fake windows | No window gets an id: lists are empty until the code changes. |
| `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, `CGSCopySpacesForWindows` | Space of each window and Current Space | Apps living only in other Spaces, and minimized windows of other Spaces, are no longer recognized. |
| `CGSGetActiveSpace` | Whether the focused display shows a full-screen Space | From a full-screen Space the App row filters by Space like from a normal one. |
| `_AXUIElementCreateWithRemoteToken` | Accessibility element of a window in another Space, absent from `kAXWindows` | A window in another Space cannot be raised after activating its app. |
| `CGSSetSymbolicHotKeyEnabled`, `CGSIsSymbolicHotKeyEnabled`, `CGSGetSymbolicHotKeyValue` | Turning the native ⌘Tab and ⌘\` off when the user takes them over | The native shortcuts cannot be replaced. |

## Consequences

- No Mac App Store and no App Sandbox: private APIs rule both out.
- Only Accessibility is needed. Titles come from Accessibility, not from `CGWindowList`, whose titles require Screen Recording.
- Every macOS update can break a private API. The fallbacks above keep the app usable but degraded.
- A native shortcut turned off stays off if Downtab is killed or crashes: `make restore` (Emergency restore) turns it back on.
- Not verified by the spike, so carried over as known risks: multiple displays, slow or frozen apps, a real tap timeout (only simulated), more than about 5 minutes of continuous use, and turning off the native ⌘Tab and ⌘\`.
