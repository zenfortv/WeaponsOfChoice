# /fx_mosh engine: one input (the chain), the shaders from the old TdMosh, driven once per frame.
# Knobs: Amount (how much moshes), Trail (vectors linger), Block (1-4 = 16/32/64/128 px blocks), Crush.
# Action1 = splat (a mosh that grows from one point, holds, then washes away), Action2 = clean (I-frame).
# Audio: op.Audio null_bands low/mid/high/kick, scaled by the global Audio Amount there.
# The rest is fixed at the values the old setup was tuned to.

import random

FULL_REACH = 3.0      # splat radius that has passed every corner (mosh.glsl)
WASH_LEAD = 0.5       # the clean wave starts this far behind the origin
SPREAD, LOCK, RELEASE, STUTTER = 20.0, 30.0, 9.5, 1.0
RESIDUAL, CHROMA, GAIN, LEAK, LIQUID, TARGET = 1.5, 0.474, -1.0, 0.012, 1.0, 2.0
W, H = 1920, 1080

S = dict(seed=0.0, iframe=30, burst=0.0)
SPLAT = dict(state='idle', origin=(0.5, 0.5), reach=0.0, wash=0.0, shape=0.0, lock=0.0, moving=True, turn=0.0)


def action1(comp):
    """Splat. A second press while it holds lets it wash away."""
    if SPLAT['state'] == 'idle':
        SPLAT.update(state='grow', origin=(random.uniform(0.15, 0.85), random.uniform(0.15, 0.85)),
                     reach=0.05, wash=0.0, moving=True, turn=0.3, shape=random.uniform(0.0, 50.0))
    elif SPLAT['state'] in ('grow', 'lock'):
        SPLAT.update(state='wash', wash=0.0)


def action2(comp):
    clean()


def fb_reset(comp):
    clean()


def clean():
    S['iframe'] = 2
    S['burst'] = 0.0
    SPLAT.update(state='idle', reach=0.0, wash=0.0)


def _splat(dt, kick):
    s = SPLAT
    s['turn'] -= dt
    if s['turn'] <= 0:
        s['moving'] = not s['moving']
        s['turn'] = random.uniform(0.25, 0.8) if s['moving'] else random.uniform(0.1, 0.45) * STUTTER * 1.5
    if kick:
        s['moving'], s['turn'] = True, 0.25
    if s['state'] == 'grow':
        if s['moving']:
            s['reach'] += FULL_REACH / SPREAD * dt / 0.6
        if s['reach'] >= FULL_REACH:
            s.update(state='lock', lock=LOCK)
    elif s['state'] == 'lock':
        s['lock'] -= dt
        if s['lock'] <= 0:
            s.update(state='wash', wash=0.0)
    elif s['state'] == 'wash':
        s['wash'] += (FULL_REACH + WASH_LEAD) / RELEASE * dt
        if s['wash'] >= FULL_REACH + WASH_LEAD:
            s.update(state='idle', reach=0.0, wash=0.0)
    return 1.0 if s['state'] in ('grow', 'lock') and not s['moving'] else 0.0


def frame():
    m = parent()
    if m.op('null_mix')['mix'].eval() <= 0.001:
        return
    dt = absTime.stepSeconds
    bands = op.Audio.op('null_bands')
    low, mid, high, kick = (bands[c].eval() if bands[c] is not None else 0.0 for c in ('low', 'mid', 'high', 'kick'))

    stop = _splat(dt, kick > 0.5)
    amount = min(1.0, m.par.Amount.eval() + low * 0.3)
    refresh = (1.0 - amount) ** 2
    if S['iframe'] > 0:
        S['iframe'] -= 1
        refresh, amount = 1.0, 0.0

    S['seed'] = (S['seed'] + 1.618) % 1000.0
    seed = S['seed']
    merge = (1, 2, 4, 8)[max(1, min(4, int(m.par.Block.eval()))) - 1]
    gain = GAIN * (1.0 + mid * 1.5)
    shatter = high * 0.35

    f = m.op('glsl_field').par
    f.vec0valuex, f.vec1valuex, f.vec2valuex = gain, 0.0, m.par.Trail.eval()
    f.vec3valuex, f.vec4valuex, f.vec5valuex = merge, shatter, seed
    f.vec6valuex, f.vec7valuex = TARGET, 0.0
    f.vec8valuex = f.vec8valuey = f.vec9valuex = f.vec9valuey = 0.0

    g = m.op('glsl_mosh').par
    g.vec0valuex, g.vec0valuey = W / 16.0, H / 16.0
    g.vec1valuex, g.vec2valuex = merge, refresh
    g.vec3valuex, g.vec4valuex = RESIDUAL, CHROMA
    g.vec5valuex, g.vec6valuex = m.par.Crush.eval(), LEAK
    g.vec7valuex, g.vec8valuex = 0.0, 0.0
    g.vec9valuex = seed
    g.vec10valuex, g.vec10valuey = SPLAT['origin']
    g.vec10valuez, g.vec10valuew = SPLAT['reach'], SPLAT['wash']
    g.vec11valuex, g.vec12valuex, g.vec13valuex = stop, SPLAT['shape'], LIQUID
