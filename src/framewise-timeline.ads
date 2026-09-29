--  The timeline: sources, clips, tracks, and the invariant that makes an
--  edit well-formed. Pure data and pure operations, no I/O, no heap.
--
--  A Source is a media file with a known duration. A Clip is a window
--  [In, Src_Out) of a source placed at position At on a track. A Track is
--  a bounded list of clips, kept sorted by Start, that never overlap.
--
--  INVARIANT (Well_Formed), the proof target of the project:
--    for every clip:   In < Out and Src_Out <= Source duration
--    for every track:  clips sorted by Start, and for consecutive clips
--                      A.Start + (A.Src_Out - A.In) <= B.Start
--  Every operation below has Well_Formed as pre and post. Operations
--  that would break it (overlap, trim past the end) report Ok = False
--  and leave the sequence unchanged.
--
--  PROOF TARGET
--    T1  No index out of range (free once Well_Formed is the pre).
--    T2  Every operation preserves Well_Formed.
--    T3  Split (C, Start) yields two clips whose windows partition C's and
--        whose placement is contiguous: no frame lost, none duplicated.
--    T4  Total duration of a track equals last clip's end, or 0.

package Framewise.Timeline with SPARK_Mode is

   Max_Sources : constant := 64;
   Max_Tracks  : constant := 8;
   Max_Clips   : constant := 256;   --  per track

   type Media_Kind is (Video, Audio, Both);

   ---------------------------------------------------------------------
   --  Sources
   ---------------------------------------------------------------------

   type Source_Id is range 0 .. Max_Sources;
   No_Source : constant Source_Id := 0;

   type Source is record
      Used     : Boolean := False;
      N        : Name;
      File     : Path;
      Length   : Duration_T := 0;
      Kind     : Media_Kind := Both;
   end record;

   type Source_Table is array (Source_Id range 1 .. Max_Sources) of Source;

   ---------------------------------------------------------------------
   --  Clips and tracks
   ---------------------------------------------------------------------

   type Clip is record
      N   : Name;
      Src : Source_Id := No_Source;
      Src_In : Time := 0;   --  first tick of the source used
      Src_Out : Time := 0;   --  one past the last
      Start  : Time := 0;   --  position on the track
   end record;

   function Length (C : Clip) return Duration_T is (C.Src_Out - C.Src_In)
     with Pre => C.Src_In <= C.Src_Out;

   function Ends (C : Clip) return Time is (C.Start + (C.Src_Out - C.Src_In))
     with Pre => C.Src_In <= C.Src_Out and then C.Start <= Time'Last - (C.Src_Out - C.Src_In);

   type Clip_Index is range 0 .. Max_Clips;
   type Clip_Array is array (Clip_Index range 1 .. Max_Clips) of Clip;

   type Track is record
      Used  : Boolean := False;
      N     : Name;
      Kind  : Media_Kind := Video;
      Count : Clip_Index := 0;
      Clips : Clip_Array;
   end record;

   type Track_Id is range 0 .. Max_Tracks;
   type Track_Table is array (Track_Id range 1 .. Max_Tracks) of Track;

   type Sequence is record
      Sources : Source_Table;
      Tracks  : Track_Table;
   end record;

   ---------------------------------------------------------------------
   --  The invariant
   ---------------------------------------------------------------------

   function Clip_OK (S : Sequence; C : Clip) return Boolean is
     (C.Src in 1 .. Max_Sources
      and then S.Sources (C.Src).Used
      and then C.Src_In < C.Src_Out
      and then C.Src_Out <= S.Sources (C.Src).Length
      and then C.Start <= Time'Last / 2 and then C.Src_Out <= Time'Last / 2);
   --  The halving keeps Start + Length inside Time without a proof of
   --  its own; 800 000 years of video is enough.

   function Track_OK (S : Sequence; T : Track) return Boolean is
     ((for all I in 1 .. T.Count => Clip_OK (S, T.Clips (I)))
      and then (for all I in 1 .. T.Count - 1 =>
                  Ends (T.Clips (I)) <= T.Clips (I + 1).Start));

   function Well_Formed (S : Sequence) return Boolean is
     (for all T in Track_Table'Range =>
        (if S.Tracks (T).Used then Track_OK (S, S.Tracks (T))));

   ---------------------------------------------------------------------
   --  Lookup
   ---------------------------------------------------------------------

   function Find_Source (S : Sequence; N : Name) return Source_Id;
   function Find_Track  (S : Sequence; N : Name) return Track_Id;
   procedure Find_Clip
     (S : Sequence; N : Name; T : out Track_Id; I : out Clip_Index);
   --  T = 0 when absent.

   function Track_End (S : Sequence; T : Track_Id) return Time
     with Pre => T in 1 .. Max_Tracks and then Well_Formed (S);
   --  End of the last clip, or 0.

   function Sequence_End (S : Sequence) return Time
     with Pre => Well_Formed (S);

   ---------------------------------------------------------------------
   --  Operations. All: Pre => Well_Formed, Post => Well_Formed, and
   --  the sequence is unchanged when Ok = False.
   ---------------------------------------------------------------------

   procedure Clear (S : out Sequence)
     with Post => Well_Formed (S);

   procedure Add_Source
     (S : in out Sequence; N : Name; File : Path; Length : Duration_T;
      Kind : Media_Kind; Ok : out Boolean)
     with Pre  => Well_Formed (S) and then Length > 0 and then Length <= Time'Last / 2,
          Post => Well_Formed (S);
   --  Ok = False: table full, or a source with that name exists.

   procedure Add_Track (S : in out Sequence; N : Name; Kind : Media_Kind; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);

   procedure Place
     (S : in out Sequence; Clip_Name : Name; On : Name; From : Name;
      Src_In, Src_Out, Start : Time; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);
   --  Adds a clip. Ok = False on: unknown track or source, duplicate
   --  clip name, Src_In >= Src_Out, Src_Out past the source, overlap with an
   --  existing clip, track full.

   procedure Move (S : in out Sequence; Clip_Name : Name; To : Time; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);
   --  Same track, new position. Ok = False on overlap.

   procedure Trim
     (S : in out Sequence; Clip_Name : Name; New_In, New_Out : Time; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);
   --  Changes the source window; Start is unchanged (so trimming In does
   --  not move the clip's start on the timeline: it changes what plays
   --  there). Ok = False if the new window is empty, past the source,
   --  or the new length overlaps the next clip.

   procedure Split
     (S : in out Sequence; Clip_Name : Name; Start : Time; Right_Name : Name; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);
   --  Cuts the clip at timeline time Start (strictly inside it) into two
   --  contiguous clips; the right part gets Right_Name. T3.

   procedure Delete (S : in out Sequence; Clip_Name : Name; Ok : out Boolean)
     with Pre => Well_Formed (S), Post => Well_Formed (S);
   --  Leaves a gap. Ripple delete (close the gap) is a milestone.

end Framewise.Timeline;
