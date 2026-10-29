---
title: "CE 7405 | Complete engineering and development handoff"
subtitle: "2D matrix-based bridge analysis and condition-assessment platform"
date: "28 October 2026"
---

# CE 7405 — Complete engineering and development handoff

**Status:** This file records agreed plans and design choices, **not implemented or verified software**.  
**Course:** CE 7405, Statically Indeterminate Structures, LSU, Fall 2026.  
**Working project title:** *Interactive Matrix-Based Bridge Analysis and Condition Assessment Platform* (the user has also used “Damage Assessment Platform” and “Bridge Condition Assessment Platform”).  
**Revised final deadline:** **24 November 2026**; this supersedes the **5 December 2026** date printed in the older supplied course template.  
**Development tool:** MATLAB, preferably App Designer for the GUI; Claude Code for programming; Claude Cowork for documentation.  
**Model selected:** **Option A: 2D equivalent bridge beam**, **not** 3D grillage or solid FE.  
**Materials:** Structural steel (primary); reinforced concrete/RCC (additional simplified equivalent-linear-elastic input option).  
**Critical priority:** A **verified numerical solver and moving-load analysis** before sophisticated GUI design or optional stages.

## 1. Intended use and engineering motivation

The aim is an interactive, transparent, verifiable matrix-based bridge analysis and preliminary condition-assessment tool. It addresses how a moving multi-axle truck affects bridge reactions, shear forces, moments and deflection, and how a localized change in effective flexural stiffness alters the response. Continuous, statically indeterminate beams are essential because support reactions and moments may redistribute when stiffness changes. Students, researchers, and engineers conducting preliminary studies are intended users.

“**Transparent**” means computational steps can be inspected: individual element matrices, global stiffness matrix, free/restrained DOFs, equivalent nodal load vector, solved displacement vector, reactions, and recovery of member forces. “**Verifiable**” means analytical/numerical benchmarks and error tables are supplied. A custom direct stiffness solver is preferred to an external FE engine because the course is about matrix structural analysis. Commercial structural software may be used as an *independent comparison*, not the main calculation engine.

**Limits:** No official DOT load rating, bridge safety certification, complete damage diagnosis, final repair design, or replacement for professional engineering judgment. A 2D equivalent beam represents a **longitudinal region**, not a separately identifiable real-world girder (G1/G2) in a multi-girder bridge.

## 2. How the design evolved — final decisions and alternatives

1. Original idea: moving-load bridge analyzer, locating critical axle/vehicle positions and plotting response envelopes.
2. Expanded Stage 2: deliberate local $EI$ loss, compare healthy and degraded responses and location-dependent sensitivity.
3. Expanded Stage 3: estimate **unknown** degraded element/region and effective-stiffness reduction from user-provided sensor deflections under **known loading** (inverse candidate search).
4. Expanded Stage 4: use the inferred structural result **plus inspection-confirmed physical damage** to suggest a documented repair/maintenance *category*; optionally simulate assumed restored stiffness.
5. Considered 3D options: A = 2D equivalent beam; B = grillage/space-frame with multiple girders; C = detailed 3D solid/shell FE. **Option A was explicitly selected.** Do not add transverse distribution, torsional effects, lateral lane analysis, or individual girder IDs to the implementation.
6. Primary MATLAB + App Designer, although Python/NumPy was considered technically feasible. Do **not** switch platforms without explicit user decision.
7. Added simplified **RCC** material selection using externally justified $E_c I_{eff}$, without a cracking/reinforcement nonlinear solver; steel remains the primary material and likely the first case for Stage 3 and any repair guidance.
8. Deadline changed from **Dec 5** to **Nov 24, 2026**. Delivery scope must reflect shortened schedule.
9. GUI/slide style chosen: tidy **sage green**; diagrams use conventional **pin triangle, roller wheel(s) and ground line, fixed end with wall/hatching**. No support symbols that imply incorrect boundary conditions.
10. Proposal presentation planned for **5 minutes** under a peer rubric weighted problem/objectives 25%, method 35%, feasibility 20%, delivery/Q&A 20%; template's **12-minute** demonstration refers to the separate *final* demo. Presentation material is conceptual, not test evidence.

## 3. Objectives and prioritized acceptance scope

**Five agreed measurable objectives** (wording condensed from the revised proposal):

