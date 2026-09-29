--  ISO Base Media File Format (MP4 / MOV) demuxer. Pure Ada, SPARK.
--  PLACEHOLDER in the seed: Parse reports Ok = False.
--
--  Why our own: the proxy file (Motion JPEG + PCM in a .mov) is the
--  only file the editor reads, and reading it must not crash on a
--  malformed input. That is a parser over untrusted bytes with bounded
--  state, which is what SPARK proves best. No libavformat.
--
--  The format (ISO/IEC 14496-12) is a tree of boxes:
--
--     box := size (4 bytes, big-endian) type (4 chars) payload
--     size = 1  -> 64-bit largesize follows
--     size = 0  -> box extends to end of file
--
--  What we need, and nothing more:
--
--     ftyp                        ignore
--     moov                        container
--       mvhd                      timescale, duration
--       trak                      one per stream
--         tkhd                    track id
--         mdia
--           mdhd                  media timescale (ticks/s for this track)
--           hdlr                  'vide' or 'soun'
--           minf/stbl             the sample tables:
--             stsd                codec: 'jpeg' or 'sowt'/'lpcm'/'twos'
--             stts                sample durations (run-length)
--             stsc                samples per chunk (run-length)
--             stsz                sample sizes
--             stco / co64         chunk offsets (32 / 64 bit)
--     mdat                        the bytes; offsets above point here
--
--  ALGORITHM (Parse):
--    1. Walk top-level boxes. Remember mdat's range. Descend into moov.
--    2. For each trak, descend to stbl and read the five tables into
--       bounded arrays (Max_Samples). Reject a table that overflows.
--    3. Resolve: sample I's file offset = chunk offset of its chunk +
--       sum of sizes of earlier samples in that chunk (stsc + stsz +
--       stco). Sample I's time = sum of earlier durations (stts), in
--       the track's mdhd timescale; convert to Framewise.Time by
--       T * Timebase / timescale (exact when timescale divides
--       Timebase, which it does for 90000, 48000, 30, 25, 24).
--    4. Every resolved (offset, size) must lie inside mdat. Reject
--       otherwise. That is the postcondition that makes Frame_At safe.
--
--  ALGORITHM (Sample_At): binary search the video track's start times
--  for the last sample with start <= T. Intra-only means that sample
--  is the frame; no reference-frame walk.
--
--  Proof targets: no index out of range, no overflow in the offset
--  arithmetic, and Well_Formed (every sample inside mdat) as the post
--  of Parse.

package Framewise.ISOBMFF with SPARK_Mode is

   Max_Samples : constant := 65_536;   --  ~36 min of 30 fps proxy

   type Byte is mod 2 ** 8 with Size => 8;
   type Byte_Array is array (Positive range <>) of Byte with Pack;

   type Sample is record
      Offset : Natural := 0;          --  absolute, into the file
      Size   : Natural := 0;
      Start  : Time := 0;            --  in Framewise ticks
   end record;

   type Sample_Index is range 0 .. Max_Samples;
   type Sample_Array is array (Sample_Index range 1 .. Max_Samples) of Sample;

   type Track_Codec is (None, JPEG, PCM_S16);

   type Track is record
      Codec     : Track_Codec := None;
      Timescale : Positive := 1;
      Count     : Sample_Index := 0;
      Samples   : Sample_Array;
      --  PCM only:
      Channels  : Positive := 1;
      Rate      : Positive := 48_000;
   end record;

   type File_Map is record
      Ok         : Boolean := False;
      Mdat_First : Natural := 0;
      Mdat_Last  : Natural := 0;
      Video      : Track;
      Audio      : Track;
      Length     : Duration_T := 0;
   end record;

   function Inside (S : Sample; First, Last : Natural) return Boolean is
     (S.Offset >= First and then S.Offset <= Last
      and then S.Size <= Last - S.Offset + 1);

   function Track_OK (T : Track; First, Last : Natural) return Boolean is
     (for all I in 1 .. T.Count => Inside (T.Samples (I), First, Last));

   function Well_Formed (M : File_Map) return Boolean is
     (Track_OK (M.Video, M.Mdat_First, M.Mdat_Last)
      and then Track_OK (M.Audio, M.Mdat_First, M.Mdat_Last));

   procedure Parse (Header : Byte_Array; File_Size : Natural; M : out File_Map)
     with Post => (if M.Ok then Well_Formed (M));
   --  Header is the moov box and everything before it (the caller reads
   --  the file's first bytes; moov comes first in a proxy written with
   --  -movflags faststart, and ffmpeg's default for .mov puts it last,
   --  so the caller may have to read the tail: see Decode).

   function Sample_At (T : Track; At_Time : Time) return Sample_Index;
   --  0 when the track is empty or At_Time is before the first sample.

end Framewise.ISOBMFF;
