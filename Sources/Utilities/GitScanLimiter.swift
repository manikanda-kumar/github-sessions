import Foundation

actor GitScanLimiter {
    private let limit: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
        self.available = max(1, limit)
    }

    func withPermit<T: Sendable>(_ work: @Sendable () async -> T) async -> T {
        await acquire()
        let result = await work()
        release()
        return result
    }

    private func acquire() async {
        if available > 0 {
            available -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if let continuation = waiters.first {
            waiters.removeFirst()
            continuation.resume()
            return
        }
        available = min(available + 1, limit)
    }
}