1. Implement and analytically verify the 2D direct-stiffness Euler–Bernoulli bending-beam solver for simple, propped and continuous configurations.
2. Accept steel $E_s I_s$ or RCC $E_c I_{eff}$ inputs in the **same** solver.
3. Move multi-axle loads through arbitrary locations inside beam elements; produce shear/moment/deflection plots, positive and negative envelopes, critical load/vehicle positions.
4. Apply user-specified local effective-$EI$ reduction and quantify healthy-versus-degraded response changes.
5. Explore—**only if time permits**—inverse stiffness-loss localization and inspection-informed, **initially steel** repair decision support.

| Priority | Features | Definition of done |
|---|---|---|
| **Must — Stage 1** | Beam model, per-element $EI$, stiffness assembly, supports, static solver, axle loads/interpolation, correct member-force recovery, moment/shear/deflection, reactions, envelopes, critical positions, basic GUI, analytical verification, steel and simplified RCC input | Executable MATLAB code, reproducible test cases, benchmarks within documented tolerance, clear demo, actual plots/data |
| **Should — Stage 2** | Select element, prescribe $EI$ loss, reassemble and compare healthy/degraded, sensitivity across candidate locations, continuous-beam example | Correct element is modified; $d\to0$ recovers healthy solution; comparison plot/table; physically consistent force redistribution on an indeterminate example |
| **Nice — Stage 3** | Single-region inverse RMSE search, synthetic/field-data import, 0–60% scan and refinement, blind synthetic tests, noise and ambiguity display | Separate tests recover synthetic cases and report competing candidates; never claim field validation without independent real measurements |
| **Nice — Stage 4** | Inspection-informed classification, documented **steel** repair categories, traceability, optional hypothetical repaired-state reanalysis | Actual referenced rules; conservative wording and professional-review requirement; no unsupported repair design |

## 4. Structural model: geometry, mesh, DOFs, materials

### 4.1 2D equivalent beam

Represent the entire bridge as a horizontal Euler–Bernoulli beam with nodes/elements. User inputs: bridge span(s) or support locations, element count/mesh, material, elastic modulus, sectional moment of inertia or effective stiffness, support conditions, optional uniformly distributed load, vehicle axle loads/spacings, movement increment. For uniform $n_e$-element mesh over total length $L$: $L_e=L/n_e$. Example: 30 m / 20 elements = 1.5 m per element, 21 nodes, 42 bending DOFs before constraints. Support continuous beams by adding supports at suitable nodes (or enforce mesh alignment with support coordinates). Later extension may include nonuniform meshes and piecewise $EI$.

Each node contains **only** $v_i$ (vertical displacement) and $\theta_i$ (cross-sectional rotation). The element DOF order is

$$\mathbf q_e=[v_1,\theta_1,v_2,\theta_2]^T.$$

No axial displacement $u$, transverse/shear beam formulation, torsion, deck action, or nonlinear geometry in the base solver. **Do not claim a full 2D frame-element or 3D FE solver is implemented.** If future 2D frame support is proposed, it would require $u,v,\theta$ (3 DOF/node), $E,A,I$, and a 6×6 element matrix; this was discussed but **not chosen for initial development**.

### 4.2 Beam element stiffness and assembly

The exact $4\times4$ Euler–Bernoulli element stiffness matrix is:

$$
\mathbf k_e=\frac{EI}{L_e^3}
\begin{bmatrix}
12 & 6L_e & -12 & 6L_e \\
6L_e & 4L_e^2 & -6L_e & 2L_e^2 \\
-12 & -6L_e & 12 & -6L_e \\
6L_e & 2L_e^2 & -6L_e & 4L_e^2
\end{bmatrix}.
$$

For horizontal elements local/global frames coincide and $T=I$. General transformation relationship (background for a future inclined element) is $k_e^G=T^T k_e^L T$; it is **not** a reason to add an inclined-frame solver now.

Assemble using connectivity and DOF maps:

$$\mathbf K=\sum_e\mathbf A_e^T\mathbf k_e\mathbf A_e.$$

Partition free and restrained degrees of freedom; for zero prescribed restrained displacements:

$$\mathbf K_{ff}\mathbf U_f=\mathbf F_f.$$

General partitioning may include $F_f-K_{fc}U_c$ if nonzero prescribed $U_c$ are later supported. Solve via MATLAB backslash or a reused factorization, **not** `inv(K)`.

Recover restrained reactions from full-system equilibrium, including applied forces at restrained DOFs:

