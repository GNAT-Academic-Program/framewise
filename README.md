# framewise

Non-linear video editing with a proven timeline kernel, driven by
text. An edit engine you script, and a GUI that is a script generator.

GNAT Academic Program capstone project. Proposal title: *Framewise:
a non-linear video editor in Ada*.

## What it is

```
$ framewise_cli
settings 1280 720 30
ok
import take1 take1.mp4 30 video
ok
track v1 video
ok
place c1 v1 take1 2 8.5 0
ok
place c2 v1 take1 5 9 4
err cannot place: unknown track/source, bad window, or overlap
split c1 4 c1b
ok
info c1b
ok clip c1b on v1 from take1 in 6 out 8.5 at 4 ends 6.5 length 2.5
plan out.mp4
ok ffmpeg -y -hide_banner -loglevel error -i take1.mp4 -filter_complex "[0:v]trim=start=2:end=6,setpts=PTS-STARTPTS[v0]; ..." -map "[vout]" -r 30 -pix_fmt yuv420p out.mp4
export out.mp4
ok exported out.mp4
save cut.fw
ok saved 5 commands to cut.fw
```

That transcript is the whole architecture:

- **The document is text.** A `.fw` file is the command history, one
  line per edit. It is an EDL you can read, diff, and write by hand.
  There is no binary project format; the text is the project. Undo is
  "replay minus the last line".
- **One entry point.** `Framewise.Session.Execute (S, Line, Response)`.
  The CLI feeds it stdin. A GUI feeds it the line it built when you
  dragged a clip. An agent feeds it the line it reasoned to. All three
  get `ok` or `err reason` back, and can `info` anything.
- **The GUI cannot pollute the engine** because it has no other door.
  It draws `Sequence_Of (S)` (a read-only copy) and sends lines.
  Everything the GUI can do, a script can do, by construction.
- **The render is text too.** `plan` prints the exact ffmpeg command
  `export` will run. You can inspect it, run it yourself, or hand it
  to an agent to check before spending an hour encoding.
- **The kernel never allocates and never does I/O.** `Framewise.Timeline`
  is a SPARK package on bounded records. `Framewise.Session` owns the
  history; `cli/` and `ui/` own files and screens; ffmpeg owns pixels.

"Proven" in year one means the **timeline invariant**: clips on a
track are sorted and never overlap, and every clip's window lies
inside its source. Every operation promises well-formed in,
well-formed out, or `Ok = False` and nothing changed. Time is integer
ticks at 90 kHz (the MPEG timebase), so there is no floating point
anywhere in the kernel and 24, 25, 30, 48, 60 fps are all exact.

## What is in the seed

```
src/framewise.ads           Time (ticks), Timebase, Name, Path              Pure, SPARK
src/framewise-timeline.ads  Source, Clip, Track, Sequence, Well_Formed,
                            Place/Move/Trim/Split/Delete                   SPARK, proof target
src/framewise-commands.ads  the grammar: Parse <-> Image, round-trips      SPARK
src/framewise-plan.ads      Sequence -> ffmpeg filter_complex command      done
src/framewise-isobmff.ads   MP4/MOV demuxer: boxes, sample tables          PLACEHOLDER, SPARK
src/framewise-jpeg.ads      baseline JPEG decoder                          PLACEHOLDER, SPARK
src/framewise-decode.ads    Probe, Frame_At on the proxy, pure Ada         PLACEHOLDER: the project
src/framewise-session.ads   history, undo, save/load, plan/export/proxy    done
cli/                        REPL, file runner, -c one-liners; exit = failures
ui/README.md                the contract for the GUI (adi2)                contract only
examples/cut.fw             two takes cut with a gap over one music track
tests/                      60 checks: time, timeline invariant, grammar round trip, session
```

Everything runs, including a real export: generate synthetic sources
with ffmpeg (see `.github/workflows/ci.yml`), `load cut.fw`,
`export out.mp4`, and you get a 22-second file. The hole in the
middle is exactly the size of the capstone: reading the proxy in
pure Ada (`ISOBMFF`, `JPEG`, `Decode`), and the GUI it makes possible.

## Why we do not decode MP4, and why we do not need to

No editor edits H.264. Every frame depends on earlier frames, so
seeking is a decode from the last keyframe and cutting mid-GOP means
re-encoding. Resolve, Premiere and Final Cut transcode on ingest to
an intra-only intermediate (ProRes, DNxHR, or proxies), edit that,
and go back to the originals only at export. framewise does the same
with the simplest intra-only codec that exists:

