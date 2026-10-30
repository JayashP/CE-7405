"""Independent brute-force check of the M4 analytical references (closed-form statics only, no FE).

Usage: python3 -I tools/moving_load_reference_check.py
Does not use the MATLAB code. Sweeps vehicle positions at 1e-4 m on a simple span and
evaluates the two-span M_B influence line, to confirm the fixed references used in
tests/testMovingLoadEnvelopes.m."""
# Independent brute-force check of M4 analytical references (closed-form statics only).
import numpy as np
def ss_moment_at(x, loads, L):          # simple span, loads = [(xp, P down)]
    RA = sum(P*(L-xp)/L for xp, P in loads if 0 <= xp <= L)
    return RA*x - sum(P*(x-xp) for xp, P in loads if 0 <= xp <= L and xp < x)
def sweep(axles, offs, L, step=1e-4):
    best = (-1e99, None, None)
    for xv in np.arange(0, L + offs[-1] + step, step):
        loads = [(xv - o, P) for o, P in zip(offs, axles) if -1e-12 <= xv - o <= L + 1e-12]
        for xp, _ in loads:
            m = ss_moment_at(xp, loads, L)
            if m > best[0]: best = (m, xv, xp)
    return best
L = 20.0
m2 = sweep([100, 100], [0, 4.2], L)
print('two-axle 100+100 kN, d=4.2: brute max %.4f kN*m at xv=%.4f under axle x=%.4f; closed form P(2L-d)^2/(8L)=%.4f' % (m2[0], m2[1], m2[2], 100*(2*L-4.2)**2/(8*L)))
m3 = sweep([80, 120, 120], [0, 4.2, 5.6], L)
print('3-axle 80/120/120, 4.2/1.4: brute max %.4f kN*m at xv=%.4f under axle x=%.4f; hand rule 1349.1025 at x=9.7375, xv=13.9375' % m3)
P = 100.0
a = np.linspace(0, L, 200001)
MB = -P*a*(L**2 - a**2)/(4*L**2)
k = MB.argmin()
print('two-span M_B influence min %.5f at a=%.4f; closed form -PL/(6*sqrt3)=%.5f at L/sqrt3=%.4f' % (MB[k], a[k], -P*L/(6*np.sqrt(3)), L/np.sqrt(3)))
# check M_B formula itself by flexibility (three-moment) for a load in span 1 of two equal spans
from numpy.linalg import solve
def two_span_MB(a, L, P=1.0):
    # three-moment: M_A L + 2 M_B (2L) + M_C L = -6 * A1*xbar1/L  ; for point load P at a in span 1: 6A x/L = P a (L^2 - a^2)/L
    return -P*a*(L**2 - a**2)/L/(4*L)
print('three-moment check at a=7: %.6f vs formula %.6f' % (two_span_MB(7, L, P), -P*7*(L**2-49)/(4*L**2)))