$$\mathbf R=(\mathbf K\mathbf U-\mathbf F)_{\mathrm{restrained}}.$$

Member end actions and internal shear/moment must include member applied loads, not just $k_e q_e$.

### 4.3 Supports and sign conventions

| Idealized support | Vertical $v$ | Rotation $\theta$ | Symbol |
|---|---|---|---|
| Simple end pin / roller for **bending-only** model | restrained | free | Triangle on ground / triangle above roller(s) |
| Continuous beam interior support | restrained | free | Grounded support beneath continuous beam |
| Fixed end | restrained | restrained | Hatched built-in wall |
| Free end | free | free | No restraint |

The bending-only model cannot distinguish pin/roller *horizontal* restraint; their horizontal distinction exists in a frame/axial model, not here. Pick and document a consistent sign convention: $x$ positive along bridge, $v$ upward-positive or downward-positive consistently, rotation sign fixed, positive bending (sagging) and shear defined in outputs, and applied downward loads signed consistently.

### 4.4 Steel and RCC

**Steel:** $EI=E_s I_s$. Support user-defined elastic modulus and section inertia; future presets and geometric I-section property calculation are optional. Example steel $E=200$ GPa is illustrative, not universal.

**RCC:** $EI=E_c I_{eff}$, where $I_{eff}$ is **user supplied or externally justified** for the assumed cracking state. Freeze it during a linear analysis. Do not automatically model nonlinear flexural cracking, reinforcement steel yielding, composite slip, bond deterioration, creep, shrinkage, strength loss, or compute $I_{eff}$ from reinforcement layouts. Two otherwise identical steel and RCC models with **equal assigned $EI$**, geometry, supports and loads must yield **the same** linear beam response; that tests the input/solver consistency, **not** concrete behavior.

**Damage fractions describe model $EI$ reduction**; 30% decrease in flexural rigidity does not imply 30% corrosion, concrete section loss, reinforcement loss, or load-carrying strength loss.

## 5. Stage 1 — Moving vehicle and forward analysis

### 5.1 Vehicle input and reference

User defines number of axles, positive downward axle force magnitudes, and spacings. Illustrative 3-axle truck (not a specified AASHTO design truck): $P_1=80$ kN, $P_2=120$ kN, $P_3=120$ kN; spacings $4.2$ m and $1.4$ m. One possible coordinate convention: $x_1=x_v$, $x_2=x_v-4.2$, $x_3=x_v-5.6$ m. Choose **one** clear reference definition and retain it in GUI labels, tests and exported data. Begin with no axle on bridge; end once the final axle has exited. Only axles with coordinates within the active bridge span are applied, with an explicit policy at exact support coordinates.

This is a **quasi-static** sequence: inertial effects, vehicle suspension, roughness, speed-dependent dynamics and vehicle-bridge interaction are excluded. Animation is visualization of successive static solutions, not a dynamic time integration.

### 5.2 Arbitrary in-element axle placement

**Do not snap axle loads to the nearest node.** For an axle acting inside a beam element, use cubic Hermite bending shape functions and consistent nodal force/moment contributions. Let $r=a/L_e$ be position within the element:

$$N_1=1-3r^2+2r^3,\quad N_2=L_e(r-2r^2+r^3),$$
$$N_3=3r^2-2r^3,\quad N_4=L_e(-r^2+r^3).$$

Under an algebraically signed vertical point load $P$, element consistent load vector is

$$\mathbf f_e=P[N_1,N_2,N_3,N_4]^T.$$

Assemble contributions from all active axles into $\mathbf F(x_v)$ (plus optionally uniformly distributed loading) and solve $K U(x_v)=F(x_v)$ after constraints.

**Critical postprocessing requirement:** internal shears and moments must account for actual point loads located **within** elements and the chosen sign convention. Equivalent nodal loading is used in solving, but diagrams should show real jumps in shear and correct piecewise bending-moment shapes, with equilibrium checks. Include sampled element locations and allow response recovery at sensor coordinates, not just nodes.

### 5.3 Response envelopes / critical positions

At each bridge coordinate $x$, store positive and negative extrema over all vehicle reference positions $p$:

$$M_{max}(x)=\max_p M(x,p),\qquad M_{min}(x)=\min_p M(x,p).$$

