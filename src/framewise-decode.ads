--  Frame access, for the GUI preview and (later) a native renderer.
--  THE BINDING. Placeholder in the seed: Open reports Ok = False.
--
--  What it is: a thin Ada binding to libavformat + libavcodec +
--  libswscale, enough to open a file, seek to a time, and decode one
--  frame into an RGBA buffer. That is three FFmpeg APIs and about 300
--  lines of Ada, and it is the part of this project that touches C.
--
--  Milestones:
--    1. Probe: open a file, report duration and kind. Lets `import`
--       fill in the length instead of the user typing it.
--    2. Frame_At: decode the frame at time T into RGBA. The GUI
--       preview and thumbnails.
--    3. Native export: replace the ffmpeg spawn in Session with a
--       decode/encode loop over the plan. Optional; the spawn works.
--
--  Nothing else in framewise depends on this package. The timeline,
--  commands, session and plan are complete without it; the tool works
--  as an EDL editor with ffmpeg doing the rendering.

package Framewise.Decode is

   type Byte is mod 2 ** 8 with Size => 8;
   type RGBA_Buffer is array (Positive range <>) of Byte with Pack;

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
   end record;
end Framewise.Decode;
