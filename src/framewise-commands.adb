package body Framewise.Commands with SPARK_Mode => Off is
   --  Off for 'Value / 'Image. Hand-rolling the number parser in SPARK
   --  is a fair small task.

   Max_Tokens : constant := 8;
   type Bounds is record
      First, Last : Natural := 0;
   end record;
   type Token_Array is array (1 .. Max_Tokens) of Bounds;

   procedure Tokenize (Line : String; T : out Token_Array; N : out Natural);
   function Lower (S : String) return String;
   function Kind_Img (K : Media_Kind) return String;

   procedure Tokenize (Line : String; T : out Token_Array; N : out Natural) is
      I : Natural := Line'First;
   begin
      N := 0;
      T := [others => <>];
      while I <= Line'Last loop
         while I <= Line'Last and then Line (I) = ' ' loop
            I := I + 1;
         end loop;
         exit when I > Line'Last or else N = Max_Tokens;
         N := N + 1;
         T (N).First := I;
         while I <= Line'Last and then Line (I) /= ' ' loop
            I := I + 1;
         end loop;
         T (N).Last := I - 1;
      end loop;
   end Tokenize;

   function Lower (S : String) return String is
      R : String := S;
   begin
      for I in R'Range loop
         if R (I) in 'A' .. 'Z' then
            R (I) := Character'Val (Character'Pos (R (I)) + 32);
         end if;
      end loop;
      return R;
   end Lower;

   ----------------
   -- Image_Time --
   ----------------

   function Image_Time (T : Time) return String is
      Whole : constant Time := T / Timebase;
      Rem_T : constant Time := T mod Timebase;
      W : constant String := Time'Image (Whole);
      Ws : constant String := W (W'First + 1 .. W'Last);
   begin
      if Rem_T = 0 then
         return Ws;
      end if;
      declare
         --  Up to 5 decimals: 90_000 ticks per second means a tick is
         --  1/90000 s; 5 decimals is not exact for every tick, so the
         --  contract is "exact for the values Value_Time produces".
         Frac : constant Time := Rem_T * 100_000 / Timebase;
         F : constant String := Time'Image (Frac + 100_000);
         D : constant String := F (F'First + 2 .. F'Last);
         L : Natural := D'Last;
      begin
         while L > D'First and then D (L) = '0' loop
            L := L - 1;
         end loop;
         return Ws & "." & D (D'First .. L);
      end;
   end Image_Time;

   ----------------
   -- Value_Time --
   ----------------

   procedure Value_Time (S : String; T : out Time; Ok : out Boolean) is
      Dot   : Natural := 0;
      Whole : Time := 0;
      Frac  : Time := 0;
      Scale : Time := 1;
   begin
      T := 0;
      Ok := False;
      if S'Length = 0 then
         return;
      end if;
      for I in S'Range loop
         if S (I) = '.' then
            if Dot /= 0 then
               return;
            end if;
            Dot := I;
         elsif S (I) not in '0' .. '9' then
            return;
         elsif Dot = 0 then
            if Whole > Time'Last / 20 then
               return;
            end if;
            Whole := Whole * 10 + Time (Character'Pos (S (I)) - Character'Pos ('0'));
         else
            if Scale < 1_000_000 then
               Frac := Frac * 10 + Time (Character'Pos (S (I)) - Character'Pos ('0'));
               Scale := Scale * 10;
            end if;
         end if;
      end loop;
      if Whole > Time'Last / Timebase / 2 then
         return;
      end if;
      T := Whole * Timebase + Frac * Timebase / Scale;
      Ok := True;
   end Value_Time;

   -----------
   -- Parse --
   -----------

   procedure Parse
     (Line  : String; C : out Command; Ok : out Boolean;
      Error : out Error_String; Last : out Natural)
   is
      T : Token_Array;
      N : Natural;
      G : Boolean := True;

      Names : array (1 .. 3) of Name;
      Times : array (1 .. 3) of Time := [others => 0];
      Kd    : Media_Kind := Both;
      Ints  : array (1 .. 3) of Positive := [others => 1];
      Pth   : Path;

      function Tok (I : Positive) return String is (Line (T (I).First .. T (I).Last));

      procedure Need (Lo, Hi : Natural);
      procedure Get_Name (Tok_I, Into : Positive);
      procedure Get_Time (Tok_I, Into : Positive);
      procedure Get_Kind (Tok_I : Positive; Default : Media_Kind);
      procedure Get_Int (Tok_I, Into : Positive);
      procedure Get_Path (Tok_I : Positive);
      procedure Fail (Msg : String);

      procedure Need (Lo, Hi : Natural) is
      begin
         if N < Lo or else N > Hi then
            G := False;
         end if;
      end Need;

      procedure Get_Name (Tok_I, Into : Positive) is
         S : constant String := Tok (Tok_I);
      begin
         if not G or else Tok_I > N then
            G := False;
            return;
         end if;
         if S'Length > Max_Name then
            G := False;
            return;
         end if;
         for Ch of S loop
            if not (Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_') then
               G := False;
               return;
            end if;
         end loop;
         Names (Into) := To_Name (S);
      end Get_Name;

      procedure Get_Time (Tok_I, Into : Positive) is
         V  : Time;
         OkT : Boolean;
      begin
         if not G or else Tok_I > N then
            G := False;
            return;
         end if;
         Value_Time (Tok (Tok_I), V, OkT);
         if OkT then
            Times (Into) := V;
         else
            G := False;
         end if;
      end Get_Time;

      procedure Get_Kind (Tok_I : Positive; Default : Media_Kind) is
      begin
         Kd := Default;
         if Tok_I > N then
            return;
         end if;
         declare
            S : constant String := Lower (Tok (Tok_I));
         begin
            if S = "video" then
               Kd := Video;
            elsif S = "audio" then
               Kd := Audio;
            elsif S = "both" then
               Kd := Both;
            else
               G := False;
            end if;
         end;
      end Get_Kind;

      procedure Get_Int (Tok_I, Into : Positive) is
      begin
         if not G or else Tok_I > N then
            G := False;
            return;
         end if;
         Ints (Into) := Positive'Value (Tok (Tok_I));
      exception
         when Constraint_Error => G := False;
      end Get_Int;

      procedure Get_Path (Tok_I : Positive) is
         S : constant String := Tok (Tok_I);
      begin
         if not G or else Tok_I > N or else S'Length > Max_Path then
            G := False;
            return;
         end if;
         Pth := To_Path (S);
      end Get_Path;

      procedure Fail (Msg : String) is
         L : constant Natural := Natural'Min (Msg'Length, Max_Error);
      begin
         C := (K => Empty);
         Ok := False;
         Error := [others => ' '];
         Error (1 .. L) := Msg (Msg'First .. Msg'First + L - 1);
         Last := L;
      end Fail;

   begin
      Ok := True;
      Error := [others => ' '];
      Last := 0;
      C := (K => Empty);
      Tokenize (Line, T, N);
      if N = 0 then
         return;
      end if;
      if Line (T (1).First) = '#' then
         C := (K => Comment);
         return;
      end if;

      declare
         Verb : constant String := Lower (Tok (1));
      begin
         if Verb = "import" then
            Need (4, 5); Get_Name (2, 1); Get_Path (3); Get_Time (4, 1); Get_Kind (5, Both);
            if G then
               C := (K => Import, Src_Name => Names (1), File => Pth, Length => Times (1),
                     Src_Kind => Kd);
            end if;
         elsif Verb = "track" then
            Need (2, 3); Get_Name (2, 1); Get_Kind (3, Video);
            if G then
               C := (K => Track, Trk_Name => Names (1), Trk_Kind => Kd);
            end if;
         elsif Verb = "place" then
            Need (7, 7); Get_Name (2, 1); Get_Name (3, 2); Get_Name (4, 3);
            Get_Time (5, 1); Get_Time (6, 2); Get_Time (7, 3);
            if G then
               C := (K => Place, Clip_Name => Names (1), On => Names (2), From => Names (3),
                     Src_In => Times (1), Src_Out => Times (2), Start => Times (3));
            end if;
         elsif Verb = "move" then
            Need (3, 3); Get_Name (2, 1); Get_Time (3, 1);
            if G then
               C := (K => Move, Mv_Name => Names (1), To => Times (1));
            end if;
         elsif Verb = "trim" then
            Need (4, 4); Get_Name (2, 1); Get_Time (3, 1); Get_Time (4, 2);
            if G then
               C := (K => Trim, Tr_Name => Names (1), New_In => Times (1), New_Out => Times (2));
            end if;
         elsif Verb = "split" then
            Need (4, 4); Get_Name (2, 1); Get_Time (3, 1); Get_Name (4, 2);
            if G then
               C := (K => Split, Sp_Name => Names (1), Cut => Times (1), Right => Names (2));
            end if;
         elsif Verb = "delete" then
            Need (2, 2); Get_Name (2, 1);
            if G then
               C := (K => Delete, Target => Names (1));
            end if;
         elsif Verb = "settings" then
            Need (4, 4); Get_Int (2, 1); Get_Int (3, 2); Get_Int (4, 3);
            if G then
               C := (K => Settings, Width => Ints (1), Height => Ints (2), FPS => Ints (3));
            end if;
         elsif Verb = "list" then
            Need (1, 1);
            C := (K => List);
         elsif Verb = "info" then
            Need (2, 2); Get_Name (2, 1);
            if G then
               C := (K => Info, Target => Names (1));
            end if;
         elsif Verb = "plan" then
            Need (2, 2); Get_Path (2);
            if G then
               C := (K => Plan, Out_File => Pth);
            end if;
         elsif Verb = "export" then
            Need (2, 2); Get_Path (2);
            if G then
               C := (K => Export, Out_File => Pth);
            end if;
         elsif Verb = "proxy" then
            Need (2, 2); Get_Name (2, 1);
            if G then
               C := (K => Proxy, Target => Names (1));
            end if;
         elsif Verb = "undo" then
            Need (1, 1);
            C := (K => Undo);
         elsif Verb = "save" then
            Need (2, 2); Get_Path (2);
            if G then
               C := (K => Save, Out_File => Pth);
            end if;
         elsif Verb = "load" then
            Need (2, 2); Get_Path (2);
            if G then
               C := (K => Load, Out_File => Pth);
            end if;
         else
            Fail ("unknown command: " & Tok (1));
            return;
         end if;
         if not G then
            Fail ("bad arguments for " & Verb);
         end if;
      end;
   end Parse;

   -----------
   -- Image --
   -----------

   function Kind_Img (K : Media_Kind) return String is
     (case K is when Video => "video", when Audio => "audio", when Both => "both");

   function Image (C : Command) return String is
      function Ni (N : Positive) return String;
      function Ni (N : Positive) return String is
         S : constant String := Positive'Image (N);
      begin
         return S (S'First + 1 .. S'Last);
      end Ni;
   begin
      case C.K is
         when Import =>
            return "import " & Image (C.Src_Name) & " " & Image (C.File) & " "
              & Image_Time (C.Length) & " " & Kind_Img (C.Src_Kind);
         when Track =>
            return "track " & Image (C.Trk_Name) & " " & Kind_Img (C.Trk_Kind);
         when Place =>
            return "place " & Image (C.Clip_Name) & " " & Image (C.On) & " " & Image (C.From)
              & " " & Image_Time (C.Src_In) & " " & Image_Time (C.Src_Out) & " "
              & Image_Time (C.Start);
         when Move =>
            return "move " & Image (C.Mv_Name) & " " & Image_Time (C.To);
         when Trim =>
            return "trim " & Image (C.Tr_Name) & " " & Image_Time (C.New_In) & " "
              & Image_Time (C.New_Out);
         when Split =>
            return "split " & Image (C.Sp_Name) & " " & Image_Time (C.Cut) & " " & Image (C.Right);
         when Delete =>
            return "delete " & Image (C.Target);
         when Settings =>
            return "settings " & Ni (C.Width) & " " & Ni (C.Height) & " " & Ni (C.FPS);
         when List =>
            return "list";
         when Info =>
            return "info " & Image (C.Target);
         when Plan =>
            return "plan " & Image (C.Out_File);
         when Export =>
            return "export " & Image (C.Out_File);
         when Proxy =>
            return "proxy " & Image (C.Target);
         when Undo =>
            return "undo";
         when Save =>
            return "save " & Image (C.Out_File);
         when Load =>
            return "load " & Image (C.Out_File);
         when Comment =>
            return "#";
         when Empty =>
            return "";
      end case;
   end Image;

end Framewise.Commands;