Similarly compute $V_{max/min}(x)$ and $\delta_{max/min}(x)$ (and optionally extrema of absolute magnitude, carefully labelled). Do not confuse **the envelope at each bridge coordinate** with **the one vehicle position** producing a particular global extreme. Track: quantity, sign, response magnitude, $x$ of response, $x_v$ causing it, and axle configuration. Moment, shear, and deflection may be governed by different vehicle positions.

A finite movement step $\Delta x$ approximates the continuous search; offer step refinement / convergence near extreme positions so results are not overly mesh/step dependent.

### 5.4 Stage 1 output / user-facing display

- Structural beam, numbered nodes/elements, conventional supports and loads.
- Moving truck schematic and axle positions; interactive position slider, optionally Play/Pause/Step/Reset.
- Deformed shape (explicit display magnification), $v$ and $\theta$.
- Support reaction values.
- Shear, bending moment and vertical deflection at current vehicle position.
- Positive/negative response envelopes for each selected quantity.
- Critical axle/vehicle positions and locations of the extreme response.
- Numerical results tables, SI-based export when feasible.
- A view for $k_e$, $K$, constrained DOFs, $F$, $U$ and reactions to realize computational transparency.

## 6. Stage 2 — Known stiffness degradation / sensitivity

**Forward problem:** user chooses element $j$ and assumed effective stiffness loss $d_j$. Baseline $EI_j^0$ becomes

$$EI_j^D=(1-d_j)EI_j^0,\qquad 0\le d_j<1.$$

For the pure bending element, $k_j^D=(1-d_j)k_j^0$. Reassemble the global matrix, re-solve the same moving vehicle loading and compare healthy/degraded maximum/minimum reactions, deflections, moments, shears, envelope plots, and governing vehicle positions. Highlight degraded element and compute relative change when healthy reference is nonzero:

$$\%\Delta R=100(R_D-R_H)/|R_H|.$$

If healthy reference is zero, use absolute difference, not a misleading percent. A sensitivity sweep may move the same degradation across all elements, ranking regions by influence on a chosen response. For a **statically determinate simply supported** beam, changing only $EI$ under prescribed force loads normally changes displacement **but not equilibrium-determined reactions or internal forces**. A **continuous/propped indeterminate** beam can redistribute moments/reactions. This distinction must be reflected in examples, assertions and plots.

## 7. Stage 3 — Unknown damage inferred from user-provided response

**Inverse problem:** given a healthy baseline beam model, known load configurations/vehicle positions, known response sensor coordinates, and measured deflections, estimate the single most plausible effective-$EI$ reduction location/severity. Initially assume **one locally degraded region**; do not infer a physical failure mechanism or multiple simultaneous defects.

Initial conceptual sensor locations: $L/4$, $L/2$, $3L/4$. Make sensor positions configurable and extract FE deflections by shape-function interpolation where sensors lie between nodes. Use multiple known loading positions, e.g. $x_v=5,10,15,20,25$ m for a sufficiently long span, rather than one load case. With 3 sensors × 5 vehicle positions there are 15 scalar measurements. Check units, load alignment, support assumptions and missing data.

**Candidate search:** include the healthy $d=0$ case *once*. For each element $j=1..n_e$, test $d=5\%,10\%,...,60\%$ at **5% increments**. With 20 elements this is **240 damaged models + 1 healthy model = 241 distinct candidate structures**. Refine around the promising element/severity using **1%** increments; optional 0.5% refinement. If optimum occurs at 60% boundary, flag search-boundary uncertainty; potential extension to 80% requires justification and cautious interpretation.

For $m$ sensor/load observations, the basic objective is

$$J(j,d)=\sqrt{\frac1m\sum_{i=1}^{m}(u_i^{FE}(j,d)-u_i^{obs})^2}.$$

The best candidate is $(j^*,d^*)=\arg\min_{j,d}J(j,d)$. Optional normalized error is $J_N=\sqrt{\sum(u^{FE}-u^{obs})^2/\sum(u^{obs})^2}$ when denominator > 0. Report best element/region, loss percent, remaining stiffness, RMSE, residual plot, and competing low-error candidates. Do **not** describe arbitrary transformed RMSE rankings as calibrated probabilities; if distinct candidates fit nearly equally well, report a region of uncertainty rather than unjustified precision.

**Verification:** synthetic blind cases where true element/loss are hidden from search; demonstrate accurate recovery across several cases (e.g. E7 at 30%). Test an undamaged case, noise (0%, 1%, 2%, 5%, potentially 10%), alternate mesh for data generation, differing material assumptions and mis-specified support/loading conditions if time permits. Agreement with self-generated idealized observations is algorithm verification **not field validation**. Field-measured deflection data have not been supplied so far.

