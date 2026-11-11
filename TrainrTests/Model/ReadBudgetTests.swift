import Foundation
import Testing
@testable import Trainr

@Suite("The time a read is given")
struct ReadBudgetTests {

    private static let budget = Duration.seconds(120)
    private static let slice = Duration.seconds(1)

    @Test("A read that runs the whole way through still runs out")
    func aReadThatTakesEveryStepRunsOut() {
        var read = ReadBudget(budget: Self.budget, slice: Self.slice)
        var slices = 0
        while !read.isSpent {
            read.charge(read.nextSlice)
            slices += 1
        }
        #expect(slices == 120)
    }

    // The app is suspended whole while a call is taken: the step is overdue by
    // the length of the call, and the model was stopped for all of it.
    @Test("Time the app spent suspended costs the step it interrupted, not its length")
    func aSuspensionCostsOneStep() {
        var read = ReadBudget(budget: Self.budget, slice: Self.slice)
        read.charge(.seconds(1800))
        var slices = 1
        while !read.isSpent {
            read.charge(read.nextSlice)
            slices += 1
        }
        #expect(slices == 120)
    }

    @Test("A step never asks for more time than the read has left")
    func aStepNeverOutlastsTheRead() {
        var read = ReadBudget(budget: .milliseconds(1500), slice: Self.slice)
        #expect(read.nextSlice == .seconds(1))
        read.charge(.seconds(1))
        #expect(read.nextSlice == .milliseconds(500))
        read.charge(.milliseconds(500))
        #expect(read.isSpent)
    }

    @Test("A read with no time at all is spent before it starts")
    func aReadWithNoTimeIsSpent() {
        #expect(ReadBudget(budget: .zero, slice: Self.slice).isSpent)
    }
}
