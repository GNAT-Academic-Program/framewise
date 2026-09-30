--  framewise: a video editor whose document is text.
--
--  Root package: time and names. Pure.
--
--  Time is an integer count of ticks at Timebase per second, like
--  MPEG's 90 kHz clock. Exact, comparable, provable; no float creeps
--  into the timeline. Seconds appear only at the text boundary.

with Bedrock.Names;

package Framewise with SPARK_Mode, Pure is

   Timebase : constant := 90_000;

   type Time is range 0 .. 2 ** 62;
   --  Ticks. 2**62 / 90_000 seconds is about 1.6 million years.

   subtype Duration_T is Time;

   function Seconds (T : Time) return Long_Float is (Long_Float (T) / Long_Float (Timebase));

   ---------------------------------------------------------------------
   --  Names: identifiers for sources, clips and tracks.
   ---------------------------------------------------------------------

   ---------------------------------------------------------------------
   --  Names and paths: bedrock's bounded strings, so a name means the
   --  same thing in every GAP tool.
   ---------------------------------------------------------------------

   Max_Name : constant := Bedrock.Names.Max_Name;
   subtype Name is Bedrock.Names.Name;
   function To_Name (S : String) return Name renames Bedrock.Names.To_Name;
   function Image (N : Name) return String renames Bedrock.Names.Image;
   function "=" (A, B : Name) return Boolean renames Bedrock.Names."=";

   Max_Path : constant := Bedrock.Names.Max_Path;
   subtype Path is Bedrock.Names.Path;
   function To_Path (S : String) return Path renames Bedrock.Names.To_Path;
   function Image (P : Path) return String renames Bedrock.Names.Image;

end Framewise;
