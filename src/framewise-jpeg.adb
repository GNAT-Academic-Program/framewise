package body Framewise.JPEG with SPARK_Mode is

   --  PLACEHOLDER. The algorithm is in the spec header.

   procedure Read_Header (Data : Byte_Array; H : out Header; Ok : out Boolean) is
      pragma Unreferenced (Data);
   begin
      H := (others => <>);
      Ok := False;
   end Read_Header;

   procedure Decode (Data : Byte_Array; H : Header; Pixels : out Byte_Array; Ok : out Boolean)
   is
      pragma Unreferenced (Data, H);
   begin
      Pixels := [others => 0];
      Ok := False;
   end Decode;

end Framewise.JPEG;
