# MetalShow control panel (/control), from the laser rig's Video Knobs: one shader (knobs.glsl) draws every control from a
# small data image and one Text TOP writes the labels. Here: where things go, and what the mouse does.
# No TD calls in here. The TD side is panel.py.

import numpy as np

WIDTH = 1920
HEIGHT = 650
HERO_R, KNOB_R = 44, 30
KNOB, BUTTON = 0.0, 1.0
DRAG_PIXELS = 220.0            # dragging this far covers the whole range
DOUBLE_CLICK = 0.35            # seconds; double click = back to default
TEXT_LIFT = 3                  # the measured height includes room below the letters

TITLE = ''
PAD_KNOBS = ()
COL_W = 240
# effect columns: (shortcut, title, knobs (par, label), action buttons (Action1 label, Action2 label))
EFFECTS = (('Metal', 'METAL', (('Feedback', 'feedback'), ('Relief', 'relief'), ('Zoom', 'zoom'), ('Rotate', 'rotate'),
                                ('Mirror', 'mirror'), ('Shine', 'shine'), ('Color', 'color'), ('Video', 'video')), ('CLEAR', 'MELT')),
           ('Mosh', 'EDGE', (('Edge', 'edge'), ('Glow', 'glow'), ('Thick', 'thick'), ('Keep', 'keep'),
                             ('Etrail', 'trail'), ('Tint', 'tint'), ('Stretch', 'stretch'), ('Relief', 'relief')), ('BLOOM', 'CLEAN')),
           ('Blob', 'BLOB', (('Threshold', 'threshold'), ('Size', 'size'), ('Split', 'split'), ('Glow', 'glow'),
                             ('Trail', 'trail'), ('Labels', 'labels')), ('LABELS', 'WIPE')),
           ('Strobe', 'CRASH', (('Cells', 'cells'), ('Rate', 'rate'), ('Duty', 'duty'), ('Kick', 'kick'),
                                ('Source', 'source')), ('FLASH', 'INVERT')),
           ('Luma', 'LUMA', (('Split', 'split'), ('Width', 'width'), ('Soft', 'soft'), ('Order', 'order'),
                             ('Beat', 'beat')), ('FLIP', 'SWEEP')))
AUDIO = (('Audio:Gain', 'gain'), ('Audio:Amount', 'amount'), ('Audio:Kick', 'kick'), ('Show:Padfade', 'pad fade'))
STAGES = ('METAL', 'EDGE', 'BLOB')
MASTER_KNOBS = (('Boom:Bright', 'bright'), ('Boom:Keep', 'keep'), ('Show:Idle', 'idle sec'), ('Show:Autostep', 'auto step'),
                ('Boom:Length', 'boom len'), ('Boom:Fb', 'boom fb'), ('Boom:Strobehz', 'strobe hz'), ('Boom:Pump', 'kick pump'))
INPUT_KNOBS = (('Input:Mix', 'mix'), ('Hud:Interval', 'interval'), ('Hud:Tickerspeed', 'ticker'),
               ('Hud:Scan', 'scan'), ('Hud:Phosphor', 'phosphor'), ('Hud:Glitch', 'glitch'))
Y_TITLE, Y_BTN1, Y_BTN2, Y_TIME = 625, 205, 172, 92
Y_KNOBS = (552, 460, 368, 276)     # up to 8 knobs per column, 2 per row
Y_PRESET = 138                     # STORE 1 2 3 4
Y_SETUP = 42                       # setup row under the timeline (MetalShow.81)
PAD_BOX = (120, 505, 1.0)          # gamepad drawing: centre x, y (y up), pixels per unit (MetalShow.88)
PATHS = {'Metal': '/fx_metal', 'Mosh': '/fx_mosh', 'Blob': '/fx_blob', 'Strobe': '/fx_strobe', 'Luma': '/fx_luma'}

