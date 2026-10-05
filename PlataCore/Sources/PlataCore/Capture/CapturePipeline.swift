import Foundation

public enum CaptureDecision: Equatable, Sendable {
    case create(MovementStatus)
    case duplicateOf(UUID)
    case unreadable
}

public enum CapturePipeline {
    public static func decide(parsed: ParsedMovement?, accountID: UUID?, date: Date,
                              existing: [MovementSnapshot]) -> CaptureDecision {
        guard let parsed else { return .unreadable }
        if let id = Deduplicator.duplicate(amount: parsed.amount, kind: parsed.kind, accountID: accountID,
                                           date: date, existing: existing) {
            return .duplicateOf(id)
        }
        return .create(parsed.isExplicit && accountID != nil ? .confirmado : .porRevisar)
    }
}
