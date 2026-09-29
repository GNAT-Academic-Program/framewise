package body Framewise.ISOBMFF with SPARK_Mode is

   --  PLACEHOLDER. The algorithm is in the spec header.

   procedure Parse (Header : Byte_Array; File_Size : Natural; M : out File_Map) is
      pragma Unreferenced (Header, File_Size);
   begin
      M := (others => <>);
   end Parse;

   function Sample_At (T : Track; At_Time : Time) return Sample_Index is
      pragma Unreferenced (T, At_Time);
   begin
      return 0;
   end Sample_At;

end Framewise.ISOBMFF;
