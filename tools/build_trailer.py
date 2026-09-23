#!/usr/bin/env python3
"""
Assemble the MECHA-FORGE trailer -> cine/trailer.mp4

Two modes, auto-detected:
  * If cine/clips/*.mp4 exist  -> stitch those Veo clips (scaled to 1280x720).
  * Else                        -> Ken-Burns slideshow of the FLUX panels p1..p6
                                    + a hero title card (works with zero video, so
                                    you can preview the whole thing NOW).

Every segment cross-fades into the next (xfade), the synthwave bed (cine/synthwave.wav)
is muxed on top with fades. 1280x720, 30fps, h264 + aac. ffmpeg only, no GPU.
"""
import os, glob, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CINE = os.path.join(ROOT, "cine")
W, H, FPS, X = 1280, 720, 30, 0.7  # crossfade seconds
FONT = "'C\\:/Windows/Fonts/arialbd.ttf'"


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("FFMPEG ERR:", r.stderr[-600:]); sys.exit(1)


def kenburns(img, dur, mode, out):
    """Render one still into a Ken-Burns segment."""
    frames = int(dur * FPS)
    # upscale 2x so zoompan has pixels to crop from -> smooth motion
    z = {
        "in":   "z='min(1.0+0.00060*on,1.20)'",
        "out":  "z='max(1.20-0.00060*on,1.02)'",
        "left": "z='1.10':x='max(0,(iw-iw/zoom)-(iw-iw/zoom)*on/%d)'" % frames,
        "right":"z='1.10':x='(iw-iw/zoom)*on/%d'" % frames,
        "up":   "z='1.10':y='max(0,(ih-ih/zoom)-(ih-ih/zoom)*on/%d)'" % frames,
    }[mode]
    xy = ":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'" if mode in ("in", "out") else ""
    vf = ("scale=%d:%d,zoompan=%s%s:d=1:fps=%d:s=%dx%d,"
          "format=yuv420p" % (W * 2, H * 2, z, xy, FPS, W, H))
    run(["ffmpeg", "-y", "-loop", "1", "-framerate", str(FPS), "-t", "%.3f" % dur,
         "-i", img, "-vf", vf, "-r", str(FPS), "-frames:v", str(frames),
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", out])


def titlecard(img, dur, out):
    frames = int(dur * FPS)
    # NB: commas inside filter expressions break the graph parser, so the text
    # is static here; the reveal comes from the incoming xfade + slow push-in.
    vf = (
        "scale=%d:%d,zoompan=z='min(zoom+0.00045,1.12)'"
        ":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:fps=%d:s=%dx%d,"
        # darken lower third for the title
        "drawbox=x=0:y=%d:w=%d:h=%d:color=black@0.45:t=fill,"
        "drawtext=fontfile=%s:text='MECHA-FORGE':fontcolor=white:fontsize=92"
        ":borderw=3:bordercolor=cyan@0.6:x=(w-text_w)/2:y=h*0.60,"
        "drawtext=fontfile=%s:text='SURVIVE THE HORDE':fontcolor=cyan:fontsize=34"
        ":x=(w-text_w)/2:y=h*0.60+112,"
        "format=yuv420p"
        % (W * 2, H * 2, FPS, W, H, int(H * 0.55), W, int(H * 0.45),
           FONT, FONT)
    )
    run(["ffmpeg", "-y", "-loop", "1", "-framerate", str(FPS), "-t", "%.3f" % dur,
         "-i", img, "-vf", vf, "-r", str(FPS), "-frames:v", str(frames),
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", out])


def clip_seg(src, dur, out):
    """Normalize a Veo clip to 1280x720/30fps, trimmed to dur."""
    vf = ("scale=%d:%d:force_original_aspect_ratio=increase,"
          "crop=%d:%d,fps=%d,format=yuv420p" % (W, H, W, H, FPS))
    run(["ffmpeg", "-y", "-t", "%.3f" % dur, "-i", src, "-an",
         "-vf", vf, "-c:v", "libx264", "-preset", "medium", "-crf", "20", out])


def main():
    tmp = os.path.join(CINE, "_seg")
    os.makedirs(tmp, exist_ok=True)
    clips = sorted(glob.glob(os.path.join(CINE, "clips", "*.mp4")))

    segs = []
    if clips:
        print("MODE: Veo clips (%d found)" % len(clips))
        for i, c in enumerate(clips):
            o = os.path.join(tmp, "s%02d.mp4" % i)
            clip_seg(c, 8.0, o); segs.append((o, 8.0))
    else:
        print("MODE: Ken-Burns slideshow (no clips yet)")
        plan = [  # (image, dur, motion) — mapped to the 6 story beats + title
            ("p1.png", 8.5, "in"),
            ("p2.png", 8.0, "left"),
            ("p3.png", 8.0, "in"),
            ("p4.png", 8.0, "out"),
            ("p5.png", 8.0, "right"),
            ("p6.png", 8.6, "in"),
        ]
        for i, (img, dur, mode) in enumerate(plan):
            o = os.path.join(tmp, "s%02d.mp4" % i)
            kenburns(os.path.join(CINE, img), dur, mode, o); segs.append((o, dur))
            print("  seg", i, img, mode)
        tc = os.path.join(tmp, "s99.mp4")
        titlecard(os.path.join(CINE, "hero_hq.png"), 9.0, tc); segs.append((tc, 9.0))
        print("  titlecard")

    # stepwise xfade chain
    cur, cur_len = segs[0]
    for i in range(1, len(segs)):
        nxt, nxt_len = segs[i]
        off = cur_len - X
        out = os.path.join(tmp, "chain%02d.mp4" % i)
        run(["ffmpeg", "-y", "-i", cur, "-i", nxt, "-filter_complex",
             "[0][1]xfade=transition=fade:duration=%.2f:offset=%.3f,format=yuv420p" % (X, off),
             "-c:v", "libx264", "-preset", "medium", "-crf", "20", out])
        cur = out; cur_len = cur_len + nxt_len - X
        print("  xfade -> %.1fs" % cur_len)

    # mux synthwave bed (fade in/out), cut to video length
    music = os.path.join(CINE, "synthwave.wav")
    final = os.path.join(CINE, "trailer.mp4")
    af = "afade=t=in:st=0:d=0.6,afade=t=out:st=%.2f:d=1.6" % (cur_len - 1.6)
    run(["ffmpeg", "-y", "-i", cur, "-i", music, "-filter:a", af,
         "-map", "0:v", "-map", "1:a", "-t", "%.3f" % cur_len,
         "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", final])
    print("DONE", final, os.path.getsize(final) // 1024, "Ko", "%.1fs" % cur_len)


if __name__ == "__main__":
    main()
