# /fx_blob engine. No Blob Track TOP (it cost ~170 ms CPU per frame = 4 fps). Instead:
# res_track shrinks the image on the GPU to a GW x GH mono grid; once per frame track() reads that tiny
# grid, finds the connected bright areas (the brightest cells, Threshold = quantile), boxes them and keeps ids by matching
# each box to the nearest box of the last frame. script_boxes (Script CHOP) turns the boxes into
# the uniform array uBlobs for the shaders (u, v = lower left corner, w, h; fractions), script_labels into text rows.
# Knobs: Threshold, Size (largest box, fraction of the frame), Xray, Glow, Trail, Labels.
# Action1 = labels on/off, Action2 = clear trails.

import numpy as np

MAX_BLOBS = 24
W, H = 1920, 1080
GW, GH = 64, 36          # tracking grid (res_track resolution)
MIN_CELLS = 8          # smaller areas get no box (user wants few, big boxes)

S = dict(boxes=[], next_id=1, frame=-1)


def _components(mask):
    """Connected areas of True cells (4-neighbour), as lists of (y, x)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        stack, cells = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            cells.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append(cells)
    return out


def track():
    """Once per frame (executeDAT): grid -> boxes with ids."""
    c = parent()
    if absTime.frame == S['frame']:
        return S['boxes']
    S['frame'] = absTime.frame
    if c.op('null_mix')['mix'].eval() <= 0.001:
        S['boxes'] = []
        return []
    g = c.op('res_track').numpyArray(delayed=True)
    if g is None:
        return S['boxes']
    lum = g[..., 0]
    gh, gw = lum.shape
    # Threshold is relative to this frame: 0.85 = the brightest 15% of the cells, whatever the content
    mask = lum >= max(np.quantile(lum, c.par.Threshold.eval()), lum.min() + 1e-3)
    size = c.par.Size.eval()
    new = []
    for cells in _components(mask):
        if len(cells) < MIN_CELLS:
            continue
        ys = [p[0] for p in cells]
        xs = [p[1] for p in cells]
        u, v = min(xs) / gw, min(ys) / gh
        w, h = (max(xs) + 1 - min(xs)) / gw, (max(ys) + 1 - min(ys)) / gh
        if w > size or h > size:
            continue
        new.append([u, v, w, h, len(cells)])
    new.sort(key=lambda b: -b[4])
    new = new[:MAX_BLOBS]
    # keep ids: nearest centre of last frame within 0.08
    old = list(S['boxes'])
    boxes = []
    for u, v, w, h, n in new:
        cx, cy = u + w / 2, v + h / 2
        best, dist = None, 0.08
        for o in old:
            d = abs(o[1] + o[3] / 2 - cx) + abs(o[2] + o[4] / 2 - cy)
            if d < dist:
                best, dist = o, d
        if best is not None:
            old.remove(best)
            bid = best[0]
        else:
            bid = S['next_id']
            S['next_id'] += 1
        boxes.append((bid, u, v, w, h))
    S['boxes'] = boxes
    c.op('script_boxes').cook(force=True)
    c.op('script_labels').cook(force=True)
    return boxes


def _blobs():
    return S['boxes']


def cook_boxes(scriptOp):
    """Script CHOP: channels u v w h, MAX_BLOBS samples -> uniform vec4 uBlobs[] in the shaders."""
    scriptOp.clear()
    scriptOp.numSamples = MAX_BLOBS
    chans = [scriptOp.appendChan(n) for n in ('u', 'v', 'w', 'h')]
    for k, (bid, u, v, w, h) in enumerate(_blobs()):
        for ch, val in zip(chans, (u, v, w, h)):
            ch[k] = val


def cook_labels(scriptOp):
    scriptOp.clear()
    scriptOp.appendRow(['x', 'y', 'text'])
    if parent().par.Labels.eval() < 0.5:
        return
    for bid, u, v, w, h in _blobs():
        x = int(u * W) + 4          # on top of the box, left aligned (reference look)
        y = int((v + h) * H) + 6
        scriptOp.appendRow([x, y, '%d  %.2f %.2f' % (bid, u + w / 2, v + h / 2)])


def action1(comp):
    comp.par.Labels = 0.0 if comp.par.Labels.eval() > 0.5 else 1.0


def action2(comp):
    comp.op('feedback_trail').par.resetpulse.pulse()
    comp.op('feedback_xray').par.resetpulse.pulse()
