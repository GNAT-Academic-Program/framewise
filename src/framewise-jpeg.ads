--  Baseline JPEG decoder (ITU T.81, sequential DCT, Huffman, 8-bit).
--  Pure Ada, SPARK. PLACEHOLDER in the seed: Decode reports Ok = False.
--
--  Why our own: the proxy is Motion JPEG, one baseline JPEG per frame,
--  because it is the simplest intra-only codec that every tool on
--  earth reads and writes, and a baseline decoder is ~2000 lines from
--  a 30-year-old spec. Progressive, arithmetic coding, 12-bit, CMYK:
--  not supported, and ffmpeg never writes them into MJPEG.
--
--  Bitstream:
--    SOI  FFD8
--    APPn FFEn   skip (JFIF/AVI1 header)
--    DQT  FFDB   quantization tables, 8x8, zigzag order
--    SOF0 FFC0   height, width, components (1 or 3), sampling factors
--                (4:2:0 in our proxies: Y 2x2, Cb 1x1, Cr 1x1)
--    DHT  FFC4   Huffman tables: DC/AC x table 0/1
--    SOS  FFDA   scan header, then entropy-coded data until EOI
--    EOI  FFD9
--  Inside the scan, FF00 is a stuffed FF; FFD0..FFD7 are restart markers
--  (ffmpeg writes none for MJPEG, but handle them: reset DC predictors).
--
--  ALGORITHM (Decode), per MCU (16x16 pixels at 4:2:0), left to right,
--  top to bottom:
--    1. For each block of the MCU (4 Y, 1 Cb, 1 Cr):
--       a. DC: read Huffman symbol S from the DC table, read S extra
--          bits, extend sign, add to the component's DC predictor.
--       b. AC: coefficients 1..63 in zigzag order. Read symbol (R, S):
--          R zeros to skip, S bits of value; 0x00 = end of block,
--          0xF0 = 16 zeros.
--       c. Dequantize: coef (i) * Q (i).
--       d. Un-zigzag into an 8x8, inverse DCT (separable, integer:
--          the AAN or the plain O(N^2) row-column form; the plain one
--          is fine at 540p and is the one you can prove), +128, clamp
--          to 0..255.
--    2. Upsample Cb and Cr 2x (nearest is fine for a proxy), convert
--       YCbCr to RGB:
--          R = Y + 1.402 (Cr-128)
--          G = Y - 0.344 (Cb-128) - 0.714 (Cr-128)
--          B = Y + 1.772 (Cb-128)
--       in fixed point (x256), clamp, write RGBA with A = 255.
--
--  Proof targets: no index out of range in the Huffman lookup and the
--  bit reader on any input (a truncated scan ends the decode with
--  Ok = False, never an exception), no overflow in IDCT accumulators
--  (bound them: 12 bits of coefficient x 8 bits of basis x 64 terms).
--  This package is the SPARK showpiece of the project.

package Framewise.JPEG with SPARK_Mode is

   type Byte is mod 2 ** 8 with Size => 8;
   type Byte_Array is array (Positive range <>) of Byte with Pack;

   Max_Width  : constant := 1920;
   Max_Height : constant := 1080;

   type Header is record
      Width, Height : Natural := 0;
      Components    : Natural := 0;   --  1 grey, 3 YCbCr
   end record;

   procedure Read_Header (Data : Byte_Array; H : out Header; Ok : out Boolean)
     with Post => (if Ok then H.Width in 1 .. Max_Width and then H.Height in 1 .. Max_Height);
   --  Scans markers up to SOF0. Cheap: lets the caller size the buffer.

   procedure Decode (Data : Byte_Array; H : Header; Pixels : out Byte_Array; Ok : out Boolean)
     with Pre  => H.Width in 1 .. Max_Width and then H.Height in 1 .. Max_Height
                  and then Pixels'Length >= H.Width * H.Height * 4,
          Post => (if not Ok then Pixels'Length >= 0);
   --  RGBA, row-major, top-down, straight alpha 255.

end Framewise.JPEG;
