# Shared by every effect COMP (/fx_metal, /fx_mosh, /fx_blob, /fx_strobe) as its 'fx' DAT.
# Every effect has the same page 'Effect': On, its 3-4 look knobs, Action1, Action2, Reset, Fbreset,
# and a page 'Internal' with Fade (seconds of the On fade; the show sets it before it switches).
# What Action1/Action2 do is up to the effect's own 'engine' DAT (action1(comp), action2(comp)).
# Every action also fires a short envelope, null_act a1/a2 (1 -> 0 in about a second), for expressions.

FIXED = {'On', 'Fade'}


def reset(comp):
    """Look knobs back to their defaults."""
    for p in comp.customPars:
        if p.isPulse or p.readOnly or p.name in FIXED:
            continue
        p.val = p.default


def fb_reset(comp):
    """Clear every feedback / cache buffer inside."""
    for o in comp.findChildren(type=feedbackTOP) + comp.findChildren(type=cacheTOP):
        o.par.resetpulse.pulse()
    eng = comp.op('engine')
    if eng is not None and hasattr(eng.module, 'fb_reset'):
        eng.module.fb_reset(comp)


def action(comp, n):
    c = comp.op('const_act')
    if c is not None:
        c.par['const%dvalue' % (n - 1)] = 1
        run("op(%r).par.const%dvalue = 0" % (c.path, n - 1), delayFrames=2)
    eng = comp.op('engine')
    f = getattr(eng.module, 'action%d' % n, None) if eng is not None else None
    if f is not None:
        f(comp)


def on_pulse(par):
    comp = par.owner
    if par.name == 'Reset':
        reset(comp)
    elif par.name == 'Fbreset':
        fb_reset(comp)
    elif par.name == 'Action1':
        action(comp, 1)
    elif par.name == 'Action2':
        action(comp, 2)


# ---- presets: 4 slots per effect in the 'presets' table DAT (row = slot, columns = look knobs).
# Panel: STORE arms (Storearm), then a slot button saves; a slot button without STORE recalls.

def _look(comp):
    return [p for p in comp.customPars if not p.isPulse and not p.readOnly and p.name not in FIXED
            and p.name not in ('Storearm', 'Preset')]


def _table(comp):
    t = comp.op('presets')
    if t is None:
        t = comp.create(tableDAT, 'presets')
        t.nodeX, t.nodeY = comp.op('fx').nodeX, comp.op('fx').nodeY - 150
    names = ['slot'] + [p.name for p in _look(comp)]
    if t.numRows == 0 or [c.val for c in t.row(0)] != names:
        old = {t[r, 0].val: {t[0, c].val: t[r, c].val for c in range(1, t.numCols)} for r in range(1, t.numRows)} if t.numRows else {}
        t.clear()
        t.appendRow(names)
        for s in range(1, 5):
            t.appendRow([s] + [old.get(str(s), {}).get(n, '') for n in names[1:]])
    return t


def slot(comp, n):
    if comp.par.Storearm.eval():
        store(comp, n)
        comp.par.Storearm = False
    else:
        recall(comp, n)


def store(comp, n):
    t = _table(comp)
    for p in _look(comp):
        t[n, p.name] = p.eval()
    comp.par.Preset = n


def recall(comp, n):
    t = _table(comp)
    for p in _look(comp):
        v = t[n, p.name].val if t[n, p.name] is not None else ''
        if v == '':
            continue
        p.val = int(float(v)) if p.style == 'Int' else (float(v) if p.isNumber else v)
    comp.par.Preset = n
