# 034 — Storage/throughput decision

Status: deferred after evaluation 2026-09-30. Reopen when a playtest or integration run demonstrates a specific intake or reserve bottleneck.

The [post-slice plan](../POST_SLICE_PLAN.md) makes this card conditional: skip a new storage constraint unless episodic abundance creates a real buffering problem. Task 033's command-driven run collected all 24 units of the temporary protein spill through ordinary aggregate trails. `PileState.deposit_resource` accepted the delivered amount; no intake queue, overflow, lost harvest or player choice around buffering arose. The extended slice also still reaches its brood and chamber milestones. Adding capacity now would manufacture the problem the card is meant to address.

No game state, UI or balance rule changes in this evaluation. Keep the current resource storage contract and revisit with recorded quantities, missed intake, labor commitments and a clear player decision. Next bounded card: 035 recurring environmental pressure. The full 3,788-check suite and task-033 episodic run are the evidence; no separate code test applies to this documentation decision.