For RCC, normal cracking or uncertain baseline $I_{eff}$ could mimic damage; defer inverse RCC unless baseline is defensibly established. **Stage 3 is optional under the Nov 24 deadline**.

## 8. Stage 4 — Inspection-informed repair decision support

Stage 3 estimates **where** effective stiffness may have changed and **how much**; it cannot tell whether the physical cause is corrosion, fatigue crack, section loss, buckling, impact deformation, connection deterioration, or other mechanisms. Stage 4 therefore requires separately entered **inspection-confirmed** defect type, material, affected member/region, extent, physical severity (e.g. section loss/crack observation), structural consequence, and whether primary load-carrying.

Use a **documented rule-based engineering decision engine**, not an LLM deciding repairs. Initial documented repair logic is **steel only**; RCC-specific repair rules were not added to scope. Categories could include coating/corrosion protection, detailed structural evaluation, strengthening/rehabilitation assessment, inspection/NDE and fatigue evaluation, or possible member replacement subject to detailed engineering. Present source for each invoked rule and its conditions; do not fabricate guidance thresholds (e.g. "30% EI loss always needs a plate"). Require professional review. **No final sizing of strengthening plates, bolts, welds or load-rating approval.**

Optional repaired-state scenario: assign illustrative restored $EI$ (e.g. 0.90 $EI_0$), rerun Stage 1 and compare healthy/damaged/hypothetically repaired deflections and envelopes. This is a **scenario**, not proof that the real repair is safe or adequate. Stage 4 is the **last and most deferrable** part.

## 9. GUI and visual design

Preferred look: **light, neat sage-green** engineering dashboard, with responsive areas but legibility taking precedence over decoration. Original conceptual tab plan (may consolidate into fewer actual tabs initially):

1. Bridge Model — span(s), mesh, supports, material, $E$ and $I$/$I_{eff}$.
2. Vehicle — axle loads and spacing, step size.
3. Moving Load Analysis — animation and current response.
4. Response Envelopes — positive/negative extrema and governing vehicle positions.
5. Damage Sensitivity — element selection and stiffness-loss slider.
6. Damage Identification — import measured responses, candidate search, RMSE ranking.
7. Repair Decision Support — inspection data and rule trace (steel only).
8. Verification — benchmark inputs/results/error tables.

Main window concept: left inputs, center model/truck graphic, bottom moment/shear/deflection and numerical results, tabs/controls for analysis modes. Conventional support symbols are required in **all figures**, not stylized icons with ambiguous meaning. Show labels and units clearly. Matrices should be displayed as **real matrices, not layout tables**; the written proposal was edited accordingly. Use a proper $4\times4$ mathematical matrix representation in documentation.

The current proposal/presentation images are **concepts**, not the finished application. Do not claim GUI functionality until actually implemented.

## 10. Verification and numerical accuracy — required

The proposal includes **at least three independent benchmark problems, including an indeterminate case**. Tolerances are **targets**, not demonstrated results. Analytical references must stay fixed even if code disagrees. Calculate percent error against nonzero analytical values, absolute error against zero references; check static equilibrium and mesh/step convergence.

### Benchmark A — Central point load on simply supported beam

$$R_A=R_B=P/2,\quad M_{max}=PL/4,\quad |\delta_{mid}|=PL^3/(48EI).$$

Illustrative values $L=20$ m, $P=100$ kN, $E=200$ GPa, $I=0.01$ m$^4$. Analytical reference $R_A=R_B=50$ kN, $M_{max}=500$ kN·m, $|\delta|=8.333\ldots$ mm. Proposed **<0.1%** target. This checks matrix, BCs, nodal displacement and force recovery.

### Benchmark B — Single point load moving on simple span

At $a$ from left end:

$$R_A=P(L-a)/L,\quad R_B=Pa/L,\quad M(a)=Pa(L-a)/L.$$

The maximum of moment directly beneath a single load occurs at $a=L/2$ ($M_{max}=PL/4$); check many positions, including loads inside elements and at node boundaries. Proposed **<0.5%** target. This checks position mapping, Hermite equivalent loads, internal-force recovery and critical-position detection.

### Benchmark C — Uniformly loaded propped cantilever (indeterminate)

Fixed at A, roller at B; constant $EI$; uniform $w$:

