// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {PlantTestBase} from "./PlantOrganism.t.sol";
import {PlantOrganism} from "../src/PlantOrganism.sol";
import {WeatherQuestion} from "../src/WeatherQuestion.sol";
import {MockIntake} from "./mocks/Mocks.sol";

contract PlantAssumptionsTest is PlantTestBase {
    function test_explicitZeroCellQuestionRemainsInvalid() public {
        uint32 cell = organism.location();
        uint32 day = organism.lastSettledDay() + 1;
        vm.expectRevert(WeatherQuestion.InvalidCell.selector);
        organism.question(cell, day);
    }

    function test_timeoutsDoNotCountAndEventuallyDie() public {
        _birthWithCommittedCandidate(300 ether);
        for (uint256 i; i < 23; ++i) {
            _ask();
            vm.warp(vm.getBlockTimestamp() + 1 days);
            organism.clearPending();
            vm.warp(vm.getBlockTimestamp() + 6 hours);
        }
        assertTrue(organism.isDead());
        assertEq(organism.incompletes(START + 2), 0);
        assertEq(organism.location(), LISBON);
    }

    function test_oldRotationSignatureAccepted() public {
        MockIntake next = new MockIntake();
        bytes memory sig = _signDigest(KEY, organism.rotationDigest(vm.addr(555), address(next), ACTION, 0));
        vm.warp(vm.getBlockTimestamp() + 400 days);
        organism.rotate(vm.addr(555), address(next), ACTION, 0, sig);
        assertEq(organism.oracleSigner(), vm.addr(555));
    }

    function test_redeemedSupplyStillCountsInThreshold() public {
        _birth();
        _weather(1, 0);
        _unpark(alice, LISBON, 100 ether);
        vm.prank(alice);
        organism.redeem(600 ether);
        vm.prank(bob);
        organism.redeem(300 ether);
        vm.prank(carol);
        organism.redeem(60 ether);
        _park(carol, OTHER, 40 ether);
        _weather(0, 0); // Mature the stake so the next READ exercises the supply threshold.
        organism.challenge(OTHER);
        assertEq(organism.votingStake(OTHER), 40 ether);
        assertEq(organism.votingStake(LISBON), 0);
        _weather(0, 0);
        assertEq(organism.burned(), 960 ether);
        assertEq(organism.location(), LISBON);
    }

    function test_rotatedIntakeCanPriceAbovePotAndPullAdvance() public {
        _birth();
        MockIntake next = new MockIntake();
        next.setPrice(10000 ether);
        bytes memory sig = _signDigest(KEY, organism.rotationDigest(vm.addr(555), address(next), ACTION, 0));
        organism.rotate(vm.addr(555), address(next), ACTION, 0, sig);
        imd.mint(keeper, 10000 ether);
        uint256 before = imd.balanceOf(keeper);
        _ask();
        assertEq(imd.balanceOf(address(next)), 10000 ether);
        assertEq(before - imd.balanceOf(keeper), 9000 ether);
        assertEq(organism.feeAdvances(keeper), 9000 ether);
    }

    function test_oldSourceWindowBacklogIsAlreadyDead() public {
        _birth();
        vm.warp(uint256(START + 101) * 1 days);
        assertTrue(organism.isDead());
        vm.expectRevert(PlantOrganism.DeadPlant.selector);
        organism.heartbeat();
    }

    function test_preBindDonationsHaveNoExit() public {
        PlantOrganism fresh = _deploy();
        imd.mint(address(fresh), 1000 ether);
        fresh.claim();
        vm.warp(vm.getBlockTimestamp() + 2 days);
        fresh.settle();
        vm.expectRevert(PlantOrganism.Unbound.selector);
        fresh.redeem(1);
        assertEq(imd.balanceOf(address(fresh)), 1000 ether);
    }
}
