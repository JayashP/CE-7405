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