def row(items, y, par, hh=12):
    gap = 1.0 / len(items)
    return [dict(par=par, value=v, label=label, kind=BUTTON, x=WIDTH * gap * (i + 0.5), y=y,
                 hw=WIDTH * gap / 2 - 5, hh=hh) for i, (v, label) in enumerate(items)]


def stepper(y, par, x0=0, w=WIDTH, hh=12):
    """Arrows either side of a wide button showing the menu's current entry. All three step it."""
    common = dict(par=par, kind=BUTTON, y=y, hh=hh, value=None)
    return [dict(common, step=-1, label='<', x=x0 + 23, hw=18),
            dict(common, step=1, label='', x=x0 + w / 2, hw=w / 2 - 46),
            dict(common, step=1, label='>', x=x0 + w - 23, hw=18)]


def button(par, label, x, y, hw, value=1.0, hh=13, call=None):
    c = dict(par=par, value=value, label=label, kind=BUTTON, x=x, y=y, hw=hw, hh=hh)
    if call:
        c['call'] = call
    return c


def knob(par, label, x, y, r=KNOB_R):
    return dict(par=par, label=label, kind=KNOB, x=x, y=y, r=r)


def device_name(label):
    """A menu label short enough for the stepper: no driver in brackets."""
    return 'IN  ' + label.split(' (')[0].upper()[:13]


