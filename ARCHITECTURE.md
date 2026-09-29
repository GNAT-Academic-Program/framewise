# Architecture

## Layers

```
ui/  (adi2)              cli/  (stdin)         an agent (pipe)     front ends: lines in, lines out
          \                  |                    /
           Framewise.Session   Execute (S, Line, Response); Sequence_Of for renderers
                 |             history, undo, save/load, plan/export (spawns ffmpeg)
           Framewise.Commands  Command <-> text, Parse and Image are inverses      SPARK
                 |
   Framewise.Plan          Framewise.Decode          Probe, Frame_At on the proxy (PLACEHOLDER)
   Sequence -> ffmpeg           |          \
                 |     Framewise.ISOBMFF   Framewise.JPEG      demuxer, codec: pure byte-array functions, SPARK
                 |
           Framewise.Timeline  Source, Clip, Track, Sequence, Well_Formed          SPARK, proof target
                 |
           Framewise           Time in ticks, Timebase, Name, Path                 Pure
```

Dependencies point down only. Nothing above `Framewise.Session` names a
kernel package. Nothing at or below `Framewise.Plan` allocates or does
I/O; `Decode` reads files and hands byte arrays to `ISOBMFF` and
`JPEG`, which are pure. There is no C in `src/`. ffmpeg is a process
the session spawns for two jobs: `proxy` and `export`.

## The edge, and why it holds

Every NLE has a project file, a scripting API added later, and a GUI
that can do things neither can express. framewise inverts the order:
the command language is the only layer. `Framewise.Session.Execute`
takes a `String` and returns a `Response`. There is no second API.

Consequences:

- A drag in the GUI is a function that builds `move c1 12.5` and calls
  `Execute`. The command bar shows that line. A user learns the
  language by watching the bar.
- The document is the history. Save writes it; load replays it. There
  is no project serializer to keep in sync with the model, because the
  model is a replay. A `.fw` file is a valid EDL and a valid script.
- Undo is pop-and-replay. O(n), and there is nothing to get wrong.
- An agent has the same power as a user: read the file, emit lines,
  read `info`. No screenshot parsing, no accessibility tree, no
  binary project format to reverse-engineer.
- The render is also text. `plan` prints the ffmpeg command; `export`
  runs it. Any render problem is debuggable by pasting one line into
  a shell.

The cost: replay must be deterministic. The kernel is pure, so it is.

## Kernel

### Time

`Time` is an integer count of ticks at `Timebase = 90_000` per second.
90 kHz is the MPEG transport timebase, and it is divisible by 24, 25,
30, 48, 50, 60, 1000 and 44100/48000-friendly factors, so any frame at
any common rate is a whole number of ticks. No floating point, no
drift, and SPARK proves arithmetic on it. On the wire (the `.fw` file)
times are seconds as decimals, up to six places; `Value_Time` and
`Image_Time` are inverses on representable values.

### Timeline

A `Sequence` is a bounded table of `Source`s and a bounded table of
`Track`s; a `Track` is a bounded array of `Clip`s; a `Clip` is a
window `[Src_In, Src_Out)` of a source placed at `Start`. Everything is
a plain record with defaults; `Clear` gives an empty, well-formed
sequence. No heap.

`Well_Formed` is the invariant: every clip's source exists, its window
is non-empty and inside the source, and on each track clips are sorted
by `Start` with `Ends (A) <= B.Start` for consecutive clips. Every
operation has it as pre and post, and the sequence is unchanged on
`Ok = False`.

The halving trick (`Start <= Time'Last / 2`, `Src_Out <= Time'Last / 2`)
in `Clip_OK` keeps `Start + Length` inside `Time` without a separate
overflow proof. It limits an edit to about 800 000 years.

`Overlaps`, `Insert_Sorted`, `Remove_At` are the three helpers; every
operation is a check followed by at most one insert and one remove.
`Split` is the interesting one (T3): the right clip starts at the cut
and at `Src_In + offset`; the left clip's `Src_Out` moves to the same
place; so windows partition and placement is contiguous.

### Plan

`Generate` walks the first video track and the first audio track,
emits `trim`/`setpts` (or `atrim`/`asetpts`) per clip, `color=black`
or `anullsrc` per gap, one `concat` per track, and maps `[vout]` and
`[aout]`. The output is a single shell line. It is pure text
generation over a well-formed sequence, and its tests compare
strings. Adding a feature to the plan means adding a filter to the
graph and a test for the resulting line.

### Media: the project

Three packages, all placeholders in the seed, each with its algorithm
in the spec header.

`Framewise.ISOBMFF`: the MP4/MOV box tree and the five sample tables
(`stts`, `stsc`, `stsz`, `stco`/`co64`), resolved into a bounded array
of (offset, size, time) per track. `Well_Formed` says every sample
lies inside `mdat`; it is the postcondition of `Parse` and what makes
every later read safe. `Sample_At` is a binary search, and because the
proxy is intra-only, the sample it finds is the frame.

`Framewise.JPEG`: baseline sequential JPEG. Huffman decode, dequantize,
inverse DCT, chroma upsample, YCbCr to RGBA. Bit reader and Huffman
lookup bounded on any input; IDCT accumulators bounded by construction.

`Framewise.Decode`: the only one that opens a file. Reads the proxy,
parses it once, and serves `Frame_At (T)` by one seek and one JPEG
decode. Caches the last frame.

Why a proxy and not the original: H.264 frames depend on earlier
frames; an editor that seeks by decoding from keyframes is an editor
that stutters, and a decoder for it is out of scope by two orders of
magnitude. Every NLE transcodes on ingest. Motion JPEG is the
intra-only format that costs the least to read and that ffmpeg and
every player already write. The original is read exactly once, by
ffmpeg, at export.

## Session

`Seq`: the live sequence. `Cfg`: render settings. `History`: 4096
modeling commands. `Execute` parses, dispatches, and for modeling
commands appends to the history only on success, so the history is
always replayable. Queries (`list`, `info`, `plan`), side effects
(`export`) and meta commands (`undo`, `save`, `load`) are never
recorded. `settings` is recorded: it changes what `export` produces.

`Response` is a bounded string with an `Ok` flag; the first word is
always `ok` or `err`. Front ends parse that word and show the rest.

## Commands

A `Command` is a discriminated record; `Parse` builds one from a line,
`Image` prints it. The grammar is in the spec header. `Round_Trip` in
the tests is the contract: `Parse (Image (C)) = C`.

## What is deliberately not here

- Multiple video tracks in the plan (overlay), transitions, speed,
  gain. Each is a command family plus a `Plan` case; none changes the
  architecture.
- Ripple edits. A milestone on the timeline side, with T2 still the
  postcondition.
- Any encoder. ffmpeg makes the proxy and encodes the delivery file.
  `Decode` is for the preview and for analysis, never for export.
- Any inter-frame codec. If a source is not MJPEG+PCM, it gets a proxy.
- A GUI in the seed. `ui/README.md` is the contract; adi2 is the tool;
  milestone 4.
