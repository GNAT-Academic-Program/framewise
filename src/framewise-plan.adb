package body Framewise.Plan is

   function Sec (T : Time) return String;
   function Img (N : Natural) return String;

   function Sec (T : Time) return String is
      --  Seconds with 5 decimals, enough for 90 kHz ticks to be exact
      --  in ffmpeg's microsecond parser.
      Whole : constant Time := T / Timebase;
      Frac  : constant Time := (T mod Timebase) * 100_000 / Timebase;
      W : constant String := Time'Image (Whole);
      F : constant String := Time'Image (Frac + 100_000);
   begin
      return W (W'First + 1 .. W'Last) & "." & F (F'First + 2 .. F'Last);
   end Sec;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   procedure Generate
     (S      : Sequence;
      Cfg    : Settings;
      Output : String;
      Plan   : out String;
      Last   : out Natural;
      Ok     : out Boolean)
   is
      P : Natural := Plan'First - 1;

      procedure Put (Str : String);
      procedure Emit_Track (T : Track_Id; Video : Boolean; Label : String);

      procedure Put (Str : String) is
      begin
         if Ok and then P + Str'Length <= Plan'Last then
            Plan (P + 1 .. P + Str'Length) := Str;
            P := P + Str'Length;
         else
            Ok := False;
         end if;
      end Put;

      --  Source k (1-based in the table) is ffmpeg input index k-1,
      --  but only used sources are listed, so map table id -> input.
      Input_Of : array (Source_Id range 1 .. Max_Sources) of Integer := [others => -1];
      Inputs   : Natural := 0;

      VT, ATr : Track_Id := 0;

      procedure Emit_Track (T : Track_Id; Video : Boolean; Label : String) is
         Tr     : Track renames S.Tracks (T);
         Cursor : Time := 0;
         Parts  : Natural := 0;
         function Tag (I : Natural) return String is (Label & Img (I));

      begin
         for I in 1 .. Tr.Count loop
            declare
               C : Clip renames Tr.Clips (I);
            begin
               if C.Start > Cursor then
                  --  gap
                  Parts := Parts + 1;
                  if Video then
                     Put ("color=black:size=" & Img (Cfg.Width) & "x" & Img (Cfg.Height)
                          & ":rate=" & Img (Cfg.FPS) & ":duration=" & Sec (C.Start - Cursor)
                          & "[" & Tag (Parts) & "];");
                  else
                     Put ("anullsrc=r=" & Img (Cfg.Sample_Rate) & ":cl=stereo,atrim=duration="
                          & Sec (C.Start - Cursor) & "[" & Tag (Parts) & "];");
                  end if;
               end if;
               Parts := Parts + 1;
               if Video then
                  Put ("[" & Img (Input_Of (C.Src)) & ":v]trim=start=" & Sec (C.Src_In)
                       & ":end=" & Sec (C.Src_Out) & ",setpts=PTS-STARTPTS,scale="
                       & Img (Cfg.Width) & ":" & Img (Cfg.Height) & ",fps=" & Img (Cfg.FPS)
                       & "[" & Tag (Parts) & "];");
               else
                  Put ("[" & Img (Input_Of (C.Src)) & ":a]atrim=start=" & Sec (C.Src_In)
                       & ":end=" & Sec (C.Src_Out) & ",asetpts=PTS-STARTPTS[" & Tag (Parts) & "];");
               end if;
               Cursor := Ends (C);
            end;
         end loop;
         for I in 1 .. Parts loop
            Put ("[" & Tag (I) & "]");
         end loop;
         Put ("concat=n=" & Img (Parts) & ":v=" & (if Video then "1" else "0")
              & ":a=" & (if Video then "0" else "1") & "[" & Label & "out];");
      end Emit_Track;

   begin
      Ok := True;
      Last := Plan'First - 1;
      Plan := [others => ' '];

      --  Pick tracks.
      for T in S.Tracks'Range loop
         if S.Tracks (T).Used and then S.Tracks (T).Count > 0 then
            if VT = 0 and then S.Tracks (T).Kind in Video | Both then
               VT := T;
            elsif ATr = 0 and then S.Tracks (T).Kind in Audio | Both then
               ATr := T;
            end if;
         end if;
      end loop;
      if VT = 0 then
         Ok := False;
         return;
      end if;

      --  Inputs: every source used by a chosen track, in table order.
      Put ("ffmpeg -y -hide_banner -loglevel error");
      for Src in S.Sources'Range loop
         if S.Sources (Src).Used then
            declare
               Used : Boolean := False;
            begin
               for T in S.Tracks'Range loop
                  if T = VT or else T = ATr then
                     for I in 1 .. S.Tracks (T).Count loop
                        if S.Tracks (T).Clips (I).Src = Src then
                           Used := True;
                        end if;
                     end loop;
                  end if;
               end loop;
               if Used then
                  Input_Of (Src) := Inputs;
                  Inputs := Inputs + 1;
                  Put (" -i " & Image (S.Sources (Src).File));
               end if;
            end;
         end if;
      end loop;

      Put (" -filter_complex """);
      Emit_Track (VT, True, "v");
      if ATr /= 0 then
         Emit_Track (ATr, False, "a");
      end if;
      --  Drop the trailing ';'
      if P >= Plan'First and then Plan (P) = ';' then
         P := P - 1;
      end if;
      Put (""" -map ""[vout]""");
      if ATr /= 0 then
         Put (" -map ""[aout]""");
      end if;
      Put (" -r " & Img (Cfg.FPS) & " -pix_fmt yuv420p " & Output);
      Last := P;
   end Generate;

end Framewise.Plan;
