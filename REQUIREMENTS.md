# Requirements

Written for someone who has never opened a video editor. Read the
glossary first; every requirement uses those words and only those.

## Glossary

**Source.** A media file on disk: `take1.mp4`, `music.wav`. It has a
length. We never modify a source.

**Clip.** A piece of a source, placed on the timeline. "Seconds 2 to
8.5 of take1, playing at second 0 of my edit." A clip is three
numbers: where it starts in the source (**in point**), where it ends
in the source (**out point**), and where it sits on the timeline
(**position**). The same source can be used by many clips.

**Track.** A row on the timeline. Clips on one track play one after
another and never overlap. A video track shows pictures; an audio
track plays sound. A minimal edit has one of each: the pictures on
top, the music underneath.

**Timeline (Sequence).** All the tracks together. The thing you are
building. Its length is where the last clip ends.

**Gap.** Empty space on a track. Plays as black (video) or silence
(audio).

**Cut.** The moment one clip ends and the next begins.

**Split.** Cutting one clip into two at a chosen time. Nothing is
lost; the two halves together are the original.

**Trim.** Changing a clip's in or out point, so it shows more or less
of its source.

**Ripple.** When you delete a clip and everything after it slides left
to close the gap. Not in the seed; a milestone.

**Frame.** One picture. Video is 24, 25, 30 or 60 of them per second.

**Keyframe vs. inter-frame.** In an mp4, most frames are stored as
"the difference from the previous frame." Only a keyframe (every
few seconds) is a complete picture. To show frame 137 you must
decode from the last keyframe forward. This is why editors do not
edit mp4 directly.

**Intra-only.** A format where every frame is a complete picture.
Showing any frame is one read and one decode. Motion JPEG is one:
literally one JPEG per frame.

**Proxy.** A small intra-only copy of a source, made once when you
import it. The editor reads the proxy for everything you see on
screen. The original is only read again at export. Every
professional editor works this way; they just hide it.

**Export (render).** Producing the final mp4 from the timeline. Slow,
done once. We hand this to ffmpeg.

**ffmpeg.** The open-source command-line tool every video program
uses underneath. It reads and writes every format. We use it for
two jobs only: make proxies, and export.

**Tick.** Our unit of time: 1/90000 of a second. Integer, so no
rounding. 30 fps is 3000 ticks per frame, 24 fps is 3750, 25 fps is
3600. All exact.

**EDL (edit decision list).** A text file listing the cuts. The oldest
interchange format in the industry. Our `.fw` file is one.

## Part 1. What a user can do

**U1. Import a source.** Give it a name and a file. The tool records
its length and makes its proxy. Any file ffmpeg can read is accepted.

**U2. Create tracks.** At least one video and one audio track.

**U3. Place a clip.** Pick a source, an in point, an out point, and a
position on a track. If it would overlap another clip on that track,
the tool refuses and says why. Nothing changes.

**U4. Move a clip** to a new position on its track. Same refusal rule.

**U5. Trim a clip's** in or out point. Same refusal rule. The clip's
position on the timeline does not move.

**U6. Split a clip** at a time inside it, giving the right half a new
name.

**U7. Delete a clip.** Leaves a gap.

**U8. Undo** the last change, as many times as there were changes.

**U9. Save and load.** A saved project reloads to exactly the same
timeline, on any machine, and is readable in a text editor.

**U10. See the timeline.** Tracks as rows, clips as labelled boxes,
time left to right.

**U11. See a frame.** Put the playhead anywhere and see the picture
at that moment. Step one frame forward or back. See a thumbnail on
each clip.

**U12. Hear the sound.** See a waveform on each audio clip. (Playing
audio in real time is a stretch goal.)

**U13. Export** the timeline to an mp4 at a chosen size and frame
rate. Before exporting, see the exact ffmpeg command that will run.

**U14. Type any of the above** as one line in a command bar, and see
the line the mouse produced whenever a button or drag is used.

**U15. Run the whole thing without a screen:** the same commands from
a file or a pipe give the same result.

## Part 2. How the system must be built

**S1. One entry point.** Every front end (GUI, command line, script,
AI agent) talks to the engine through a single call that takes a
text line and returns `ok` or `err reason`. There is no second API.

**S2. The document is the history.** A project file is the list of
editing commands that built it, one per line. Load is replay. Undo
is replay without the last line. There is no other project format.

**S3. Every editing command round-trips.** Parsing the printed form of
a command gives back the same command. Tested for every command.

**S4. The timeline is always valid.** On every track, clips are sorted
by position and never overlap; every clip has a positive length and
lies inside its source. Every operation either keeps this true or
refuses and leaves the timeline untouched. Never an exception, never
a crash.

**S5. This is proven, not tested.** S4 is written as contracts on the
timeline package and discharged by gnatprove.

**S6. The editor reads proxies, never originals.** A proxy is Motion
JPEG at 540p plus 16-bit PCM audio in a `.mov` file, produced once by
ffmpeg at import.

**S7. Proxies are read by Ada code.** The MOV container parser and the
JPEG decoder are written in Ada, with no C library in the process.

**S8. The parsers cannot crash.** On any input, including corrupt and
truncated files, the container parser and the JPEG decoder return
`Ok = False` or a correct result. Proven with gnatprove; fuzzed in
CI to show it.

**S9. No allocation and no I/O in the engine.** Everything below the
session layer works on bounded records. Only the session and the
proxy reader touch files.

**S10. The GUI is a script generator.** It builds a line, shows it,
sends it through S1, and redraws from a read-only copy of the
timeline. It never reaches below the session layer. Enforced by CI.

**S11. Export is derived.** The export command is text (an ffmpeg
command line) generated from the timeline, printable before it
runs, and reading the original sources at the same times as the
proxies.

**S12. Builds on Linux and Windows,** with Alire, in CI.

## Part 3. Out of scope, on purpose

- Decoding H.264, HEVC, AV1, AAC or MP3 in Ada. Years of work, no
  academic return, patents. ffmpeg does it once at import.
- Writing any video encoder. ffmpeg does it once at export.
- Transitions, effects, colour correction, titles, more than two
  video tracks. Each is a command family later; none changes the
  architecture.
- Real-time playback with audio in sync. Nice, not required.

## Part 4. Milestones

1. **October.** Timeline proven: `gnatprove --mode=all` clean on
   `Framewise.Timeline`. S4, S5.
2. **November.** MOV container parser. `import` no longer needs the
   length typed in. S6, S7, half of S8.
3. **December to January.** JPEG decoder. A frame can be shown. Rest
   of S8. U11.
4. **February to March.** The GUI (adi2): track view, preview,
   thumbnails, waveform, command bar. U10 to U14, S10.
5. **April.** Ripple delete; a `beats` file and snap-to-beat;
   a second video track as overlay if time allows.

## Part 5. Acceptance demo

In a room, on a laptop:

1. Import ten short clips and one song. Watch the proxies get made.
2. Cut the clips to the downbeats of the song in the GUI. Watch the
   command bar print each line.
3. Save. Open the `.fw` file in Notepad. Read it aloud.
4. Close the GUI. Replay the file in the command-line tool. Export.
   Play the mp4.
5. Feed a corrupt proxy to the tool. It says `err`, it does not die.
6. Run a script that writes a `.fw` file from a beat list with no
   screen at all. Export that too.

If all six happen, the project is done.
