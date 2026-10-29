"""Mutation check: verify that the M1 test suite detects deliberately injected solver bugs."""
import shutil, subprocess, sys, pathlib, re
# Usage: python3 -I tools/mutation_check.py <repo_root> <empty_scratch_dir>
# Copies the repo once per mutation, injects one deliberate bug, runs the suite in
# GNU Octave and reports which tests detect it. Never modifies <repo_root>.
repo = pathlib.Path(sys.argv[1]).resolve()
work = pathlib.Path(sys.argv[2]).resolve()
mutations = [
  ('k22 coefficient 4->3', 'src/elements/beamElementStiffness.m', '6*Le,   4*Le^2,  -6*Le,   2*Le^2;', '6*Le,   3*Le^2,  -6*Le,   2*Le^2;'),
  ('rotation-coupling sign flipped (k12,k21)', 'src/elements/beamElementStiffness.m', "ke = (EI / Le^3) * [ 12,     6*Le,    -12,     6*Le;\n                     6*Le,", "ke = (EI / Le^3) * [ 12,    -6*Le,    -12,     6*Le;\n                    -6*Le,"),
  ('DOF map v/theta swapped', 'src/model/elementDofs.m', 'dofMap = [2*i - 1, 2*i, 2*j - 1, 2*j];', 'dofMap = [2*i, 2*i - 1, 2*j, 2*j - 1];'),
  ('end-moment sign at node i', 'src/solver/recoverElementForces.m', 'ef.moment = [-endActions(:, 2), endActions(:, 4)];', 'ef.moment = [endActions(:, 2), endActions(:, 4)];'),
  ('reactions ignore loads at restrained DOFs', 'src/solver/recoverReactions.m', 'R(r) = full(K(r, :) * U(:) - F(r));', 'R(r) = full(K(r, :) * U(:));'),
  ('no under-restraint check', 'src/solver/partitionDofs.m', "if isempty(vRestrainedNodes)", "if false"),
  ('assembly uses wrong element length (x_j only)', 'src/model/assembleGlobalK.m', 'Le = x(conn(e, 2)) - x(conn(e, 1));', 'Le = 1.0;'),
]
for name, rel, old, new in mutations:
    d = work / re.sub(r'[^a-z0-9]+', '_', name.lower())
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(repo, d, ignore=shutil.ignore_patterns('.git', 'results'))
    f = d / rel
    text = f.read_text()
    assert text.count(old) == 1, f'mutation target not found exactly once: {name}'
    f.write_text(text.replace(old, new))
    p = subprocess.run(['timeout', '300', 'octave-cli', '--no-gui', '--norc', '--eval', 'runAllTests'], cwd=d, capture_output=True, text=True)
    out = p.stdout + p.stderr
    total = re.findall(r'Total: (\d+) passed, (\d+) failed', out)
    failed_tests = re.findall(r'^\s+FAIL\s+(\S+ / .*)$', out, re.M)
    print(f'MUTATION: {name}\n  exit={p.returncode} summary={total}\n  detected by: ' + ('; '.join(failed_tests[:6]) + (' ...' if len(failed_tests) > 6 else '') if failed_tests else '  NOT DETECTED'))
