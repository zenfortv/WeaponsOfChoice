# /fx_metal actions. Action1 = clear the feedback (fresh chrome), Action2 = melt burst
# (the a2 envelope triples Melt for about a second, see the displace expressions).

def action1(comp):
    for n in ('feedback_pl', 'feedback_smooth'):
        o = comp.op(n)
        if o is not None:
            o.par.resetpulse.pulse()


def action2(comp):
    pass
