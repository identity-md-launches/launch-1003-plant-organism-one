# Plant Organism

One non-upgradeable application on Robinhood Chain (4663). `PlantOrganism` contains the plant, weather consumer, staking records and IMD accounting. It creates no token, pool or hook. There is no owner setter, pause, sweep or upgrade. `OracleAttestation.sol` is copied from the supplied protocol reference; the application uses its canonical domain, struct, verifier and replay consumption.

Deploy the nonpayable constructor in this exact order (the launch factory must substitute the real `$owner`, not itself):

| Argument | Value |
| --- | --- |
| `imd_` | `0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127` |
| `intake_` | `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56` |
| `action_` | `0x6f7261636c652e72657175657374406f7261636c652d31000000000000000000` |
| `signer_` | `0x5598aa9146215bc13eb26f2c692ad1461fd32982` |
| `fallbackCell_` | `10223579` |
| `deployer_` | `$owner` |

These addresses are supplied launch inputs, not live-network discoveries. All economic/time parameters are constants. The deployer must call `bind(hook)` once after the second launch: the real hook must return this organism and its PLANT token. This is the only deployer privilege, and it ends at binding. No unknown future address is guessed or embedded here.

Anyone can fund by transferring IMD directly. Keepers call `settle()` for unbound catch-up and birth; thereafter call `heartbeat()` for the next ended UTC day, wait for delivery, then `settle()`. The callback only verifies and stores. Anyone can clear an unanswered request after 24 hours, or settle an incomplete result; re-asking that day waits six hours. Three incomplete results settle an empty day with a location vote. Initial location is nowhere; three unsuccessful birth votes select Lisbon. Each successful settle advances exactly one biological day. All days before binding are skipped together without weather, rewards or voting. Maintain settlement before `max(bindDay,lastSettledDay)+30`; at that UTC day the plant is permanently dead. `die()`, exits and claims materialize death, merge positive pot into backing, and also absorb later donations. Claims and withdrawals survive death.

Holders approve PLANT, then `park(cell,amount)`, `unpark(cell,amount)` and `redeem(amount)` from their wallet. Cells pack signed quarter-degree latitude/longitude into two 16-bit halves; zero is reserved. Moves use the candidate captured by heartbeat and current balances/supply. Deposits become reward-eligible after the next successful settle, so that settle cannot reward a last-minute deposit. Withdrawals immediately remove eligibility but preserve earned rewards. No holder or cell list is kept. `claim()` checkpoints the caller's last parked cell and the last rewarded cell, then pays all credited IMD; use `claim(uint32[] cells)` or `checkpoint(cell,holder)` for other historical cells. Index `Parked`, `Moved` and `Rewarded` events to supply those cells. Settlement never scans holders.

Accounting uses base token units. `floor()` exposes the backing ratio scaled by `1e18`; redemption rounds down, pays 90% while alive and 100% when dead. Redeemed PLANT remains permanently in custody. After all supply is redeemed, the displayed floor retains its final value. SIP division and reward dust go to backing; fractional gardener liabilities are tracked until checkpointed. The required conservation identity is `pot() + backing + owed() == IMD.balanceOf(organism)`.

**Funding interpretation:** oracle fees are spent immediately. An unfunded fee advance necessarily creates a deficit, so `pot()` is signed and `spendablePot()` clamps it at zero. Advances become repayable at the next successful settle, using available IMD without taking backing or gardener/bounty reserves; any shortfall remains owed and claimable after funding. Repayment of an impossible cash shortfall is not fabricated. Bounties are 1% of positive post-hours pot, credited to the heartbeat caller; failed transfers remain claimable. Keepers must approve IMD to cover any advance.

Only the current oracle EOA can authorize `rotate`, relayed by anyone. Sign the `Rotate(address organism,uint256 chainId,address newSigner,address newIntake,bytes32 newAction,uint256 nonce)` struct using the existing `IdentityMD Oracle` / `2` EIP-712 domain and sequential `rotationNonce`. Each replaced signer remains valid for attestations for 30 days, never for rotations. Pending requests retain their original Intake. Signers must remain EOAs; binding is the sole hook interaction, and subsequent external contract calls are limited to IMD, PLANT and Intake.

Assumptions: the bound PLANT has fixed total supply and ordinary exact-transfer balances; IMD does not rebase or charge transfer fees. The next launch must preserve those properties for the floor/custody guarantees. The oracle controls weather truth and authenticated endpoint rotation. Routine chain availability, oracle operation, funding and daily keeper calls remain external responsibilities. This project performs no transactions. Independent adversarial review remains a release responsibility.

Run `forge build`, `forge test`, and `forge fmt --check`. Solidity 0.8.26, Cancun, optimizer/via-IR and no metadata hash are pinned. OpenZeppelin 5.5.0 dependencies and forge-std 1.9.7 are vendored as ordinary files with licenses; checks need no network, environment secrets, FFI or filesystem permissions. Tests cover exact JSON, protocol vectors, signatures, gas ceilings, retries, reward timing, movement, exits, rotation, reentrancy, and stateful accounting/floor/custody invariants.
