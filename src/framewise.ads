--  framewise: a video editor whose document is text.
--
--  Root package: time and names. Pure.
--
--  Time is an integer count of ticks at Timebase per second, like
--  MPEG's 90 kHz clock. Exact, comparable, provable; no float creeps
--  into the timeline. Seconds appear only at the text boundary.

package Framewise with SPARK_Mode, Pure is

   Timebase : constant := 90_000;

   type Time is range 0 .. 2 ** 62;
   --  Ticks. 2**62 / 90_000 seconds is about 1.6 million years.

   subtype Duration_T is Time;

   function Seconds (T : Time) return Long_Float is (Long_Float (T) / Long_Float (Timebase));

   ---------------------------------------------------------------------
   --  Names: identifiers for sources, clips and tracks.
   ---------------------------------------------------------------------

   Max_Name : constant := 32;

   type Name is record
      Length : Natural range 0 .. Max_Name := 0;
      Text   : String (1 .. Max_Name) := [others => ' '];
   end record;

   function To_Name (S : String) return Name
     with Pre => S'Length <= Max_Name;

   function Image (N : Name) return String is (N.Text (1 .. N.Length));

   function "=" (A, B : Name) return Boolean is
     (A.Length = B.Length and then A.Text (1 .. A.Length) = B.Text (1 .. B.Length));

   Max_Path : constant := 256;

   type Path is record
      Length : Natural range 0 .. Max_Path := 0;
      Text   : String (1 .. Max_Path) := [others => ' '];
   end record;

   function To_Path (S : String) return Path
     with Pre => S'Length <= Max_Path;

   function Image (P : Path) return String is (P.Text (1 .. P.Length));

end Framewise;
