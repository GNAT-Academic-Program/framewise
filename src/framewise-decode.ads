--  Frame access for the GUI preview, thumbnails and analysis.
--  Pure Ada, built on Framewise.ISOBMFF (container) and Framewise.JPEG
--  (codec). PLACEHOLDER in the seed: Open reports Ok = False.
--
--  What it reads: the PROXY, never the original. `proxy NAME` makes
--  FILE.proxy.mov with ffmpeg: Motion JPEG at 540p (every frame is a
--  keyframe, so seeking is a table lookup) plus 16-bit PCM. That is
--  what every real NLE does on ingest (ProRes, DNxHR, proxies); we do
--  it with the simplest codec that exists, so the whole editing path
--  is Ada and provable. Export still reads the original through
--  ffmpeg (the "conform" step), at the same times.
--
--  ALGORITHM (Open): read the file; find moov (ffmpeg writes it at the
--  end of a .mov unless -movflags faststart; scan top-level boxes
--  either way); ISOBMFF.Parse; keep the map and the file handle.
--
--  ALGORITHM (Frame_At): I := Sample_At (Map.Video, T); read
--  Samples (I).Size bytes at Samples (I).Offset (inside mdat by
--  Well_Formed); JPEG.Read_Header; JPEG.Decode into a 540p buffer;
--  nearest-neighbour scale to Width x Height. Cache the last decoded
--  sample index: a scrub bar asks for the same frame many times.
--
--  ALGORITHM (Probe): Open, report Map.Length and which tracks exist,
--  Close. When it lands, `import NAME FILE` needs no LENGTH.
--
--  Milestones:
--    1. ISOBMFF.Parse on the proxy; Probe works; `import` drops LENGTH.
--    2. JPEG.Decode; Frame_At works; the GUI gets a preview and
--       thumbnails; the beat-matching script gets motion curves.
--    3. Samples_At for audio (PCM is just bytes) so the GUI can draw
--       waveforms.
--    4. Native export (stretch): decode proxies, write your own
--       MJPEG+PCM .mov (the muxer is the demuxer backwards), and let
--       ffmpeg only do the final H.264 encode.
--
--  Nothing else in framewise depends on this package. The timeline,
--  commands, session and plan are complete without it; the tool works
--  as an EDL editor with ffmpeg doing the rendering.

with Framewise.ISOBMFF;

package Framewise.Decode is

   subtype Byte is ISOBMFF.Byte;
   subtype RGBA_Buffer is ISOBMFF.Byte_Array;

   type Handle is limited private;

   procedure Probe (File : String; Length : out Duration_T; Kind_Video, Kind_Audio : out Boolean;
                    Ok : out Boolean);
   --  Milestone 1.

   procedure Open (H : in out Handle; File : String; Ok : out Boolean);
   procedure Close (H : in out Handle);

   procedure Frame_At
     (H : in out Handle; T : Time; Width, Height : Positive;
      Pixels : out RGBA_Buffer; Ok : out Boolean)
     with Pre => Pixels'Length >= Width * Height * 4;
   --  Milestone 2. Scaled to Width x Height, straight alpha 255.

private
   type Handle is limited record
      Opened : Boolean := False;
      Map    : ISOBMFF.File_Map;
   end record;
end Framewise.Decode;