```
proxy take1        -> ffmpeg writes take1.mp4.proxy.mov: Motion JPEG 540p + PCM
```

Motion JPEG is one baseline JPEG per frame. A baseline JPEG decoder
is ~2000 lines from a 30-year-old spec; the MOV container is a box
tree with five sample tables. Both are parsers over untrusted bytes
with bounded state, which is exactly what SPARK proves. So the whole
editing path (scrub, thumbnails, motion analysis, waveforms) is Ada
with no C in the process, and the two things we leave to ffmpeg
(making the proxy, encoding the delivery H.264) are the two things
that would take years and give nothing back. Writing an H.264 or AAC
codec is out of scope, and so is binding libavcodec.

Read `ARCHITECTURE.md` before touching anything.

## Milestones

1. **Prove the timeline.** `gnatprove --mode=all` on
   `Framewise.Timeline`. The seed proves flow; the contracts are
   written; loop invariants are yours. T1-T4 in the spec header.
2. **The container.** `Framewise.ISOBMFF.Parse` on the proxy: walk
   the boxes, read `stts/stsc/stsz/stco`, resolve every sample to an
   (offset, size, time) inside `mdat`. `Probe` works; `import` drops
   its LENGTH argument. Proven: no sample points outside the file.
3. **The codec.** `Framewise.JPEG.Decode`: Huffman, dequantize, IDCT,
   YCbCr to RGB. `Frame_At` works; a scrub bar and thumbnails are
   possible, and the GUI becomes worth building. Proven: no crash on
   any input. This is the SPARK showpiece.
4. **The GUI.** See `ui/README.md`. adi2 window, a track view drawn
   from `Sequence_Of`, a preview drawn from `Frame_At`, a command bar
   at the bottom that shows every line the mouse generates.
5. **Richer plans.** Second video track as overlay, `xfade`
   transitions, per-clip speed, audio gain. Each is a new command,
   a new `Plan` case, and a test that the ffmpeg line is what you
   expect. Ripple delete on the timeline side.
6. **Native intermediate export** (stretch). Decode proxies, write
   your own MJPEG+PCM `.mov` (the muxer is the demuxer backwards),
   and let ffmpeg only do the final H.264 encode. Only if 1-4 land
   early.

## Build

Three [Alire](https://alire.ada.dev) crates; cli and tests pin the
library by path. `ffmpeg` on the PATH for `proxy` and `export`; nothing else.

```
alr build
cd tests && alr build && ./bin/tests
cd cli   && alr build && ./bin/framewise_cli ../examples/cut.fw
alr with gnatprove && alr exec -- gnatprove -P framewise.gpr --mode=flow
```

Contracts are checked at runtime (`-gnata`). Warnings are errors.

## Driving it from anything

Because the protocol is lines in, lines out:

```
echo "import a a.mp4 30" | framewise_cli
framewise_cli -c "load cut.fw" -c "split c3 16 c4" -c "delete c4" -c "save cut.fw"
python: subprocess.Popen(["framewise_cli"], stdin=PIPE, stdout=PIPE)
```

An agent that can read a `.fw` file, run `info`, and emit lines can
edit video with no screen at all. Give it a transcript with
timestamps and the command `split`, and it cuts the dead air. An MCP
server exposing `execute(line)` and `history()` is an afternoon.

## Rules of the road

- `src/` below `Framewise.Session` has no I/O and no allocation
  (`Framewise.Decode` is the one exception, and it only reads).
- `Framewise.ISOBMFF` and `Framewise.JPEG` are pure functions over
  byte arrays. They never see a file handle. No C anywhere in `src/`.
- Every timeline operation: well-formed in, well-formed out, or
  `Ok = False` with the sequence untouched. Never an exception.
- Every new editing command gets a `Parse` case, an `Image` case, a
  round-trip test, and a line in the grammar comment. No command
  exists that the text cannot express.
- Nothing in `ui/` or `cli/` withs anything below `Framewise.Session`.

See `CONTRIBUTING.md` for the fork workflow.

## Contact

Olivier Henley, GAP Coordinator, AdaCore. Weekly meeting, plus the
project Discord.

## License

Apache-2.0. See `LICENSE`.
