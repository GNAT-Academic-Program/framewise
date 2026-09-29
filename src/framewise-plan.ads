--  Render plan: a Sequence becomes an ffmpeg command line.
--
--  The plan is text on purpose. You can read it, diff it, run it by
--  hand, or hand it to an agent to check. Export = generate the plan,
--  then spawn ffmpeg with it. Nothing in framewise decodes a frame
--  for export in v1; ffmpeg does. (Framewise.Decode is for the GUI
--  preview and is the binding milestone.)
--
--  v1 scope: one video track and one audio track (the first of each
--  kind found). Each track becomes a concat of segments in timeline
--  order; gaps become black (video) or silence (audio) of the gap
--  length. Every clip is trim + setpts (or atrim + asetpts).
--
--  Output shape:
--    ffmpeg -y -hide_banner -loglevel error -i src1 -i src2 ... -filter_complex "<graph>"
--           -map "[vout]" -map "[aout]" -r FPS -s WxH out.mp4
--
--  Milestones: multiple video tracks (overlay), transitions (xfade),
--  per-clip speed, audio gain.

with Framewise.Timeline; use Framewise.Timeline;

package Framewise.Plan is

   type Settings is record
      Width, Height : Positive := 1920;
      FPS           : Positive := 30;
      Sample_Rate   : Positive := 48_000;
   end record;

   Default_Settings : constant Settings := (1920, 1080, 30, 48_000);

   Max_Plan : constant := 16_384;

   procedure Generate
     (S      : Sequence;
      Cfg    : Settings;
      Output : String;
      Plan   : out String;
      Last   : out Natural;
      Ok     : out Boolean)
     with Pre => Well_Formed (S) and then Plan'Length >= Max_Plan;
   --  Plan (Plan'First .. Last) is the full ffmpeg command line, one
   --  argument per space, filter graph quoted. Ok = False when there
   --  is nothing to render (no video track or no clips) or the plan
   --  would not fit.

end Framewise.Plan;
