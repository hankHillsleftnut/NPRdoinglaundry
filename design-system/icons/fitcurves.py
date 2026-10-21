# Fit cubic Béziers to a polyline within a tolerance (Philip J. Schneider, "An Algorithm for Automatically
# Fitting Digitized Curves", Graphics Gems, 1990). Used by outline.py so shipped icons are true curves, not facets.
import numpy as np
def _bez(ctrl, t):
    t = t[:, None]
    return ((1-t)**3)*ctrl[0] + 3*((1-t)**2)*t*ctrl[1] + 3*(1-t)*t*t*ctrl[2] + t**3*ctrl[3]
def _q1(c, t): return 3*((1-t)**2)*(c[1]-c[0]) + 6*(1-t)*t*(c[2]-c[1]) + 3*t*t*(c[3]-c[2])
def _q2(c, t): return 6*(1-t)*(c[2]-2*c[1]+c[0]) + 6*t*(c[3]-2*c[2]+c[1])
def _unit(v): n = np.linalg.norm(v); return v / n if n > 1e-12 else v
def fit(points, err):
    pts = np.asarray(points, float)
    if len(pts) < 2: return []
    return _fit(pts, _unit(pts[1]-pts[0]), _unit(pts[-2]-pts[-1]), err)
def _fit(pts, t1, t2, err):
    if len(pts) == 2:
        d = np.linalg.norm(pts[1]-pts[0]) / 3
        return [[pts[0], pts[0]+t1*d, pts[1]+t2*d, pts[1]]]
    u = _chord(pts)
    bez = _gen(pts, u, t1, t2)
    e, split = _maxerr(pts, bez, u)
    if e < err: return [bez]
    if e < err * 4:
        for _ in range(20):
            u = _reparam(bez, pts, u)
            bez = _gen(pts, u, t1, t2)
            e, split = _maxerr(pts, bez, u)
            if e < err: return [bez]
    tc = _unit(pts[split-1] - pts[split+1])
    return _fit(pts[:split+1], t1, tc, err) + _fit(pts[split:], -tc, t2, err)
def _gen(pts, u, t1, t2):
    b = np.array([pts[0], pts[0], pts[-1], pts[-1]])
    A = np.zeros((len(u), 2, 2))
    A[:, 0] = np.outer(3*(1-u)**2*u, t1); A[:, 1] = np.outer(3*(1-u)*u**2, t2)
    C = np.zeros((2, 2)); X = np.zeros(2)
    for i, (p, uu) in enumerate(zip(pts, u)):
        C[0][0] += A[i][0] @ A[i][0]; C[0][1] += A[i][0] @ A[i][1]; C[1][0] += A[i][0] @ A[i][1]; C[1][1] += A[i][1] @ A[i][1]
        tmp = p - _bez(b, np.array([uu]))[0]
        X[0] += A[i][0] @ tmp; X[1] += A[i][1] @ tmp
    det = C[0][0]*C[1][1] - C[1][0]*C[0][1]
    if abs(det) < 1e-12: al = ar = 0.0
    else:
        al = (X[0]*C[1][1] - X[1]*C[0][1]) / det; ar = (C[0][0]*X[1] - C[1][0]*X[0]) / det
    seg = np.linalg.norm(pts[-1]-pts[0]); eps = 1e-6 * seg
    if al < eps or ar < eps: al = ar = seg / 3
    return np.array([pts[0], pts[0]+t1*al, pts[-1]+t2*ar, pts[-1]])
def _reparam(bez, pts, u):
    out = []
    for p, t in zip(pts, u):
        d = _bez(bez, np.array([t]))[0] - p
        q1, q2 = _q1(bez, t), _q2(bez, t)
        den = q1 @ q1 + d @ q2
        out.append(t if abs(den) < 1e-12 else min(1, max(0, t - (d @ q1) / den)))
    return np.array(out)
def _chord(pts):
    d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    return d / d[-1] if d[-1] > 0 else d
def _maxerr(pts, bez, u):
    diff = np.linalg.norm(_bez(bez, u) - pts, axis=1)
    i = int(np.argmax(diff[1:-1])) + 1 if len(pts) > 2 else len(pts) // 2
    return diff[i], i
