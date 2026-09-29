package body Framewise with SPARK_Mode is

   function To_Name (S : String) return Name is
      N : Name;
   begin
      N.Length := S'Length;
      N.Text (1 .. S'Length) := S;
      return N;
   end To_Name;

   function To_Path (S : String) return Path is
      P : Path;
   begin
      P.Length := S'Length;
      P.Text (1 .. S'Length) := S;
      return P;
   end To_Path;

end Framewise;
