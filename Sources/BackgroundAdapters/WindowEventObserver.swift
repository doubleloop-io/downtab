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
        let logger = Logger(subsystem: "local.downtab", category: "observer")

        init(onChange: @escaping @MainActor @Sendable () -> Void) {
            self.onChange = onChange
        }

        var context: UnsafeMutableRawPointer {
            Unmanaged.passUnretained(self).toOpaque()
        }

        func report(_ notification: String, from element: AXUIElement, observer: AXObserver) {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            logger.info("window event \(notification, privacy: .public) pid=\(pid)")
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

    private let relay: Relay
    private let thread = Mutex(ThreadState())
    /// Touched only on the observer thread.
    private let observers = Mutex<[AppID: AXObserver]>([:])

    public init(onChange: @escaping @MainActor @Sendable () -> Void) {
        relay = Relay(onChange: onChange)
    }

    public func start() {
        let observerThread = Thread { [self] in runObserverThread() }
        observerThread.name = "window-event-observer"
        observerThread.qualityOfService = .utility
        observerThread.start()
    }

    public func watch(_ app: AppID) {
        perform { [self] in
            // Created under the lock: an observer is not Sendable, so it cannot be handed into the Mutex.
            let isWatching = observers.withLock { observers in
                if observers[app] == nil {
                    observers[app] = Self.makeObserver(for: app, context: relay.context)
                }
                return observers[app] != nil
            }
            if isWatching {
                relay.logger.info("watching window events pid=\(app.processIdentifier)")
            } else {
                relay.logger.error("window events unavailable pid=\(app.processIdentifier)")
            }
        }
    }

    public func unwatch(_ app: AppID) {
        perform { [self] in
            guard let observer = observers.withLock({ $0.removeValue(forKey: app) }) else { return }
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
    }

    private func runObserverThread() {
        let runLoop = CFRunLoopGetCurrent()
        // Without a source the run loop would return at once, before any app is watched.
        let keepAlive = CFRunLoopTimerCreateWithHandler(nil, .greatestFiniteMagnitude, 0, 0, 0) { _ in }
        CFRunLoopAddTimer(runLoop, keepAlive, .defaultMode)
        let pending = thread.withLock { state in
            state.runLoop = runLoop
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

    private static func makeObserver(for app: AppID, context: UnsafeMutableRawPointer) -> AXObserver? {
        var created: AXObserver?
        guard AXObserverCreate(app.processIdentifier, handleWindowEvent, &created) == .success,
            let observer = created
        else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, accessibilityTimeout)
        // Registered on the app: one registration catches every window it opens later.
        AXObserverAddNotification(observer, element, kAXWindowCreatedNotification as CFString, context)
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
        for window in windows as? [AXUIElement] ?? [] {
            watchWindow(window, with: observer, context: context)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        return observer
    }

    /// Registered on each window, not on the app: on the app these would fire for every element, not only windows.
    fileprivate static func watchWindow(
        _ window: AXUIElement, with observer: AXObserver, context: UnsafeMutableRawPointer
    ) {
        AXUIElementSetMessagingTimeout(window, accessibilityTimeout)
        for notification in windowNotifications {
            AXObserverAddNotification(observer, window, notification as CFString, context)
        }
    }

    private static let windowNotifications = [
        kAXUIElementDestroyedNotification,
        kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]
    private static let accessibilityTimeout: Float = 0.25
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
