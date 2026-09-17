# 24 — Historial de la rama `m2/gate-two-instances`, conservado antes de compactar

**Fecha:** 2026-09-17. La rama acumuló **52 commits** sobre `main` (`2b16e99`) y su historial se compactó a uno solo para que el repositorio no cargue con ~140 MB de volcados crudos que ya se habían borrado del árbol en tres tandas. Los ficheros que sobreviven siguen ahí; lo que desaparece son las versiones intermedias.

Respaldo completo del historial original: `RutaFragil_RESPALDO_20260917.bundle` (57 MB, `git bundle verify` correcto), fuera del repositorio.

## Los commits, con su autor

| # | Hash original | Fecha | Autor | Asunto |
|---:|---|---|---|---|
| 1 | `25cef0e` | 2026-09-15 | lhidalgo42 | docs: plan and round-1 prompt (M2-GATE) |
| 2 | `a414c87` | 2026-09-15 | lhidalgo42 | feat: the harness asserts the exact test count (M2-GATE paso 0b, r2.1) |
| 3 | `94e17c2` | 2026-09-15 | lhidalgo42 | test: split the restraint suite in two by theme (M2-GATE paso 0c, r2.2) |
| 4 | `4576d38` | 2026-09-15 | lhidalgo42 | docs: BACKLOG note on gdUnit discovery dropping tests in fresh clones (M2-GATE paso 0d) |
| 5 | `d7d956f` | 2026-09-15 | lhidalgo42 | docs: client-bus carry measurement before building the replica (M2-GATE paso 1, D92) |
| 6 | `7e7ca35` | 2026-09-15 | lhidalgo42 | docs: review 01 and round-2 prompt (M2-GATE) |
| 7 | `04fd25b` | 2026-09-15 | lhidalgo42 | docs: plan updated by the reviewer — D95 rewritten after review 01 (M2-GATE) |
| 8 | `4b5ada2` | 2026-09-15 | lhidalgo42 | chore: drop the orphaned restraint_test.gd.uid, commit the two new suites' .uid (M2-GATE g0.3) |
| 9 | `8700c06` | 2026-09-15 | lhidalgo42 | docs: harness comments now describe the exact-count guard, not the old '>= 3' floor (M2-GATE g0.6) |
| 10 | `ee83865` | 2026-09-15 | lhidalgo42 | docs: deterministic carry probe committed + paso-1 table remade (M2-GATE g0.2, A/B/C of round 2) |
| 11 | `d9ad291` | 2026-09-15 | lhidalgo42 | docs: evidence 02 — three harness runs, exit 0, 180 tests each + net (M2-GATE g0.4) |
| 12 | `98dccc1` | 2026-09-15 | lhidalgo42 | docs: review 02, round-3 prompt, plan with D92/D95 rewritten by the reviewer (M2-GATE) |
| 13 | `bc2323f` | 2026-09-16 | lhidalgo42 | docs: preserve reviewer write-order probe and Codex handoff (M2-GATE) |
| 14 | `6002a11` | 2026-09-16 | lhidalgo42 | docs: preserve reviewer withdrawal of g2.1 and phase-zero handoff |
| 15 | `61c8c5d` | 2026-09-16 | lhidalgo42 | fix: close M2 gate phase zero with declared sampling and authority lookups |
| 16 | `3f1d17e` | 2026-09-16 | lhidalgo42 | feat(net): spawn and interpolate one local-authority crew per peer |
| 17 | `53901a4` | 2026-09-16 | lhidalgo42 | feat(net): replicate cargo states and validate host authority transfers |
| 18 | `469e28c` | 2026-09-16 | lhidalgo42 | fix(net): validate held snapshots and allow ground drops beside a moving bus |
| 19 | `cd76dc5` | 2026-09-16 | lhidalgo42 | feat(tooling): run the two-instance gate with declared observation and metrics |
| 20 | `ff1e96e` | 2026-09-16 | lhidalgo42 | fix(net): preserve crew interaction frame alongside world snapshots |
| 21 | `078e36c` | 2026-09-16 | lhidalgo42 | fix(net): validate cargo reach in the sender bus frame |
| 22 | `dabd154` | 2026-09-16 | lhidalgo42 | fix(net): interpolate bus snapshots on a continuous source timeline |
| 23 | `9a4be92` | 2026-09-16 | lhidalgo42 | fix(net): replicate bus velocity as interpolation reference data |
| 24 | `7762949` | 2026-09-16 | lhidalgo42 | fix(crew): use the replicated bus reference when releasing aboard |
| 25 | `d237f8f` | 2026-09-16 | lhidalgo42 | fix(cargo): preserve world drop velocity with a frozen client bus |
| 26 | `000c52f` | 2026-09-16 | lhidalgo42 | test(gate): record first valid D95 failure and expose render configuration |
| 27 | `47c3b41` | 2026-09-16 | lhidalgo42 | fix(tooling): bound the Bash gate launcher independently of Godot ticks |
| 28 | `95455f5` | 2026-09-16 | lhidalgo42 | fix(tooling): retain the gate process exit code for short runs |
| 29 | `37b0acc` | 2026-09-16 | lhidalgo42 | docs: deliver M2 gate measurements, final regressions and unresolved limits |
| 30 | `34e50ab` | 2026-09-16 | lhidalgo42 | docs: verify clean fresh worktree imports for the M2 gate delivery |
| 31 | `fefc4d8` | 2026-09-16 | lhidalgo42 | docs: keep the M2 gate pending and close stale regression notes |
| 32 | `632fafa` | 2026-09-16 | lhidalgo42 | docs: preserve reviewer correction of M2 gate failure criteria |
| 33 | `c23e751` | 2026-09-16 | lhidalgo42 | test(gate): capture support-loss edges and isolate cargo-free experiments |
| 34 | `f362783` | 2026-09-16 | lhidalgo42 | fix(cargo): reject overlapping releases and apply corrected gate criteria |
| 35 | `19836c7` | 2026-09-16 | lhidalgo42 | fix(cargo): teleport confirmed state before resuming kinematic replication |
| 36 | `1eeb635` | 2026-09-16 | lhidalgo42 | fix(cargo): carry confirmed free replicas while awaiting their first pose |
| 37 | `266f459` | 2026-09-16 | lhidalgo42 | docs(gate): preserve reductions, corrected verdicts and remaining cargo contact failure |
| 38 | `a0b6bd3` | 2026-09-16 | lhidalgo42 | docs(gate): record three 236-test passes, regressions and clean fresh imports |
| 39 | `5ea5b56` | 2026-09-16 | lhidalgo42 | docs(gate): preserve final clean branch and import verification |
| 40 | `e2f69ac` | 2026-09-17 | lhidalgo42 | docs: preserve M2 gate round five review and instructions |
| 41 | `6454cea` | 2026-09-17 | lhidalgo42 | test(gate): record three ticks of cargo motion and support recovery |
| 42 | `25c7a72` | 2026-09-17 | lhidalgo42 | fix(net): apply cargo requests after rigid sync and bound final gate experiment |
| 43 | `3094021` | 2026-09-17 | lhidalgo42 | docs(gate): stop round five after failed 300 second precondition |
| 44 | `91ffbb7` | 2026-09-17 | lhidalgo42 | docs(gate): record clean round five delivery and fresh import |
| 45 | `e379837` | 2026-09-17 | lhidalgo42 | docs: preserve round six review and owner decision D98 |
| 46 | `7d82b3f` | 2026-09-17 | lhidalgo42 | docs: preserve reviewer clarification and evidence retention rule |
| 47 | `8e05d73` | 2026-09-17 | lhidalgo42 | feat(gate): keep bus inertia in the air (D98) and fix the slip filter |
| 48 | `aa8058f` | 2026-09-17 | lhidalgo42 | fix(gate): a body without an active shape is excluded, not missing instrumentation |
| 49 | `d61d93c` | 2026-09-17 | lhidalgo42 | feat(gate): M2 gate passes the automatic criterion on iteration 6 |
| 50 | `c4e4941` | 2026-09-17 | lhidalgo42 | chore(gate): drop iteration 5 traces, an invalid run that consumed no D96 attempt |
| 51 | `d2c4731` | 2026-09-17 | lhidalgo42 | chore(gate): keep only the approving run's traces |
| 52 | `a70c7c3` | 2026-09-17 | lhidalgo42 | perf(gate): stop writing 18000 mostly-null depth samples per body |
