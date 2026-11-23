# /show/kantan_load (MetalShow.85): load a kantan mapping project (.json) without kantan's file dialog.
# Same steps as kantan's own Projecter.Load(). Used by /show page Screens: Mapfile + Loadmap (parexec_loadmap).
# Layouts: mapping/kantan_1screen.json, kantan_2screen.json, kantan_3screen.json (made by code/make_kantan_layouts.py),
# mapping/bunker3screen.json = the hand-mapped Bunker show (3 screens).
import json


def load(path):
    k = op('/kantan')
    given = path                                         # kept as typed, so the .toe stays portable
    if ':' not in path and not path.startswith('/'):      # relative = inside the project folder
        path = project.folder + '/' + path
    proj = json.loads(open(path, 'r').read())
    k.ext.Projecter.Clear()
    shapes = proj.get('shapes', [])
    tree = k.op('project/tree')
    full = k.op('project/fullPath')
    for i in shapes:
        tree.appendRow([i['sId'], i['sType'], i['sOwner'], i['sLayer'], i['sLock'], i['sVisible']])
    missing = []
    for i in sorted(shapes, key=lambda d: d['sOwner']):
        k.op('project').ext.Layerizer.cookOwner(owner=int(i['sOwner']))
        shape = op(full[i['sId'], 'path'].val)
        if shape:
            shape.SetDefinition(defDict=proj['shapeDef'][i['sId']], undo=False)
            shape.cook(force=True)
        else:
            missing.append(i['sId'])
    k.par.Project = given
    return missing


def screens_changed(n):
    """/show Screens changed to n (parexec_screens). With 1 screen every effect is switched on for screen 1 (its S1
    button is hidden then). If kantan holds one of the default layouts, the default for n screens is loaded;
    a hand-made mapping (any other file, e.g. bunker3screen.json) is left alone."""
    if n == 1:
        for path in ('/fx_metal', '/fx_mosh', '/fx_blob', '/fx_strobe', '/fx_luma'):
            o = op(path)
            if o is not None and hasattr(o.par, 'Screen1'):
                o.par.Screen1 = True
    cur = str(op('/kantan').par.Project.eval()).replace(chr(92), '/')
    if cur.split('/')[-1].startswith('kantan_') and cur.endswith('screen.json'):
        new = 'mapping/kantan_%dscreen.json' % n
        op('/show').par.Mapfile = new
        load(new)
