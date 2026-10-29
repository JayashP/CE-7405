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
| MATLAB | **NOT RUN** for the M2 tests. The user needs to run them; record the result as V-004 |
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

- These results are from **GNU Octave only.** The M2 tests have **not** been run in MATLAB.
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