$$R_A=5wL/8,\quad R_B=3wL/8,\quad M_A=-wL^2/8.$$

Reference derives from compatibility of free-end deflection $wL^4/(8EI)$ and counter-deflection $R_BL^3/(3EI)$. Proposed **<0.5%** target. Check zero deflection at prop and correct fixed-end rotation restraint.

### Optional benchmark D — Two-span equal continuous beam

For two equal spans $L$, constant $EI$, uniform $w$ on both, simple outer supports and continuous middle support:

$$M_B=-wL^2/8,\quad R_A=R_C=3wL/8,\quad R_B=5wL/4.$$

Useful both for course relevance and moment redistribution under Stage 2.

### Additional solver-level checks

- Exact element matrix values, symmetry, size, units, connectivity and assembled symmetry.
- Correct support mapping; detect rigid-body modes/singular reduced $K$ clearly.
- Force/moment equilibrium at nodes and whole structure; load summation.
- Correct jump in shear at concentrated axle locations and corresponding piecewise bending moment.
- Axle entry/exit, crossing support or element boundary, multi-axle superposition, negative/positive envelope tracking.
- Mesh and vehicle-step convergence, reasonable numerical tolerance based on discretization.
- RCC/steel equivalence test under equal assigned $EI$, not a concrete-cracking validation.
- Stage 2: $d=0$ yields healthy result, specified element only altered, continuous-beam behavior plausible.
- Stage 3: blind synthetic cases, no-damage recognition, sensitivity to noise and ambiguous candidates.
- Stage 4: traceable, condition-based example rule paths, no unsupported thresholds.

**Never report “passed” until an executable test actually ran**. If MATLAB is unavailable to Claude Code, it should create scripts and precise local execution instructions, with status `NOT RUN`.

## 11. Suggested data model and modular software architecture

Internal SI units: length **m**, force **N**, moment **N·m**, displacement **m**, rotation **rad**, Young's modulus **Pa**, inertia **m⁴**, $EI$ **N·m²**. GUI may show mm, kN, kN·m and GPa via explicit converters. Choose and document sign convention before implementation. Main model objects/structs should include `nodes`, `elements`, `material`, `EI`, `supports`, `vehicle`, `loads`, `sampling`, `results`; record metadata such as units, reference axle and solver/test version. Untrusted imported field data should be validated (columns, coordinates, load IDs, timestamps if applicable, missing values, units).

Recommended initial repository layout (create lazily; **do not** build empty advanced modules just to fill folders):

```text
CE7405_Bridge_Platform/
  README.md
  PROJECT_SPEC.md              # authoritative copy of this document
  START_HERE.md
  DECISIONS.md
  DEVELOPMENT_PLAN.md
  VERIFICATION_LOG.md
  CHANGELOG.md
  src/
    elements/beamElementStiffness.m
    elements/beamShapeFunctions.m
    model/createBeamModel.m
    model/assembleGlobalK.m
    model/validateModel.m
    solver/applyBoundaryConditions.m
    solver/solveStaticModel.m
    solver/recoverReactions.m
    solver/recoverElementForces.m
    loads/equivalentPointLoad.m
    loads/equivalentDistributedLoad.m
    loads/vehicleLoadVector.m
    loads/generateVehiclePositions.m
    postprocess/evaluateBeamResponse.m
    postprocess/calculateEnvelopes.m
    postprocess/findCriticalPositions.m
    damage/applyStiffnessDamage.m                  # Stage 2
    damage/identifyDamage.m                       # Stage 3, later
    repair/repairAdvisor.m                        # Stage 4, later
    visualization/plotBridge.m
    visualization/plotDeformedShape.m
    visualization/plotShearMoment.m
  app/BridgeConditionApp.mlapp                    # later, after numerical proof
  tests/
    testBeamStiffness.m
    testAssembly.m
    testSimplySupportedBeam.m
    testMovingPointLoad.m
    testProppedCantilever.m
    testContinuousBeam.m
    testMaterialEquivalence.m
    testDamageSensitivity.m
  examples/
  docs/theory/
  docs/verification/
  docs/development_logs/
  docs/user_guide/
  docs/final_report/
  results/figures/
  results/tables/
```

**Non-negotiable architecture:** numerical functions callable independently of App Designer; no central math hidden in GUI callbacks; avoid duplicated steel/RCC solver; write automated unit/benchmark tests; no black-box FE solver as primary; use version control and change log; reproducible inputs/outputs; validate model instability and invalid inputs; no fabricated calculations.

