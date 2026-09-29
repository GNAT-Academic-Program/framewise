package body Framewise.Timeline with SPARK_Mode is

   -----------------
   -- Find_Source --
   -----------------

   function Find_Source (S : Sequence; N : Name) return Source_Id is
   begin
      for I in S.Sources'Range loop
         if S.Sources (I).Used and then S.Sources (I).N = N then
            return I;
         end if;
      end loop;
      return No_Source;
   end Find_Source;

   ----------------
   -- Find_Track --
   ----------------

   function Find_Track (S : Sequence; N : Name) return Track_Id is
   begin
      for T in S.Tracks'Range loop
         if S.Tracks (T).Used and then S.Tracks (T).N = N then
            return T;
         end if;
      end loop;
      return 0;
   end Find_Track;

   ---------------
   -- Find_Clip --
   ---------------

   procedure Find_Clip
     (S : Sequence; N : Name; T : out Track_Id; I : out Clip_Index) is
   begin
      for TT in S.Tracks'Range loop
         if S.Tracks (TT).Used then
            for II in 1 .. S.Tracks (TT).Count loop
               if S.Tracks (TT).Clips (II).N = N then
                  T := TT;
                  I := II;
                  return;
               end if;
            end loop;
         end if;
      end loop;
      T := 0;
      I := 0;
   end Find_Clip;

   ---------------
   -- Track_End --
   ---------------

   function Track_End (S : Sequence; T : Track_Id) return Time is
      Tr : Track renames S.Tracks (T);
   begin
      if not Tr.Used or else Tr.Count = 0 then
         return 0;
      end if;
      return Ends (Tr.Clips (Tr.Count));
   end Track_End;

   ------------------
   -- Sequence_End --
   ------------------

   function Sequence_End (S : Sequence) return Time is
      E : Time := 0;
   begin
      for T in S.Tracks'Range loop
         E := Time'Max (E, Track_End (S, T));
      end loop;
      return E;
   end Sequence_End;

   -----------
   -- Clear --
   -----------

   procedure Clear (S : out Sequence) is
   begin
      S := (Sources => [others => <>], Tracks => [others => <>]);
   end Clear;

   ----------------
   -- Add_Source --
   ----------------

   procedure Add_Source
     (S : in out Sequence; N : Name; File : Path; Length : Duration_T;
      Kind : Media_Kind; Ok : out Boolean) is
   begin
      Ok := False;
      if Find_Source (S, N) /= No_Source then
         return;
      end if;
      for I in S.Sources'Range loop
         if not S.Sources (I).Used then
            S.Sources (I) := (Used => True, N => N, File => File, Length => Length, Kind => Kind);
            Ok := True;
            return;
         end if;
      end loop;
   end Add_Source;

   ---------------
   -- Add_Track --
   ---------------

   procedure Add_Track (S : in out Sequence; N : Name; Kind : Media_Kind; Ok : out Boolean) is
   begin
      Ok := False;
      if Find_Track (S, N) /= 0 then
         return;
      end if;
      for T in S.Tracks'Range loop
         if not S.Tracks (T).Used then
            S.Tracks (T).Used := True;
            S.Tracks (T).N := N;
            S.Tracks (T).Kind := Kind;
            S.Tracks (T).Count := 0;
            Ok := True;
            return;
         end if;
      end loop;
   end Add_Track;

   ---------------------------------------------------------------------
   --  Helpers on one track
   ---------------------------------------------------------------------

   --  True when a clip [Start, Start + Len) would overlap any clip on Tr
   --  other than slot Skip (0 = none).
   function Overlaps (Tr : Track; Start, Len : Time; Skip : Clip_Index) return Boolean
     with Pre => Start <= Time'Last / 2 and then Len <= Time'Last / 2
                 and then Tr.Count <= Max_Clips
                 and then (for all I in 1 .. Tr.Count =>
                             Tr.Clips (I).Src_In <= Tr.Clips (I).Src_Out
                             and then Tr.Clips (I).Start <= Time'Last / 2
                             and then Tr.Clips (I).Src_Out <= Time'Last / 2);

   procedure Insert_Sorted (Tr : in out Track; C : Clip)
     with Pre => Tr.Count < Max_Clips;

   procedure Remove_At (Tr : in out Track; I : Clip_Index)
     with Pre => I in 1 .. Tr.Count;

   function Overlaps (Tr : Track; Start, Len : Time; Skip : Clip_Index) return Boolean
   is
   begin
      for I in 1 .. Tr.Count loop
         if I /= Skip then
            declare
               C : Clip renames Tr.Clips (I);
            begin
               if Start < Ends (C) and then C.Start < Start + Len then
                  return True;
               end if;
            end;
         end if;
      end loop;
      return False;
   end Overlaps;

   --  Insert C into Tr keeping clips sorted by Start. Caller has checked
   --  no overlap and room.
   procedure Insert_Sorted (Tr : in out Track; C : Clip) is
      Pos : Clip_Index := Tr.Count + 1;
   begin
      for I in 1 .. Tr.Count loop
         if Tr.Clips (I).Start > C.Start then
            Pos := I;
            exit;
         end if;
      end loop;
      for I in reverse Pos .. Tr.Count loop
         Tr.Clips (I + 1) := Tr.Clips (I);
      end loop;
      Tr.Clips (Pos) := C;
      Tr.Count := Tr.Count + 1;
   end Insert_Sorted;

   procedure Remove_At (Tr : in out Track; I : Clip_Index) is
   begin
      for J in I .. Tr.Count - 1 loop
         Tr.Clips (J) := Tr.Clips (J + 1);
      end loop;
      Tr.Count := Tr.Count - 1;
   end Remove_At;

   -----------
   -- Place --
   -----------

   procedure Place
     (S : in out Sequence; Clip_Name : Name; On : Name; From : Name;
      Src_In, Src_Out, Start : Time; Ok : out Boolean)
   is
      T   : constant Track_Id  := Find_Track (S, On);
      Src : constant Source_Id := Find_Source (S, From);
      DT  : Track_Id;
      DI  : Clip_Index;
      C   : Clip;
   begin
      Ok := False;
      if T = 0 or else Src = No_Source then
         return;
      end if;
      Find_Clip (S, Clip_Name, DT, DI);
      if DT /= 0 then
         return;  --  duplicate name
      end if;
      C := (N => Clip_Name, Src => Src, Src_In => Src_In, Src_Out => Src_Out, Start => Start);
      if not Clip_OK (S, C) then
         return;
      end if;
      if S.Tracks (T).Count = Max_Clips then
         return;
      end if;
      if Overlaps (S.Tracks (T), Start, Src_Out - Src_In, 0) then
         return;
      end if;
      Insert_Sorted (S.Tracks (T), C);
      Ok := True;
   end Place;

   ----------
   -- Move --
   ----------

   procedure Move (S : in out Sequence; Clip_Name : Name; To : Time; Ok : out Boolean) is
      T : Track_Id;
      I : Clip_Index;
      C : Clip;
   begin
      Ok := False;
      Find_Clip (S, Clip_Name, T, I);
      if T = 0 or else To > Time'Last / 2 then
         return;
      end if;
      C := S.Tracks (T).Clips (I);
      if Overlaps (S.Tracks (T), To, Length (C), I) then
         return;
      end if;
      C.Start := To;
      Remove_At (S.Tracks (T), I);
      Insert_Sorted (S.Tracks (T), C);
      Ok := True;
   end Move;

   ----------
   -- Trim --
   ----------

   procedure Trim
     (S : in out Sequence; Clip_Name : Name; New_In, New_Out : Time; Ok : out Boolean)
   is
      T : Track_Id;
      I : Clip_Index;
      C : Clip;
   begin
      Ok := False;
      Find_Clip (S, Clip_Name, T, I);
      if T = 0 then
         return;
      end if;
      C := S.Tracks (T).Clips (I);
      C.Src_In := New_In;
      C.Src_Out := New_Out;
      if not Clip_OK (S, C) then
         return;
      end if;
      if Overlaps (S.Tracks (T), C.Start, Length (C), I) then
         return;
      end if;
      S.Tracks (T).Clips (I) := C;
      Ok := True;
   end Trim;

   -----------
   -- Split --
   -----------

   procedure Split
     (S : in out Sequence; Clip_Name : Name; Start : Time; Right_Name : Name; Ok : out Boolean)
   is
      T  : Track_Id;
      I  : Clip_Index;
      DT : Track_Id;
      DI : Clip_Index;
      L, R : Clip;
      Offset : Time;
   begin
      Ok := False;
      Find_Clip (S, Clip_Name, T, I);
      if T = 0 then
         return;
      end if;
      Find_Clip (S, Right_Name, DT, DI);
      if DT /= 0 then
         return;  --  right name taken
      end if;
      L := S.Tracks (T).Clips (I);
      if Start <= L.Start or else Start >= Ends (L) then
         return;  --  cut must be strictly inside
      end if;
      if S.Tracks (T).Count = Max_Clips then
         return;
      end if;
      Offset := Start - L.Start;
      R := (N => Right_Name, Src => L.Src, Src_In => L.Src_In + Offset,
            Src_Out => L.Src_Out, Start => Start);
      L.Src_Out := L.Src_In + Offset;
      --  L now ends exactly where R starts: Ends (L) = Start = R.Start. T3.
      S.Tracks (T).Clips (I) := L;
      Insert_Sorted (S.Tracks (T), R);
      Ok := True;
   end Split;

   ------------
   -- Delete --
   ------------

   procedure Delete (S : in out Sequence; Clip_Name : Name; Ok : out Boolean) is
      T : Track_Id;
      I : Clip_Index;
   begin
      Find_Clip (S, Clip_Name, T, I);
      if T = 0 then
         Ok := False;
         return;
      end if;
      Remove_At (S.Tracks (T), I);
      Ok := True;
   end Delete;

end Framewise.Timeline;
