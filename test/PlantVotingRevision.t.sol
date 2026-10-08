// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlantTestBase} from "./PlantOrganism.t.sol";
import {PlantOrganism} from "../src/PlantOrganism.sol";

contract PlantVotingRevisionTest is PlantTestBase {
    function test_questionIsEmptyBeforeBindAndDuringBirth() public {
        PlantOrganism fresh = _deploy();
        assertEq(fresh.question(), "");
        assertEq(organism.question(), "");
        _birth();
        assertEq(organism.question(), organism.question(LISBON, START + 2));
    }

    function test_atomicDestinationTopUpCannotMoveOrCaptureRewards() public {
        _birth();
        _park(bob, OTHER, 1);
        _weather(0, 0);
        _ask();
        _deliver(0, 0, true);
        uint256 before = plant.balanceOf(bob);
        _park(bob, OTHER, 100 ether);
        organism.settle();
        _unpark(bob, OTHER, 100 ether);
        assertEq(plant.balanceOf(bob), before);
        assertEq(organism.location(), LISBON);
        _weather(0xffffff, 0);
        vm.prank(bob);
        organism.claim();
        vm.prank(alice);
        organism.claim();
        assertEq(imd.balanceOf(bob), 0);
        assertGt(imd.balanceOf(alice), 0);
        _conservation();
    }

    function test_atomicCurrentCellTopUpCannotVetoCommittedCandidate() public {
        _birthWithCommittedCandidate(200 ether);
        _ask();
        _deliver(0, 0, true);
        _park(alice, LISBON, 300 ether);
        organism.settle();
        _unpark(alice, LISBON, 300 ether);
        assertEq(organism.location(), OTHER);
        _conservation();
    }

    function test_emptyCapturedCandidateFallsBackToRepairedLiveCandidate() public {
        _park(alice, THIRD, 201 ether);
        _birthWithCommittedCandidate(200 ether);
        organism.challenge(THIRD);
        _ask();
        (,, uint32 captured,,,,,,) = organism.pending();
        assertEq(captured, THIRD);
        _unpark(alice, THIRD, 201 ether);
        organism.challenge(OTHER);
        _deliver(0, 0, true);
        organism.settle();
        assertEq(organism.location(), OTHER);
        _conservation();
    }

    function test_fallbackCannotUseNewPostHeartbeatStake() public {
        _birthWithCommittedCandidate(150 ether);
        _ask();
        _unpark(bob, OTHER, 150 ether);
        _park(alice, THIRD, 200 ether);
        _deliver(0, 0, true);
        organism.settle();
        assertEq(organism.location(), LISBON);
        organism.challenge(THIRD);
        _weather(0, 0);
        assertEq(organism.location(), THIRD);
    }

    function test_withdrawalRemovesPowerAndReaskCannotRestoreIt() public {
        _birthWithCommittedCandidate(200 ether);
        _ask();
        _unpark(bob, OTHER, 199 ether);
        assertEq(organism.votingStake(OTHER), 1 ether);
        _deliver(0, 0, false);
        organism.settle();
        _park(bob, OTHER, 199 ether);
        vm.warp(vm.getBlockTimestamp() + 6 hours);
        _ask();
        assertEq(organism.votingStake(OTHER), 1 ether);
        _deliver(0, 0, true);
        organism.settle();
        assertEq(organism.location(), LISBON);
        assertEq(organism.votingStake(OTHER), 200 ether);
        organism.challenge(OTHER);
        _weather(0, 0);
        assertEq(organism.location(), OTHER);
        _conservation();
    }

    function test_thirdIncompleteAlsoUsesRepairedCandidate() public {
        _park(alice, THIRD, 201 ether);
        _birthWithCommittedCandidate(200 ether);
        organism.challenge(THIRD);
        for (uint256 i; i < 3; ++i) {
            if (i != 0) _park(alice, THIRD, 201 ether);
            _ask();
            _unpark(alice, THIRD, 201 ether);
            organism.challenge(OTHER);
            _deliver(0, 0, false);
            organism.settle();
            if (i < 2) vm.warp(vm.getBlockTimestamp() + 6 hours);
        }
        assertEq(organism.location(), OTHER);
        assertEq(organism.water(), 50);
        assertEq(organism.incompletes(START + 2), 3);
    }

    function test_currentCellWithdrawalBreaksTieForCommittedCandidate() public {
        _birth();
        _park(bob, OTHER, 100 ether);
        _ask();
        _deliver(0, 0, true);
        _unpark(alice, LISBON, 1);
        organism.settle();
        assertEq(organism.location(), OTHER);
        assertEq(organism.challenger(), 0);
        _conservation();
    }

    function test_timeoutRetryRefreshesSnapshotIncludingCooldownDeposits() public {
        _birth();
        _park(bob, OTHER, 50 ether);
        _ask();
        uint256 oldRound = organism.voteRound();
        _park(bob, OTHER, 150 ether);
        assertEq(organism.votingStake(OTHER), 50 ether);
        vm.warp(vm.getBlockTimestamp() + 1 days);
        organism.clearPending();
        _park(bob, OTHER, 50 ether);
        vm.warp(organism.retryAt());
        _ask();
        assertEq(organism.voteRound(), oldRound + 1);
        assertEq(organism.votingStake(OTHER), 250 ether);
        _deliver(0, 0, true);
        organism.settle();
        assertEq(organism.location(), OTHER);
        assertEq(organism.lastSettledDay(), START + 2);
        _conservation();
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_repeatedTopUpsCannotOverwriteHeartbeatSnapshot(uint96 seed) public {
        _birth();
        _park(bob, OTHER, 100 ether);
        _ask();
        uint256 amount = bound(seed, 1, 100 ether);
        _park(bob, OTHER, amount);
        _park(bob, OTHER, amount);
        assertEq(organism.votingStake(OTHER), 100 ether);
        _deliver(0, 0, true);
        organism.settle();
        assertEq(organism.location(), LISBON, "post-request deposits cannot break a voting tie");
        _weather(0, 0);
        assertEq(organism.location(), OTHER, "retained deposits vote on the following request");
        _conservation();
    }
}
