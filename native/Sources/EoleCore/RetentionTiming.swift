import Foundation

// Port de src/lib/retention-timing.ts — ding à chaque minute pleine de rétention.

public func getNewRetentionMinute(elapsedSeconds: Double, lastMinute: Int) -> Int? {
    let completedMinute = Int(floor(elapsedSeconds / 60))
    return (completedMinute > 0 && completedMinute > lastMinute) ? completedMinute : nil
}
