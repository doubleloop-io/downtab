import ApplicationServices
// CF run loops are thread-safe but not marked Sendable; the observer thread's run loop is shared through a Mutex.
@preconcurrency import CoreFoundation
import Foundation
public import SwitcherCore
import Synchronization
import os

/// Reports windows created, closed, renamed, minimized or restored, as Accessibility notifies them.
/// On its own thread: registering with a busy or frozen app blocks until the Accessibility timeout.
public final class WindowEventObserver: Sendable {
    /// Shared with the observer thread through the callbacks' context pointer.
    fileprivate final class Relay: Sendable {
        let onChange: @MainActor @Sendable () -> Void

        init(onChange: @escaping @MainActor @Sendable () -> Void) {
            self.onChange = onChange
        }

        var context: UnsafeMutableRawPointer {
            Unmanaged.passUnretained(self).toOpaque()
        }

        func report(_ notification: String, from element: AXUIElement, observer: AXObserver) {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            WindowEventObserver.logger.info("window event \(notification, privacy: .public) pid=\(pid)")
            if notification == kAXWindowCreatedNotification {
                WindowEventObserver.watchWindow(element, with: observer, context: context)
            }
            Task { @MainActor in onChange() }
        }
    }

    private struct ThreadState {
        var runLoop: CFRunLoop?
        /// Work asked before the thread started.
        var pending: [@Sendable () -> Void] = []
    }

    /// Touched only on the observer thread.
    private struct Watched {
        var observers: [AppID: AXObserver] = [:]
        var retryAfter: [AppID: ContinuousClock.Instant] = [:]
    }

    private struct WatchFailure: Error {
        let step: String
        let error: AXError
    }

    private let relay: Relay
    private let thread = Mutex(ThreadState())
    private let watched = Mutex(Watched())
    /// Registering with a busy or frozen app blocks the observer thread: a failed app is not retried at every scan.
    private static let retryDelay = Duration.seconds(5)

    public init(onChange: @escaping @MainActor @Sendable () -> Void) {
        relay = Relay(onChange: onChange)
    }

    public func start() {
        let observerThread = Thread { [self] in runObserverThread() }
        observerThread.name = "window-event-observer"
        observerThread.qualityOfService = .utility
        observerThread.start()
    }

    /// Watches these apps and stops watching any other, such as one that quit or stopped being regular.
    /// An app whose registration failed is retried on a later call.
    public func watch(only apps: Set<AppID>) {
        perform { [self] in
            // Created under the lock: an observer is not Sendable, so it cannot be handed into the Mutex.
            watched.withLock { watched in
                for (app, observer) in watched.observers where !apps.contains(app) {
                    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
                    watched.observers[app] = nil
                    Self.logger.info("stopped watching window events pid=\(app.processIdentifier)")
                }
                watched.retryAfter = watched.retryAfter.filter { apps.contains($0.key) }
                let now = ContinuousClock.now
                let due = apps.filter { app in
                    watched.observers[app] == nil && watched.retryAfter[app].map { retry in now >= retry } ?? true
                }
                for app in due {
                    switch Self.makeObserver(for: app, context: relay.context) {
                    case .success(let observer):
                        watched.observers[app] = observer
                        watched.retryAfter[app] = nil
                        Self.logger.info("watching window events pid=\(app.processIdentifier)")
                    case .failure(let failure):
                        watched.retryAfter[app] = now + Self.retryDelay
                        Self.logger.error(
                            "window events unavailable pid=\(app.processIdentifier) \(failure.step, privacy: .public) error=\(failure.error.rawValue)"
                        )
                    }
                }
            }
        }
    }

    private func runObserverThread() {
        // Without a source the run loop would return at once, before any app is watched.
        RunLoop.current.add(NSMachPort(), forMode: .default)
        let pending = thread.withLock { state in
            state.runLoop = CFRunLoopGetCurrent()
            defer { state.pending = [] }
            return state.pending
        }
        for work in pending { work() }
        CFRunLoopRun()
    }

    private func perform(_ work: @escaping @Sendable () -> Void) {
        thread.withLock { state in
            guard let runLoop = state.runLoop else {
                state.pending.append(work)
                return
            }
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, work)
            CFRunLoopWakeUp(runLoop)
        }
    }

    private static func makeObserver(
        for app: AppID, context: UnsafeMutableRawPointer
    ) -> Result<AXObserver, WatchFailure> {
        var created: AXObserver?
        let creation = AXObserverCreate(app.processIdentifier, handleWindowEvent, &created)
        guard creation == .success, let observer = created else {
            return .failure(WatchFailure(step: "create", error: creation))
        }
        let element = Accessibility.application(app.processIdentifier)
        // Registered on the app: one registration catches every window it opens later.
        let registration = AXObserverAddNotification(
            observer, element, kAXWindowCreatedNotification as CFString, context)
        guard registration == .success || registration == .notificationAlreadyRegistered else {
            return .failure(WatchFailure(step: "register", error: registration))
        }
        var windows: CFTypeRef?
        let listing = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
        guard listing == .success || listing == .noValue else {
            return .failure(WatchFailure(step: "list windows", error: listing))
        }
        for window in windows as? [AXUIElement] ?? [] {
            watchWindow(window, with: observer, context: context)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        return .success(observer)
    }

    /// Registered on each window, not on the app: on the app these would fire for every element, not only windows.
    /// A window that refuses one is still caught by the periodic scan.
    fileprivate static func watchWindow(
        _ window: AXUIElement, with observer: AXObserver, context: UnsafeMutableRawPointer
    ) {
        AXUIElementSetMessagingTimeout(window, Accessibility.messagingTimeout)
        for notification in windowNotifications {
            let registration = AXObserverAddNotification(observer, window, notification as CFString, context)
            if registration != .success && registration != .notificationAlreadyRegistered {
                logger.info("window event \(notification, privacy: .public) unavailable error=\(registration.rawValue)")
            }
        }
    }

    private static let logger = Logger(subsystem: "io.doubleloop.downtab", category: "observer")
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification,
        kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]
}

/// Runs on the observer thread. A named function, not an inline closure: Accessibility is not
/// concurrency-audited, so an inline closure touching main-actor state only gets a warning that escapes
/// warnings-as-errors.
private func handleWindowEvent(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    let relay = Unmanaged<WindowEventObserver.Relay>.fromOpaque(context).takeUnretainedValue()
    relay.report(notification as String, from: element, observer: observer)
}
