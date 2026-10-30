"""Render drawing primitives exported by exportDrawingPreviews.m (development check only).

Usage: python tools/preview/render_drawing_previews.py <json_dir> <png_dir>
Draws exactly the coordinates produced by bridgeDrawing.m (lines, markers,
patches, text) and, when present, the M/V/v diagram data, with matplotlib.
Requires matplotlib. Not used by the MATLAB app.
"""
import json, pathlib, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def as_list(v):
    return v if isinstance(v, list) else [v]

def draw(ax, prims, limits=None):
    for p in prims:
        x, y = as_list(p['x']), as_list(p['y'])
        ls = {'-': '-', '--': '--', ':': ':'}.get(p['lineStyle'], '-')
        if p['kind'] == 'line':
            ax.plot(x, y, color=p['color'], lw=p['lineWidth'], ls=ls)
        elif p['kind'] == 'marker':
            ax.plot(x, y, ls='none', marker=p['marker'], ms=p['markerSize'], mec=p['color'], mfc=p['faceColor'])
        elif p['kind'] == 'patch':
            ax.fill(x, y, facecolor=p['faceColor'], edgecolor=p['color'], lw=p['lineWidth'])
        elif p['kind'] == 'text':
            va = {'middle': 'center'}.get(p['vAlign'], p['vAlign'])
            ax.text(x[0], y[0], p['text'], color=p['color'], fontsize=p['fontSize'], ha=p['hAlign'], va=va)
    ax.set_aspect('equal')
    if limits:
        ax.set_xlim(limits['xl']); ax.set_ylim(limits['yl'])
    ax.set_yticks([])
    ax.set_xlabel('x [m]')

def main(src, dst):
    dst = pathlib.Path(dst); dst.mkdir(parents=True, exist_ok=True)
    for f in sorted(pathlib.Path(src).glob('*.json')):
        case = json.loads(f.read_text())
        prims = case['prims']
        d = case.get('diagram')
        n = 4 if d else 1
        fig, axs = plt.subplots(n, 1, figsize=(12, 3 + (7 if d else 0)), squeeze=False,
                                gridspec_kw={'height_ratios': [2] + [1] * (n - 1)})
        draw(axs[0][0], prims, case.get('limits'))
        axs[0][0].set_title(case['name'])
        if d:
            for ax, key, scale, label in [(axs[1][0], 'M', 1e-3, 'M [kN*m]'), (axs[2][0], 'V', 1e-3, 'V [kN]'), (axs[3][0], 'v', 1e3, 'v [mm]')]:
                y = [v * scale for v in d[key]]
                ax.fill_between(d['x'], y, 0, alpha=0.18)
                ax.plot(d['x'], y, lw=1.6)
                ax.axhline(0, color='0.3', lw=0.8)
                ax.set_ylabel(label); ax.grid(True)
            axs[3][0].set_xlabel('x [m]')
        fig.tight_layout()
        out = dst / (f.stem + '.png')
        fig.savefig(out, dpi=90)
        plt.close(fig)
        print('rendered', out)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
