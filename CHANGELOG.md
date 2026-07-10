# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the package is `0.y.z`, breaking changes may land in any release; see
each entry below for what actually changed.

## [0.1.1]

### Fixed
- Fixed a rare crash under concurrent requests caused by `Networker`'s internal session being mutated
  after initialization. The session is now fixed at `init` and never changes afterward.

### Removed
- **Breaking:** `HTTPRequestProtocol.isExtendSession`. It had no meaningful effect beyond what
  `HTTPRequestProtocol.timeoutInterval` (still supported) already provides. Conforming types must
  remove this requirement.

## [0.1.0]

### Added
- `HTTPRequestProtocol` now exposes `timeoutInterval`, `retryPolicy`, and `cachePolicy`, each with a
  default via protocol extension (`180`, `.none`, `.useProtocolCachePolicy`) so requests own these
  decisions instead of `Networker` hardcoding them.
- `RetryPolicy` — per-request retry configuration (`maxAttempts`, backoff strategy, retryable status
  codes, whether to retry transport errors), with `.none`, `.fixed`, and `.exponential` presets.
- `Networker.request(...)` and `Networker.download(...)` now retry automatically per the request's
  `retryPolicy`, rechecking network reachability before every attempt and respecting cancellation
  during backoff delays.
- `HTTPRequestProtocol` now exposes `requestInterceptors` and `responseInterceptors` (default `[]`),
  letting a request declare its own request/response middleware (e.g. header injection, response
  transformation). Interceptors re-run on every retry attempt.
- `RequestInterceptor` and `ResponseInterceptor` protocols.
- `NetworkingError`, a public error type replacing the previously non-public `NetworkError`:
  `.invalidURL`, `.networkNotAvailable`, `.transport(URLError)`,
  `.badStatus(statusCode:data:response:)`, `.cancelled`. Conforms to `LocalizedError`.
- Cancellation by request identity: `Networker.cancel(id:)` and `Networker.cancelAll()`, backed by an
  internal `TaskRegistry` actor. Cancelling surfaces as `NetworkingError.cancelled`.
- `URLSessionProtocol`, a public seam wrapping `data(for:)`/`download(for:)`; `Networker`'s session is
  now injected as `URLSessionProtocol` (satisfied by `URLSession` itself, so existing callers are
  unaffected) — enables mocking `Networker` in tests.
- `Tests/NetworkerTests` — the package's first automated test suite, covering URL construction, retry
  behavior (status-code and transport-error paths), timeout/cache application, status-code handling,
  download success/failure/cancellation, and interceptor ordering.
- `.macOS(.v12)` added to `platforms` in `Package.swift` so `swift test` can run locally on macOS
  (the package still ships as an iOS library; this only affects local tooling).

### Changed
- `Networker.download(...)` now returns `URL` and throws `NetworkingError.badStatus` on a non-2xx
  response, instead of silently returning `nil`. **Breaking:** any call site using
  `if let url = try await networker.download(...)` must switch to a plain `try await` with
  `do`/`catch`.
- `Networker.download(...)` moves the downloaded temp file to `destinationURL` via
  `FileManager.moveItem` instead of reading it fully into memory and rewriting it.
- `Networker.download(...)`'s success check now accepts any `2xx` status code, matching
  `request(...)`, instead of only exact `200`.

### Fixed
- `NetworkError.badRequest(statusCode: String)` — the associated value was actually a pre-formatted
  message, not a status code. Replaced by `NetworkingError.badStatus`, which carries the real
  `Int` status code and response body as structured data.
- `Networker`'s initializer had an invalid `override` keyword on `init(session:)`, which does not
  override anything on `NSObject` (confirmed via isolated compilation — this was a latent error,
  never caught because the package could not previously build end-to-end).

### Removed
- `NetworkError` (superseded by `NetworkingError`, see above). It was not `public`, so this cannot
  have affected any consumer outside this package.
