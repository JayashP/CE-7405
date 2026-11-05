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
