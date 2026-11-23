# Words of the show monitor (/monitor/text_mon), matching monitor.glsl's layout (1030 x 360, y from the bottom).
# script_labels (Script DAT) calls rows(); it re-cooks only when one of the pars read here changes.

TEXT_LIFT = 3


def rows(measure):
    s, i, b = op('/show'), op('/input'), op('/fx_boom')
    out = [['x', 'y', 'text']]

    def left(x, y, t):
        w, h = measure(t)
        out.append([round(x), round(y - h / 2) + TEXT_LIFT, t])

    def centred(x, y, t):
        w, h = measure(t)
        out.append([round(x - w / 2), round(y - h / 2) + TEXT_LIFT, t])

    def label(p):
        return p.menuLabels[p.menuIndex] if p.menuLabels else str(p.eval())

    # audio
    left(30, 335, 'AUDIO IN   AUTO GAIN ON   thin = raw' if op('/audio').par.Autogain.eval() else 'AUDIO IN   RAW   (auto gain off)')
    for x, t in ((70, 'LOW'), (165, 'MID'), (260, 'HIGH'), (355, 'KICK')):
        centred(x, 30, t)
    # beat + auto + holds + fps
    left(430, 335, 'BEAT   %d BPM   bang /%s' % (round(s.par.Bpm.eval()), s.par.Beatevery.eval()))
    if not s.par.Auto.eval():
        state = 'AUTO OFF'
    elif s.par.Autorunning.eval():
        state = 'AUTO RUNNING  > next change'
    else:
        state = 'AUTO ARMED  > starts when idle'
    left(430, 215, state)
    left(430, 148, 'idle %ds   step %ds' % (s.par.Idle.eval(), s.par.Autostep.eval()))
    tw = (270 - 16) / 3.0
    for k, t in enumerate(('STROBE', 'ZOOM', 'BLACK')):
        centred(430 + tw / 2 + k * (tw + 8), 112, t)
    left(430, 70, 'FPS   marks 20 / 25 / 30')
    # now
    left(730, 335, 'NOW')
    fw = (290 - 18) / 4.0
    for k, t in enumerate(('METAL', 'EDGE', 'BLOB', 'CRASH')):
        centred(730 + fw / 2 + k * (fw + 6), 285, t)
    iw = (290 - 12) / 3.0
    for k, t in enumerate(('VIDEO', 'HUD', 'POP')):
        centred(730 + iw / 2 + k * (iw + 6), 240, t)
    src = i.par.Video.eval()
    if src == 'resolume':       # Spout gives 128x128 until a sender is there
        extra = 'SPOUT OK' if i.op('spout_resolume').width > 128 else 'NO SIGNAL - start Resolume output'
    elif src == 'clips':
        extra = 'FOLDER ' + str(i.par.Clipfolder.eval()).replace(chr(92), '/').rstrip('/').split('/')[-1].upper()
    else:
        extra = ''
    left(730, 195, 'SOURCE %s    %s' % (label(i.par.Video).upper(), extra))
    clip = i.par.Clip.eval().rsplit('.', 1)[0].upper()
    left(730, 170, clip[:26] or '-')
    left(730, 118, 'GRADE  %s' % label(op('/grade').par.Look))
    left(730, 96, 'POP MODEL  %s' % label(op('/src_pop').par.Model).upper())
    return out


def onCook(scriptOp):
    scriptOp.clear()
    measure = scriptOp.parent().op('text_mon').evalTextSize
    for r in rows(measure):
        scriptOp.appendRow(r)
    return
