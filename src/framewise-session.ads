--  The session: the single entry point for every front end.
--
--     Execute (S, "place c1 v1 intro 12.0 18.5 4.0", Response)
--
--  State = a Sequence + render settings + the history of modeling
--  commands. Undo pops the history and replays from empty. Save writes
--  the history; load replays a file. The .fw document IS the history.
--
--  No heap needed: a Sequence is bounded and lives inside the Session.
--  Export spawns ffmpeg with the plan; plan only prints it.

with Framewise.Commands; use Framewise.Commands;
with Framewise.Plan;
with Framewise.Timeline;

package Framewise.Session is

   Max_History : constant := 4096;

   type Session is limited private;

   Max_Response : constant := 16_384;

   type Response is record
      Ok     : Boolean := True;
      Length : Natural range 0 .. Max_Response := 0;
      Text   : String (1 .. Max_Response) := [others => ' '];
   end record;

   function Image (R : Response) return String is (R.Text (1 .. R.Length));

   procedure Execute (S : in out Session; Line : String; R : out Response);

   ---------------------------------------------------------------------
   --  Read-back for front ends
   ---------------------------------------------------------------------

   function Sequence_Of (S : Session) return Timeline.Sequence;
   --  A copy; the GUI draws the timeline from it. Bounded, so cheap
   --  enough per Execute.

   function Settings_Of (S : Session) return Plan.Settings;

   function History_Length (S : Session) return Natural;
   function History_Line (S : Session; I : Positive) return String
     with Pre => I <= History_Length (S);

private

   type History_Array is array (1 .. Max_History) of Command;

   type Session is limited record
      Seq     : Timeline.Sequence;
      Cfg     : Plan.Settings := Plan.Default_Settings;
      History : History_Array;
      Count   : Natural := 0;
   end record;

end Framewise.Session;
