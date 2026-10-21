enum RestoreOutcome: Equatable {
    case restored
    case cancelled
    case failed(String)
}
