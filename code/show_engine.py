# /show (op.Show): the timeline and the gamepad. Lives in /show as the 'engine' DAT.
#
# Timeline: STAGES play in order, Section minutes each. At every stage change the effect of that stage
# fades in and the others fade out over Fadetime seconds (slow crossfade). Play pauses / runs,
# Restart goes back to stage 1, Next jumps on. Strobe is never switched by the timeline.
#
# Pad (joystick CHOP channel -> what it does). Same buttons for every effect: the actions go to every
# effect that is on, and each effect does its own thing with them.
#   X / Y / A / B   metal / mosh / blob / strobe on-off (fade Padfade seconds)
#   RB              Action1  (metal: clear  mosh: splat  blob: labels  strobe: flash)
#   RT              Action2  (metal: melt burst  mosh: clean  blob: clear trails  strobe: blackout)
#   LB              next stage
#   Back            panic: FB RESET on every effect
#   Start           play / pause the timeline

EFFECTS = ('/fx_metal', '/fx_mosh', '/fx_blob', '/fx_strobe', '/fx_luma')
STAGES = ('/fx_metal', '/fx_mosh', '/fx_blob')

PAD = {'b3': ('toggle', '/fx_metal'), 'b4': ('toggle', '/fx_mosh'), 'b1': ('toggle', '/fx_blob'),
       'b2': ('toggle', '/fx_strobe'), 'b6': ('action', 1), 'slider2': ('action', 2),
       'b5': ('next',), 'b7': ('panic',), 'b8': ('play',), 'b9': ('hudnext',), 'b10': ('boom',)}
PRESS = 0.5          # an axis / trigger counts as pressed above this


def S():
    return op('/show')


def set_on(path, on, fade):
    fx = op(path)
    if fx is None:
        return
    if S().par.Cut.eval():
        fade = 0.0
    fx.par.Fade = fade
    fx.par.On = on


def go_stage(n):
    s = S()
    n = max(0, min(len(STAGES) - 1, n))
    s.par.Stage = n
    s.store('stage', n)
    for path in STAGES:
        set_on(path, path == STAGES[n], s.par.Fadetime.eval())


def restart():
    S().store('elapsed', 0.0)
    go_stage(0)


def next_stage():
    s = S()
    n = (int(s.par.Stage.eval()) + 1) % len(STAGES)
    s.store('elapsed', n * s.par.Section.eval() * 60.0)
    go_stage(n)


def sleep_check():
    """An effect whose mix is 0 and that is off sleeps: its feedback / cache TOPs are bypassed, so nothing
    forces its insides to cook (feedback TOPs cook their loop every frame even when nothing shows it,
    ~15 ms for metal). It wakes the frame On goes up."""
    s = S()
    for path in EFFECTS:
        fx = op(path)
        if fx is None:
            continue
        awake = fx.par.On.eval() or fx.op('null_mix')['mix'].eval() > 0.001
        if path == '/fx_metal' and op('/fx_blob').par.On.eval():
            awake = True            # blob draws metal's picture inside its boxes
        key = 'awake_' + fx.name
        if s.fetch(key, None, search=False) == awake:
            continue
        s.store(key, awake)
        for o in fx.findChildren(type=feedbackTOP) + fx.findChildren(type=cacheTOP):
            o.bypass = not awake


def boom_sleep():
    """BOOM's feedback loop only runs while it is used (BOOM, strobe or tilt)."""
    b = op('/fx_boom')
    awake = bool(b.par.Strobe.eval() or b.par.Tilt.eval() or b.op('timer_boom')['running'].eval() > 0)
    if S().fetch('awake_boom', None, search=False) != awake:
        S().store('awake_boom', awake)
        b.op('feedback_boom').bypass = not awake


