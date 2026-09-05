// Which models have already refused today, so a generation stops paying for
// answers it has been told it cannot have.
//
// The free allowance is counted per model per day, so a model that returned
// "spent" this morning will return it again all afternoon. Asking anyway costs
// a full network round trip for a guaranteed refusal, and with five models in
// the chain a client can wait through five of them before reaching one with
// budget left. That is where the minutes come from.
protocol SpentModels {

    // Names to skip. Empty once the allowance has reset.
    func spentToday() -> Set<String>

    func markSpent(_ model: String)
}
