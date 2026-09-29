package body Framewise.Decode is

   --  PLACEHOLDER. See the spec.

   procedure Probe (File : String; Length : out Duration_T; Kind_Video, Kind_Audio : out Boolean;
                    Ok : out Boolean) is
      pragma Unreferenced (File);
   begin
      Length := 0;
      Kind_Video := False;
      Kind_Audio := False;
      Ok := False;
   end Probe;

   procedure Open (H : in out Handle; File : String; Ok : out Boolean) is
      pragma Unreferenced (File);
   begin
      H.Opened := False;
      Ok := False;
   end Open;

   procedure Close (H : in out Handle) is
   begin
      H.Opened := False;
   end Close;

   procedure Frame_At
     (H : in out Handle; T : Time; Width, Height : Positive;
      Pixels : out RGBA_Buffer; Ok : out Boolean) is
      pragma Unreferenced (H, T, Width, Height);
   begin
      Pixels := [others => 0];
      Ok := False;
   end Frame_At;

end Framewise.Decode;
