--  framewise: the command-line front end.
--
--     framewise_cli                 REPL on stdin, one response line per command
--     framewise_cli edit.fw          run a file, then keep reading stdin
--     framewise_cli -c "load edit.fw" -c "plan out.mp4"
--
--  This program contains no modeling logic. It reads lines, hands them
--  to Framewise.Session.Execute, prints the response. That is the design:
--  the GUI is the same thing with a picture. An agent is the same thing
--  with a pipe.
--
--  Exit status is the number of failed commands, capped at 255, so a
--  script that goes wrong is visible to whatever ran it.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Framewise.Session;    use Framewise.Session;

procedure Framewise_CLI is
   S        : Session;
   R        : Response;
   Failures : Natural := 0;
   I        : Positive := 1;

   procedure Run (Line : String);
   procedure Run (Line : String) is
   begin
      Execute (S, Line, R);
      Put_Line (Image (R));
      if not R.Ok then
         Failures := Failures + 1;
      end if;
   end Run;

begin
   while I <= Argument_Count loop
      if Argument (I) = "-c" and then I < Argument_Count then
         Run (Argument (I + 1));
         I := I + 2;
      else
         Run ("load " & Argument (I));
         I := I + 1;
      end if;
   end loop;

   if Argument_Count = 0 or else (Argument_Count >= 1 and then Argument (1) /= "-c") then
      while not End_Of_File loop
         Run (Get_Line);
      end loop;
   end if;

   Set_Exit_Status (Exit_Status (Natural'Min (Failures, 255)));
end Framewise_CLI;
