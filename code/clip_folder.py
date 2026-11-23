# /input/clip_folder (MetalShow.86): CLIP FOLDER button on the panel. Pick a folder of videos, it becomes the
# MY CLIPS source (Clipfolder) and starts on its first clip. Event only (a click), nothing per frame.


def choose():
    i = op('/input')
    path = ui.chooseFolder(title='Folder with your clips', start=project.folder)
    if not path:
        return
    i.par.Clipfolder = path
    run("args[0].op('folder_clips').cook(force=True); n = list(args[0].par.Clip.menuNames); "
        "args[0].par.Clip = n[0] if n else ''", i, delayFrames=2)
