--  Unit tests. Plain Ada, no framework, non-zero exit on failure.

with Ada.Command_Line;
with Ada.Text_IO;         use Ada.Text_IO;
with Framewise;           use Framewise;
with Framewise.Commands;  use Framewise.Commands;
with Framewise.Session;
with Framewise.Timeline;  use Framewise.Timeline;

procedure Tests is

   Failures : Natural := 0;

   procedure Check (Name : String; Cond : Boolean);
   procedure Test_Time;
   procedure Test_Timeline;
   procedure Test_Commands;
   procedure Test_Session;
   function Sec (S : String) return Time;

   procedure Check (Name : String; Cond : Boolean) is
   begin
      Put_Line ((if Cond then "PASS  " else "FAIL  ") & Name);
      if not Cond then
         Failures := Failures + 1;
      end if;
   end Check;

   function Sec (S : String) return Time is
      T  : Time;
      Ok : Boolean;
   begin
      Value_Time (S, T, Ok);
      return (if Ok then T else 0);
   end Sec;

   ---------------------------------------------------------------------

   procedure Test_Time is
      T  : Time;
      Ok : Boolean;
   begin
      Value_Time ("12.5", T, Ok);
      Check ("12.5 s = 1125000 ticks", Ok and T = 1_125_000);
      Check ("image 12.5", Image_Time (1_125_000) = "12.5");
      Check ("image whole", Image_Time (90_000 * 7) = "7");
      Check ("image 0.04", Image_Time (3_600) = "0.04");
      Value_Time ("abc", T, Ok);
      Check ("bad time rejected", not Ok);
      Value_Time ("1.2.3", T, Ok);
      Check ("two dots rejected", not Ok);
      Value_Time ("0.25", T, Ok);
      Check ("round trip 0.25", Ok and Image_Time (T) = "0.25");
   end Test_Time;

   procedure Test_Timeline is
      S  : Sequence;
      Ok : Boolean;
      T  : Track_Id;
      I  : Clip_Index;
      procedure P (C, Tr, Src, I1, I2, At1 : String; Ok : out Boolean);
      procedure P (C, Tr, Src, I1, I2, At1 : String; Ok : out Boolean) is
      begin
         Place (S, To_Name (C), To_Name (Tr), To_Name (Src),
                Sec (I1), Sec (I2), Sec (At1), Ok);
      end P;
   begin
      Clear (S);
      Check ("empty is well formed", Well_Formed (S));
      Add_Source (S, To_Name ("a"), To_Path ("a.mp4"), Sec ("30"), Video, Ok);
      Check ("add source", Ok);
      Add_Source (S, To_Name ("a"), To_Path ("b.mp4"), Sec ("30"), Video, Ok);
      Check ("duplicate source refused", not Ok);
      Add_Track (S, To_Name ("v1"), Video, Ok);
      Check ("add track", Ok);

      P ("c1", "v1", "a", "0", "10", "0", Ok);
      Check ("place c1", Ok and Well_Formed (S));
      P ("c2", "v1", "a", "5", "8", "5", Ok);
      Check ("overlap refused", not Ok);
      P ("c2", "v1", "a", "0", "40", "20", Ok);
      Check ("window past source refused", not Ok);
      P ("c2", "v1", "a", "8", "8", "20", Ok);
      Check ("empty window refused", not Ok);
      P ("c2", "v1", "a", "20", "25", "15", Ok);
      Check ("place c2 after gap", Ok and Well_Formed (S));
      Check ("sequence end 20", Sequence_End (S) = Sec ("20"));

      --  Insert before: sorted order maintained.
      P ("c0", "v1", "a", "0", "2", "11", Ok);
      Check ("place in the gap", Ok);
      Check ("clips sorted", S.Tracks (1).Clips (1).N = To_Name ("c1")
                             and S.Tracks (1).Clips (2).N = To_Name ("c0")
                             and S.Tracks (1).Clips (3).N = To_Name ("c2"));
      Check ("still well formed", Well_Formed (S));

      Move (S, To_Name ("c0"), Sec ("9"), Ok);
      Check ("move into c1 refused", not Ok);
      Move (S, To_Name ("c0"), Sec ("13"), Ok);
      Check ("move ok", Ok and Well_Formed (S));

      Trim (S, To_Name ("c1"), Sec ("0"), Sec ("14"), Ok);
      Check ("trim into next clip refused", not Ok);
      Trim (S, To_Name ("c1"), Sec ("2"), Sec ("12"), Ok);
      Check ("trim ok (in moved, at unchanged)", Ok);
      Find_Clip (S, To_Name ("c1"), T, I);
      Check ("trim kept start", S.Tracks (T).Clips (I).Start = 0
                                and S.Tracks (T).Clips (I).Src_In = Sec ("2"));

      Split (S, To_Name ("c1"), Sec ("4"), To_Name ("c1b"), Ok);
      Check ("split ok", Ok and Well_Formed (S));
      declare
         TL, TR : Track_Id;
         IL, IR : Clip_Index;
      begin
         Find_Clip (S, To_Name ("c1"), TL, IL);
         Find_Clip (S, To_Name ("c1b"), TR, IR);
         Check ("split partitions source window",
                S.Tracks (TL).Clips (IL).Src_Out = S.Tracks (TR).Clips (IR).Src_In
                and S.Tracks (TR).Clips (IR).Src_Out = Sec ("12"));
         Check ("split is contiguous on the timeline",
                Ends (S.Tracks (TL).Clips (IL)) = S.Tracks (TR).Clips (IR).Start
                and S.Tracks (TR).Clips (IR).Start = Sec ("4"));
      end;
      Split (S, To_Name ("c1"), Sec ("0"), To_Name ("x"), Ok);
      Check ("split at start refused", not Ok);
      Split (S, To_Name ("c1"), Sec ("1"), To_Name ("c2"), Ok);
      Check ("split with taken name refused", not Ok);

      Delete (S, To_Name ("c0"), Ok);
      Check ("delete", Ok and Well_Formed (S) and S.Tracks (1).Count = 3);
      Delete (S, To_Name ("nope"), Ok);
      Check ("delete unknown refused", not Ok);
   end Test_Timeline;

   procedure Test_Commands is
      C, D : Command;
      Ok   : Boolean;
      Err  : Error_String;
      Last : Natural;
      procedure Round_Trip (L : String);
      procedure Round_Trip (L : String) is
      begin
         Parse (L, C, Ok, Err, Last);
         Check ("parse: " & L, Ok);
         Parse (Image (C), D, Ok, Err, Last);
         Check ("round trip: " & Image (C), Ok and then Image (D) = Image (C));
      end Round_Trip;
   begin
      Round_Trip ("import a a.mp4 30 video");
      Round_Trip ("track v1 video");
      Round_Trip ("place c1 v1 a 2 8.5 0");
      Round_Trip ("move c1 12.25");
      Round_Trip ("trim c1 2 9");
      Round_Trip ("split c1 4 c2");
      Round_Trip ("delete c2");
      Round_Trip ("settings 1280 720 30");
      Round_Trip ("proxy a");
      Parse ("import a a.mp4", C, Ok, Err, Last);
      Check ("import needs length", not Ok);
      Parse ("place c1 v1 a 2 8.5", C, Ok, Err, Last);
      Check ("place needs 6 args", not Ok);
      Parse ("track v1 sideways", C, Ok, Err, Last);
      Check ("bad kind rejected", not Ok);
      Parse ("# hi", C, Ok, Err, Last);
      Check ("comment", Ok and C.K = Comment);
   end Test_Commands;

   procedure Test_Session is
      use Framewise.Session;
      S : Framewise.Session.Session;
      R : Response;
      function Has (R : Response; Sub : String) return Boolean is
        (for some I in 1 .. R.Length - Sub'Length + 1 =>
           R.Text (I .. I + Sub'Length - 1) = Sub);
   begin
      Execute (S, "import a a.mp4 30", R);
      Execute (S, "track v1", R);
      Execute (S, "place c1 v1 a 0 10 0", R);
      Check ("session place", R.Ok and History_Length (S) = 3);
      Execute (S, "place c2 v1 a 0 10 5", R);
      Check ("overlap not recorded", not R.Ok and History_Length (S) = 3);
      Execute (S, "info c1", R);
      Check ("info clip", R.Ok and Has (R, "length 10"));
      Execute (S, "plan out.mp4", R);
      Check ("plan is an ffmpeg line",
             R.Ok and Has (R, "-i a.mp4") and Has (R, "[vout]"));
      Execute (S, "undo", R);
      Check ("undo", R.Ok and History_Length (S) = 2);
      Execute (S, "plan out.mp4", R);
      Check ("plan with no clips fails", not R.Ok);
      Execute (S, "list", R);
      Check ("list", R.Ok and Has (R, "v1()"));
      Check ("history line", History_Line (S, 1) = "import a a.mp4 30 both");
      Execute (S, "proxy zz", R);
      Check ("proxy unknown source", not R.Ok and History_Length (S) = 2);
   end Test_Session;

begin
   Test_Time;
   Test_Timeline;
   Test_Commands;
   Test_Session;
   New_Line;
   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
