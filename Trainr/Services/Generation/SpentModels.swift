// The free allowance is counted per model per day, so a model that returned
// "spent" this morning returns it all afternoon; asking anyway costs a full
// round trip for a guaranteed refusal.
protocol SpentModels {

    // Names to skip. Empty once the allowance has reset.
    func spentToday() -> Set<String>

    func markSpent(_ model: String)
}
