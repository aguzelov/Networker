# Networker

A lightweight networking layer for iOS built around one idea: **the request owns its behavior.**
Timeout, retry policy, cache policy, headers, body, and middleware aren't configured on a shared
client — each request declares its own, right next to its `path` and `method`. `Networker` just
executes what the request tells it to do.

## Features

- **Request-owned identity** — every request has its own `id`, `baseURL`, `path`, `method`,
  `headers`, `queryParameters`, and `Encodable` body, encoded as either JSON or URL-form.
- **Request-owned configuration** — `timeoutInterval`, `retryPolicy`, and `cachePolicy` also live
  on the request, with defaults so most conformers don't need to set them at all.
- **Retry with backoff** — fixed or exponential, per-request, with control over which status codes
  and transport errors are retryable.
- **Interceptors** — a request can declare its own `requestInterceptors` / `responseInterceptors`
  for things like header injection or response transformation. They re-run on every retry attempt.
- **Typed errors** — `NetworkingError` distinguishes invalid URLs, unreachable networks, transport
  failures, and bad status codes (with the real status code and body, not a formatted string).
- **Cancellation by identity** — cancel any in-flight request via `Networker.cancel(id:)`, using
  the same `id` the request already carries, or stop everything with `cancelAll()`.
- **Downloads** — `download(request:destinationURL:logger:)` streams a response straight to disk.
- **Pluggable logging** — pass any `RequestLoggerProtocol` conformer to observe outgoing requests
  and incoming responses; logging is entirely opt-in and owned by the caller.
- **Reachability-aware** — requests fail fast with `.networkNotAvailable` when there's no
  connection, checked via an injectable `NetworkReachabilityProvider`.
- **Testable by design** — `URLSessionProtocol` and `NetworkReachabilityProvider` are both
  injectable seams, so `Networker` can be driven by mocks in unit tests without touching the network.
- **Zero dependencies.**

## Installation

Add it via Swift Package Manager:

```swift
.package(url: "https://github.com/aguzelov/Networker/", from: "0.1.0")
```

## Usage

Define a request by conforming to `HTTPRequestProtocol`:

```swift
struct GetUser: HTTPRequestProtocol {
    let id = UUID()
    let baseURL = "https://api.example.com"
    let path = "/users/me"
    let method: HTTPMethod = .get
    let headers: [String: String] = [:]
    let parameters: Encodable? = nil
    let queryParameters: [String: String]? = nil
    let encoding: HTTPEncoding = .jsonEncoded
    let isExtendSession = false

    // Opt in only where the defaults aren't enough:
    var timeoutInterval: TimeInterval { 10 }
    var retryPolicy: RetryPolicy { .exponential(attempts: 3) }
}
```

Then execute it:

```swift
let networker = Networker()
let data = try await networker.request(request: GetUser(), logger: nil)
```

Downloads follow the same shape:

```swift
let fileURL = try await networker.download(request: request, destinationURL: destination, logger: nil)
```

Cancel by request identity when needed:

```swift
networker.cancel(id: request.id)
// or
networker.cancelAll()
```

Handle errors by matching on `NetworkingError`:

```swift
do {
    let data = try await networker.request(request: GetUser(), logger: nil)
} catch NetworkingError.badStatus(let statusCode, let data, _) {
    // real status code + response body, not a formatted string
} catch NetworkingError.networkNotAvailable {
    // no connection
} catch {
    // .invalidURL, .transport(URLError), .cancelled
}
```

## Requirements

- iOS 16+
- Swift 5.8+

## License

MIT — see [LICENSE](LICENSE).
