# 099 — Local brood health

Status: complete, 2026-10-03.

Player outcome: sustained heavy unisolated refuse can leave larvae visibly unhealthy, then cause gradual brood loss. Cleanup prevents further exposure and permits recovery; airing damp developed Nursery supports prevention. Existing Nursery/Midden attention explains symptoms and opens real cleanup controls. No exact pathogen diagnosis or exterior attribution.

Original basis: Part 3 §§46–51 (Nursery stability, sanitation and eventual disease/brood loss); Part 4 §§108–109 defer network transmission/quarantine until satellites exist. Dependencies: 064 sanitation, 066 humidity, 074/076 local visual attention, 080 distinct food-sharing losses, existing brood/adaptation loss accounting.

Bounded contract: pile-owned integer local health burden, deterministic fixed ticks. Heavy refuse with larvae adds burden; damp developed Nursery accelerates it. Clean conditions permit gradual recovery even after larvae leave. Symptoms persist while burden remains; severe sustained strain removes the oldest larva through BroodSystem's conserved loss path, releasing trial nurses if the last trial larva dies. Eggs/pupae, queens and adults are unaffected. Existing environmental slowdown combines by minimum, never additional multiplied penalties or food tax. Do not reveal the private burden or a disease identity in UI.

Provisional authored defaults: burden 0–10,000; heavy refuse adds four units/tick, damp adds two; recovery two/tick without heavy exposure. Symptoms at 1,000, severe at 8,000; symptomatic larval progress 75%, severe 50%; one larva may be lost per 480 severe ticks. Below severe, loss clock resets. Show known unhealthy/recovering/stable condition, health-related cumulative brood loss and practical cleanup/airing guidance; no countdown or forecast. Legacy saves start clean, optional version-five field; strict atomic validation/reconciliation.

Verification: delayed onset, clean prevention, damp acceleration, recovery, only larval deaths, mixed loss causes/trial cleanup, no adult debit, saved/RNG/pause/speed equivalence, malformed/legacy state, detached symptoms and actual standard/compact input. Paired ordinary colony trials compare neglected and cleanup-response runs without injected resources or disease state. Final full suite, import and Main smoke.

Completion: 51 focused checks; full suite 6,176 checks, zero failures/script errors. Final import/Main smoke and standard/compact symptoms/severe/recovery rendering plus actual mouse/touch cleanup passed. Twelve ordinary trials passed conservation and exact midpoint saves; early cleanup prevented health losses in all four paired cases. [Evaluation](../BROOD_HEALTH_EVALUATION.md).

Changed groups: health configuration/state/system and aggregate larval loss ownership; pile/controller/save reconciliation; detached symptoms, existing local attention and visual health; focused/ordinary/graphical evidence. Trial runs exposed and fixed five-decimal rain/pickup and ten-decimal coverage persistence residues.

Handoff: local sanitation disease foundation complete; next scope Nursery temperature and a bounded authored heat event from Parts 3/6. No mobile, global balance or session-duration target.
