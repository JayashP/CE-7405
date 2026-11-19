# VERIFICATION_LOG — executed test evidence only

**Rules**
- A result appears here only if a test actually ran. Every run names the platform it ran on.
- Anything not executed is marked **NOT RUN**.
- Analytical references are fixed (DECISIONS.md D-010).
- Raw logs are in `results/verification/`.

---

## V-001 — 2026-10-29 — Milestone M1 (element, assembly, supports, static solve, reactions, nodal-load force recovery)

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | Not run in this entry; MATLAB is not installed in the Claude Code environment (D-011). The user's MATLAB run is recorded as **V-002** |
| App Designer | Not applicable. No GUI exists yet |
| Command (repo root) | `octave-cli --no-gui --norc --eval "runAllTests;"` |
| Raw log | `results/verification/2026-10-29_M1_octave-8.4.0_runAllTests.log` |
| Overall result (Octave) | **26 passed, 0 failed, 26 tests.** octave-cli exit status 0 |
| Determinism | Two consecutive runs printed identical numeric tables |

### Benchmark A — simply supported beam, central point load (spec §10)

**Inputs**
- L = 20 m, P = 100 kN downward, E = 200 GPa, I = 0.01 m⁴, so EI = 2×10⁹ N·m²
- 20 uniform elements, so L_e = 1 m
- Pin at x = 0, roller at x = 20 m, load −P at the node at x = 10 m

**Solver diagnostics:** rcond(K_ff) = 6.840×10⁻⁶; max |K_ff·U_f − F_f| = 8.941×10⁻⁸.

**Sign convention:** v up +, θ CCW +, M sagging +.

The **actual** values are copied from the Octave log.

| Quantity | Expected (analytical) | Actual (Octave) | Abs. error | Rel. error % | Criterion | Result |
|---|---|---|---|---|---|---|
| R_A [kN] | 50 | 50.000000000039 | 3.912e‑11 | 7.823e‑11 | <0.1 % | PASS |
| R_B [kN] | 50 | 50.000000000054 | 5.402e‑11 | 1.080e‑10 | <0.1 % | PASS |
| M_max [kN·m] (sagging) | 500 | 500.00000000031 | 3.134e‑10 | 6.269e‑11 | <0.1 % | PASS |
| x of M_max [m] | 10 | 10 | 0 | 0 | <0.1 % | PASS |
| M(midspan⁺), right element [kN·m] | 500 | 500.0000000003 | 2.963e‑10 | 5.925e‑11 | <0.1 % | PASS |
| M at pin A / roller B [kN·m] | 0 / 0 | 9.31e‑13 / 0 | 9.31e‑13 / 0 | n/a | abs ≤ 5e‑4 | PASS |
| v_mid [mm] (signed, + up) | −8.3333333333333 | −8.3333333333391 | 5.809e‑12 | 6.970e‑11 | <0.1 % | PASS |
| \|δ_mid\| [mm] | 8.3333333333333 | 8.3333333333391 | 5.809e‑12 | 6.970e‑11 | <0.1 % | PASS |
| θ_A [rad] | −1.25e‑3 | −1.2500000000009e‑3 | 8.537e‑16 | 6.830e‑11 | <0.1 % | PASS |
| θ_B [rad] | +1.25e‑3 | 1.250000000001e‑3 | 9.602e‑16 | 7.681e‑11 | <0.1 % | PASS |
| θ_mid [rad] | 0 | −7.63e‑17 | 7.63e‑17 | n/a | abs ≤ 1.25e‑9 | PASS |
| V, left half (min / max) [kN] | +50 | 49.999999999978 / 50.00000000006 | ≤ 5.96e‑11 | ≤ 1.19e‑10 | <0.1 % | PASS |
| V, right half (min / max) [kN] | −50 | −50.000000000067 / −49.999999999965 | ≤ 6.71e‑11 | ≤ 1.34e‑10 | <0.1 % | PASS |
| ΣF_v, loads + reactions [kN] | 0 | 9.31e‑11 | 9.31e‑11 | n/a | abs ≤ 1e‑4 | PASS |
| ΣM about x = 0 [kN·m] | 0 | 1.08e‑9 | 1.08e‑9 | n/a | abs ≤ 5e‑4 | PASS |

**Further Benchmark A checks (all PASS in Octave)**
- **References vs spec.** The closed forms reproduce the spec's stated values: 50 kN, 500 kN·m and 25/3 mm, with zero difference.
- **Mesh independence.** ne = 2, 4, 8, 20 and 40 were tested. The largest relative error is 1.28e‑9 %, for R_A at ne = 40.
  - The error grows slightly with refinement, which is expected round-off as K_ff becomes worse conditioned.
  - Nodal values are exact for cubic Hermite elements under nodal loads, so no discretization error is expected.
- **Elastic curve at all 21 nodes.** The test compares against v(x) = −Px(3L²−4x²)/(48EI) and θ(x) = −P(L²−4x²)/(16EI) for x ≤ L/2, mirrored for the right half.
  - Largest error |v − v_exact|/δ_mid = 6.97e‑13. Largest |θ − θ_exact|/|θ_A| = 7.68e‑13.
  - A hand spot-check of v(1 m) = −1.2458333 mm agrees.
- **Load at a restrained DOF.** An extra 10 kN downward load at roller B gives R_B = 60.000000000054 kN and leaves R_A = 50 kN. U is bit-identical to the run without the extra load.

### Other M1 tests (Octave, all PASS)

| Test file / test | What was checked | Key actual result |
|---|---|---|
| testBeamStiffness: exact matrix, EI = 2e9 N·m², L_e = 2 m | Entries against hand-computed literals (3e9, 3e9, −3e9, 4e9, 2e9, −3e9) | Zero error |
| testBeamStiffness: EI = 1, L_e = 1 | Exact integer coefficient matrix | `isequal` true |
| testBeamStiffness: L_e = 1.5 m (spec mesh example) | Entries against 12EI/L³, 6EI/L², 4EI/L, 2EI/L | max rel error 0 |
| testBeamStiffness: symmetry | `isequal(ke, ke')` for 5 (EI, L_e) pairs | Exact |
| testBeamStiffness: null space and definiteness (EI = 2e9, L_e = 1.5 m) | k_e·[1 0 1 0]ᵀ = 0, k_e·[0 1 L_e 1]ᵀ = 0, rank 2, eigenvalues ≥ 0 within round-off | Normalized residuals 0 and 1.34e‑16; rank 2. Eigenvalues (−3.99e‑6, −3.67e‑7, 2.667e9, 2.222e10): the two near-zero values are round-off, |λ|/λ_max ≤ 1.8e‑16. The nonzero pair sums to trace(k_e) = 2.489e10 |
| testBeamStiffness: linearity | k(0.7EI) = 0.7·k(EI) | 1.34e‑16 relative (criterion ≤ 1e‑14) |
| testBeamStiffness: validation | EI or L_e in {0, −2e9, NaN, Inf, [1 2], 1+2i, 'abc', true, []} | All rejected with `BridgeFE:invalidInput` |
| testAssembly: DOF map | `elementDofs` against a hand-written map | Exact |
| testAssembly: 2 unit elements | 6×6 K against a hand-assembled matrix | Exact |
| testAssembly: nonuniform 3 elements (L_e = 2, 3, 0.5 m; EI = 3e9, 1e9, 2.5e9) | Triplet assembly against explicit Σ A_eᵀ k_e A_e | 0 relative difference (criterion ≤ 1e‑14) |
| testAssembly: 30 m / 20 elements | 42 DOFs, symmetry, rank 40, both rigid modes in the null space | Asymmetry 0; rank 40 |
| testAssembly: load vector | Forces at v DOFs, couples at θ DOFs, repeats summed | Exact |
| testAssembly: invalid data | Zero-length, reversed, single node, EI ≤ 0, EI count, bad mesh, broken conn | Correct error IDs |
| testSupportsAndStability: mapping and partition | pin/roller → v; fixed → v, θ; SS restrained [1;9]; fixed+roller restrained [1;2;9] | Exact |
| testSupportsAndStability: **under-restrained** | No supports, single pin, single interior roller | `BridgeFE:underRestrained` from `partitionDofs` and `solveStaticModel` |
| testSupportsAndStability: rule vs rank(K_ff) | 10 support layouts | Rule = numerical rank in all 10 |
| testSupportsAndStability: invalid supports and off-node coordinates | Duplicate, unknown type, out of range, flag mismatch, x not on a node | Correct error IDs |
| testCantileverTipLoad (extra, not a spec benchmark) | L = 10 m, P = 50 kN at tip, EI = 2e9, 10 elements, fixed at x = 0 | See below |

**Cantilever results (Octave)**
- R_A = 49.999999999973 kN (expected 50)
- Reaction couple = 499.99999999984 kN·m CCW (expected 500)
- M(0) = −499.99999999984 kN·m (expected −500, hogging)
- v_tip = −8.3333333333312 mm (expected −8.3333…)
- θ_tip = −1.2499999999997e‑3 rad (expected −1.25e‑3)
- V = +50 kN along the span
- Largest relative error 9.3e‑11 %

### Test-sensitivity (mutation) check — 2026-10-29, Octave 8.4.0

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Method:** each mutant is a scratch copy of the repo with one injected fault. The repo itself is untouched.
- **Result: 7 of 7 faults detected.** For every mutant, `runAllTests` exited with status 1.
- **Raw output:** `results/verification/2026-10-29_M1_mutation_check_octave-8.4.0.txt`.

| Injected fault | Tests failed (of 26) |
|---|---|
| k22 coefficient 4 → 3 | 12 |
| Sign of the k12/k21 rotation coupling flipped | 12 |
| v/θ order swapped in the DOF map | 9 |
| Sign of the end moment at node i | 2 (Benchmark A, cantilever) |
| Reactions ignore loads at restrained DOFs | 1 (load-at-support test) |
| Under-restraint check removed | 2 |
| Element length forced to 1 m | 3 |

The last fault does not show up in Benchmark A itself, because L_e = 1 m there. The nonuniform-assembly and mesh-independence tests catch it.

### Limits of this evidence

- These results were produced by **GNU Octave, not MATLAB.** The `.m` source is the same, and results are expected to agree to round-off. MATLAB confirmation of the same 26 tests is recorded in **V-002**.
- Only **nodal** loads and **determinate** structures (simple span, cantilever) were analytically benchmarked.
  - The indeterminate benchmarks C (propped cantilever) and D (two-span continuous) are **NOT RUN**, because they are not implemented yet (M2).
  - Benchmark B (moving point load) is **NOT RUN** (M3).
- No GUI, plots, vehicles, envelopes, materials layer or damage features exist yet. Nothing about them is claimed.

### Commands to reproduce locally

From the repository root, in MATLAB (any release with `matlab.unittest`; script-based tests need R2016a or later):

```matlab
addProjectPaths;
results = runAllTests;               % prints every comparison table and a PASS/FAIL summary; errors if any test fails
```

Alternatively, using the MATLAB test framework directly:

```matlab
addProjectPaths;
r = runtests('tests');
table(r)
```

From a terminal:

```bash
matlab -batch "runAllTests"
```

```bash
octave-cli --no-gui --norc --eval "runAllTests;"
```

---

