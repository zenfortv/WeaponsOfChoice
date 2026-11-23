# TD side of the MetalShow control panel (/control). Every control's par is 'Shortcut:Par'.
# The Script TOP and Script DAT read those pars, so they cook only when one moves.

import time

import numpy as np


COMPS = {'Audio': '/audio', 'Show': '/show', 'Metal': '/fx_metal', 'Mosh': '/fx_mosh', 'Blob': '/fx_blob',
         'Strobe': '/fx_strobe', 'Luma': '/fx_luma', 'Input': '/input', 'Hud': '/weapons_hud', 'Boom': '/fx_boom', 'Pop': '/src_pop', 'Grade': '/grade',
         'Time': '/local/time'}    # TouchDesigner's own timeline (TD PLAY / TD PAUSE, MetalShow.81)


def M():
    return op('/control')


def K():
    return M().op('knobs').module


def controls():
    """The panel's controls for the screens that exist (/show Screens): S2 / S3 buttons and the screen width
    knobs hide with 1 screen (MetalShow.85)."""
    n = op('/show').par.Screens.menuIndex + 1
    return [c for c in K().controls() if c.get('need', 0) <= n]


def _par(c):
    comp, name = c['par'].split(':')
    return op(COMPS[comp]).par[name]


def status():
    s = op('/show')
    t = s.par.Elapsed.eval()
    on = '  '.join({'Mosh': 'EDGE', 'Strobe': 'CRASH'}.get(n, n.upper()) for n in ('Metal', 'Mosh', 'Blob', 'Strobe', 'Luma') if op(COMPS[n]).par.On.eval())
    n = len(_pending()['vals']) + len(_pending()['acts'])
    return ('' if op('/local/time').par.play.eval() else 'TD PAUSED!   ') + ('SHIFT: %d WAITING   ' % n if s.par.Shift.eval() else '') + ('AUTO RUNNING   ' if s.par.Autorunning.eval() else '') + 'BPM %d /%s   ' % (s.par.Bpm.eval(), s.par.Beatevery.eval()) + 'IN %s   TIMELINE %s   stage %d/3   %d:%02d   section %.1f min      ON: %s      PAD: %s' % (
        '+'.join(n for n, u in (('VIDEO', 'Usevideo'), ('HUD', 'Usehud'), ('POP', 'Usepop')) if op('/input').par[u].eval()) or '-', 'PLAY' if s.par.Play.eval() else 'STOP', s.par.Stage.eval() + 1, t // 60, t % 60, s.par.Section.eval(), on or '-', ('ON' if s.par.Padon.eval() else 'OFF') + ('' if op('/show/pad')['connected'] else ' (not connected)'))


# ---- SHIFT (MetalShow.58): while Show:Shift is on, panel changes wait in a pending list (shown on the panel,
# marked) and nothing reaches the output; clicking SHIFT again applies them all on the same frame.
FREE = ('Show:Shift', 'Show:Tap', 'Show:Beatevery', 'Show:Panic', 'Time:play')     # these act at once even in SHIFT


def _shifting(c):
    return c['par'] not in FREE and bool(op('/show').par.Shift.eval())


def _pending():
    return M().fetch('Pending', {'vals': {}, 'acts': []}, search=False)


def _cur(c):
    """The value the panel shows: the pending one if SHIFT holds one, else the par's."""
    v = _pending()['vals'].get(c['par'])
    return _par(c).eval() if v is None else v


def _refresh():
    for o in M().findChildren(type=scriptTOP) + M().findChildren(type=scriptDAT):
        o.cook(force=True)


def _set(c, value):
    if _shifting(c):
        pend = _pending()
        pend['vals'][c['par']] = value
        M().store('Pending', pend)
        _refresh()
    else:
        _par(c).val = value


def _act(c, kind, what):
    """kind 'pulse' or 'call': run now, or queue it while SHIFT is on."""
    if _shifting(c):
        pend = _pending()
        pend['acts'].append((kind, c['par'], what, str(c.get('label', ''))))
        M().store('Pending', pend)
        _refresh()
        return
    _run(kind, c['par'], what, str(c.get('label', '')))


def _run(kind, key, what, label):
    if kind == 'pulse':
        comp, name = key.split(':')
        op(COMPS[comp]).par[name].pulse()
        flash(key)
    else:
        exec(what)
        flash(key + '#' + label)


def shift_release():
    """Apply everything SHIFT held back, all on this frame."""
    pend = _pending()
    M().store('Pending', {'vals': {}, 'acts': []})
    for key, v in pend['vals'].items():
        comp, name = key.split(':')
        p = op(COMPS[comp]).par[name]
        if p.isMenu and isinstance(v, int) and not isinstance(v, bool):
            p.menuIndex = v
        else:
            p.val = v
        flash(key)
    for kind, key, what, label in pend['acts']:
        _run(kind, key, what, label)
    _refresh()


def _range(c):
    p = _par(c)
    return p.normMin, p.normMax, p.style == 'Int'


def state(c):
    """(position 0-1, lit, pad, text inside it) of a control."""
    k, p = K(), _par(c)
    pend = _pending()['vals']
    mark = 1.0 if c['par'] in pend else 0.0
    if 'step' in c:
        if c['label']:
            return 0.0, False, mark, ''
        idx = pend[c['par']] if c['par'] in pend else p.menuIndex
        lab = p.menuLabels[idx] if p.menuLabels else '-'
        if mark:
            lab = '* ' + lab
        if c.get('prefix'):      # driver steppers: short names (AUD DIRECTSOUND, CAM DIRECTSHOW)
            lab = c.get('names', {}).get(p.menuNames[idx], lab.split(' (')[0])
        if lab.lower().endswith(('.mov', '.mp4', '.avi')):     # clip names without the extension
            lab = lab.rsplit('.', 1)[0]
        return 0.0, False, 0.0, (c.get('prefix', '') + lab.upper())[:c.get('maxlen', 17)] if c.get('raw') else k.device_name(lab)
    if c['kind'] == k.BUTTON:
        if c.get('nolit'):       # PREV / NEXT: never lit, they flash when clicked
            return 0.0, False, 0.0, ''
        v = _cur(c)
        lit = p.isPulse is False and (v == c['value'] if p.isMenu else abs(v - c['value']) < 0.5)
        return 0.0, lit, mark, ''
    low, high, _ = _range(c)
    v = _cur(c)
    pad = 1.0 if (mark or c['par'] in op('/show/engine').module.focus_knobs()) else 0.0
    return k.norm(v, low, high), v != p.default, pad, k.text(v)


def flash(key):
    """Make the control(s) of a par ('Shortcut:Par') flash, for pulses AUTO fires (BOOM, actions, dolly)."""
    m = M()
    f = dict(m.fetch('Flashes', {}, search=False))
    f[key] = absTime.seconds
    m.store('Flashes', f)
    m.op('script_data').cook(force=True)


def cook_data(scriptOp):
    """Rows 0-1: every control (knobs.data). Row 2: when each control last changed. Rows 3-4: the 16 most
    recent changes for the flash pass (glsl_flash): x, y, size, time / kind, half height."""
    k, m = K(), M()
    found = controls()
    states = [state(c) for c in found]
    now = absTime.seconds
    keys = [(round(s[0], 3), bool(s[1]), s[3]) for s in states]
    prev = m.fetch('Panelprev', None, search=False)
    times = m.fetch('Paneltimes', None, search=False)
    if prev is None or times is None or len(prev) != len(keys):
        times = [-100.0] * len(keys)       # first cook: nothing flashes
    else:
        # times saved in the .toe come from an older session (absTime restarts on open): drop future ones
        times = [now if a != b else (t if t <= now else -100.0) for a, b, t in zip(keys, prev, times)]
    pulses = {p: t for p, t in m.fetch('Flashes', {}, search=False).items() if 0.0 <= now - t < 2.0}
    for n, c in enumerate(found):
        t = pulses.get(c['par'] + '#' + str(c.get('label'))) if 'call' in c else pulses.get(c['par'])
        if t is not None and t > times[n] and not c.get('label') in ('<', '>'):
            times[n] = t
    m.store('Panelprev', keys)
    m.store('Paneltimes', times)
    m.store('Flashes', pulses)
    out = np.zeros((5, len(found), 4), np.float32)
    out[:2] = k.data(found, [s[:3] for s in states])
    out[2, :, 0] = times
    out[2, :, 1] = [c.get('group', 0) for c in found]     # 1 = POP control: own backing colour
    out[3, :, 3] = -100.0
    recent = sorted((n for n in range(len(found)) if now - times[n] < 2.0), key=lambda n: -times[n])[:16]
    for j, n in enumerate(recent):
        c = found[n]
        out[3, j] = c['x'], c['y'], c.get('r', c.get('hw')), times[n]
        out[4, j] = c['kind'], c.get('hh', 0.0), 0.0, 0.0
    scriptOp.copyNumpyArray(out)


def cook_labels(scriptOp):
    k = K()
    found = controls()
    scriptOp.clear()
    measure = scriptOp.parent().op('text_labels').evalTextSize
    for row in k.labels(found, [state(c)[3] for c in found], measure, status()):
        scriptOp.appendRow(row)


def down(panel):
    k = K()
    x, y = panel.panel.u.val * k.WIDTH, panel.panel.v.val * k.HEIGHT
    c = k.hit(controls(), x, y)
    if c is None or c['par'] not in ('Show:Tap', 'Show:Beatevery'):   # tapping the tempo keeps AUTO running
        op('/show/engine').module.mark_input()
    if c is None:
        return
    p = _par(c)
    if c['par'] == 'Show:Shift':
        p.val = not p.eval()
        if not p.eval():
            shift_release()
        return
    if 'step' in c:
        pend = _pending()['vals']
        cur = pend[c['par']] if c['par'] in pend else p.menuIndex
        nxt = (cur + c['step']) % len(p.menuNames)
        if _shifting(c):
            _set(c, nxt)
        else:
            p.menuIndex = nxt
        return
    if 'call' in c:
        _act(c, 'call', c['call'])          # exec: PREV / NEXT assign (eval refused them)
        return
    if c['kind'] == k.BUTTON:
        if p.isPulse:
            _act(c, 'pulse', None)
        elif p.isToggle and 'fixed' not in c:     # fixed: TD PLAY / TD PAUSE set, not flip
            _set(c, not _cur(c))
        else:
            _set(c, c['value'])
        return
    m = M()
    now = time.perf_counter()
    last = m.fetch('Knoblast', (None, 0.0), search=False)
    m.store('Knoblast', (c['par'], now))
    if last[0] == c['par'] and now - last[1] < k.DOUBLE_CLICK:
        _set(c, p.default)
        return
    m.store('Knobdrag', (c, x, y, _cur(c)))


def drag(panel):
    k, m = K(), M()
    held = m.fetch('Knobdrag', None, search=False)
    if held is None:
        return
    c, x, y, start = held
    low, high, whole = _range(c)
    moved = panel.panel.u.val * k.WIDTH - x + panel.panel.v.val * k.HEIGHT - y
    value = k.dragged(start, moved, high - low)
    _set(c, k.from_norm(k.norm(value, low, high), low, high, whole))


def up():
    M().unstore('Knobdrag')