def frame():
    s = S()
    sleep_check()
    boom_sleep()
    auto_check()
    if not s.par.Play.eval():
        return
    t = s.fetch('elapsed', 0.0, search=False) + absTime.stepSeconds
    s.store('elapsed', t)
    section = max(s.par.Section.eval(), 0.05) * 60.0
    n = min(int(t // section), len(STAGES) - 1)
    if n != s.fetch('stage', -1, search=False):
        go_stage(n)
    s.par.Elapsed = t


def panic():
    for path in EFFECTS:
        fx = op(path)
        if fx is not None:
            fx.par.Fbreset.pulse()
    _flash('Show:Panic')


def press(what):
    kind = what[0]
    if kind == 'toggle':
        fx = op(what[1])
        set_on(what[1], not fx.par.On.eval(), S().par.Padfade.eval())
    elif kind == 'action':
        for path in EFFECTS:
            fx = op(path)
            if fx is not None and fx.par.On.eval():
                fx.par['Action%d' % what[1]].pulse()
                _flash(SHORTCUT[path] + ':Action%d' % what[1])
    elif kind == 'next':
        next_stage()
        _flash('Show:Next')
    elif kind == 'panic':
        panic()
    elif kind == 'play':
        S().par.Play = not S().par.Play.eval()
    elif kind == 'boom':
        op('/fx_boom').par.Boom.pulse()
        _flash('Boom:Boom')
    elif kind == 'hudnext':
        op.Hud.par.Seed = (op.Hud.par.Seed.eval() + 1) % 11
        _flash('Hud:Seed#NEXT')
    elif kind == 'source':
        i = op('/input')      # cycle VIDEO, HUD, POP, VIDEO+HUD, VIDEO+POP
        combos = ((1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 0), (1, 0, 1))
        cur = (int(i.par.Usevideo.eval()), int(i.par.Usehud.eval()), int(i.par.Usepop.eval()))
        nxt = combos[(combos.index(cur) + 1) % len(combos)] if cur in combos else combos[0]
        i.par.Usevideo, i.par.Usehud, i.par.Usepop = nxt


def pad(name, val, prev):
    """chopexec onValueChange on the joystick: fire once when a button / trigger goes down."""
    if name == 'connected':          # plug the pad in = PAD on (the panel's PAD button turns it off)
        if val >= 0.5 > prev:
            S().par.Padon = True
        return
    if not S().par.Padon.eval():
        return
    if abs(val - prev) > 0.1:
        mark_input()
    if play_mode():
        play_pad(name, val, prev)
        return
    if name == 'b5':                 # LB held = strobe + tilt
        op('/fx_boom').par.Strobe = val >= PRESS
        op('/fx_boom').par.Tilt = val >= PRESS
        return
    if name in ('p1_X', 'p1_Y'):
        if abs(val) >= PRESS > abs(prev):
            dpad(name, 1 if val > 0 else -1)
        return
    if name in PAD and val >= PRESS > prev:
        press(PAD[name])


# ---- pad focus (2026-11-20): D-pad left/right picks the column the sticks play, up/down its presets
# (INPUT column: up/down = next/previous clip). Sticks push that column's first 4 knobs up/down from where they
# are (full range in SWEEP seconds at full tilt). L3 = next HUD object, R3 = source VIDEO / HUD / MIX.
FOCUS = ('metal', 'mosh', 'blob', 'strobe', 'luma', 'input')
FX_OF = {'metal': '/fx_metal', 'mosh': '/fx_mosh', 'blob': '/fx_blob', 'strobe': '/fx_strobe', 'luma': '/fx_luma'}
STICK_SLOT = {'xaxis': 0, 'yaxis': 1, 'xrot': 2, 'yrot': 3}
SWEEP = 2.0


def focus_knobs():
    k = op('/control/knobs').module
    f = S().par.Focus.eval()
    if f == 'input':
        return [p for p, _ in k.INPUT_KNOBS][:4]
    sc, _, knobs, _ = k.EFFECTS[FOCUS.index(f)]
    return ['%s:%s' % (sc, p) for p, _ in knobs][:4]


def stick(name, v):
    """chopexec whileOn on null_held: v = stick position rounded to -4..4 (0 = dead zone)."""
    if play_mode():          # PLAY: the sticks drive the difference layers (nodes: /show/null_amp -> /sw_play_l, _r)
        return
    mark_input()
    knobs = focus_knobs()
    i = STICK_SLOT.get(name, 9)
    if i >= len(knobs) or not v:
        return
    p = op('/control/panel').module._par({'par': knobs[i]})
    low, high = p.normMin, p.normMax
    key = 'acc_' + knobs[i]
    acc = S().fetch(key, p.eval(), search=False)
    if abs(acc - p.eval()) >= 1.0 or p.style != 'Int':
        acc = p.eval()
    acc = max(low, min(high, acc + v / 4.0 * (high - low) * absTime.stepSeconds / SWEEP))
    S().store(key, acc)
    p.val = int(round(acc)) if p.style == 'Int' else acc


def dpad(name, sign):
    s = S()
    if name == 'p1_X':
        s.par.Focus = FOCUS[(FOCUS.index(s.par.Focus.eval()) + sign) % len(FOCUS)]
        return
    f = s.par.Focus.eval()
    if f == 'input':
        c = op('/input').par.Clip
        if c.menuNames:
            c.menuIndex = (c.menuIndex + sign) % len(c.menuNames)
        return
    fx = op(FX_OF[f])
    cur = int(fx.par.Preset.eval()) or (0 if sign > 0 else 1)
    n = (cur - 1 + sign) % 4 + 1
    op(FX_OF[f] + '/fx').module.slot(fx, n)
    _flash(SHORTCUT[FX_OF[f]] + ':Preset#%d' % n)


# ---- auto (2026-11-20): after Idle seconds without pad or panel input, change the look every Autostep
# seconds: 1-2 effects on (crash sometimes), a stored preset, sometimes an action or a BOOM. Any input stops it.
import random


def mark_input():
    s = S()
    s.store('last_input', absTime.seconds)
    s.par.Lastinput = absTime.seconds      # for the monitor's AUTO bar
    if s.par.Autorunning.eval() and not play_mode():     # PLAY: AUTO keeps the show moving under the guest
        s.par.Autorunning = False


def _stored_slots(fx):
    t = fx.op('presets')
    if t is None:
        return []
    return [r for r in range(1, t.numRows) if any(t[r, c].val != '' for c in range(1, t.numCols))]


def auto_step():
    s = S()
    fade = 0.0 if s.par.Cut.eval() else s.par.Autofade.eval()
    pool = ['/fx_metal', '/fx_mosh', '/fx_blob']
    on = random.sample(pool, random.choice((1, 1, 2)))
    if random.random() < 0.25:
        on.append('/fx_strobe')
    if random.random() < 0.35:          # LUMA brightness layers (MetalShow.54)
        on.append('/fx_luma')
    for path in EFFECTS:
        want = path in on
        fx = op(path)
        if bool(fx.par.On.eval()) != want:
            fx.par.Fade = fade
            fx.par.On = want
    for path in on:
        fx = op(path)
        slots = _stored_slots(fx)
        if slots and random.random() < 0.6:
            op(path + '/fx').module.recall(fx, random.choice(slots))
    if '/fx_blob' in on and random.random() < 0.3:     # blob colour scheme (MetalShow.56)
        c = op('/fx_blob').par.Color
        c.menuIndex = random.randrange(len(c.menuNames))
    if pop_visible() and random.random() < 0.35:     # another point-cloud model
        m = op('/src_pop').par.Model
        m.menuIndex = (m.menuIndex + 1) % len(m.menuNames)
    r = random.random()
    if r < 0.15:
        op('/fx_boom').par.Boom.pulse()
        _flash('Boom:Boom')
    elif r < 0.45:
        path = random.choice(on)
        op(path).par.Action1.pulse()
        _flash(SHORTCUT[path] + ':Action1')
    elif r < 0.7 and (pop_visible() or op('/input').par.Usehud.eval()):
        particle_bang()                     # explode / melt / twist / dolly the point models (MetalShow.59)


SHORTCUT = {'/fx_metal': 'Metal', '/fx_mosh': 'Mosh', '/fx_blob': 'Blob', '/fx_strobe': 'Strobe', '/fx_luma': 'Luma'}


def _flash(key):
    """Light the panel control of a pulse AUTO fired (MetalShow.42)."""
    try:
        op('/control/panel').module.flash(key)
    except Exception:
        pass


def auto_check():
    s = S()
    now = absTime.seconds
    if not s.par.Auto.eval():
        if s.par.Autorunning.eval():
            s.par.Autorunning = False
        return
    last = s.fetch('last_input', None, search=False)
    if last is not None and last > now:          # saved in an older session (absTime restarts on open)
        last = None
        s.store('auto_next', now)
    if s.fetch('auto_next', now, search=False) > now + s.par.Autostep.eval() + 1.0:
        s.store('auto_next', now)
    if last is None:
        s.store('last_input', now)
        s.par.Lastinput = now
        return
    if now - last < s.par.Idle.eval() and not play_mode():
        return
    if not s.par.Autorunning.eval():
        s.par.Autorunning = True
        s.par.Play = False
        s.store('auto_next', now)
    if now >= s.fetch('auto_next', now, search=False):
        auto_step()
        s.store('auto_next', now + s.par.Autostep.eval())
        s.par.Autonext = now + s.par.Autostep.eval()


# ---- beat (MetalShow.38): TAP tempo + bang every N beats while the automation runs ----
def tap():
    s = S()
    now = absTime.seconds
    taps = s.fetch('taps', [], search=False)
    if taps and now - taps[-1] > 2.0:
        taps = []
    taps = (taps + [now])[-8:]
    s.store('taps', taps)
    if len(taps) >= 2:
        bpm = 60.0 * (len(taps) - 1) / (taps[-1] - taps[0])
        s.par.Bpm = min(max(bpm, 60.0), 200.0)
    s.op('speed_beat').par.resetpulse.pulse()     # the beat lands on the tap


def pop_visible():
    i = op('/input')
    return bool(i.par.Usepop.eval()) or (bool(i.par.Usevideo.eval()) and i.par.Video.eval() == 'pop')


PARTICLE_BANGS = ('Dollybang', 'Quake', 'Quake', 'Quake', 'Explode', 'Melt', 'Twistbang')   # quake favoured (WAVE removed .62)


def particle_bang():
    """One of the particle moves at random (MetalShow.59): POP models and HUD weapons."""
    name = random.choice(PARTICLE_BANGS if pop_visible() else PARTICLE_BANGS[1:])
    op('/src_pop').par[name].pulse()
    _flash('Pop:' + name)


def bang():
    """A particle bang on the point cloud, BOOM on anything else."""
    if pop_visible():
        particle_bang()
    else:
        op('/fx_boom').par.Boom.pulse()
        _flash('Boom:Boom')


def beat_tick():
    s = S()
    if s.fetch('drop_armed', False, search=False):
        drop_return()
    if s.par.Beatbang.eval() and s.par.Autorunning.eval():
        bang()


# ---- PLAY pad map (MetalShow.49): /show Padmode = pro | play (panel PAD PRO / PAD PLAY, left column).
# For anyone holding the pad: nothing here changes knobs or presets for good. Taps = bangs, holds = punch-ins
# that go back on release, sticks = picture warp that springs back (nodes). AUTO keeps changing the look underneath
# (no idle wait, pad input doesn't stop it), Y asks it for the next look now.
#   A  BOOM            B (hold)  CRASH          X  HIT (dolly on POP, else Action1 of what is on)   Y  NEXT LOOK
#   LB (hold) STROBE + ZOOM     RB (hold) BLACK, release = the drop     LT  HUD punch (as PRO)   RT (hold) EDGE
#   D-pad L/R colour (Grade look)   D-pad U/D next / prev clip (POP: model, HUD only: weapon)
#   L3 next weapon   R3 TAP tempo   Back PANIC (feedback clear)   Start AUTO on / off
#   Left stick = DIFFERENCE with POP (CLIPS if POP is on screen), right stick = with CLIPS (HUD if clips are on)
#   (how far you push = how much; nodes, code/build_padplay_diff.py)
PLAY_TAP = {'b1': 'boom', 'b3': 'hit', 'b4': 'look', 'b7': 'panic', 'b8': 'auto', 'b9': 'hudnext', 'b10': 'tap'}
PLAY_HOLD = {'b2': '/fx_strobe', 'slider2': '/fx_mosh'}


def play_mode():
    return S().par.Padmode.eval() == 'play'


def play_pad(name, val, prev):
    down = val >= PRESS > prev
    up = prev >= PRESS > val
    if name == 'b5':                 # PLAY: strobe + slow zoom (Tilt par = ZOOM since MetalShow.53, no rotation)
        op('/fx_boom').par.Strobe = val >= PRESS
        op('/fx_boom').par.Tilt = val >= PRESS
    elif name == 'b6':                 # RB = DROP (MetalShow.67)
        if down:
            drop_press()
    elif name in PLAY_HOLD:
        path = PLAY_HOLD[name]
        if down:
            S().store('held_' + name, bool(op(path).par.On.eval()))
            set_on(path, True, 0.1)
        elif up and not S().fetch('held_' + name, True, search=False):
            set_on(path, False, 0.3)
    elif name in ('p1_X', 'p1_Y'):
        if abs(val) >= PRESS > abs(prev):
            play_dpad(name, 1 if val > 0 else -1)
    elif down and name in PLAY_TAP:
        play_tap(PLAY_TAP[name])


def play_tap(what):
    s = S()
    if what == 'boom':
        op('/fx_boom').par.Boom.pulse()
        _flash('Boom:Boom')
    elif what == 'hit':
        on = [p for p in EFFECTS if op(p).par.On.eval()]
        if op('/input').par.Usehud.eval() and not pop_visible():
            particle_bang()                 # the HUD weapon model moves
        if pop_visible():                  # MetalShow.70: X on POP = DOLLY every time
            op('/src_pop').par.Dollybang.pulse()
            _flash('Pop:Dollybang')
        elif not on:
            bang()
        else:
            for p in on:
                op(p).par.Action1.pulse()
                _flash(SHORTCUT[p] + ':Action1')
    elif what == 'look':
        auto_step()
        s.store('auto_next', absTime.seconds + s.par.Autostep.eval())
        s.par.Autonext = absTime.seconds + s.par.Autostep.eval()
    elif what == 'panic':
        panic()
    elif what == 'auto':
        s.par.Auto = not s.par.Auto.eval()
    elif what == 'hudnext':
        press(('hudnext',))
    elif what == 'tap':
        tap()
        _flash('Show:Tap')


def _step(p, sign):
    if p.menuNames:
        p.menuIndex = (p.menuIndex + sign) % len(p.menuNames)


def play_dpad(name, sign):
    if name == 'p1_X':
        _step(op('/grade').par.Look, sign)
        return
    i = op('/input')
    if pop_visible():
        _step(op('/src_pop').par.Model, sign)
    elif i.par.Usevideo.eval() and i.par.Video.eval() == 'clips':
        _step(i.par.Clip, sign)
    else:
        op.Hud.par.Seed = (op.Hud.par.Seed.eval() + sign) % 11
        _flash('Hud:Seed#' + ('NEXT' if sign > 0 else 'PREV'))


# ---- DROP (MetalShow.67, build_drop.py): fade to black, come back on something different ----
def drop_press():
    s = S()
    if not s.par.Drop.eval():
        s.store('drop_armed', False)
        s.par.Drop = True
    elif s.par.Dropbeat.eval():
        s.store('drop_armed', True)        # beat_tick brings it back on the next beat
    else:
        drop_return()
    _flash('Show:Drop#DROP')


def drop_return():
    s = S()
    s.store('drop_armed', False)
    new_scene()
    s.par.Drop = False


def new_scene():
    """Something different, picked while the screen is black: effects cut, other source / colour / clip, trails cleared."""
    s = S()
    cut = s.par.Cut.eval()
    s.par.Cut = True
    auto_step()
    s.par.Cut = cut
    i = op('/input')
    combos = ((1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 0), (1, 0, 1))
    cur = (int(i.par.Usevideo.eval()), int(i.par.Usehud.eval()), int(i.par.Usepop.eval()))
    i.par.Usevideo, i.par.Usehud, i.par.Usepop = random.choice([c for c in combos if c != cur])
    if i.par.Usevideo.eval() and i.par.Video.eval() == 'clips' and i.par.Clip.menuNames:
        i.par.Clip.menuIndex = random.randrange(len(i.par.Clip.menuNames))
    g = op('/grade').par.Look
    pick = [k for k, n in enumerate(g.menuNames) if n != 'off' and k != g.menuIndex]
    if pick:
        g.menuIndex = random.choice(pick)
    panic()