## V-002 — 2026-10-29 — Milestone M1 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | **MATLAB 26.2.0.3386108 (R2026b)**, on the user's own computer |
| Run by | The user (Jayash Pradhananga). Claude Code has no MATLAB, so it did not run this |
| Code version | `main` at commit `4dced60`; the source and tests are identical to `dbb8588`, the commit tested in V-001 |
| Runner | `runAllTests`, MATLAB branch, using `matlab.unittest`. MATLAB converted each `%%` section title into a test identifier |
| Timestamp printed by the runner | 2026-10-29 13:57:39 (the user's local clock) |
| Overall result | **26 passed, 0 failed, 26 tests** |
| Evidence | Screenshot of the runner's TEST SUMMARY block: `results/verification/2026-10-29_M1_matlab-R2026b_summary_screenshot.png` |

**Per-test result:** every one of the 26 tests listed in V-001 printed **PASS** in MATLAB. They are the same five test files with the same sections, under MATLAB's identifier names.

**What this entry does and does not show**
- The pass criteria are written in the test files, so they are the same as in V-001. Every comparison therefore met its criterion in MATLAB, including Benchmark A within 0.1 %.
- The individual MATLAB numbers (the comparison tables) were **not** sent back. So this entry records PASS/FAIL against the criteria, not MATLAB's actual values.
- If the exact MATLAB numbers are needed for the report, save the full Command Window output as `results/verification/<date>_M1_matlab-R2026b_runAllTests.log`.
- App Designer: still not applicable (no GUI yet).

**Status of M1:** verified in GNU Octave 8.4.0 (V-001, with numbers) and in MATLAB R2026b (V-002, pass/fail).

---

## V-003 — 2026-10-29 — Milestone M2 (indeterminate beams, uniform loads) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | Not run in this entry. The user's MATLAB run of the same 46 tests is recorded as **V-004** |
| Code version | Branch `claude/m2-indeterminate-beams` |
| Command (repo root) | `octave-cli --no-gui --norc --eval "runAllTests;"` |
| Raw log | `results/verification/2026-10-29_M2_octave-8.4.0_runAllTests.log` |
| Overall result (Octave) | **46 passed, 0 failed, 46 tests.** This is the 26 M1 tests plus 20 new: testMeshSpansAndLoads 9, testUniformLoadBeams 4, testProppedCantilever 3, testContinuousBeam 4. octave-cli exit status 0 |
| M1 regression | All 26 M1 tests still pass, and their numeric tables are unchanged from V-001 |
| Determinism | Two consecutive runs printed identical comparison tables |

**Common inputs:** EI = 200 GPa × 0.01 m⁴ = 2×10⁹ N·m², q = 20 kN/m downward, P = 100 kN downward. Signs: v up +, θ CCW +, M sagging +. The **actual** values below are copied from the Octave log.

### Benchmark C — propped cantilever, uniform load (spec §10)

**Setup:** L = 10 m, fixed at x = 0, roller at x = 10 m, 16 elements. Solver diagnostics: rcond(K_ff) = 3.689×10⁻⁵; max residual 1.49×10⁻⁸.

| Quantity | Expected | Actual (Octave) | Rel. error % | Criterion | Result |
|---|---|---|---|---|---|
| R_A [kN] = 5qL/8 | 125 | 125.00000000002 | 1.25e‑11 | <0.5 % | PASS |
| R_B [kN] = 3qL/8 | 75 | 75.000000000013 | 1.74e‑11 | <0.5 % | PASS |
| M_A [kN·m] = −qL²/8 | −250 | −250.00000000005 | 2.00e‑11 | <0.5 % | PASS |
| Reaction couple at A [kN·m] (CCW) | +250 | 250.00000000005 | 2.00e‑11 | <0.5 % | PASS |
| Max sagging M [kN·m] = 9qL²/128 | 140.625 | 140.62500000005 | 3.31e‑11 | <0.5 % | PASS |
| x of max sagging M [m] = 5L/8 | 6.25 | 6.25 | 0 | <0.5 % | PASS |
| θ_B [rad] = qL³/(48EI) | 2.0833333e‑4 | 2.0833333333339e‑4 | 2.65e‑11 | <0.5 % | PASS |
| v(L/2) [mm] = −qL⁴/(192EI) | −0.52083333333333 | −0.52083333333347 | 2.66e‑11 | <0.5 % | PASS |
| M at roller [kN·m] | 0 | 7.8e‑13 | n/a | abs ≤ 2.5e‑4 | PASS |

**Further Benchmark C checks**
- **Displacement field.** Nodal v at all 17 nodes matches the exact curve: largest error 2.8e‑13 of qL⁴/(192EI).
- **Sampled diagrams.** M and V at 144 points match the exact parabola and line: largest errors 2.0e‑13 of qL²/8 and 1.9e‑13 of 5qL/8.
- **Restraints.** v_A = θ_A = 0 at the fixed end and v_B = 0 at the prop, all exactly zero.
- **Equilibrium.** ΣF_v = 2.9e‑11 kN and ΣM = 1.8e‑10 kN·m.
- **Mesh independence.** ne = 1, 2, 4 and 16 all reproduce R_A, R_B, M_A and θ_B. The largest error is 2.6e‑11 %, at ne = 16. With ne = 1 the errors are 0 to 1e‑14 %.

### Benchmark D — two equal 10 m spans, uniform load on both (spec §10, optional)

**Setup:** pin at x = 0, rollers at x = 10 m and x = 20 m, 16 elements per span. Solver diagnostics: rcond(K_ff) = 1.581×10⁻⁵; max residual 2.19×10⁻⁸.

| Quantity | Expected | Actual (Octave) | Rel. error % | Criterion | Result |
|---|---|---|---|---|---|
| R_A [kN] = 3qL/8 | 75 | 75 | 0 | <0.5 % | PASS |
| R_B [kN] = 5qL/4 | 250 | 250.00000000001 | 2.42e‑12 | <0.5 % | PASS |
| R_C [kN] = 3qL/8 | 75 | 75.000000000014 | 1.86e‑11 | <0.5 % | PASS |
| M_B [kN·m] = −qL²/8, from span 1 / span 2 | −250 | −250.00000000001 / −250.00000000001 | 5.4e‑12 | <0.5 % | PASS |
| Max sagging M, span 1 / span 2 [kN·m] = 9qL²/128 | 140.625 | 140.62499999998 / 140.62500000003 | ≤ 2.25e‑11 | <0.5 % | PASS |
| x of max sagging M [m] | 3.75 / 16.25 | 3.75 / 16.25 | 0 | <0.5 % | PASS |
| θ_A [rad] = −qL³/(48EI) | −2.0833333e‑4 | −2.0833333333331e‑4 | 1.33e‑11 | <0.5 % | PASS |
| θ_B [rad] | 0 | −3.7e‑17 | n/a | abs ≤ 2.1e‑10 | PASS |

**Further Benchmark D checks**
- **Displacement field.** Nodal v at all 33 nodes: largest error 3.2e‑13 of qL⁴/(192EI).
- **Sampled diagrams.** M and V at 288 points: largest errors 1.7e‑13 of qL²/8 and 1.7e‑13 of 5qL/8.
- **Equilibrium.** ΣF_v = 2.0e‑11 kN and ΣM = 3.4e‑10 kN·m.

### Supplementary checks (Octave, all PASS)

| Test | Analytical reference | Key actual result | Largest rel. error % |
|---|---|---|---|
| Propped cantilever, P at L/2 (16 elements) | R_A = 11P/16 = 68.75 kN, R_B = 5P/16 = 31.25 kN, M_A = −3PL/16 = −187.5 kN·m, M(L/2) = 5PL/32 = 156.25 kN·m, v(L/2) = −7PL³/(768EI) = −0.455729 mm | 68.750000000013, 31.250000000011, −187.50000000004, 156.25000000003, −0.45572916666678 mm; V jump and M field errors ≤ 2.3e‑13 | 3.6e‑11 |
| Two spans, P at each midspan | R_A = R_C = 5P/16, R_B = 11P/8 = 137.5 kN, M_B = −3PL/16 = −187.5 kN·m, v(L/2) = −7PL³/(768EI) | R_B = 137.50000000001 kN, M_B = −187.50000000001 kN·m from both sides, θ_B = −3.2e‑17 rad | 3.0e‑11 |
| Two spans, q on span AB only | R_A = 7qL/16 = 87.5 kN, R_B = 5qL/8 = 125 kN, **R_C = −qL/16 = −12.5 kN (uplift)**, M_B = −qL²/16 = −125 kN·m | 87.500000000002, 125, −12.500000000006, −124.99999999999 | 4.5e‑11 |
| Unequal spans 10 m + 15 m, q on both (three-moment equation) | M_B = −q(L₁³+L₂³)/(8(L₁+L₂)) = −437.5 kN·m, R_A = 56.25, R_B = 322.9167, R_C = 120.8333 kN | −437.50000000003, 56.249999999997, 322.91666666668, 120.83333333334 | 6.5e‑12 |
| Simple span, uniform q (10 elements) | R = qL/2 = 100 kN, M_mid = qL²/8 = 250 kN·m, v_mid = −5qL⁴/(384EI) = −1.30208 mm, θ_A = −qL³/(24EI) | 100, 250.00000000001, −1.3020833333334 mm; v, M and V fields ≤ 1e‑3 | 4.7e‑12 |
| Fixed-fixed beam, **one element** (no free DOFs; forces come only from −f_e0) | R = qL/2 = 100 kN, reaction couples ±qL²/12 = ±166.667 kN·m, M ends = −qL²/12, M_mid = +qL²/24 = 83.333 kN·m | 100, ±166.66666666667, −166.66666666667, 83.333333333333 | 1.7e‑14 |
| Fixed-fixed beam, 16 elements | M(0) = −166.667, M(L/2) = 83.333 kN·m, v_mid = −qL⁴/(384EI) = −0.260417 mm | −166.66666666668, 83.333333333346, −0.2604166666667 mm; v and M fields ≤ 1.2e‑13 | 1.6e‑11 |
| Sampled diagrams close element equilibrium (fixed + roller, uniform load on 4 elements, nodal force and couple) | V(L_e) = V_j, M(L_e) = M_j | Largest normalized differences 7.3e‑17 (V) and 3.3e‑16 (M) | — |
| Consistent load vector | Hand literals for w = −12 kN/m, L_e = 2 m; Gauss integral of w·N_i | Literals exact; Gauss difference 1.8e‑16 | 0 |
| Resultants on a nonuniform 6-node mesh (uniform load plus a nodal force and couple) | ΣF = wL − 8 kN; ΣM about 0 = wL²/2 − 8 kN·x₃ + 2 kN·m | Matched | 0 |
| meshSpans, elementsBetween, invalid input | Hand-written coordinates and element lists; error IDs | Exact; all invalid inputs rejected with the expected IDs | — |

### Test-sensitivity (mutation) check — 2026-10-29, Octave 8.4.0

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Result: 12 of 12 faults detected** (the 7 M1 faults plus 5 new M2 faults). For every mutant, `runAllTests` exited with status 1.
- **Raw output:** `results/verification/2026-10-29_M2_mutation_check_octave-8.4.0.txt`.

| M2 injected fault | Tests failed (of 46) |
|---|---|
| f_e0 not subtracted in force recovery | 9 |
| Signs of the consistent-load end moments swapped | 11 |
| Element loads left out of the global F | 8 |
| Sign of the parabolic term flipped in sampling | 7 |
| Element load computed with L_e = 1 | 9 |

### Limits of this evidence

- Numeric values in this entry come from GNU Octave. MATLAB PASS/FAIL confirmation of the same tests is in **V-004**.
- **Not implemented, so NOT RUN:**
  - point loads inside elements and Benchmark B (M3)
  - deflection between nodes
  - moving and multi-axle loads, envelopes (M4)
  - the materials layer (M5), GUI (M6) and Stage 2 (M7)

### Command for the MATLAB confirmation (V-004)

```bash
git fetch origin && git checkout claude/m2-indeterminate-beams
```

```bash
matlab -batch "runAllTests"
```

---

## V-004 — 2026-10-29 — Milestone M2 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer. The screenshot is cropped above the summary, so the "Platform" line is **not visible**. It is most likely the same R2026b installation as V-002, but this is **not confirmed** |
| Run by | The user. Claude Code has no MATLAB |
| Code version | Branch `claude/m2-indeterminate-beams` at commit `2d10bd7`, downloaded as a ZIP of that branch |
| Runner | `runAllTests` (MATLAB branch, `matlab.unittest`) |
| Overall result | **46 passed, 0 failed, 46 tests** |
| Evidence | Screenshot of the end of the TEST SUMMARY: `results/verification/2026-10-29_M2_matlab_summary_screenshot.png` |

**What this entry shows**
- The visible lines show PASS for every test in `testSimplySupportedBeam`, `testSupportsAndStability` and `testUniformLoadBeams`, then the total line `Total: 46 passed, 0 failed, 46 tests`.
- A total of 46 means the 20 M2 tests (`testMeshSpansAndLoads`, `testUniformLoadBeams`, `testProppedCantilever`, `testContinuousBeam`) ran and passed. That includes Benchmarks C and D against their 0.5 % criteria.
- As with V-002, the MATLAB comparison tables were not sent, so this entry records PASS/FAIL, not MATLAB's numbers.

**Status of M2:** verified in GNU Octave 8.4.0 (V-003, with numbers) and in MATLAB (V-004, pass/fail). The gate is met, so the branch is merged into `main`.

---

## V-005 — 2026-10-29 — Milestone M3 (point loads inside elements, deflection between nodes) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | Not run in this entry. The user's MATLAB run of the same 61 tests is recorded as **V-006** |
| Code version | Branch `claude/m3-in-element-point-loads` (from `main` at `b0e3d72`) |
| Command (repo root) | `octave-cli --no-gui --norc --eval "runAllTests;"` |
| Raw log | `results/verification/2026-10-29_M3_octave-8.4.0_runAllTests.log` |
| Overall result (Octave) | **61 passed, 0 failed, 61 tests.** That is 46 earlier tests plus 15 new: testShapeFunctionsAndPointLoads 8, testMovingPointLoad 2, testPointLoadsInElements 5. octave-cli exit status 0 |
| Regression | All 46 M1/M2 tests still pass. The Benchmark A table is identical to V-001 |
| Determinism | Two consecutive runs printed identical comparison tables |

**Common inputs:** EI = 2×10⁹ N·m², loads downward. Signs: v up +, M sagging +. The **actual** values are copied from the Octave log.

### Benchmark B — single point load moving on a simple span (spec §10)

**Setup**
- L = 20 m, P = 100 kN, pin at x = 0, roller at x = 20 m.
- Mesh of **8 elements of 2.5 m** (deliberately coarse).
- **88 load positions**, of which 79 are inside elements. They are a 0.25 m grid plus 0.1, 1.234, 7.77, 12.3456 and 19.99 m and 5 m ± 1e‑7 m.

**Selected positions**

| a [m] | R_A [kN] actual / exact | M under load [kN·m] actual / exact | v under load [mm] actual / exact |
|---|---|---|---|
| 0.1 | 99.500000 / 99.500000 | 9.950000 / 9.950000 | −0.0033001 / −0.0033001 |
| 1.234 | 93.830000 / 93.830000 | 115.786220 / 115.786220 | −0.4468816 / −0.4468816 |
| 2.5 (node) | 87.500000 / 87.500000 | 218.750000 / 218.750000 | −1.5950521 / −1.5950521 |
| 7.77 | 61.150000 / 61.150000 | 475.135500 / 475.135500 | −7.5251248 / −7.5251248 |
| 10 (node, L/2) | 50.000000 / 50.000000 | 500.000000 / 500.000000 | −8.3333333 / −8.3333333 |
| 12.3456 | 38.272000 / 38.272000 | 472.490803 / 472.490803 | −7.4415853 / −7.4415853 |
| 19.99 | 0.050000 / 0.050000 | 0.999500 / 0.999500 | −0.0000333 / −0.0000333 |

**Summary over all 88 positions**

| Quantity | Actual (Octave) | Criterion | Result |
|---|---|---|---|
| Largest relative error of R_A [%] | 6.98e‑12 | ≤ 0.5 % | PASS |
| Largest relative error of R_B [%] | 2.48e‑12 | ≤ 0.5 % | PASS |
| Largest relative error of M under the load [%] | 2.42e‑12 | ≤ 0.5 % | PASS |
| Largest relative error of v under the load [%] | 2.07e‑12 | ≤ 0.5 % | PASS |
| Largest relative error of the shear jump vs P [%] | 6.72e‑12 | ≤ 0.5 % | PASS |
| Largest gap between the maximum sampled M and M under the load, / (PL/4) | 0 | ≤ 1e‑9 | PASS |
| Load at a = 0: R_A / R_B [kN] | 100 / 0 | exact | PASS |
| Load at a = L: R_B [kN] | 100 | exact | PASS |
| Critical position a* for maximum M [m] | 10 (= L/2) | < 0.5 % | PASS |
| Maximum M over positions [kN·m] | 500 (error 8.9e‑13 %) | < 0.5 % | PASS |
| Largest \|ΣF_v\| / \|ΣM about 0\| over positions | 3.5e‑12 kN / 1.9e‑11 kN·m | abs | PASS |

**Continuity across a node:** the load was placed at x = 5 m (on node 3) and 1e‑7 m to either side (inside elements 2 and 3).
- Largest change in U: 1.64e‑8 of max|U|, for both sides.
- R_A(5 + δ) − R_A(5 − δ) = 0.0010000001639 N, against the exact 2Pδ/L = 0.001 N.

### Other M3 checks (Octave, all PASS)

| Test | Analytical reference | Key actual result | Largest rel. error % |
|---|---|---|---|
| **Two loads inside one element** (simple span of one 10 m element; 50 kN at 3 m, 80 kN at 7 m) | R_A = 59, R_B = 71 kN; M(3) = 177, M(7) = 213 kN·m; V = 59 → 9 → −71 kN; v from superposed closed forms | All exact to ≤ 8e‑14 %. Deflection v(3) = −0.8595 mm, v(7) = −0.8955 mm; largest field error over 41 points is 3e‑16 | 7.9e‑14 |
| **Propped cantilever, 100 kN at 3.7 m** (inside element 2 of 4) | R_B = Pa²(3L − a)/(2L³) = 18.00235 kN, M_A = −189.9765 kN·m, M(a) = 113.414805 kN·m, jump 100 kN, v(a) from the elastic curve | 18.00235, −189.9765, 113.414805, 100; v(a) = −0.3040756574625 mm | 3.2e‑13 |
| **Deflection between nodes** | Simple span with UDL on only 2 elements, at 41 points; simple span with P at 7.3 m on 4 elements; fixed-fixed beam as one element (U = 0, pure particular solution) | Field errors 5.0e‑16 and 6.2e‑15. Fixed-fixed v(L/2) = −0.26041666666667 mm (= −qL⁴/384EI) and v(L/4) = −0.146484375 mm, both exact | 5.7e‑13 |
| **Mixed loads in one model** (fixed + roller; UDL on elements 2–4; loads at 4.5 m down and 5.2 m up in the same element; load at a node; nodal couple) | Element-end equilibrium of the sampled diagrams; jumps −60 and +25 kN | Normalized end gaps 6.1e‑17 (V) and 1.9e‑16 (M); jumps −60 and +25 kN exactly | 0 |
| **Load exactly on the pin** | U = 0, R_A = 50 kN, R_B = 0 | U = 0 exactly, R_A = 50, R_B = 0 | 0 |
| **Shape functions and point-load vectors** | Nodal values; rigid-body reproduction; N(1/3) = [20/27, 4L_e/27, 7/27, −2L_e/27]; end slopes; fixed-end actions Pab²/L², −Pa²b/L², P b²(3a+b)/L³, P a²(a+3b)/L³; resultant force and moment for 5 positions | All match | ≤ 2e‑14 |
| **Load location and F assembly** | Loads at 0, 2.5 and 10 m go to nodes 1, 2, 5; 2.5 m + 1e‑12 goes to node 2; 3.7 m to element 2 at a = 1.2 m; 9.9 m to element 4 at a = 2.4 m. A point load at a node gives the same F as a nodal load; an interior load gives F equal to the Hermite vector | Exact | — |
| Invalid input | r outside [0, 1], a outside the element, loads off the beam, Inf load, broken `loads.point` | Expected error IDs | — |

### Test-sensitivity (mutation) check — 2026-10-29, Octave 8.4.0

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Result: 18 of 18 faults detected** (7 M1 + 5 M2 + 6 M3). For every mutant, `runAllTests` exited with status 1.
- **Raw output:** `results/verification/2026-10-29_M3_mutation_check_octave-8.4.0.txt`.

| M3 injected fault | Tests failed (of 61) |
|---|---|
| N2 shape-function coefficient wrong | 11 |
| Sign of the point-load shear jump flipped in sampling | 2 |
| UDL particular solution left out of the deflection | 1 |
| Point-load particular solution left out (s ≤ a) | 3 |
| Point load located in the wrong element | 7 |
| Point loads at nodes dropped from F | 4 |

### Limits of this evidence

- Numeric values in this entry come from GNU Octave. MATLAB PASS/FAIL confirmation of the same tests is in **V-006**.
- **Not implemented, so NOT RUN:** multi-axle vehicles, position stepping, envelopes and step refinement (M4); the materials layer (M5); GUI (M6); Stage 2 (M7).

### Command for the MATLAB confirmation (V-006)

Download a ZIP of branch `claude/m3-in-element-point-loads` from GitHub (or `fetch` and `switchBranch` in MATLAB). Then, in its folder:

```matlab
restoredefaultpath
runAllTests
```

Expected last line: `Total: 61 passed, 0 failed, 61 tests`.

---

## V-006 — 2026-10-29 — Milestone M3 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer. The screenshot starts below the summary header, so the "Platform" line is **not visible**. It is most likely the same R2026b installation as V-002, but this is **not confirmed** |
| Run by | The user. Claude Code has no MATLAB |
| Code version | Branch `claude/m3-in-element-point-loads` at commit `46fda13` |
| Runner | `runAllTests` (MATLAB branch, `matlab.unittest`) |
| Overall result | **61 passed, 0 failed, 61 tests** |
| Evidence | Screenshot of the end of the TEST SUMMARY: `results/verification/2026-10-29_M3_matlab_summary_screenshot.png` |

**What this entry shows**
- The visible lines show PASS for every test in `testSimplySupportedBeam`, `testSupportsAndStability` and `testUniformLoadBeams`, then `Total: 61 passed, 0 failed, 61 tests`.
- A total of 61 means the 15 M3 tests (`testShapeFunctionsAndPointLoads`, `testMovingPointLoad`, `testPointLoadsInElements`) ran and passed in MATLAB. That includes Benchmark B against its 0.5 % criterion.
- The `>>` prompt follows the summary directly, with no `ans = 1x61 struct array` echo. This confirms in MATLAB the M3 change to `runAllTests`.
- As in V-002 and V-004, the MATLAB comparison tables were not sent, so this entry records PASS/FAIL, not MATLAB's numbers.

**Status of M3:** verified in GNU Octave 8.4.0 (V-005, with numbers) and in MATLAB (V-006, pass/fail). The gate is met, so the branch is merged into `main`.

---

## V-007 — 2026-10-30 — Milestone M4 (moving vehicle, envelopes, critical positions) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | Not run in this entry. The user's MATLAB run of the same 74 tests is recorded as **V-008** |
| Code version | Branch `claude/m4-moving-vehicle-envelopes` (from `main` at `f87e3d8`) |
| Command (repo root) | `octave-cli --no-gui --norc --eval "runAllTests;"`; one full run takes about 13 s |
| Raw log | `results/verification/2026-10-30_M4_octave-8.4.0_runAllTests.log` |
| Overall result (Octave) | **74 passed, 0 failed, 74 tests.** That is 61 earlier tests plus 13 new: testVehicleAndPositions 4, testMovingLoadFastPath 2, testMovingLoadEnvelopes 7. octave-cli exit status 0 |
| Regression | All 61 M1–M3 tests still pass |
| Determinism | Two consecutive runs printed identical comparison tables |

**Common inputs:** EI = 2×10⁹ N·m². The spec 3-axle truck is 80/120/120 kN with spacings 4.2 m and 1.4 m, and the front axle is the reference. It is illustrative, not an AASHTO truck. Signs: v up +, M sagging +. The actual values are copied from the Octave log.

### Independent confirmation of the moving-load references

- **Command:** `python3 -I tools/moving_load_reference_check.py` (Python 3.13.17, NumPy 2.5.3).
- **Method:** closed-form statics only, sweeping positions at 1e‑4 m. It does not use the MATLAB code.
- **Raw output:** `results/verification/2026-10-30_M4_reference_brute_force_check.txt`.

| Reference | Closed form | Brute force |
|---|---|---|
| Two 100 kN axles at 4.2 m, 20 m span: absolute maximum M | P(2L − d)²/(8L) = 801.0250 kN·m | 801.0250 kN·m at x_v = 13.15 m, under the axle at x = 8.95 m |
| Spec 3-axle truck, 20 m span: maximum M | Resultant rule: 1349.1025 kN·m at x = 9.7375 m, x_v = 13.9375 m | 1349.1025 kN·m at x_v = 13.9375 m, x = 9.7375 m |
| Two equal 20 m spans, 100 kN: minimum M_B | −PL/(6√3) = −192.45009 kN·m at a = L/√3 = 11.5470 m | −192.45009 kN·m at a = 11.5470 m |

### Moving-load results (Octave, all PASS)

| Test | Analytical reference | Actual (Octave) | Error / criterion |
|---|---|---|---|
| **Single 100 kN load, 20 m simple span**: envelopes at all interior stations (8 elements, stations every 0.625 m, positions every 0.125 m) | Mmax = Px(L−x)/L, Vmax = P(L−x)/L, Vmin = −Px/L | Largest normalized errors 4.3e‑14 (M), 5.7e‑14 (Vmax), 3.7e‑14 (Vmin) | ≤ 5e‑3 |
| Same: midspan deflection envelope | −PL³/(48EI) = −8.3333 mm | −8.3333333333337 mm | 3.8e‑12 % |
| Same: critical maximum M | PL/4 = 500 kN·m at x = 10 m for x_v = 10 m | 500.00000000002 kN·m at x = 10, x_v = 10 | 4.0e‑12 % |
| Same: reactions | R_A,max = R_B,max = 100 kN (load on the support), R_A,min = 0 | 100 (at x_v = 0), 100, 0 | exact |
| **Two 100 kN axles at 4.2 m**: absolute maximum M (coarse step 0.55 m, refined ×10) | 801.025 kN·m under an axle at L/2 ± d/4 | **801.02475** kN·m at x = 8.945 m (under the rear axle), x_v = 13.145 m. Coarse value 801.000 at x_v = 13.2 | 3.1e‑5 % |
| **Step convergence**, two axles, no refinement | Error ≤ (2P/L)(h/2)², since M is quadratic in x_v near the optimum | Steps 2.42 / 1.21 / 0.605 / 0.3025 m give errors 11.025 / 0.256 / 0.256 / 0.203 kN·m, which is 0.75 / 0.07 / 0.28 / 0.89 of the bound. No overshoot. Step 2.42 m refined ×20 gives 801.00979 | each ≤ bound; refined 1.9e‑3 % |
| **Spec 3-axle truck, 20 m span** (positions every 0.1 m, refined to 0.01 m) | max M 1349.1025 kN·m at x = 9.7375, x_v = 13.9375 | **1349.1024** kN·m at x = 9.74 (middle axle), x_v = 13.94. Coarse value 1349.080 at x_v = 13.90 | 7.4e‑6 %; location within one refined step |
| Same: maximum reactions | R_A = 289.2 kN at x_v = 5.6 m (rear axle on A), R_B = 261.2 kN at x_v = 20 m | 289.2 at 5.6; 261.2 at 20 | ≤ 7.2e‑13 % |
| Same: upward deflection | none | 0 | exact |
| **Two-span 2 × 20 m, single 100 kN load** (16 elements per span, step 0.1 m, refined) | Envelope M_min at B = −PL/(6√3) = −192.45009 kN·m; R_A,min = −P/(6√3) = −9.62250 kN at x_v = 2L − L/√3 = 28.453 m | M_min(B) = −192.45007 kN·m at x_v = 11.55; R_A,min = −9.6225035 kN at x_v = 28.45; R_A,max = R_B,max = 100 kN | 1.0e‑5 %; x_v within 0.003 m |
| **Superposition**: 20 kN/m permanent load + spec truck (same positions) | Every envelope equals the static q response plus the truck envelope | Largest normalized differences: Mmax 8.7e‑15, Mmin 1.1e‑14, Vmax 3.8e‑14, Vmin 2.8e‑14, vmax 0, vmin 6.1e‑16. R_A,max difference = 200.000 kN = qL/2 | ≤ 1e‑9 |
| **Travel direction** −x vs +x on a symmetric span | Mirror images: M and v mirror; V mirrors with a sign change; R_A ↔ R_B | Largest normalized differences ≤ 7.6e‑14; R_A,max(−x) − R_B,max(+x) = −9.3e‑13 kN; critical M difference −1.4e‑12 kN·m | ≤ 1e‑9 |
| **Fast path vs verified static engine** (2-span 12 + 15 m, two EI values, permanent UDL, nodal force and couple, permanent point load; 14 vehicle positions in both directions, including axles at nodes, on supports and off the bridge) | `analyzeVehiclePosition` = `addPointLoad` + `solveStaticModel` + `sampleInternalForces` + `evaluateDeflection` | Largest normalized differences: U 1.5e‑14, R 3.4e‑14, V(x⁻) and V(x⁺) 2.5e‑13, M 6.6e‑14, v 1.5e‑14 | ≤ 1e‑9 |
| **On-bridge policy** (spec truck, 20 m span) | x_v = 0: front axle on A, so R_A = 80 kN. x_v = 2: R_A = 72 kN. x_v = 25.6: rear axle on B, so R_B = 120 kN. x_v = 15: R_A = 138.8 kN, ΣR = 320 kN | 80, 72, 120, 138.8, 320.00000000001. U = 0 exactly when only support axles are on the bridge | ≤ 6.4e‑13 % |
| Positions and validation | Grids 0 → 25.6 m (+x, 257 positions) and 20 → −5.6 m (−x). Requested step 0.3 m becomes 25.6/86 m. A single axle runs 0 → 20 m. Invalid vehicles and options are rejected | As expected | — |

### Test-sensitivity (mutation) check — 2026-10-30, Octave 8.4.0

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Result: 26 of 26 faults detected** (7 M1 + 5 M2 + 6 M3 + 8 M4). For every mutant, `runAllTests` exited with status 1.
- **Raw output:** `results/verification/2026-10-30_M4_mutation_check_octave-8.4.0.txt`.

| M4 injected fault | Tests failed (of 74) |
|---|---|
| Only one triangular solve with the Cholesky factor | 10 |
| Axles off the bridge applied at the ends | 4 |
| Right-limit shear ignores a load at the point | 2 |
| Rear axles placed ahead of the front axle | 3 |
| Envelope minimum tracks maxima | 4 |
| Step refinement disabled | 3 |
| Axle load vector mirrored inside the element | 8 |
| Crossing stops when the front axle leaves | 2 |

### Limits of this evidence

- Numeric values in this entry come from GNU Octave. MATLAB PASS/FAIL confirmation of the same tests is in **V-008**.
- The analysis is **quasi-static**. No dynamic or impact effects, load factors, lane or multiple-presence factors, or code load models are included, so it gives no load rating.
- **Not implemented, so NOT RUN:** the materials layer (M5), GUI (M6), Stage 2 (M7), and Stages 3 and 4.

### Command for the MATLAB confirmation (V-008)

Download a ZIP of branch `claude/m4-moving-vehicle-envelopes` from GitHub (or `fetch` and `switchBranch` in MATLAB). Then, in its folder:

```matlab
restoredefaultpath
runAllTests
```

Expected last line: `Total: 74 passed, 0 failed, 74 tests`.

---

## V-008 — 2026-10-30 — Milestone M4 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer. The screenshot shows the end of the TEST SUMMARY but not its "Platform" line; `runAllTests.m` is open in the editor above. It is most likely the same R2026b installation as V-002, but this is **not confirmed** |
| Run by | The user. Claude Code has no MATLAB |
| Code version | Branch `claude/m4-moving-vehicle-envelopes` at commit `027c99a` |
| Runner | `runAllTests` (MATLAB branch, `matlab.unittest`) |
| Overall result | **74 passed, 0 failed, 74 tests** |
| Evidence | Screenshot of the end of the TEST SUMMARY: `results/verification/2026-10-30_M4_matlab_summary_screenshot.png` |

**What this entry shows**
- The visible lines show PASS for the last tests of `testShapeFunctionsAndPointLoads`, then every test in `testSimplySupportedBeam`, `testSupportsAndStability`, `testUniformLoadBeams` and **`testVehicleAndPositions`** (all 4 M4 tests in that file), then `Total: 74 passed, 0 failed, 74 tests`.
- A total of 74 means all 13 M4 tests ran and passed in MATLAB, including `testMovingLoadEnvelopes` and `testMovingLoadFastPath`. That covers the moving-load benchmarks against their 0.5 % criterion, and the check that the fast path matches the static engine to within 1e‑9.
- In particular, MATLAB's sparse Cholesky path (`chol` on K_ff, then two triangular solves) gives the same results as the static engine within the test tolerances.
- As in V-002, V-004 and V-006, the MATLAB comparison tables were not sent, so this entry records PASS/FAIL, not MATLAB's numbers.

**Status of M4:** verified in GNU Octave 8.4.0 (V-007, with numbers) and in MATLAB (V-008, pass/fail). The gate is met, so the branch is merged into `main`.

---

## V-009 — 2026-10-30 — Milestone M5 (steel and RCC material input) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | Not run in this entry. The user's MATLAB run of the same 82 tests is recorded as **V-010** |
| Code version | Branch `claude/m5-steel-rcc-materials` (code at `d4810da`, from `main` at `268b442`) |
| Command (repo root) | `octave-cli --no-gui --norc --eval "runAllTests;"` |
| Raw log | `results/verification/2026-10-30_M5_octave-8.4.0_runAllTests.log` |
| Overall result (Octave) | **82 passed, 0 failed, 82 tests.** That is 74 earlier tests plus 8 new in testMaterials. octave-cli exit status 0 |
| Regression | All 74 M1–M4 tests still pass |
| Determinism | Two consecutive runs printed identical comparison tables |
| Expected warnings | The log shows two `BridgeFE:unusualModulus` warnings. The unit-sanity test triggers them on purpose (steel E = 200 Pa, RCC E = 30 MPa) |

### Material results (Octave, all PASS)

**What is being checked.** Spec §4.4 requires that "two otherwise identical steel and RCC models with equal assigned EI must yield the same linear beam response". This checks input and solver consistency only, **not** concrete behaviour.

**Materials used.** The values make the products exact in binary:
- steel E_s = 200 GPa, I_s = 0.01 m⁴, so EI = 2×10⁹ N·m²
- RCC E_c = 32 GPa, I_eff = 0.0625 m⁴, so EI = 2×10⁹ N·m²
- RCC E_c = 32 GPa, I_eff = 0.03125 m⁴, so EI = 1×10⁹ N·m²

| Test | Reference | Actual (Octave) | Criterion |
|---|---|---|---|
| Material records | EI = E·I; type, I label (I_s / I_eff), name, basis | EI = 2×10⁹ exactly for both steel and RCC; fields as given | exact |
| **Equal-EI equivalence, static** (two spans 10 + 15 m; UDL 20 kN/m, 100 kN point load at 16.3 m, 15 kN·m nodal couple) | steel = RCC = plain-EI model | max\|U_steel − U_rcc\| = 0, max\|R_steel − R_rcc\| = 0, max\|f_steel − f_rcc\| = 0. U and R also bit-identical to the plain-EI model | `isequal` |
| **Equal-EI equivalence, moving load** (spec truck on two spans 12 + 15 m, step 0.25 m) | identical envelopes | All envelopes, reaction envelopes and critical values identical (max M = 735.9731 kN·m in both) | `isequal` |
| **Uniform EI change**, two-span 10 + 15 m with UDL (EI 2×10⁹ steel vs 1×10⁹ RCC) | indeterminate forces unchanged, deflections × 2 | U_rcc − 2U_steel: 9.3e‑14; R difference 5.5e‑14; M difference 1.1e‑13 (normalized) | ≤ 1e‑12 |
| **Mixed steel span 10 m (EI 2×10⁹) + RCC span 15 m (EI 1×10⁹)**, q = 20 kN/m | Three-moment equation with two EI values: M_B = −q(L₁³/EI₁ + L₂³/EI₂)/(8(L₁/EI₁ + L₂/EI₂)) = −484.375 kN·m; R_A = 51.5625, R_B = 330.72917, R_C = 117.70833 kN | M_B = −484.37499999999 (from both sides), R_A = 51.562500000001, R_B = 330.72916666666, R_C = 117.70833333334 kN. Change vs uniform EI = −46.875 kN·m, as predicted | ≤ 6.1e‑12 % (target 0.1 %) |
| Material bookkeeping | span 1 uses material 1 (steel), span 2 uses material 2 (RCC) | 2 materials; materialId 1 for elements 1–8, 2 for elements 9–20 | exact |
| EI-edit guard and reassignment | Editing EI directly is rejected; an identical material is reused; reassigning an element works | `BridgeFE:invalidModel` thrown; still 1 material; materialId [1 1 2 1] with EI(3) = E_c·I_eff | — |
| Unit-sanity warning | E = 200 Pa (steel) and 30 MPa (RCC) warn; 30 GPa (RCC) does not | `BridgeFE:unusualModulus` twice, none for 30 GPa; materials still created | — |
| Invalid input | Unknown type, E ≤ 0, I = 0, a record with EI ≠ E·I, element out of range | Expected error IDs | — |

### Test-sensitivity (mutation) check — 2026-10-30, Octave 8.4.0

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Result: 31 of 31 faults detected** (7 M1 + 5 M2 + 6 M3 + 8 M4 + 5 M5). For every mutant, `runAllTests` exited with status 1.
- **Raw output:** `results/verification/2026-10-30_M5_mutation_check_octave-8.4.0.txt`.

| M5 injected fault | Tests failed (of 82) |
|---|---|
| Material EI stored as E instead of E·I | 8 |
| `assignMaterial` does not update EI | 1 |
| EI-vs-material consistency check disabled | 1 |
| `createBeamModel` takes E as EI | 6 |
| Unit-sanity warning disabled | 1 |

### Limits of this evidence

- Numeric values in this entry come from GNU Octave. MATLAB PASS/FAIL confirmation of the same tests is in **V-010**.
- The equal-EI equivalence shows input and solver consistency. It says **nothing** about real RCC behaviour: there is no cracking, I_eff calculation, creep or shrinkage (spec §4.4).
- **Not implemented, so NOT RUN:** GUI (M6), Stage 2 (M7), and Stages 3 and 4.

### Command for the MATLAB confirmation (V-010)

Download a ZIP of branch `claude/m5-steel-rcc-materials` from GitHub (or `fetch` and `switchBranch` in MATLAB). Then, in its folder:

```matlab
restoredefaultpath
runAllTests
```

Expected last line: `Total: 82 passed, 0 failed, 82 tests`. Two yellow `BridgeFE:unusualModulus` warnings are expected; the unit-sanity test triggers them on purpose.

---

## V-010 — 2026-10-30 — Milestone M5 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer. The screenshot shows the end of the TEST SUMMARY but not its "Platform" line. It is most likely the same R2026b installation as V-002, but this is **not confirmed** |
| Run by | The user. Claude Code has no MATLAB |
| Code version | Branch `claude/m5-steel-rcc-materials` at commit `b2fb7e3` (code identical to `d4810da`) |
| Runner | `runAllTests` (MATLAB branch, `matlab.unittest`) |
| Overall result | **82 passed, 0 failed, 82 tests** |
| Evidence | Screenshot of the end of the TEST SUMMARY: `results/verification/2026-10-30_M5_matlab_summary_screenshot.png` |

**What this entry shows**
- The visible lines show PASS for the end of `testSimplySupportedBeam`, then `testSupportsAndStability`, `testUniformLoadBeams` and `testVehicleAndPositions`, then `Total: 82 passed, 0 failed, 82 tests`.
- A total of 82 means all 8 M5 tests in `testMaterials` ran and passed in MATLAB. That includes the bit-identical equal-EI steel/RCC check and the mixed steel/RCC three-moment check.
- The two intentional `BridgeFE:unusualModulus` warnings are above the visible part, so they are not in the screenshot.
- As in V-002 to V-008, MATLAB's numeric tables were not sent, so this entry records PASS/FAIL, not MATLAB's numbers.

**Status of M5:** verified in GNU Octave 8.4.0 (V-009, with numbers) and in MATLAB (V-010, pass/fail). The gate is met, so the branch is merged into `main`.

---

## V-011 — 2026-10-30 — Milestone M6 (code-built MATLAB app) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0** (`octave-cli`), Linux 6.18 x86_64, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The app has **not** been opened in MATLAB. Its rendering, layout and appearance are **not verified**. The user needs to run it; record the result as V-012 |
| Code version | Branch `claude/m6-basic-gui` (code at `7633fac`, from `main` at `301abf6`) |
| Main suite | `octave-cli --no-gui --norc --eval "runAllTests;"` gives **95 passed, 0 failed, 95 tests**: 82 earlier plus 13 new (testGuiHelpers 9, testDrawingGeometry 4). Raw log: `results/verification/2026-10-30_M6_octave-8.4.0_runAllTests.log` |
| App check (stand-in components) | `octave-cli --no-gui --norc --eval "addpath('tools/gui_mock'); runGuiMockCheck(true)"` gives **27 of 27 checks PASS**. Raw log: `results/verification/2026-10-30_M6_octave-8.4.0_app_check_with_stand-ins.log` |
| Drawing previews | `tools/preview` renders the same drawing coordinates with matplotlib (not MATLAB): `results/verification/2026-10-30_M6_drawing_previews_matplotlib/*.png` (4 cases) |

### Why the GUI could only be checked indirectly here (DECISIONS.md D-024)

- MATLAB is not installed in this container.
- Octave has no App Designer components.
- Octave figure rendering fails here with a FreeType "invalid bounding box" error. It persisted with the gnuplot and Qt toolkits, under Xvfb, and with the font set restricted to DejaVu.

The GUI was therefore checked in three layers:

1. **Helper tests in the main suite.** These also run in MATLAB.
2. **The scripted app check against stand-in components.** The stand-ins reject unknown properties, Layout set outside a grid, invalid colours, out-of-range values, non-increasing axis limits and mismatched legend calls.
3. **matplotlib previews** of the drawing data.

None of these shows what MATLAB actually displays.

### New main-suite tests (Octave, all PASS)

| Test | What is checked | Key result |
|---|---|---|
| testGuiHelpers: number parsing | '20 20', '80, 120,120', ' 4.2;1.4 ', exponents; rejects '', 'abc', 'Inf', '2i' and 'exit' (no code is evaluated) | Exact |
| testGuiHelpers: model from app inputs | Inputs (2 × 20 m spans, 16 elements per span, pin/roller/roller, steel 200 GPa / 0.01 m⁴, 20 kN/m) give a model `isequal` to one built directly with the engine. Benchmark D: M_B = −qL²/8 = −1000 kN·m, R_B = 500 kN | M_B and R_B within 0.5 % (round-off) |
| testGuiHelpers: support entries, RCC, unit warning | 'free FIXED' builds a cantilever fixed at the right end; RCC E_c = 32 GPa, I_eff = 0.0625 m⁴ gives EI = 2e9; E = 200e9 typed in the GPa field is reported as a warning | Exact |
| testGuiHelpers: invalid inputs | Wrong number of support entries, 'hinge', 'none none none', 'pin none', negative load, E = 0, fractional element count | Expected error IDs, including `BridgeFE:underRestrained` |
| testGuiHelpers: vehicle from inputs | '80 120 120' kN with '4.2 1.4' m equals `createVehicle([80e3 120e3 120e3], [4.2 1.4])`; single axle; invalid vehicles rejected | `isequal` |
| testGuiHelpers: Matrices-tab path | `modelWithVehicle` + `solveStaticModel` against `analyzeVehiclePosition` at 6 positions, including partly on the bridge | Largest normalized U/R difference ≤ 1e‑9 |
| testGuiHelpers: diagram data | Two rows (x⁻, x⁺) per point, sorted; jump under the 120 kN axle at 12.2 m | ΔV = −120 kN |
| testGuiHelpers: tables, labels, theme | Critical table 6 × 7 in kN·m and mm; reaction envelope with a couple row for the fixed support; current reactions add up to 320 kN; DOF labels; formatted cells; 17 theme colours are valid RGB | Exact |
| testDrawingGeometry: symbols | Pin triangle with its apex at the node, base at −h, ground line plus 6 hatch strokes. Roller wheels touch the ground line. Fixed-wall hatching lies outside the beam at both ends. 'none' draws nothing | Exact coordinates |
| testDrawingGeometry: loads and labels | Beam along y = 0; 'q = 20 kN/m', '100 kN' and '30 kN*m (CCW)' labels; at least 5 uniform-load arrowheads; point-load arrowhead at 7.3 m pointing down; 9 node and 8 element labels | Present |
| testDrawingGeometry: vehicle and deformed shape | Front axle on the bridge is solid blue; 2 axles off the bridge are dotted grey; the deformed shape is dashed with v × 50 | Exact |
| testDrawingGeometry: limits | Axis limits contain every primitive and leave room above bottom-aligned labels | Holds |

### Scripted app check against stand-in components (Octave, 27/27 PASS)

`tests/gui/checkBridgeConditionApp(true)` drives `BridgeConditionApp` like a user and compares it with direct engine calls. The same file is meant for the user's MATLAB run.

- **Start-up:** the model and vehicle are `isequal` to the engine built from the default inputs; x_v = 0; the model drawing is present.
- **Model input:** 2 spans 12 + 15 m, RCC 32 GPa / 0.0625 m⁴, 10 kN/m. The app's model is `isequal` to `buildModelFromInputs`, and the summary text is shown.
- **Vehicle position x_v = 16.4 m:** U and R are identical to `analyzeVehiclePosition` (difference 0); the reaction table shows the engine's R_B; the beam, M, V and v axes are drawn; Forward moves x_v by exactly one step (0.1 m).
- **Envelopes:** the app's envelopes and critical values are `isequal` to `runMovingLoad`; the tables are 6 × 7 and 3 rows; all three envelope axes are drawn.
- **Matrices:** U is identical to `solveStaticModel(modelWithVehicle(...))`; k_e is 4 × 4; K and the DOF table are nDof wide/long; K(1,1) text equals the engine's value.
- **Travel direction:** −x gives Direction = −1 with the start at the right end (27 m).
- **Invalid input:** 2 support entries for 3 span ends is rejected with a message and the previous model kept; axle loads '80 abc' are rejected with a message naming 'abc'.
- **Unit slip:** E = 32e9 typed in the GPa field builds the model and reports one unit warning.
- **Callbacks:** all 19 (buttons, edit fields, check box, drop-downs, slider changing/changed, spinner, every tab) ran without error.
- **Verification tab:** "Run all tests" inside the app reports `0 failed`.

### Drawing previews (matplotlib rendering of the app's drawing data; not MATLAB screenshots)

Checked by eye on 2026-10-30:

- **A, simple span:** pin triangle on hatched ground, roller on two wheels.
- **C, propped cantilever:** fixed wall hatched on the outside (left) and a row of uniform-load arrows. The first rendering clipped the labels, which was fixed by reserving label room in `drawingLimits`.
- **D, two spans with a truck:** blue axles under the truck body with the cab leading; the dashed deformed shape matches the v diagram.
  - Static checks: M drops by the applied 50 kN·m CCW couple, as M = ΣF(x − x_i) − ΣC predicts; V jumps by each axle load and by R_B; hogging is largest over the support.
- **E, cantilever fixed at the right end, truck entering:** wall hatched on the outside (right); axles not yet on the bridge are dotted grey.
  - Static checks: M = −80 kN × 9 m = −720 kN·m at the wall; V = −80 kN.

### Test-sensitivity (mutation) check — 2026-10-30, Octave 8.4.0

- **Full run:** 38 single-fault mutants (7 M1 + 5 M2 + 6 M3 + 8 M4 + 5 M5 + 7 M6). Raw output: `results/verification/2026-10-30_M6_mutation_check_octave-8.4.0.txt`.
- **One equivalent mutant.** "M6: diagram rows not sorted" (`sortrows(rows, 1)` instead of `[1 2]`) was **not detected because it changes nothing**: `sortrows` is stable and the rows are built with every left limit first. It was replaced by "right limit listed before left limit" (`sortrows(rows, [1 -2])`), which a separate run shows is **detected**.
- **Result:** all 38 real faults detected, i.e. 37 in the full run plus the replacement.

| M6 injected fault | Tests failed (of 95) |
|---|---|
| GPa input converted with 1e6 instead of 1e9 | 2 |
| Uniform load entered upward | 1 |
| Axle loads in kN not converted to N | 1 |
| Right limit listed before left limit in diagram data (replacement) | 1 |
| Fixed-wall hatching drawn inside the beam | 1 |
| No label room in drawing limits | 1 |
| Critical table shows N·m instead of kN·m | 1 |
| *(equivalent, replaced)* Diagram rows sorted by x only | 0 (no behaviour change) |

### Limits of this evidence

- **No MATLAB run.** The app's actual rendering, layout, fonts, colours, slider feel and dialogs have not been seen.
- **Faults in the app file itself are not mutation-tested.** The mutants cover the helpers. Instead, the app is checked by the scripted app check, both against stand-ins here and for real in MATLAB.
- **Not implemented, so NOT RUN:** Stage 2 (M7), Stages 3 and 4.

### Commands for the MATLAB confirmation (V-012)

Download a ZIP of branch `claude/m6-basic-gui` from GitHub (or `fetch` and `switchBranch` in MATLAB). Then, in its folder:

```matlab
restoredefaultpath
addProjectPaths
runAllTests                      % expected: Total: 95 passed, 0 failed, 95 tests
checkBridgeConditionApp(true)    % expected: every row PASS (27 rows)
app = BridgeConditionApp;        % then screenshot each of the five tabs
```

---

## V-012 (partial) — 2026-11-03 — Milestone M6 in MATLAB, first run (by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer; the Platform line is not visible in the screenshots |
| Code version | Branch `claude/m6-basic-gui` at `d7bf935`, downloaded as a ZIP |
| `runAllTests` | **95 passed, 0 failed, 95 tests.** Evidence: `results/verification/2026-11-03_M6_matlab_runAllTests_summary_screenshot.png` |
| `checkBridgeConditionApp(true)` | **26 of 27 PASS, 1 FAIL.** Evidence: `results/verification/2026-11-03_M6_matlab_app_check_first_run_screenshot.png` |

**The failing check:** "M, V and v envelope axes are drawn" required at least 4 objects in each envelope axes' `Children`.

**Cause:** a mistake in the check, not in the app. `plotEnvelope` gives the shaded band, zero line and critical markers `HandleVisibility 'off'`, so the legend only lists the max and min curves. MATLAB excludes such objects from `Children`, so only the 2 curves are counted. The Octave stand-ins count every object, which is why V-011 passed.

**Visible in the screenshot:** the later checks also passed, including all 19 callbacks running without error and "Run all tests" inside the app reporting 0 failed.

**Fix (commit after `d7bf935`):** the check now requires the 2 visible curves on each envelope axes. It still passes against the Octave stand-ins.

**Still to do:** re-run `checkBridgeConditionApp(true)` in MATLAB on the fixed branch, and take screenshots of the app tabs.

### V-012 (continued) — 2026-11-04 — app check re-run in MATLAB after the fix

| Item | Value |
|---|---|
| Code version | Branch `claude/m6-basic-gui` at `1f82f3b` (check counts the 2 visible envelope curves) |
| `checkBridgeConditionApp(true)` | **27 of 27 PASS.** The visible rows (Forward step through Verification tab) all show PASS, and the function returned normally (it throws on any failure). MATLAB then printed `ans = 1x27 struct array`. Evidence: `results/verification/2026-11-04_M6_matlab_app_check_27_of_27_screenshot.png` |

**What this run confirms in MATLAB:**
- The app's model, vehicle position, envelopes and matrices equal direct engine calls; the U and R differences are 0.
- Invalid input is rejected with a message.
- All 19 callbacks run.
- "Run all tests" inside the app reports 0 failed.

**Still open:** the visual check (screenshots of the five tabs).

**Small follow-up change:** `checkBridgeConditionApp` no longer echoes `ans` when called as a command.

### V-012 (continued) — 2026-11-05 — the five app tabs in MATLAB (screenshots by the user)

**Evidence:** `results/verification/2026-11-05_M6_matlab_app_tab1_bridge_model.webp` … `tab5_verification.webp`, from code version `1056c3d`.

**Values on screen checked against earlier recorded results:**

| Tab | What is shown | Check |
|---|---|---|
| Bridge model | 20 m span, 16 elements, pin at 0 and roller at 20 m drawn with conventional symbols (pin triangle on hatched ground, roller triangle on two wheels); summary: 17 nodes, 34 DOFs, EI = 2e9 N·m² | Matches the inputs |
| Vehicle & moving load | Spec truck at x_v = 14.208 m, all 3 axles on the bridge; reactions 151.472 + 168.528 kN | Sum = 320 kN = truck weight. M peaks under the middle axle; V steps at each axle; v is negative (down) |
| Envelopes | Max M = 1349.102 kN·m at x = 9.740 m for x_v = 13.940 m; V max 289.040 kN, V min −261.040 kN; v min −24.925 mm at 10 m (x_v 13.790); R_A,max 289.200 kN at x_v 5.6 m; R_B,max 261.200 kN at x_v 20 m; 257 positions + 125 refined | **Identical** to the Octave smoke run and V-007 (1349.1024 kN·m exact 1349.1025; R 289.2 / 261.2) |
| Matrices | k_e of element 1 (L_e = 1.25 m): 12EI/L³ = 1.2288e10, 6EI/L² = 7.68e9, 4EI/L = 6.4e9, 2EI/L = 3.2e9; θ labels show correctly; K assembled with 2.458e10 at shared v DOFs; DOF table: 32 free, 2 restrained, R_v1 = 151472 N | Hand values for EI = 2e9 and L_e = 1.25 m are correct |
| Verification | "Run all tests" output, with the status bar showing **Total: 95 passed, 0 failed, 95 tests** | — |

**Layout problems seen in the screenshots, fixed in the next commit:**
1. The Vehicle-tab beam drawing was small. It keeps a 1:1 true scale, and its row was only 210 px; the row is now 300 px and the input column is wider.
2. Table headers were cut off; the reaction, critical and reaction-envelope tables now use `ColumnWidth 'fit'`.
3. The Envelopes table column was too narrow at 520 px; it is now 660 px.

These are layout-only changes. The scripted app check still passes against the stand-ins. **The new layout has not yet been seen in MATLAB.**

**Status of M6:**
- Function verified in MATLAB: runAllTests 95/95; app check 27/27; all five tabs working and showing engine-consistent values.
- Merged into `main`.
- Layout tweaks pending a visual glance.

---

## V-013 — 2026-11-05 — Milestone M7 (Stage 2 prescribed stiffness loss) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The user needs to run it; record the result as V-014 |
| Code version | Branch `claude/m7-stiffness-damage` |
| Main suite | **104 passed, 0 failed, 104 tests.** That is 95 earlier plus 9 in testStiffnessDamage. Raw log: `results/verification/2026-11-05_M7_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | Still 26/26 PASS (without the in-app test run) after the app's Matrices tab switched to `effectiveEI` |

Notation: EI = 2e9 N·m², g = d/(1 − d). Results are copied from the log.

| Test | Closed-form reference | Actual (Octave) | Error |
|---|---|---|---|
| d = 0 identity | Model and solution unchanged; re-applying d = 0 restores the model | `isequal` true | exact |
| Locality | K_D − K_H = −d·A₃ᵀk₃A₃ (d = 0.35, element 3 of 5); EI_eff = 0.65·EI only there; material EI unchanged | Normalized residual ≤ 1e‑14 | round-off |
| Simple span 20 m, P = 100 kN at midspan, d = 0.3 on 3–7 m | Reactions and moments unchanged; δ_mid = PL³/48EI + g·P(b³−a³)/(12EI) = 8.897619 mm | ΔR/P = 1.9e‑12, ΔM ≈ 2.3e‑12 (normalized); δ_mid = 8.8976190476 mm; increase 0.56428571 mm | 1.8e‑10 % |
| Propped cantilever 10 m, q = 20 kN/m, R_B = (q/2)·I3/I2 | d = 0.5 on 0–2 m: R_B = 80.16129 kN, M_A = −198.38710 kN·m. d = 0.5 on 6–8 m: R_B = 72.72727 kN, M_A = −272.72727 kN·m. d = 0.2 on 3–5 m: R_B = 74.28165 kN. Healthy: 3qL/8 = 75 kN | 80.161290322591, −198.38709677423, 72.727272727318, −272.72727272741, 74.281650071137, 74.999999999991 | ≤ 1e‑10 % |
| Spans 10 + 15 m, q = 20 kN/m, span 1 d = 0.3 | M_B = −q(L₁³/EI₁ + L₂³/EI₂)/(8(L₁/EI₁ + L₂/EI₂)) = −410.06098 kN·m; change vs healthy +27.43902 kN·m; R_A = 58.99390 kN | −410.06097560972, +27.439024390306, 58.993902439027 | ≤ 2.3e‑10 % |
| Healthy vs damaged, spec truck | Simple span: reactions and Mmax unchanged; deflection more downward. Continuous: R_B and M_B redistribute | Simple span: \|ΔR\| ≤ 3.7e‑12 kN, Mmax 1349.040 → 1349.040; vmin −24.925 → −30.837 mm (−23.72 %, i.e. larger downward); Mmin % = NaN (zero healthy value). Continuous 12 + 15 m, d = 0.4 on 6–12 m: M_B min −467.767 → −371.462 kN·m (+20.59 %); R_B max 311.297 → 308.957 kN | consistent with direct `runMovingLoad` to 1e‑10 % |
| Damaged fast path | `analyzeVehiclePosition` = static engine with axles inside the damaged elements | Largest normalized U and v difference 1.07e‑13 | round-off |
| Sensitivity, d = 0.3 moved over 8 elements, 100 kN single load, 20 m span | Middle elements most influential; symmetric; determinate forces unchanged | vmin per element [mm]: −8.361, −8.529, −8.880, −9.403, −9.403, −8.880, −8.529, −8.361 (healthy −8.333); ranking 5, 4, 6, 3, 7, 2, 1, 8; Mmax and R_A changes ≤ 1e‑11 | exact symmetry to 4e‑14 |
| Invalid input; material reassignment | d = 1, d < 0, element out of range, wrong count, factor 0; RCC reassignment keeps a 25 % loss | Expected errors; EI_eff = 1.5e9 | — |

### Test-sensitivity (mutation) check

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir>`.
- **Result: 43 of 43 faults detected.** Raw output: `results/verification/2026-11-05_M7_mutation_check_octave-8.4.0.txt`.
- **A gap found and closed.** In a first run of the 5 M7 mutants, "fast path uses the material EI" was **not** detected: no test compared the moving-load fast path with the static engine on a damaged model. The test "Moving-load fast path equals the static engine on a damaged model" was added, and the mutant is now detected.

| M7 injected fault | Tests failed (of 104) |
|---|---|
| `effectiveEI` ignores the stiffness factor | 7 |
| Damage factor 1/(1+d) instead of 1−d | 5 |
| Moving-load fast path uses the material EI | 1 (after the new test) |
| Force recovery uses the material EI | 2 |
| Zero healthy reference not excluded from percentages | 1 |

### Limits of this evidence

- These results are from **GNU Octave only**; MATLAB has not been run.
- **No GUI support for damage yet** (optional M7b).
- d is a loss of model EI in an equivalent-beam segment. It is not a measure of real damage, corrosion or capacity.

---

## V-014 — 2026-11-10 — Milestone M7 in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer; the Platform line is not in the screenshot |
| Code version | Branch `claude/m7-stiffness-damage` at `7608eed` |
| Result | **104 passed, 0 failed, 104 tests**, including the 9 Stage 2 tests in `testStiffnessDamage` |
| Evidence | Screenshot of the end of the TEST SUMMARY, shared by the user in the conversation on 2026-11-10. The image was not available as a file in the session, so it is not stored in `results/verification/` |

**Status of M7:** verified in GNU Octave (V-013, with numbers) and in MATLAB (V-014, pass/fail). Merged into `main`.

---

## V-015 — 2026-11-10 — Milestone M7b (Damage tab) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The user needs to run `runAllTests`, `checkBridgeConditionApp(true)` and open the Damage tab; record the result as V-016 |
| Code version | Branch `claude/m7b-damage-tab` |
| Main suite | **106 passed, 0 failed, 106 tests** (104 earlier plus "Damage-tab inputs and tables match the Stage 2 engine" in `testGuiHelpers` and "Damaged elements are overdrawn in the damage colour with their EI factor" in `testDrawingGeometry`). Raw log: `results/verification/2026-11-10_M7b_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **32/32 PASS** (26 earlier rows unchanged, 6 new Damage-tab rows; 23 callbacks invoked without error). Raw log: `results/verification/2026-11-10_M7b_octave-8.4.0_gui_mock_check.log` |

New app-check rows (two-span 12 + 15 m RCC model, region 9–13.875 m, d = 40 %, spec truck):

| Row | Reference | Result |
|---|---|---|
| Apply damage | `applyStiffnessDamage(refModel, elementsBetween(refModel, 9, 13.875), 0.40)`; healthy model unchanged | `isequal` true — PASS |
| Drawing highlight | more graphics objects than the healthy drawing | PASS |
| Compare | `compareHealthyDamaged` with the same step and direction: critical damaged values and damaged envelopes | `isequal` true — PASS |
| Comparison table and axes | 6 extremes + 2 × 3 reaction rows = 12; M and v axes show 4 curves | PASS |
| Sensitivity (vmin) | `damageSensitivity(..., 0.40, 'vmin', 'Step', 0.5, 'Refine', false)` | `isequal(change)` true; one table row per element — PASS |
| Clear damage | no damaged model, tables empty, healthy model unchanged | PASS |

### Test-sensitivity (mutation) check

- **Command:** `python3 -I tools/mutation_check.py <repo> <scratch_dir> 'M7b:'` (new optional name filter; the 43 earlier mutants were not rerun because no engine file changed).
- **Result: 7 of 7 M7b faults detected**, each by the new `testGuiHelpers` or `testDrawingGeometry` test. Raw output: `results/verification/2026-11-10_M7b_mutation_check_octave-8.4.0.txt`.
- **Two adjustments, recorded honestly:**
  - "100 % loss accepted" (`>= 100` → `> 100` in `damageModelFromInputs`) survived because it is an **equivalent mutant**: `applyStiffnessDamage` rejects d ≥ 1 anyway. It was replaced by "summary names the wrong last element".
  - "Drawing merges runs with different factors" survived at first: the drawing test used two separate damaged runs. The test now uses two **adjacent** runs with different factors (0.70 and 0.50), and the mutant is detected. No reference value was changed.

### Limits of this evidence

- GNU Octave only, with stand-in UI components. How MATLAB lays out and renders the Damage tab is **NOT VERIFIED IN MATLAB**.
- d is a loss of model EI in an equivalent-beam segment; the tab says so. It is not a measure of real damage, corrosion or capacity.

---

## V-016 — 2026-11-10 — Milestone M7b in MATLAB (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer; the Platform line is not in the screenshots |
| Code version | Branch `claude/m7b-damage-tab` at `33c4f03` |
| Main suite | **106 passed, 0 failed, 106 tests**. Screenshot: `results/verification/2026-11-10_M7b_matlab_runAllTests_summary.png` |
| App check | `checkBridgeConditionApp(true)`: **33 of 33 rows PASS**, including the 6 Damage-tab rows, "24 callbacks invoked without error" (24 in MATLAB because the in-app "Run all tests" button is included) and "Verification tab: test suite reports 0 failed". Screenshot: `results/verification/2026-11-10_M7b_matlab_checkBridgeConditionApp.png` |
| Damage tab, used by the user | 20 m simple span, spec truck, elements 7–10 (7.5–12.5 m), d = 30 %. Screenshots: `..._M7b_matlab_damage_tab_compare.png` (normal window) and `..._M7b_matlab_damage_tab_maximized_sensitivity.webp` (maximized, after the sensitivity run) |

Values shown in the Damage tab (MATLAB):

| Quantity | Healthy | Damaged | Change |
|---|---|---|---|
| M max [kN·m] | 1349.102 | 1349.102 | 0 (−0.000 printed) |
| V max / V min [kN] | 289.040 / −261.040 | 289.040 / −261.040 | 0 |
| v min [mm] | −24.925 | −30.839 | −5.914 (−23.73 %, larger downward) |
| R at node 1 max / node 17 max [kN] | 289.200 / 261.200 | 289.200 / 261.200 | 0 |
| Sensitivity, vmin, d = 30 % per element | — | most influential: element 8 (8.75–10 m) −1.6939 mm, element 9 −1.5881 mm, element 7 −1.4099 mm | — |

- These agree with V-013 (Octave): there, the same truck on the same span gave vmin −24.925 → −30.837 mm (−23.72 %) for a 30 % loss on 8–10 m; here the region is 7.5–12.5 m, so the numbers differ slightly, as expected.
- **Unchanged forces are correct, not a fault.** A simple span is statically determinate: its reactions, shears and moments follow from equilibrium alone and do not depend on EI. Only deflections change (spec §6; D-025; test "Simply supported beam: damage changes deflection only").
- **Display findings** from these screenshots (fixed in M7c, D-027): the healthy curves are hidden under identical damaged curves; titles are cut off in the normal window; the sensitivity chart and table are small and show `1 2 3 4 5 6` column headings before the first run; round-off zeros are printed as `−0.000` and `−0.00 %`; the `EI x 0.70` label is small.

**Status of M7b:** verified in GNU Octave (V-015) and in MATLAB (V-016). Merged into `main`.

---

## V-017 — 2026-11-10 — M7c (Damage-tab display revisions, D-027) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** One MATLAB run on branch `claude/s3-inverse-search` (which contains M7c) will cover M7c and S3; record it as V-019 |
| Code version | Branch `claude/m7c-damage-visuals` |
| Main suite | **107 passed, 0 failed, 107 tests** (new: "Table numbers never show a negative zero, and the findings name the determinacy"). Raw log: `results/verification/2026-11-10_M7c_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **33/33 PASS**: the comparison row now also requires 4 curves on the new shear axes, and a new row checks that the findings equal `damageComparisonSummary` (two-span model: "degree 1") and that each run selects its result sub-tab. Raw log: `..._M7c_octave-8.4.0_gui_mock_check.log` |
| Mutation check | `tools/mutation_check.py <repo> <scratch> M7`: **15 of 15** Stage 2 mutants detected (5 M7, 7 M7b, 3 new M7c). The M7b "percentage loses its sign" mutant now targets the `formatNumber` call that replaced `sprintf`. Raw output: `..._M7c_mutation_check_octave-8.4.0.txt` |

The user's V-016 case recomputed in Octave (20 m simple span, 16 elements, elements 7–10, d = 30 %, spec truck, step 0.1 m): v min −24.925 → −30.839 mm, change −5.914 mm, −23.73 %. **Same as the MATLAB screenshot.** Moment, shear and reaction changes now display as `0.000` / `0.00` instead of `−0.000` / `−0.00`. Findings: "Statically determinate beam … Only deflections change."; "Largest change of an extreme: Deflection v min, −24.925 -> −30.839 mm (−23.73 %, larger magnitude)."; "Vertical reactions: unchanged (to 0.001 kN)."

**Limits:** the layout and look of the sub-tabs are **NOT VERIFIED IN MATLAB**.

---

## V-018 — 2026-11-10 — Stage 3 single-region inverse search (engine) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** Record the user's run on branch `claude/s3-inverse-search` as V-019 |
| Code version | Branch `claude/s3-inverse-search` (M7c + Stage 3 engine, D-028) |
| Main suite | **115 passed, 0 failed, 115 tests** (107 + 8 in `testInverseDamage`). Raw log: `results/verification/2026-11-10_S3_octave-8.4.0_runAllTests.log` |
| Mutation check | `tools/mutation_check.py <repo> <scratch> S3:` — **7 of 7** Stage 3 faults detected. Raw output: `results/verification/2026-11-10_S3_mutation_check_octave-8.4.0.txt` |

All observations are **synthetic** (generated by the forward model from a hidden case). Recovering them is algorithm verification, **not field validation**; no field data exist.

Setup unless stated: 20 m simple span, 20 elements of 1 m, EI = 2e9 N·m², spec 3-axle truck, sensors at 5, 10, 15 m, front axle at 5, 10, 15, 20, 25 m (15 readings).

| Test | Reference / criterion | Result (Octave) |
|---|---|---|
| Sensor deflection, 100 kN at midspan | v(x) = −Px(3L² − 4x²)/(48EI): −3.0598958, −5.7291667, −7.5040958 (x = 7.3 m, between nodes), −8.3333333 mm | errors ≤ 2.7e‑11 % |
| Vehicle-only deflection with damage, a permanent UDL, travel −x, sensors between nodes | = static engine (total − permanent) | ≤ 1e‑12 relative |
| Blind noise-free cases (element, d hidden from the search) | E7 30 %, E3 45 %, E15 20 %, E12 27 % (between 5 % steps), E19 55 % | all 5 recovered exactly (J = 0), unique, 265 structures each |
| Undamaged data | best = healthy, d = 0 | yes; coarse scan = **241** structures (240 + 1, spec §7) |
| Data from a 40-element mesh (6–7 m at 30 %) | E7 at 30 % on the 20-element mesh | yes, J at round-off |
| 3 of 15 readings missing (NaN) | E7 at 30 % with m = 12 | yes |
| One sensor and one load, both at midspan | mirror elements E7 and E14 tie | both reported, ratio 1.000000, two regions |
| True loss 70 % (beyond the 60 % limit) | best d = 60 % and `boundaryFlag` | yes; best element E9, not E7: the location is not reliable beyond the limit |
| E7 30 %, proportional noise, **seed 7 only** | true 6–7 m inside the reported region | 1 %: best E8, d 0.31, region 6–8 m; 2 %: E8, 0.34, 6–10 m; 5 %: E9, 0.40, 6–13 m; 10 %: E10, 0.48, 5–14 m — inside every time |

### Noise study (not a pass/fail test) — SUPERSEDED, see D-029 and V-019

> **Superseded (2026-11-11).** An independent review found that `deterministicNormal` used the seed directly as the generator state, so seeds 1..10 gave almost the same first noise values: the rows below are **not** over independent noise draws. The seed is now hashed (D-029); the study was repeated with 20 independent seeds in V-019. The rows are kept unchanged as a record of what was run.

`tools/inverseNoiseStudy.m`, 10 noise seeds per row, spec layout, default options. Raw output: `results/verification/2026-11-10_S3_noise_study_octave-8.4.0.txt`.

| True | Noise | Best = true | Best within ±1 element | True inside region | Healthy competes | Mean region width |
|---|---|---|---|---|---|---|
| E7, 30 % | 1 % | 3/10 | 7/10 | 7/10 | 0/10 | 2.4 m |
| E7, 30 % | 2 % | 1/10 | 6/10 | 5/10 | 0/10 | 4.3 m |
| E7, 30 % | 5 % | 0/10 | 1/10 | 6/10 | 1/10 | 10.0 m |
| E3, 45 % | 1 % | 3/10 | 4/10 | 5/10 | 0/10 | 5.0 m |
| E3, 45 % | 2 % | 3/10 | 3/10 | 6/10 | 2/10 | 11.2 m |
| E3, 45 % | 5 % | 0/10 | 1/10 | 6/10 | 4/10 | 13.4 m |
| E15, 20 % | 1 % | 1/10 | 6/10 | 7/10 | 0/10 | 4.4 m |
| E15, 20 % | 2 % | 1/10 | 3/10 | 8/10 | 1/10 | 8.4 m |
| E15, 20 % | 5 % | 1/10 | 3/10 | 8/10 | 3/10 | 12.1 m |

**Interpretation, stated plainly:**
- Without noise the search is exact. With the spec layout (3 sensors × 5 positions) and **1 m** candidate regions, even 1 % noise makes single-element localization unreliable: the exact element was found in only 1–3 of 10 seeds.
- The region "fit within 10 % of the best" contained the truth in only 5–8 of 10 seeds. It is **not** a confidence region, and must not be presented as one.
- Example of a miss (seed 7, `..._S3_layout_comparison_seed7_...txt`): true E3 at 45 % with 2 % noise gave best E8 and region 4–12 m, which does not include 2–3 m.
- More sensors and positions (7 × 9) changed individual results but, with one seed each, did not show a clear improvement; that needs the same study.
- Possible improvements, not yet implemented: larger candidate regions (e.g. 2–4 m groups, already supported by `'Groups'`); more readings; a region based on the stated noise level (likelihood-ratio / χ² region) instead of the 10 % fit ratio.

---

## V-019 — 2026-11-11 — S3b (noise-based region, fit check, region size; D-029) in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** One MATLAB run on branch `claude/s3b-noise-region` covers M7c, S3 and S3b; record it as V-020 |
| Code version | Branch `claude/s3b-noise-region`, commit `8791c8d` (study and suite); records added afterwards |
| Main suite | **129 passed, 0 failed, 129 tests** (115 + 14 in `testInverseUncertainty`). Raw log: `results/verification/2026-11-11_S3b_octave-8.4.0_runAllTests.log` |
| Independent review | Multi-agent workflow: 4 reviewers (statistics, code/compatibility, tests, spec), and a skeptic tried to refute each medium/high finding (16 agents). All confirmed findings and all low findings were fixed; the changes are listed in D-029. Two "high" findings were refuted only because they had already been fixed in the working tree when the skeptic checked; the skeptic confirmed the fixes |
| Mutation check | `MUTANT_SHARD=k/3 python3 -I tools/mutation_check.py <repo> <scratch> S3 'testInverse*.m'` (3 parallel shards; only the Stage 3 test files run, since `src/inverse` is used nowhere else): **21 of 21** Stage 3 faults detected (7 S3 + 14 S3b). Raw output: `results/verification/2026-11-11_S3b_mutation_check_octave-8.4.0.txt` |

Key test results (synthetic data, spec layout unless stated):

| Test | Reference / criterion | Result |
|---|---|---|
| χ² quantiles | tables: 3.841459, 7.814728, 18.307038, 22.362032, 43.772972; exact −2 ln(1 − p) for 2 dof | ≤ 4.7e‑6 % (tables, 7 digits); 2.1e‑12 % (exact) |
| Seed hash | lowbias32 = independent Python implementation (0, 1, 2, 3, 7, 123456789, 2³² − 1) | identical |
| Seeds 1–2000, first number | independent draws | mean 0.014, std 0.999, neighbouring-seed correlation −0.007 |
| Constant σ | S = m·J²/σ² for every structure; minimum S = minimum RMSE | yes (all 381 structures) |
| σ with both parts | sqrt((0.02·\|u_healthy\|)² + (0.02 mm)²) | ≤ 1e‑15 m |
| Loss between grid points (E7 at 27.4 %, noise-free, stated 0.1 %) | no false misfit | S = 4.73 at the best 1 % point; vertex d = 0.2739, S = 0.0016; no misfit |
| Region vs exhaustive 1 % scan (1200 structures) | same groups and same best S | identical |
| Wrong supports (data from fixed–roller, model pin–roller, 1 % noise) | `modelMisfit` | S = 60 022 against a limit of 25.0, flagged; correct supports not flagged |
| 2 m regions, hidden 6–8 m at 30 % | exact recovery | yes, 206 structures |
| Region reaching 60 % (E7 at 55 %, stated 5 %) | `regionAtSearchLimit` | d range [0.45 0.60], flagged, best d 0.55 not at the limit |
| 90 % confidence; 3 readings missing | χ²(0.90, 2) = −2 ln 0.1, χ²(0.90, 13) = 19.812; m = 12, dof 10, χ²(0.95, 10) = 18.307 | yes; the 90 % region (11 groups) lies inside the 95 % region (12) |
| RCC baseline | warning `BridgeFE:rccInverse`, `rccBaseline` | yes |

### Coverage study (not a pass/fail test)

`tools/inverseNoiseStudy.m`, **20 independent noise seeds** per row, spec layout (3 sensors × 5 truck positions, 1 m elements), proportional noise, the true noise level stated to the χ² methods. Raw output: `results/verification/2026-11-11_S3b_coverage_study_octave-8.4.0.txt` (the 1–2 % and 5 % rows came from two runs, because a container restart stopped the first). "Covered" means the true element lies in the reported region; for the undamaged case it means "no damage" stays in the region.

| True | Noise | 10 % ratio, 1 m: covered | χ², 1 m: covered | χ², 2 m: covered | Best right (ratio / χ² 1 m / χ² 2 m) | Mean width, χ² 1 m |
|---|---|---|---|---|---|---|
| E7, 30 % | 1 % | 18/20 | **20/20** | 20/20 | 11 / 18 / 19 | 3.5 m |
| E7, 30 % | 2 % | 16/20 | **20/20** | 20/20 | 8 / 12 / 13 | 7.7 m |
| E7, 30 % | 5 % | 14/20 | **20/20** | 20/20 | 3 / 4 / 7 | 16.4 m |
| E3, 45 % | 1 % | 17/20 | **20/20** | 20/20 | 6 / 9 / 6 | 6.2 m |
| E3, 45 % | 2 % | 17/20 | **20/20** | 20/20 | 3 / 9 / 5 | 12.2 m |
| E3, 45 % | 5 % | 13/20 | **20/20** | 20/20 | 2 / 7 / 6 | 19.8 m |
| E15, 20 % | 1 % | 14/20 | **20/20** | 20/20 | 4 / 6 / 12 | 5.0 m |
| E15, 20 % | 2 % | 17/20 | **20/20** | 20/20 | 2 / 4 / 6 | 11.2 m |
| E15, 20 % | 5 % | 17/20 | **20/20** | 20/20 | 0 / 2 / 5 | 18.9 m |
| none | 1, 2, 5 % | 14, 14, 14 /20 | **20, 20, 20 /20** | 20, 20, 20 /20 | — | 20 m |

**Interpretation:**
- **Region coverage.** The χ² region contained the truth in every run: 180/180 damaged and 60/60 undamaged, against 143/180 and 42/60 for the D-028 ratio region.
  - At one seed, the three noise levels share the same random draws scaled by the level, so there are 80 distinct realizations. 80/80 gives a one-sided 95 % lower bound on coverage of about 96 %.
  - The region is therefore **conservative**: at least as wide as needed, possibly wider.
- **Width is the honest price.**
  - About 3.5–6 m at 1 % noise, 8–12 m at 2 %.
  - At 5 % noise it covers most of the 20 m span. With 3 sensors and 5 positions, 5 % noise does not allow localization, and the method now says so instead of naming a wrong element with false precision.
- **Better best guess.** The weighted fit picks the exact element more often than the unweighted RMSE: 71/180 against 39/180 over the damaged rows.
  - 2 m groups hit their (larger) target 79/180 times.
  - Neither makes the single best guess reliable at ≥ 2 % noise; only more information (more sensors or truck positions, less noise) would.
- **False alarms.** `modelMisfit` was set in 7 of 80 distinct correct-model realizations (8.8 %, nominal 5 %; binomial P(≥ 7 | 80, 0.05) = 0.105). This is consistent with the approximate χ² fit check, slightly above nominal.
- **Scope.** Synthetic data from the same model class: this is algorithm verification. It is **not** field validation, and the counts are not probabilities that a real bridge region is damaged.

---

## V-020 — 2026-11-12 — S3b in MATLAB, run 1 (run by the user): 128 passed, 1 failed

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer (Platform line not in the screenshots) |
| Code version | Branch `claude/s3b-noise-region` at `f9393a8` |
| Result | **128 passed, 1 failed, 129 tests**. Failed: `testInverseDamage / Sensor deflections equal the static engine and the closed form, vehicle only`. Screenshots: `results/verification/2026-11-12_S3b_matlab_runAllTests_run1_*.png` |
| Diagnostic | Not in the screenshots (printed further up). The cause below is therefore **inferred**, not read from MATLAB's message |

**Inferred cause.** The section's last check compared the moving-load fast path with the static engine, on a damaged beam with a permanent load, travel toward −x and sensors between nodes, with a limit of 1e‑12 relative. Both are the same engine reached by two solver paths (a Cholesky factor, versus backslash plus a difference of two solutions), so they differ only by round-off.
- Octave gives 7.8e‑13, already 78 % of that limit.
- The expected round-off is up to about eps·cond(K_ff) = 2.2e‑16 × 1.6e5 ≈ 3.5e‑11, and MATLAB uses different linear-algebra libraries.
- So 1e‑12 was tighter than round-off justifies.
- The closed-form checks in the same section (errors about 2.7e‑11 % against a limit of 1e‑8 %) are very unlikely to differ between platforms.

**Change (no analytical reference altered).**
- The engine-against-engine check now uses 1e‑9, the same criterion as the damaged fast-path test in `testStiffnessDamage`.
- It is a row of the printed comparison table, so the measured value is visible on both platforms (Octave: 7.819e‑13).
- The closed-form limit of 1e‑8 % is unchanged.
- The mutant "permanent-load deflection not subtracted" is still detected.
- Octave log: `results/verification/2026-11-12_S3b_octave-8.4.0_testInverseDamage_after_tolerance_fix.log`.

**Status:** MATLAB rerun pending. It will show MATLAB's measured value and confirm or refute the inferred cause.

### V-020, run 2 (2026-11-12, after commit `c4d306b`)

| Item | Value |
|---|---|
| Main suite | **129 passed, 0 failed, 129 tests**. Screenshot: `results/verification/2026-11-12_S3b_matlab_runAllTests_run2_summary.png` |
| App check | `checkBridgeConditionApp(true)`: every row visible in the screenshot is PASS, from the M, V, v envelope row through "24 callbacks invoked … without error" and "Verification tab: test suite reports 0 failed", and no error was raised (the check throws if any row fails). The first rows are above the visible part. Screenshot: `..._S3b_matlab_checkBridgeConditionApp.png` |
| Damage sub-tabs | Screenshots `..._S3b_matlab_damage_subtab_healthy_vs_damaged.png` (after "Clear damage", placeholders shown) and `..._S3b_matlab_damage_subtab_sensitivity.png` (two-span 12 + 15 m RCC model with 10 kN/m, d = 40 %: most influential element 13, 19.5–21.375 m, vmin change −1.4448 mm, −17.02 %) |

- The inferred cause of run 1 (the 1e‑12 round-off limit) is consistent with run 2 passing with the 1e‑9 criterion. MATLAB's measured value is in the printed table, but not in the screenshots.
- **Status:** M7c, S3 and S3b are verified in GNU Octave (V-017, V-018, V-019) and MATLAB (V-020), and merged into `main`.
- **Display findings for the next milestone:**
  - empty legend boxes stay in cleared axes (`cla` does not remove a legend);
  - the "Rank" column repeats the table's row numbers;
  - node coordinates such as 13.875 m are displayed as "13.88", which would be rejected if retyped;
  - the axes toolbar overlaps plot titles.

---

## V-021 — 2026-11-12 — M8 Identification (Stage 3) tab in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The user needs to run `runAllTests`, `checkBridgeConditionApp(true)` and use the new tab; record as V-022 |
| Code version | Branch `claude/m8-identification-tab` |
| Main suite | **135 passed, 0 failed, 135 tests** (129 + 6 in `testIdentificationHelpers`). Raw log: `results/verification/2026-11-12_M8_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **43/43 PASS** (33 earlier rows, of which the envelope rows now run with explicit legend handles; 10 new Stage 3 rows; 27 callbacks without error). Raw log: `..._M8_octave-8.4.0_gui_mock_check.log` |
| Mutation check | 11 M8 faults (3 parallel shards, Stage 3 test files only). **10 detected; 1 equivalent:** "positions with no axle on the beam kept" survived because the new zero-reading filter drops those positions anyway. The redundant axle check was removed, and its replacement "positions with all-zero readings kept" is detected. Raw output: `..._M8_mutation_check_octave-8.4.0.txt` |
| Independent review | 12 agents, D-030. **High:** hidden-handle objects survive `cla`; this was also latent in the M6/M7b envelope plots, and the skeptic reproduced it with real Octave graphics. **Medium (7):** TeX label, title overflow, crowded annotations, "no damage" best fit hiding its region, zero-reading defaults, untested plots and summary flags. All fixed, with tests. One test-gap claim was refuted |
| Drawing preview | matplotlib render of the Stage 3 drawing primitives (not a MATLAB screenshot): `results/verification/2026-11-12_M8_preview_stage3_drawing_matplotlib.png`. The first render showed the best-fit label covered by load arrows; this was fixed |

New app-check rows (two-span 12 + 15 m RCC model, 10 kN/m, spec truck):

| Row | Reference | Result |
|---|---|---|
| Defaults | sensors 6.75, 13.5, 20.25 m; positions 6.75, 13.5, 20.25, 27 m (33.75 m: no axle on the beam) | PASS |
| Generate | readings table = 1000 × `syntheticObservations(…, 9, 10.5, 30 %, 1 %, seed 3)`; truth kept apart | `isequal` true — PASS |
| Run (1 % stated, each element) | `identifySingleDamage` with `identificationOptions(model, 0, 1, 0, 1)`: best, competing groups, regions, S | identical — PASS |
| Table and summary | `identificationTableData`, `identificationSummary(ref, truth)` | identical — PASS |
| Fit chart | one bar per candidate + cut-off markers + limit (+ no-damage) line; legend contains "limit" | exact count — PASS |
| Readings plot | 4 objects per sensor; legend {healthy model, best fit, readings} | exact — PASS |
| Drawing | object count = `bridgeDrawing` with sensors, region, best fit, hidden case | exact — PASS |
| 2 m regions | groups = `candidateGroups(model, 2)` | PASS |
| Sensors changed after the readings | run refused with a message | PASS |
| −x travel | mirrored positions; readings and result = direct calls with direction −1 | PASS (after fixing: applying a vehicle reset the user's hidden-case inputs) |

**Limits:** layout, rendering and real legend appearance are **NOT VERIFIED IN MATLAB**; the stand-ins check property names, values and object counts only. All Stage 3 results shown by the tab for synthetic readings are algorithm verification, not field validation.

---

## V-022 — 2026-11-13 — M8 in MATLAB, run 1 (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB on the user's computer (Platform line not in the screenshots) |
| Code version | Branch `claude/m8-identification-tab` at `71ddb4f` |
| Main suite | **135 passed, 0 failed, 135 tests.** Screenshot: `results/verification/2026-11-13_M8_matlab_runAllTests_summary.png` |
| App check | `checkBridgeConditionApp(true)`: **42 of 44 rows PASS, 2 FAIL**: "fit chart: one bar per candidate, … ; legend" and "readings plot: 4 objects per sensor …; 3 legend entries". All other Stage 3 rows passed in MATLAB, including Generate, Run = `identifySingleDamage`, table and summary, drawing object by object, 2 m regions, the refused run, −x travel, 28 callbacks and the in-app test run. Screenshot: `..._M8_matlab_checkBridgeConditionApp_run1.png` |

**Cause (found from the code).** Both failing rows read `ax.Legend` as a cell array of labels, which is how the Octave stand-ins stored it. In MATLAB, `ax.Legend` is a Legend object with the labels in `.String`, so `strcmp(ax.Legend, 'limit')` and `isequal(ax.Legend, {…})` are false whatever is drawn. These are the only two places in the repository that read `.Legend`. **The check was wrong; nothing shows an app defect.** Each failing row also contained an object count, which MATLAB therefore did not report on separately.

**Changes (test harness only; no app or engine change):**
- The stand-ins now store the legend like MATLAB (`[]`, or an object with `.String`).
- Like MATLAB, `cla` now **keeps** an existing legend. The old stand-in removed it, which is why it could never show the empty legend boxes the user saw in V-020.
- The check reads labels through `legendStrings(ax)` (`ax.Legend.String`, or `{}`).
- Each failing row is split in two (object count; legend), so a failure shows which part failed.
- The "Clear damage" row also requires that no legend is left.
- Shown to work: with `legend(ax, 'off')` removed from `clearDamageResults` in a scratch copy, the corrected check fails on that row.
- Octave with stand-ins: **45/45 PASS**. Raw log: `results/verification/2026-11-13_M8_octave-8.4.0_gui_mock_check_after_legend_fix.log`. `runAllTests` does not use the stand-ins and is unaffected.

**Status:** MATLAB rerun of `checkBridgeConditionApp(true)` pending (expect 46 rows PASS), together with screenshots of the Identification tab.

### V-022 continued (2026-11-14): Identification tab used in MATLAB

Screenshots: `results/verification/2026-11-14_M8_matlab_identification_fit_by_location.png` and `..._identification_readings.png`. Case: 20 m simple span, 16 elements, spec truck, sensors 5/10/15 m, positions 5–25 m; hidden element 5 (5–6.25 m) at 30 %; 1 % noise, seed 1; search with 1 % stated noise, each element.

| Shown in MATLAB | Value |
|---|---|
| Best fit (smallest S) | element 5 (5–6.25 m), d = 30.2 % (remaining EI × 0.698), RMSE 0.0882 mm, J_N 0.66 % — the hidden region |
| Region of uncertainty | 3.75–7.5 m (elements 4, 5, 6); loss in the best region 27.0–33.0 % |
| Minimum-RMSE candidate (spec §7) | element 5, d = 33.0 %, RMSE 0.0703 mm (same element, different d) |
| Fit check | passed (S = 10.6 ≤ 22.4, 13 degrees of freedom) |
| Structures analysed | 322 |

- The result agrees with the design: the true region is found, and the 95 % region is three elements wide at 1 % noise, consistent with the V-019 coverage study.
- The `checkBridgeConditionApp(true)` rerun after `523cfab` was **not** included; still pending.

**Display findings from these screenshots and their fixes** (D-030 addendum):

| Finding | Fix |
|---|---|
| The best region's bar has height 0 (it is the reference), so the most important candidate looked like a gap | A star marks the best fit on the axis, legend "best fit"; the y-axis starts slightly below 0 to show it |
| Sensor labels S1–S3 piled up at x_v = 25 m; the legend explained line styles but not the colours | The legend names each sensor by colour ("S1 (x = 5 m)"); the title explains the styles: dots = readings, solid = best fit, dotted = healthy model |
| The readings table cut off the x_v = 25 m column | `ColumnWidth` 'fit' |
| The full summary was in a small scrolling box on the left | It has its own full-width **"Summary"** sub-tab (about 886 px wide at the default window size, so about 11 lines). The left box shows the best-fit line, **every limiting flag** and a pointer |

**Independent review of these display changes** (4 agents; a skeptic for each finding):
- **Confirmed, medium:** my first version put the summary beside the table in a fixed 720 px table column. 720 was measured in screenshot pixels at 125 % display scaling (about 577 real pixels), so the summary would have been only about 156 px wide, about 53 wrapped lines with a quarter visible, which is worse than before. Replaced by the Summary sub-tab.
- **Confirmed, medium:** the left box showed the best fit without its caveats. It now also lists the flags: failed fit check, "no damage" not ruled out, search limit, RCC, and the ratio method not being a confidence region. `identificationSummary` returns them as a second output.
- **Low, also fixed:**
  - the readings title was too wide, so it is now two lines;
  - more than 6 sensors would have repeated colours, so each sensor now has a colour and a marker shape;
  - the test's cut-off formula did not match the chart for the ratio method, so it now mirrors `plotFitProfile`, with a ratio-method run added;
  - the left box was unchecked and is now compared with the summary and flags.
- **Found while testing:** the search-limit text said "60 %" whatever the highest level; it now uses the actual limit.

After the fixes:
- Octave `runAllTests`: **135/135** (`results/verification/2026-11-14_M8_octave-8.4.0_runAllTests.log`).
- App check (stand-ins): **47/47** (`..._M8_octave-8.4.0_gui_mock_check.log`), including the rows for the left box and the ratio-method chart.
- MATLAB: rerun pending (expect 48 rows with `checkBridgeConditionApp(true)`).

### V-022, run 2 (2026-11-18, branch `claude/m8-identification-tab` at `931a33a`)

| Item | Value |
|---|---|
| Main suite | **135 passed, 0 failed, 135 tests**. Screenshot: `results/verification/2026-11-18_M8_matlab_runAllTests_summary.png` |
| App check | `checkBridgeConditionApp(true)`: **all rows PASS**, from start-up through "Verification tab: test suite reports 0 failed", with no error at the end (the check stops with an error if any row fails). This includes the rows that failed in run 1 (fit chart count and legend, readings plot count and legend), the left-box row, the ratio-method row and −x travel. Screenshots: `..._M8_matlab_checkBridgeConditionApp_part1.png`, `..._part2.png` |
| Warnings printed | `..._M8_matlab_checkBridgeConditionApp_warnings.png`: the deliberate unit-slip warning (section 8 types 32e9 into the GPa field) and the spec §7 RCC caveat `BridgeFE:rccInverse`, once per identification run, because the check's bridge is RCC. Both are expected behaviour, not failures |
| Tab used | Four screenshots shared in the conversation (Readings [mm], Fit by location, Summary, Envelopes after two runs). They were not available as files in the session, so they are **not stored**. Shown: legend by sensor colour and marker; two-line title; best-fit star at 5–6.25 m; full-width summary ("True region inside the reported region: yes. Best-fit region contains the true region: yes"; fit check passed, S = 10.6 ≤ 22.4); Envelopes critical markers drawn once after two runs, which confirms in MATLAB the hidden-handle fix (D-030) |

**Status of M8:** verified in GNU Octave (V-021) and MATLAB (V-022). Merged into `main`.

**Remaining cosmetics, moved to M8b:**
- the readings table still cuts the last column (x_v = 25 m);
- the Envelopes critical table shows `-0.000` (that table predates `formatNumber`);
- the check prints the expected RCC caveat six times.

---

## V-023 — 2026-11-18 — M8b cosmetic follow-ups in GNU Octave

| Item | Value |
|---|---|
| Code version | Branch `claude/m8b-polish` (from `main` at `c5f00c8`) |
| Changes | (1) The Envelopes critical and reaction tables and the current-reaction table use `formatNumber`: `-0.000` becomes `0.000`. On the simple span with the spec truck, M min was printed `-0.000` in MATLAB (V-022); the old formatting reproduces `-0.000` in Octave and the new one gives `0.000`. (2) Readings table column 520 → 640 px, so five truck-position columns fit. (3) `checkBridgeConditionApp` turns off the expected `BridgeFE:rccInverse` caveat while it runs (its bridge is RCC) and checks it instead in a new row (`rccBaseline` and the "RCC baseline:" line in the left box); the deliberate unit-slip warning stays on, because the app detects it through `lastwarn` |
| Main suite | **135 passed, 0 failed** (the negative-zero test now also covers the Envelopes tables). Raw log: `results/verification/2026-11-18_M8b_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **48/48 PASS**; RCC caveat printed 0 times. Raw log: `..._M8b_octave-8.4.0_gui_mock_check.log` |
| MATLAB | **NOT RUN.** Expected `checkBridgeConditionApp(true)`: 49 rows PASS, with only the unit-slip warning printed; record as V-024 |

## V-024 — 2026-11-18 — M8b in MATLAB (run by the user)

| Item | Value |
|---|---|
| Code version | Branch `claude/m8b-polish` at `4af1c39` |
| App check | `checkBridgeConditionApp(true)`: **all rows PASS**, including the new "RCC bridge: rccBaseline set and the spec section 7 caveat shown in the left box" and "Verification tab: test suite reports 0 failed". No error at the end (the check stops with an error if any row fails). The only warning text is the tail of the deliberate unit-slip warning ("In checkBridgeConditionApp (line 122)"); the six RCC caveat messages of V-022 are gone. Screenshots: `results/verification/2026-11-18_M8b_matlab_checkBridgeConditionApp_part1.png`, `..._part2.png` |
| Main suite | Not rerun in MATLAB for M8b. The change to `src/gui` is display formatting only (`formatNumber` in three table helpers), and the Verification-tab row ran the whole suite inside the app with 0 failed |

**Status of M8b:** verified in Octave (V-023) and MATLAB (V-024). Merged into `main`.

## V-025 — 2026-11-19 — M9 input redesign in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The user needs to run `runAllTests`, `checkBridgeConditionApp(true)` and use the new inputs in SI and US units; record as V-026 |
| Code version | Branch `claude/m9-input-redesign` (suite, app check and app mutants run on `e8cdd75`; later commits change only records and logs) |
| Main suite | **157 passed, 0 failed, 157 tests** (135 in M8b + `testUnitsDisplay` and `testInputTables`). Raw log: `results/verification/2026-11-19_M9_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **89/89 PASS** (90 with the in-app test run in MATLAB); only the deliberate unit-slip warning printed. The stand-ins now list container children newest first and store uitable `ColumnName`/`RowName` as columns, as MATLAB does, so the callback sweep runs in MATLAB's order. Raw log: `..._M9_octave-8.4.0_gui_mock_check.log` |
| Mutation check | **M9a:** 35 faults in the unit-aware result helpers + 4 moved legacy targets, **39/39 detected** by `testUnitsDisplay`. **M9b:** 36 faults in the table inputs, presets and drawing, **36/36 detected** by `testInputTables`. **App:** 31 faults (29 in `app/BridgeConditionApp.m`: the 16 unit-display bugs the review showed the check missed and one per fix; 2 that break the callback sweep, by a throw and by an error the app only reports), run with `tools/app_mutation_check.py` against the app check, **31/31 detected**: 29 by a FAIL row, 2 by an error that stops the check (an invalid drop-down value after a half-done switch; the engine refusing an unclamped end sensor). Raw output: `..._M9_mutation_check_octave-8.4.0.txt` |
| Independent review 1 | 21 agents (units, MATLAB UI, check coverage; adversarial verify). **3 app defects** fixed: (1) a unit switch with an invalid input left sensors, drop-downs and slider in the old units under new labels — the switch is now refused until the input is corrected; (2) the readings tab said "Readings [mm]" in US units; (3) a switch could swap E between the steel and RCC defaults. **13 app-check gaps** (each shown by a surviving app mutant) closed with new rows. Low: exact restore after an added row, SI headers on emptied tables, noise tooltip, end-of-beam sensor tolerance, text in numeric cells, 4-digit field display, and the Bridge model left panel (the notes had about 9 px on the user's 1917 x 1008, 125 % window) — all fixed |
| Independent review 2 | 4 agents on the fixes. No app defect. Check defects fixed: the sweep wrote the private `LastError` (crash on a reported error); in MATLAB's child order "Run identification" would be pressed before readings existed; `isequal` on a uitable `ColumnName` fails in MATLAB (n-by-1). Layout computed for a 651 px panel: all four left panels fit (Bridge model 626 px) |

New app-check rows (two-span 12 + 15 m RCC model unless stated):

| Row | Reference | Result |
|---|---|---|
| Span and support tables, + / − buttons | supports A, B, C follow the span ends; chosen types kept; model = `buildModelFromInputs` | PASS |
| Text '15' in a span cell | supports table shows no x; Apply names "Span 2" (as `buildModelFromTables`) | PASS |
| Node and support drop-downs | `nodeChoices`; Rmax at B = `damageSensitivity(..., 'Node', B)` | PASS |
| A Free | drop-down lists B, C only; Rmax at C = `damageSensitivity(..., 'Node', node at 27 m)` | PASS |
| Presets | HL-93 in SI and in US = `vehicleFromTable([8 32 32], [14 14], ..., US)` (rel 1e-12); + Add axle 1.2 m in SI and in US | PASS |
| Refused switch (span 1 = 0) | units, labels, inputs and model stay SI; message names "Span 1" | PASS |
| US conversion | spans, E, I, load, axles, position and sweep steps, reading noise: rel ≤ 1e-11; same model (U rel ≤ 1e-9) and vehicle | PASS |
| US display | supports x, default sensors and positions (after a switch and after Apply model), headers and labels, readings tab "[in]", diagrams and envelopes over 0–27 m in ft, slider in ft, position text, R_B, critical and reaction-envelope tables = helpers with `US` | PASS |
| US identification | noise 1 % + 0.05 mm (converted to in) = `identifySingleDamage` with `identificationOptions(..., US)`; table and summary | PASS |
| Back to SI | unedited inputs restored exactly (`isequal` model and vehicle); an axle added in US keeps the first three axles exact; E = 200 GPa typed for RCC kept through a switch | PASS |
| Callback sweep | 37 callbacks in MATLAB's child order; none throws or reports an error | PASS |

**Limits:** layout, rendering, table editing and drop-down cells are **NOT VERIFIED IN MATLAB**; the stand-ins check property names, values, child order and object counts only. US customary results are the SI engine results converted for display (exact factors); they are not an independent analysis.

## V-026 — 2026-11-19 — M9 in MATLAB, part 1: test suite and app check (run by the user)

| Item | Value |
|---|---|
| Platform | MATLAB R2026b on the user's computer (as V-002) |
| Code version | Branch `claude/m9-input-redesign` at `79bef9d` (pulled after V-025) |
| Main suite | `runAllTests`: **Total: 157 passed, 0 failed, 157 tests**, the same count as Octave (V-025). Screenshot: `results/verification/2026-11-19_M9_matlab_runAllTests_summary.png` |
| App check | `checkBridgeConditionApp(true)`: **every row PASS** and no error at the end (the check throws if any row fails). This includes the refused switch, every US-unit row, the round trips back to SI, the Free-support Rmax row, "38 callbacks invoked ... without an error thrown or reported, after a valid set-up" (38 = the 37 of the Octave run plus the in-app "Run all tests" button; the sweep ran in MATLAB's child order) and "Verification tab: test suite reports 0 failed". The only warning is the deliberate unit-slip warning (RCC E = 3.2e+19 Pa). Screenshots: `..._M9_matlab_checkBridgeConditionApp_part1.png` to `..._part4.png` |

### V-026 part 2a (2026-11-19): the app in SI and US (screenshots by the user)

Model: spans 20 m (16 elements) + 10 m (10 elements), A Pin, B and C Roller, steel E = 200 GPa, Is = 0.01 m^4; AASHTO HL-93 preset chosen in SI, then the switch to US.

| Screen | Seen in MATLAB | Result |
|---|---|---|
| Bridge model, SI (`..._M9_matlab_app_bridge_model_SI.png`) | Maximised window: the whole left panel fits, **Apply model** visible with room below; spans and supports tables; the summary box shows the model summary and the modelling notes (pin = roller, steel/RCC EI, not a load rating) | as designed |
| Vehicle, SI (`..._vehicle_HL93_SI.png`) | Preset drop-down across the panel shows "AASHTO HL-93 design truck (axles only)" in full; axle table 35.5858, 142.3431, 142.3431 kN at 4.2672 m (8, 32, 32 kip at 14 ft); total 320.272 kN, 8.5344 m | as designed; see notes 3–4 |
| Bridge model, US (`..._bridge_model_US.png`) | 65.6168 + 32.8084 ft; supports at 0, 65.6168, 98.4252 ft; E 29007.5 ksi and Is 24025.1 in^4 (6 digits); summary EI = 4.83965e+06 kip*ft^2 (= 2e6 kN*m^2) | as designed |
| Vehicle, US (`..._vehicle_HL93_US.png`) | 8, 32, 32 kip at 14, 14 ft; total 72 kip, 28 ft; step 0.328084 ft (0.1 m); reactions 8.000 kip at A, 0 at B and C with the front axle on A; drawings and diagrams in ft | as designed; see notes 1–2 |
| Identification, US (`..._identification_US.png`) | Tab title **"Readings [in]"**; sensors 24.6063, 49.2126, 73.8189 ft; hidden region node 9–10 (32.8084–36.9094 ft); candidate table in ft and in (RMSE 5 decimals); 534 structures, 2 candidate regions; best fit element 9, d = 30.8 % (hidden 30 %), range 26.0–35.0 % | as designed |

**Same numbers in Octave:** the same steps replayed in GNU Octave 8.4.0 with the stand-ins (`tools/crosscheck/replayV026.m`) give the identical status line, both candidate-table rows digit for digit (30.8 | 26.0–35.0 | 0.692 | 0.00155 and 32.7 | 31.0–34.0 | 0.673 | 0.00326 | 5.32), J_N 0.75 %, the same EI line and reactions. The synthetic noise is deterministic (`deterministicNormal`), so both platforms see the same readings.

Cosmetic notes from these screenshots (not errors):
1. The position slider labels its upper limit next to the last round tick, so in US they overlap ("120126.4").
2. The current-reaction table is wider than the panel: the last header ("Couple [kN*m] (+ ...") needs the horizontal scroll bar.
3. Choosing a preset fills the axle table, but the drawing keeps the applied truck until **Apply vehicle**, and the status line does not say so (the model tab does: "Model edited: press Apply model").
4. The vehicle name and truck-position fields are narrower than their text (the fifth position, 123.031 ft, is out of view; the Octave replay confirms it is there and was used).

### V-026 part 2b (2026-11-19): table editing and the refused switch in MATLAB

These are MATLAB uitable behaviours that the Octave stand-ins cannot show.

| Action | Seen in MATLAB | Result |
|---|---|---|
| Span length typed as `25` | `disp(app.Controls.SpansTable.Data)` gives `{[25]} {[16]}`: stored as a number (`..._M9_matlab_spans_table_typed_25.png`) | as designed |
| Span length typed as `abc` | stored as `{[NaN]}`: MATLAB never stores text in a 'numeric' column; the app's reader and `buildModelFromTables` both reject NaN (`..._typed_abc.png`). The text case handled since the review is therefore defensive only | as designed |
| Type drop-down | Support A set to Fixed and B to Free (one 10 ft span, US): the preview redraws a cantilever with the wall at A, and the summary reads "A Fixed (x = 0 ft), B Free (x = 10 ft)" (`..._app_cantilever_fixed_free_US.png`) | as designed |
| Axle table | the last axle's spacing cell is blank with no error (`..._app_vehicle_blank_last_spacing_US.png`) | as designed |
| Unit switch with span 1 = 0 (in US) | alert "Unit switch error: Span 1: length must be a positive number (ft). The units stay US: correct this input, then switch again."; the drop-down stays on US; the status line repeats the message (`..._app_refused_unit_switch.png`) | as designed |
| Cleared cell | not shown; a cleared cell gives NaN or `[]`, and the app reads both as "not a number" (Octave check row and V-025 review) | not seen in MATLAB |

**Status of M9:** verified in Octave (V-025) and in MATLAB R2026b (V-026 parts 1, 2a, 2b): suite 157/157, app check all rows PASS, the app in SI and US identical to Octave, table editing and the refused switch as designed. **Merged into `main`.** The four cosmetic notes of part 2a are handled in M9c.

## V-027 — 2026-11-19 — M9c cosmetic follow-ups in GNU Octave

| Item | Value |
|---|---|
| Platform | **GNU Octave 8.4.0**, Ubuntu 24.04.5 cloud container |
| MATLAB | **NOT RUN.** The user needs to run `checkBridgeConditionApp(true)` and look at the Vehicle and Identification tabs; record as V-028 |
| Code version | Branch `claude/m9c-polish` from `main` at `e96bd8a`; tests run on `b69ff87` |
| Changes | The four notes of V-026 part 2a: (1) round slider ticks (1, 2 or 5 x 10^k, 4 to 10 intervals, clamped inside the limits, never -0), so the crossing end is not labelled next to the last tick; (2) current-reaction headers without the sign rule, which moved to the label above ("Support reactions (forces + up, couples + CCW)"); (3) "Vehicle edited: press Apply vehicle" after a preset, an axle edit, a name, step or direction edit, and "Vehicle applied: ..." after Apply vehicle; (4) left panels 400 -> 460 px on every tab. `plotReadings`: shorter second title line. Stand-in slider: `MajorTicks` must lie inside `Limits` |
| Main suite | **157 passed, 0 failed, 157 tests**. Raw log: `results/verification/2026-11-19_M9c_octave-8.4.0_runAllTests.log` |
| App check (stand-ins) | **92/92 PASS** (89 + 3: status and slider ticks on a -x crossing; status after a preset and Apply vehicle; round ticks in US units). The callback sweep now makes 40 calls (name, step and direction fields have callbacks). Raw log: `..._M9c_octave-8.4.0_gui_mock_check.log` |
| Mutation check | 9 M9c faults with `tools/app_mutation_check.py`: **9/9 detected** (7 by a FAIL row; 2 by the check stopping when a removed callback is called). Raw output: `..._M9c_mutation_check_octave-8.4.0.txt` |
| Independent review | 2 agents (behaviour; layout measured from the user's PNGs). All findings low, all addressed: tick count promised by the check (6-16, not 8-17), -0 first tick, a tick 1e-14 outside Limits on 0.3 % of US crossings, ticks too dense on a restored window, no status after name/step/direction edits, "Vehicle applied" could hide a reported error, reaction table with about 10 px to spare, readings-plot title as wide as the narrower plot. Measured from the screenshots at 460 px: vehicle name 217 of 248 px, five truck positions 229 of 248 px |

**Limits:** the layout numbers are estimates from the user's screenshots; the MATLAB look (slider labels, reaction table without scroll bar, readings-plot title) is **NOT VERIFIED IN MATLAB** yet.

**Status of M9c:** verified in Octave (V-027). MATLAB: see V-028.

### V-027 addendum (2026-11-19): labels clipped to the axes

The user's MATLAB screenshot after a zoom on the beam drawing (a 5 + 5 ft model with B Free and HL-93 at x_v = 0.983 ft) showed node, element and axle labels outside the axes: MATLAB clips lines and patches to the axes but not text, by default. The numbers in that screenshot are right (B Free makes one 10 ft simple span: R_A = 8 x 9.017 / 10 = 7.214 kip, R_C = 0.786 kip, M = 8 x 0.983 x 9.017 / 10 = 7.09 kip*ft; the app shows 7.214, 0.786 and 7.089). Fix in `3ac60ac`: `renderDrawing` and `plotDiagram` draw text with `'Clipping', 'on'`; diagram peak labels sit on the side of their point that faces the plot. `testGuiHelpers` checks all 66 labels of a two-span drawing and the peak-label sides (3 mutants, all detected); the app check gains a row (93 rows, all PASS against the stand-ins).

**Final M9c state in Octave (`aacbc26`, after the axle-label rule of V-028 part 2):** main suite **158 passed, 0 failed, 158 tests** (`results/verification/2026-11-19_M9c_final_octave-8.4.0_runAllTests.log`); app check **93/93 PASS** (`..._M9c_final_octave-8.4.0_gui_mock_check.log`); mutants added to `..._M9c_mutation_check_octave-8.4.0.txt`: 3 label-clipping faults (testGuiHelpers), 6 axle-label faults (testInputTables; 2 replace the retired 6 %-threshold faults) and 1 app-level clipping fault, **10/10 detected**.

## V-028 — 2026-11-19 — M9c in MATLAB (run by the user)

| Item | Value |
|---|---|
| Code version | Branch `claude/m9c-polish` at `ab8ca34` (the warning points to line 169 of the check, which is line 171 from `3ac60ac` on): every M9c change except the label clipping |
| App check | `checkBridgeConditionApp(true)`: **every row PASS** and no error at the end, including "direction or step edited: the status asks for Apply vehicle; the slider has round ticks (-x crossing, from below 0)", "preset chosen: the status asks for Apply vehicle; after it: Vehicle applied: ...", "US: slider ticks are round ...", "41 callbacks invoked (buttons, fields, tables, slider, tabs) without an error thrown or reported, after a valid set-up" (40 + the in-app "Run all tests") and "Verification tab: test suite reports 0 failed". Only the deliberate unit-slip warning. Screenshots: `results/verification/2026-11-19_M9c_matlab_checkBridgeConditionApp_part1.png` to `..._part4.png` |
| Still to see | The label-clipping commit `3ac60ac` (one more check row; zoom on the beam drawing) and the app screenshots of the Vehicle and Identification tabs |

### V-028 part 2 (2026-11-19): the M9c app in MATLAB (screenshots by the user, after pulling `3ac60ac`)

Model: spans 20 m + 10 m (16 elements each), A Pin, B and C Roller, steel.

| Screen | Seen in MATLAB | Result |
|---|---|---|
| Vehicle, US, HL-93 chosen but not applied (`..._M9c_matlab_app_vehicle_US_preset_edited.png`) | Status "Vehicle edited: press "Apply vehicle" to use it (the drawing shows the applied vehicle)."; the drawing still shows the applied spec truck; vehicle name shown in full; slider labels 0, 20, ..., 100 ft (round, no end label); reaction table with all five headers ("Force [kip]", "Couple [kip*ft]") and no scroll bar, sign rule in the label above; R_A = 17.985 kip (the 80 kN front axle on A) | as designed |
| Vehicle, SI, HL-93 applied (`..._vehicle_HL93_SI.png`) | 35.5858, 142.3431, 142.3431 kN at 4.2672 m; slider 0, 5, ..., 35 m; reaction table fits; R_A = 35.586 kN | as designed |
| Identification, SI (`..._identification_SI.png`) | All five truck positions visible (7.5 15 22.5 30 37.5); hidden element 11 (12.5-13.75 m, 30 %) found: best fit element 11, d = 31.0 % (25.0-35.0), region of uncertainty elements 10-11, 661 structures | as designed |

**New finding:** in the first screenshot the two rear axles of the spec truck, both off the bridge, are labelled "26.9771 k26.9771 kip": the labels overlap. Only on-bridge axles closer than 6 % of the span shared a label, and kip values have more digits than kN values. Fixed in `aacbc26`: neighbouring axles share one label when their labels would overlap (estimated from the label length), on and off the bridge. In kN every case drawn before stays the same. Not yet seen in MATLAB.
