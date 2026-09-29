--  The command language. One line, one operation. The document (.fw)
--  is these lines; the GUI emits them; an agent emits them.
--
--  Times are seconds as decimals on the wire ("12.5"), ticks inside.
--
--    import   NAME FILE LENGTH [video|audio|both]   register a source
--    track    NAME [video|audio|both]               default video
--    place    CLIP TRACK SOURCE IN OUT AT            clip of SOURCE [IN,OUT) at AT
--    move     CLIP AT
--    trim     CLIP IN OUT
--    split    CLIP AT RIGHTNAME
--    delete   CLIP
--    settings WIDTH HEIGHT FPS                       render settings (recorded)
--    list                                            query
--    info     [CLIP|TRACK|SOURCE]                    query
--    plan     OUT.mp4                                print the ffmpeg command
--    export   OUT.mp4                                run it
--    undo
--    save     FILE.fw
--    load     FILE.fw
--    # comment
--
--  import LENGTH is required in the seed because Decode.Probe is a
--  placeholder. When probe lands, LENGTH becomes optional.

package Framewise.Commands with SPARK_Mode is

   type Kind is
     (Import, Track, Place, Move, Trim, Split, Delete, Settings,
      List, Info, Plan, Export, Undo, Save, Load, Comment, Empty);

   subtype Modeling is Kind range Import .. Settings;

   type Media_Kind is (Video, Audio, Both);

   type Command (K : Kind := Empty) is record
      case K is
         when Import =>
            Src_Name : Name;
            File     : Path;
            Length   : Time := 0;
            Src_Kind : Media_Kind := Both;
         when Track =>
            Trk_Name : Name;
            Trk_Kind : Media_Kind := Video;
         when Place =>
            Clip_Name : Name;
            On, From  : Name;
            Src_In, Src_Out, Start : Time := 0;
         when Move =>
            Mv_Name : Name;
            To      : Time := 0;
         when Trim =>
            Tr_Name : Name;
            New_In, New_Out : Time := 0;
         when Split =>
            Sp_Name  : Name;
            Cut      : Time := 0;
            Right    : Name;
         when Delete | Info =>
            Target   : Name;
         when Settings =>
            Width, Height, FPS : Positive := 1;
         when Plan | Export | Save | Load =>
            Out_File : Path;
         when List | Undo | Comment | Empty =>
            null;
      end case;
   end record;

   Max_Line : constant := 512;

   Max_Error : constant := 128;
   subtype Error_String is String (1 .. Max_Error);

   procedure Parse
     (Line  : String; C : out Command; Ok : out Boolean;
      Error : out Error_String; Last : out Natural)
     with Pre => Line'Length <= Max_Line, Post => Last <= Max_Error;

   function Image (C : Command) return String
     with Post => Image'Result'Length <= Max_Line;

   function Image_Time (T : Time) return String;
   --  Seconds, "12.5" style, exact for any tick count (up to 5 decimals).

   procedure Value_Time (S : String; T : out Time; Ok : out Boolean);

end Framewise.Commands;