## 12. November 24 delivery plan (supersedes old December schedule)

| Dates (2026) | Focus and expected evidence |
|---|---|
| Oct 28–Nov 1 | Set repository, sign/units conventions, agree data structures, basic element stiffness, assembly and simple-load benchmark |
| Nov 2–7 | Working linear beam solver, supports/reactions, at least Benchmark A and propped/continuous framework |
| Nov 8–13 | Moving multi-axle loads at arbitrary positions, correct force recovery, diagrams, critical positions and envelopes, early GUI |
| Nov 14–17 | Three required benchmarks, equilibrium and convergence, steel/RCC material selection and equal-EI check |
| Nov 18–20 | Stage 2 healthy/degraded comparison with continuous-beam example and verification |
| Nov 21–23 | Stabilize app, record demo and screenshots, documentation/final report; Stage 3 only if core is verified; Stage 4 only if remaining time and sourced rules |
| **Nov 24** | **Working source/app, report, validation logs and final demonstration/submission** |

Dates are a proposed working schedule. The original course template still contains older Dec 3/5 milestones, but the student's latest deadline instruction is Nov 24. Confirm submission logistics/actual time with instructor; **do not change back to Dec 5**.

## 13. Final demo, existing presentations and evaluation requirements

Written proposal's ten sections (all addressed in latest revision): problem/motivation; objectives/scope; technical method including DOFs, stiffness, transformation, assembly, BCs, solver and flowchart; prioritized features; GUI sketch; 3+ benchmarks including indeterminate; timeline; 12-minute final demo; risks/fallback; AI use and references. The PDF rubric especially weights **technical approach 20 points**, **verification 15**, **timeline feasibility 15**. User's separate peer-proposal rubric (5-minute talk + about 1-minute Q&A) weights **problem/objectives 25**, **proposed method 35**, **feasibility 20**, **delivery/Q&A 20**. These are different presentation events.

For final demonstration, proposed order: show verified simple point-load case and comparison table; run multi-axle vehicle on continuous bridge; show moment/shear/deflection and critical response envelopes; switch steel/RCC equivalent $EI$ inputs; demonstrate known-element stiffness reduction; show optional inverse blind case and optional steel repair suggestion **only if genuinely working and verified**. Have a recorded backup or screenshots if live GUI fails. Do not substitute illustrative graphics for actual verified outputs.

Sage-green visual preference and conventional support symbols apply to slides, GUI, diagrams and reports. Prior slide edits: all-caps prominent cover title, clean italic subtitle, no decorative “proposal concept/no analysis results” footer on cover, no goal footer on page 1, graphical prominent assumptions on page 2, no “one promise” footer on final slide. These are presentation styling decisions, not requirements to reproduce the entire slide deck in the app.

## 14. Major risks, fallback logic and engineering cautions

| Risk | Mitigation |
|---|---|
| Inconsistent signs, units or incorrect support restraints | Declare convention up front; run reactions and equilibrium benchmarks; show validation errors |
| Incorrect in-element axle equivalent loads or shear/moment recovery | Separate load vector and internal-force postprocess; verify analytically across element boundaries |
| Singularity or spurious stiffness | Check restraints/DOF indices, stiffness symmetry, rank/conditioning |
| RCC $I_{eff}$ uncertainty or changing cracking state | User-supplied justified baseline, constant per run, explicit caveat; no nonlinear claims |
| GUI consumes time before numerical model works | Run solver headless first; basic GUI after tests; defer visual refinements |
| Inverse nonuniqueness/noisy or unavailable field observations | Synthetic single-damage tests, 0% candidate, multiple sensors/loads, uncertainty ranking; otherwise defer |
| Repair advice not defensible | Require physical inspection plus documented steel-specific rule; otherwise defer Stage 4 |
| Too many commitments for Nov 24 | Finish/verify Stage 1, then Stage 2; Stages 3–4 are stretch goals |

**Statically determinate vs indeterminate:** For a simply supported beam, changing $EI$ generally affects deflections but not load-determined reactions/moments; for continuous/propped beams it can redistribute forces. Do not interpret reduced stiffness as a direct percentage of physical damage severity or load capacity. “Damaged region” means model segment, not necessarily a physically unique flaw or girder.

## 15. Coordination: Claude Code vs Claude Cowork

