# 040 — INWARD stores and Adaptation Web clarity

Status: complete 2026-09-30 from player playtest feedback.

## Goal

The colony should know its own on-hand carbohydrate, protein and water anywhere in INWARD. Adaptation Web choices must read as brood-trait trials and look distinct from chamber development; a developing Food Exchange should name the chamber being built.

## Implementation contract

- Use the already detached `GameRoot.inward_status().resources` values. Show all three named stock amounts in one restrained INWARD header line, regardless of selected node or chamber state. Format to one decimal, including zero, without adding a persistent OUTWARD economy panel or exposing physical source quantities.
- Keep Adaptation as its separate fifth functional node. Give its context a restrained violet treatment and two outlined trial controls distinct from solid green chamber-development buttons. Label the trial actions and the selected trait explicitly. While brood is developing, name Lean Foragers or Load Bearers and show its stage. Make Food Exchange's action identify the chamber. Preserve existing semantic callbacks, costs, touch rectangles, save data and simulation behavior.
- Assess the reported depletion/discovery difficulty against the authored fixture and existing recovery actions. Record concrete risks and next evidence needed. Do not rebalance resource quantities or alter scout information boundaries in this presentation card.

## Verification

Run pinned import, full headless suite, Main smoke, and compact graphical INWARD checks with no selection, Adaptation selection and Food Exchange selection. Check mouse/touch targets and that displayed stock values come from a detached summary after a deposit or spend. Update UI rules, README, decision/evaluation notes and this card. Commit one logical change.

## Completion evidence and handoff

- INWARD's header now gives named carbohydrate, protein and water stores with one-decimal precision in every selection state. It consumes the existing detached pile summary and updates after a deposit or spend. Adaptation Web has a violet context and outlined **START LEAN/LOAD BROOD TRIAL** actions; a running trial names its chosen trait and brood stage. The Food Exchange chamber action now names its project. No authoritative state, touch rectangle or save schema changed.
- Pinned Godot 4.7.2 import, Main headless smoke and the full suite passed; the suite recorded **4,059 checks, zero failures**. A 900×600 Windows graphical probe captured the 900×506 16:9 game image with no selection, Adaptation choices, Food Exchange and a live Lean trial. Visual inspection found the stock line, distinct controls and project names legible without collisions; the probe reported eight scene nodes and 60 draw calls. Existing mouse/touch path checks still pass. Physical touch and Android were not tested. `git diff --check` passed.
- Source audit: the two starting carbohydrate nodes, starting protein and starting water each begin at 100 units. Only sheltered carbohydrate renews (+12/300 simulated seconds); picnic protein is a separate 24-unit temporary episode every 600 seconds; rain gives three water after a two-route trigger and then recurs. Default scouts bypass already known sources, which need Investigate or Recheck. Starting water can become permanently unavailable if its node empties before rain starts. This is a concrete progression risk, documented in the evaluation and [card 041](041_source_recovery_audit.md); resource numbers were not changed here.
- Changed: INWARD presentation and compact graphical probe, detached-summary check, UI/decision/evaluation/plan/README documentation, and cards 040–041. Next: reproduce depletion and recovery with ordinary commands before choosing an authored ecology change.