def controls():
    """Every control: par ('Shortcut:Par'), label, kind, centre x, y (0 at the bottom), then radius for a
    knob, or half width and half height for a button, whose value is what it sets its par to, or whose
    step moves its menu, or whose call runs a line of Python."""
    out = []
    # audio column
    out += stepper(Y_TITLE, 'Audio:Device', 0, COL_W, hh=14)
    # top-left: gamepad blueprint (pad_blueprint.glsl, box PAD_BOX); audio knobs below it (MetalShow.88).
    # Screen widths + STRETCH / LETTERBOX left the panel: venue setup, /show page Screens.
    for i, (par, label) in enumerate(AUDIO):
        out.append(knob(par, label, 65 + 110 * (i % 2), Y_KNOBS[2 + i // 2]))
    out.append(button('Show:Mapping', 'MAPPING', 65, Y_BTN1, 50))
    out.append(dict(par='Show:Screens', kind=BUTTON, step=1, label='', raw=True, value=None, x=175, y=Y_BTN1, hw=50, hh=13))
    out.append(button('Show:Panic', 'PANIC  FB RESET ALL', COL_W / 2, Y_BTN2, 105))
    # gamepad on / off (one map: PLAY, anyone can play). Plugging the pad in turns it on.
    out.append(button('Show:Padon', 'PAD  ON / OFF', COL_W / 2, Y_PRESET, 105, hh=11))
    # one column per effect
    for e, (sc, title, knobs, actions) in enumerate(EFFECTS):
        x0 = COL_W * (e + 1)
        cx = x0 + COL_W / 2
        out.append(button(sc + ':On', title, x0 + 66, Y_TITLE, 61, hh=15))
        for k in (1, 2, 3):      # which screens (thirds) this effect shows on
            out.append(dict(button('%s:Screen%d' % (sc, k), 'S%d' % k, x0 + 115 + 36 * k, Y_TITLE, 15, hh=15), need=k if k > 1 else 2))
        for i, (par, label) in enumerate(knobs):
            out.append(knob(sc + ':' + par, label, cx - 55 + 110 * (i % 2), Y_KNOBS[i // 2]))
        if sc == 'Metal':   # NOISE on/off: the liquid noise under the chrome (off = only the picture shapes it)
            out.append(button('Metal:Noise', 'NOISE', cx - 74, Y_BTN1, 34))
            out.append(button('Metal:Action1', actions[0], cx, Y_BTN1, 34))
            out.append(button('Metal:Action2', actions[1], cx + 74, Y_BTN1, 34))
        elif sc == 'Mosh':  # edge / mosh look switch instead of the mosh bloom
            out.append(dict(par='Mosh:Look', kind=BUTTON, step=1, label='', raw=True, value=None, x=cx - 55, y=Y_BTN1, hw=50, hh=13))
            out.append(button(sc + ':Action2', actions[1], cx + 55, Y_BTN1, 50))
        else:
            out.append(button(sc + ':Action1', actions[0], cx - 55, Y_BTN1, 50))
            out.append(button(sc + ':Action2', actions[1], cx + 55, Y_BTN1, 50))
        out.append(button(sc + ':Reset', 'RESET', cx - 55, Y_BTN2, 50))
        out.append(button(sc + ':Fbreset', 'FB RST', cx + 55, Y_BTN2, 50))
        if sc == 'Blob':    # colour scheme stepper (MetalShow.56), free knob row
            out.append(dict(par='Blob:Color', kind=BUTTON, step=1, label='', raw=True, value=None, x=cx - 55, y=Y_KNOBS[3], hw=50, hh=13))
            out.append(knob('Pop:Popgrow', 'pop grow', cx + 55, Y_KNOBS[3]))     # cloud swells with the bass (MetalShow.84)
        # presets: STORE arms, then a number saves; a number alone recalls (lit = current preset)
        out.append(button(sc + ':Storearm', 'STORE', x0 + 36, Y_PRESET, 30, hh=11))
        for k in range(1, 5):
            out.append(button(sc + ':Preset', str(k), x0 + 46 + 44 * k, Y_PRESET, 19, value=float(k), hh=11,
                              call="op('%s/fx').module.slot(op('%s'), %d)" % (PATHS[sc], PATHS[sc], k)))
    # particles (MetalShow.59): knobs in the free CRASH slots, bang buttons in the free LUMA slots
    cxc, cxl = COL_W * 4 + COL_W / 2, COL_W * 5 + COL_W / 2
    out.append(knob('Pop:Twist', 'pop twist', cxc + 55, Y_KNOBS[2]))
    out.append(knob('Pop:Popbass', 'pop bass', cxc - 55, Y_KNOBS[3]))
    out.append(knob('Pop:Popslice', 'pop slice', cxc + 55, Y_KNOBS[3]))
    Y3 = Y_KNOBS[3]          # particle bangs: 3 small rows
    out.append(button('Pop:Explode', 'EXPLODE', cxl - 55, Y3 + 18, 50, hh=8))
    out.append(button('Pop:Melt', 'MELT', cxl - 55, Y3, 50, hh=8))
    out.append(button('Pop:Twistbang', 'TWIST', cxl + 55, Y3 + 18, 50, hh=8))
    out.append(button('Pop:Quake', 'QUAKE', cxl + 55, Y3, 50, hh=8))
    out.append(knob('Pop:Scanline', 'scan line', cxl + 55, Y_KNOBS[2]))      # constant scan line (MetalShow.61)
    # input column: source (Resolume / HUD / mix) and the weapons HUD
    x0 = COL_W * (len(EFFECTS) + 1)
    cx = x0 + COL_W / 2
    for j, (par, label) in enumerate((('Usevideo', 'VIDEO'), ('Usehud', 'HUD'), ('Usepop', 'POP'))):   # toggles, 2+ on = mix
        out.append(button('Input:' + par, label, x0 + 42 + 78 * j, Y_TITLE, 35, hh=15))
    for i, (par, label) in enumerate(INPUT_KNOBS):
        out.append(knob(par, label, cx - 55 + 110 * (i % 2), Y_KNOBS[i // 2]))
    out.append(knob('Input:Speed', 'clip speed', cx - 55, Y_KNOBS[3]))
    # video source (MetalShow.86): Resolume over Spout, your clip folder, a camera, Giga's point clouds
    out.append(button('Input:Video', 'RESOLUME', cx + 55, Y_KNOBS[3] + 22, 50, value='resolume', hh=10))
    out.append(button('Input:Video', 'MY CLIPS', cx + 55, Y_KNOBS[3], 50, value='clips', hh=10))
    out.append(button('Input:Video', 'CAMERA', cx + 55, Y_KNOBS[3] - 22, 50, value='camera', hh=10))
    out.append(button('Input:Video', 'POP', cx + 55, Y_KNOBS[3] - 44, 50, value='pop', hh=9))
    for s in stepper(Y_PRESET, 'Input:Clip', x0 + 5, COL_W - 10, hh=11):
        s['raw'] = True
        out.append(s)
    out.append(dict(par='Input:Blend', kind=BUTTON, step=1, label='', raw=True, value=None, x=cx - 55, y=Y_BTN1, hw=50, hh=13))
    out.append(button('Hud:Play', 'HUD PLAY', cx + 55, Y_BTN1, 50))
    out.append(dict(button('Hud:Seed', 'PREV', cx - 55, Y_BTN2, 50, call="op.Hud.par.Seed = (op.Hud.par.Seed.eval() - 1) % 11"), nolit=True))
    out.append(dict(button('Hud:Seed', 'NEXT', cx + 55, Y_BTN2, 50, call="op.Hud.par.Seed = (op.Hud.par.Seed.eval() + 1) % 11"), nolit=True))
    # master column: auto, cuts, brightness, the drop buttons
    x0 = COL_W * (len(EFFECTS) + 2)
    cx = x0 + COL_W / 2
    out.append(button('Show:Auto', 'AUTO', x0 + 66, Y_TITLE, 61, hh=15))
    out.append(button('Show:Cut', 'CUT', x0 + 180, Y_TITLE, 50, hh=15))
    for i, (par, label) in enumerate(MASTER_KNOBS):
        out.append(knob(par, label, cx - 55 + 110 * (i % 2), Y_KNOBS[i // 2]))
    out.append(button('Boom:Boom', 'BOOM', cx - 55, Y_BTN1, 50))
    out.append(button('Boom:Strobe', 'STROBE', cx + 55, Y_BTN1, 50))
    out.append(button('Boom:Tilt', 'ZOOM', cx - 76, Y_BTN2, 35))
    out.append(button('Show:Drop', 'DROP', cx, Y_BTN2, 35, call="op('/show/engine').module.drop_press()"))
    out.append(button('Boom:Black', 'BLACK', cx + 76, Y_BTN2, 35))  # MetalShow.80: hard blackout back, panel only
    # beat row: TAP tempo, bang every N beats (stepper), DOLLY bang by hand
    out.append(button('Show:Tap', 'TAP', x0 + 30, Y_PRESET, 24, hh=11))
    for st in stepper(Y_PRESET, 'Show:Beatevery', x0 + 54, 134, hh=11):
        st['raw'] = True
        out.append(st)
    out.append(button('Pop:Dollybang', 'DOLLY', x0 + 212, Y_PRESET, 24, hh=11))
    # timeline row
    out.append(knob('Show:Section', 'section min', 65, Y_TIME, 29))
    out.append(knob('Show:Fadetime', 'fade sec', 175, Y_TIME, 29))
    out.append(button('Show:Play', 'PLAY', 320, Y_TIME, 50, hh=16))
    out.append(button('Show:Restart', 'RESTART', 430, Y_TIME, 50, hh=16))
    out.append(button('Show:Next', 'NEXT', 540, Y_TIME, 50, hh=16))
    for i, name in enumerate(STAGES):
        out.append(button('Show:Stage', name, 690 + 120 * i, Y_TIME, 55, value=float(i), hh=16,
                          call="op('/show/engine').module.go_stage(%d)" % i))
    # POP source (timeline row, right side): model, grade, spin, scan
    for s in stepper(Y_TIME, 'Pop:Model', 975, 200, hh=16):
        s['raw'] = True
        out.append(s)
    for s in stepper(Y_TIME, 'Grade:Look', 1185, 230, hh=16):
        s['raw'] = True
        out.append(s)
    out.append(knob('Pop:Spin', 'pop spin', 1500, Y_TIME, 29))
    out.append(knob('Pop:Scanrate', 'pop scan', 1610, Y_TIME, 29))
    out.append(knob('Input:Hudtop', 'hud text', 1720, Y_TIME, 29))
    out.append(button('Show:Shift', 'SHIFT', 1840, Y_TIME, 60, hh=20))   # hold changes, apply all together (MetalShow.58)   # HUD neon text on top of the effects (MetalShow.55)
    # setup row (MetalShow.81): TouchDesigner's own timeline, audio auto gain + driver, camera input driver + device
    out.append(dict(button('Time:play', 'TD PLAY', 290, Y_SETUP, 45, value=1.0, hh=11), fixed=True))
    out.append(dict(button('Time:play', 'TD PAUSE', 385, Y_SETUP, 45, value=0.0, hh=11), fixed=True))
    out.append(button('Audio:Autogain', 'AUTO GAIN', 490, Y_SETUP, 52, hh=11))
    for s in stepper(Y_SETUP, 'Audio:Driver', 548, 250, hh=11):
        s['raw'], s['prefix'], s['names'] = True, 'AUD ', {'default': 'DIRECTSOUND'}
        out.append(s)
    for s in stepper(Y_SETUP, 'Input:Viddriver', 806, 245, hh=11):
        s['raw'], s['prefix'] = True, 'CAM '
        out.append(s)
    for s in stepper(Y_SETUP, 'Input:Viddevice', 1059, 270, hh=11):
        s['raw'], s['maxlen'] = True, 18
        out.append(s)
    out.append(dict(button('Input:Clipfolder', 'CLIP FOLDER', 1393, Y_SETUP, 58, hh=11,
                           call="op('/input').op('clip_folder').module.choose()"), nolit=True))
    for c in out:                # POP controls sit in other columns: group 1 = their own backing colour
        if c['par'].startswith('Pop:'):
            c['group'] = 1
    return out


def norm(value, low, high):
    return max(0.0, min(1.0, (value - low) / (high - low))) if high > low else 0.0


def from_norm(n, low, high, whole=False):
    value = low + (high - low) * max(0.0, min(1.0, n))
    return int(round(value)) if whole else value


def text(value):
    """A value short enough to sit inside a knob."""
    if isinstance(value, int):
        return str(value)
    return '{:.0f}'.format(value) if abs(value) >= 100 else '{:.2f}'.format(value)


def hit(items, x, y):
    """The control under a pixel, or None."""
    for c in items:
        if c['kind'] == KNOB and np.hypot(x - c['x'], y - c['y']) <= c['r'] + 4:
            return c
        if c['kind'] == BUTTON and abs(x - c['x']) <= c['hw'] and abs(y - c['y']) <= c['hh']:
            return c
    return None


def dragged(start, moved_pixels, whole_range):
    """Knob position after a drag, up or right for more."""
    return start + moved_pixels / DRAG_PIXELS * whole_range


def data(items, states):
    """The shader's data image, 2 x N x 4 float. states gives (position 0-1, lit, pad) per control.
    Row 0: x, y, radius or half width, position. Row 1: kind, lit, half height, pad."""
    out = np.zeros((2, len(items), 4), np.float32)
    for i, (c, (position, lit, pad)) in enumerate(zip(items, states)):
        out[0, i] = c['x'], c['y'], c.get('r', c.get('hw')), position
        out[1, i] = c['kind'], float(lit), c.get('hh', 0.0), float(pad)
    return out


def labels(items, shown, measure, status):
    """Rows for the Text TOP's Specification DAT, which places text by its lower left corner.
    shown gives the text inside each knob, measure a text's width and height."""
    def centred(x, y, words):
        w, h = measure(words)
        return [round(x - w / 2), round(y - h / 2) + TEXT_LIFT, words]

    rows = [['x', 'y', 'text'], [14, HEIGHT - 28, TITLE], [14, 8, status]]
    for c, inside in zip(items, shown):
        if c['kind'] == KNOB:
            rows.append(centred(c['x'], c['y'] - c['r'] - 14, c['label']))
            rows.append(centred(c['x'], c['y'], inside))
        else:
            rows.append(centred(c['x'], c['y'], inside or c['label']))
    return rows