| Topic | Claude Code (authoritative for code/tests) | Claude Cowork (authoritative for prose/layout) |
|---|---|---|
| Engineering calculations | Implement and test MATLAB source | Explain equations based on spec and actual outputs |
| GUI | Implement and verify behavior | Draft accurate UI guide/screenshots from current version |
| Benchmark results | Execute and save raw numeric results | Prepare verification tables, narrative, limitations; no invented values |
| Technical changes | Record in `DECISIONS.md` and `CHANGELOG.md` | Read records; maintain dated milestone notes |
| Documentation | Provide docstrings and reproducible examples | Write/report/layout technical theory, final report and user guide |
| Stage 3 and Stage 4 | Implement only after gates met | Describe planned vs implemented; cite repair source when actually used |
| Source files | Sole editing owner | Read-only access to solver/test code unless user authorizes change |

**Single source of truth:** `PROJECT_SPEC.md` states agreed intentions; `DECISIONS.md` records approved changes; **executed tests and outputs** state demonstrated capability. Cowork must never elevate a conceptual feature to “implemented” without logged evidence. Prefer serial editing of shared Markdown files to avoid conflicts. If Cowork must suggest a change, propose it in a documentation note, not silently edit the solver assumptions.

## 16. Decisions not made — do not silently infer

- Exact MATLAB release and whether MATLAB/App Designer/test runtime is available in Claude Code's environment.
- Concrete GUI workflow implementation details (one span-length field vs spans array, support coordinates, mesh auto-alignment).
- Whether variable element $EI$ and nonuniform mesh are needed immediately or after core uniform-$EI$ verification.
- Whether uniform dead load is core or a later additive case (needed for propped benchmark, but can first implement direct load vector).
- Choice of response sign convention and unit-display policy; decide once and record.
- Whether field deflection measurements actually exist and what their input format/sensor coordinates/load references are.
- Which specific published engineering rules and decision thresholds Stage 4 will use; cite actual authoritative provisions if implemented.
- Whether an `.mlapp` installed/packaged application is required, or source + runnable MATLAB GUI is acceptable.
- Confirm exact November 24 submission time and any updated final-demo instructions with instructor; date is known from user but original PDF is stale.

If a detail does not block the next milestone, use a conservative reversible default **and record it**. Ask the user only when an architectural decision cannot be safely made otherwise.

## 17. First development gate / definition of done

**Claude Code Session 1 should not attempt all four stages.** It should inspect files and environment; establish sign/units and data structure; implement two-node beam stiffness, global assembly, support reduction, basic static solve; run a simple beam benchmark **if MATLAB is available**; report exact actual vs analytical values, error, pass/fail or `NOT RUN`; and update logs. A complete first success is a reproducible, correct single-load beam analysis, *not* a mock-up that merely looks finished.

**Claude Cowork Session 1** should read the same specification/proposal and Code's verified log, create controlled documentation outlines and a verification report template, record all unverified outputs as `PENDING`, and not modify executable code or invent results. After the first Code milestone, Cowork may start writing technical formulation and reporting actual benchmark data.

## 18. References and existing conversation assets

**Required course text:** McGuire, W., Gallagher, R. H., and Ziemian, R. D. (2000). *Matrix Structural Analysis*, 2nd ed., Wiley.

**In the latest written proposal:** Federal Highway Administration (2019), *Manual for Refined Analysis in Bridge Design and Evaluation* (FHWA-HIF-18-046), §4.1.1.2; Federal Highway Administration (2023), *Bridge Inspector’s Reference Manual* (FHWA-NHI-23-024). Use these as proposed references and verify exact relevance before citing specific RCC effective-inertia or repair rules. AASHTO/FHWA steel-repair guidance was discussed as a possible later Stage 4 basis, not implemented rules.

**Existing user-facing materials:** Original 4-stage project-summary pasted text; CE 7405 proposal template; separate detailed peer-scoring sheet; 5-minute proposal PowerPoint revised to sage green and conventional supports; speaker cues and peer Q&A PDF; latest editable written proposal containing steel + RCC, November 24 deadline, and correctly formatted 4×4 stiffness matrix. These are design and communication artifacts, **not source code**. The latest proposal should accompany this handoff in the shared workspace.

**End-state aspiration:** Bridge definition → Matrix model → Quasi-static moving loads → Critical responses and envelopes → Known stiffness sensitivity → Optional unknown stiffness-loss localization → Optional inspection-informed repair category and hypothetical restoration. **Implement in this order.**
