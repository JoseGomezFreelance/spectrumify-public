program Spectrumify;
{
  Spectrumify — Version Pascal (Free Pascal + SDL2)
  Conversor de imagenes a pixel-art HTML con paleta ZX Spectrum
  (c) 2026 JGF

  Compilar: fpc -O2 -Mobjfpc spectrumify.pas
  Ejecutar: ./spectrumify
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Process, sdl2,
  FPImage, FPReadPNG, FPReadJPEG, FPReadBMP, FPWriteBMP,
  GIFWriter;

{ ================================================================ }
{ Constantes                                                        }
{ ================================================================ }

const
  WIN_W = 1024;
  WIN_H = 700;
  HEADER_H = 40;
  STATUS_H = 60;
  CONTROLS_H = 36;
  SEP_H = 2;
  MARGIN = 16;
  PREVIEW_Y = HEADER_H + SEP_H;
  PREVIEW_H = WIN_H - HEADER_H - STATUS_H - CONTROLS_H - SEP_H * 3;

  MODE_16 = 0;
  MODE_GRAY = 1;
  MODE_BW = 2;

type
  TColor3 = record R, G, B: Byte; end;
  TPixelArray = array of TColor3;

const
  PALETTE_16: array[0..15] of TColor3 = (
    (R:0;G:0;B:0),     (R:0;G:0;B:170),   (R:170;G:0;B:0),     (R:170;G:0;B:170),
    (R:0;G:170;B:0),   (R:0;G:170;B:170), (R:170;G:85;B:0),    (R:170;G:170;B:170),
    (R:85;G:85;B:85),  (R:85;G:85;B:255), (R:255;G:85;B:85),   (R:255;G:85;B:255),
    (R:85;G:255;B:85), (R:85;G:255;B:255),(R:255;G:255;B:85),  (R:255;G:255;B:255)
  );

  PALETTE_GRAY: array[0..3] of TColor3 = (
    (R:0;G:0;B:0), (R:85;G:85;B:85), (R:170;G:170;B:170), (R:255;G:255;B:255)
  );

  PALETTE_BW: array[0..1] of TColor3 = (
    (R:0;G:0;B:0), (R:255;G:255;B:255)
  );

  SIZES: array[0..2] of Integer = (80, 153, 256);
  SIZE_NAMES: array[0..2] of string = ('SMALL', 'MEDIUM', 'BIG');
  MODE_NAMES: array[0..2] of string = ('16 COLORES', 'GRISES', 'B&W');
  COMP_NAMES: array[0..2] of string = ('SAFARI-SAFE', 'AGRESIVA', 'SIN COMPR.');
  MODE_SUFFIX: array[0..2] of string = ('_zx', '_gray', '_ByN');

{ ================================================================ }
{ Font bitmap 8x8 (ASCII 32-127)                                    }
{ ================================================================ }

const
  FONT_8X8: array[0..95, 0..7] of Byte = (
    ($00,$00,$00,$00,$00,$00,$00,$00), // sp
    ($18,$3C,$3C,$18,$18,$00,$18,$00),
    ($66,$66,$24,$00,$00,$00,$00,$00),
    ($6C,$FE,$6C,$6C,$FE,$6C,$00,$00),
    ($18,$3E,$60,$3C,$06,$7C,$18,$00),
    ($00,$C6,$CC,$18,$30,$66,$C6,$00),
    ($38,$6C,$38,$76,$DC,$CC,$76,$00),
    ($18,$18,$30,$00,$00,$00,$00,$00),
    ($0C,$18,$30,$30,$30,$18,$0C,$00),
    ($30,$18,$0C,$0C,$0C,$18,$30,$00),
    ($00,$66,$3C,$FF,$3C,$66,$00,$00),
    ($00,$18,$18,$7E,$18,$18,$00,$00),
    ($00,$00,$00,$00,$00,$18,$18,$30),
    ($00,$00,$00,$7E,$00,$00,$00,$00),
    ($00,$00,$00,$00,$00,$18,$18,$00),
    ($06,$0C,$18,$30,$60,$C0,$80,$00),
    ($7C,$C6,$CE,$D6,$E6,$C6,$7C,$00),
    ($18,$38,$18,$18,$18,$18,$7E,$00),
    ($7C,$C6,$06,$1C,$30,$66,$FE,$00),
    ($7C,$C6,$06,$3C,$06,$C6,$7C,$00),
    ($1C,$3C,$6C,$CC,$FE,$0C,$1E,$00),
    ($FE,$C0,$FC,$06,$06,$C6,$7C,$00),
    ($38,$60,$C0,$FC,$C6,$C6,$7C,$00),
    ($FE,$C6,$0C,$18,$30,$30,$30,$00),
    ($7C,$C6,$C6,$7C,$C6,$C6,$7C,$00),
    ($7C,$C6,$C6,$7E,$06,$0C,$78,$00),
    ($00,$18,$18,$00,$00,$18,$18,$00),
    ($00,$18,$18,$00,$00,$18,$18,$30),
    ($06,$0C,$18,$30,$18,$0C,$06,$00),
    ($00,$00,$7E,$00,$00,$7E,$00,$00),
    ($60,$30,$18,$0C,$18,$30,$60,$00),
    ($7C,$C6,$0C,$18,$18,$00,$18,$00),
    ($7C,$C6,$DE,$DE,$DE,$C0,$78,$00),
    ($38,$6C,$C6,$FE,$C6,$C6,$C6,$00),
    ($FC,$66,$66,$7C,$66,$66,$FC,$00),
    ($3C,$66,$C0,$C0,$C0,$66,$3C,$00),
    ($F8,$6C,$66,$66,$66,$6C,$F8,$00),
    ($FE,$62,$68,$78,$68,$62,$FE,$00),
    ($FE,$62,$68,$78,$68,$60,$F0,$00),
    ($3C,$66,$C0,$C0,$CE,$66,$3E,$00),
    ($C6,$C6,$C6,$FE,$C6,$C6,$C6,$00),
    ($3C,$18,$18,$18,$18,$18,$3C,$00),
    ($1E,$0C,$0C,$0C,$CC,$CC,$78,$00),
    ($E6,$66,$6C,$78,$6C,$66,$E6,$00),
    ($F0,$60,$60,$60,$62,$66,$FE,$00),
    ($C6,$EE,$FE,$D6,$C6,$C6,$C6,$00),
    ($C6,$E6,$F6,$DE,$CE,$C6,$C6,$00),
    ($7C,$C6,$C6,$C6,$C6,$C6,$7C,$00),
    ($FC,$66,$66,$7C,$60,$60,$F0,$00),
    ($7C,$C6,$C6,$C6,$D6,$DE,$7C,$06),
    ($FC,$66,$66,$7C,$6C,$66,$E6,$00),
    ($7C,$C6,$60,$38,$0C,$C6,$7C,$00),
    ($7E,$5A,$18,$18,$18,$18,$3C,$00),
    ($C6,$C6,$C6,$C6,$C6,$C6,$7C,$00),
    ($C6,$C6,$C6,$C6,$6C,$38,$10,$00),
    ($C6,$C6,$C6,$D6,$FE,$EE,$C6,$00),
    ($C6,$6C,$38,$38,$6C,$C6,$C6,$00),
    ($66,$66,$66,$3C,$18,$18,$3C,$00),
    ($FE,$C6,$8C,$18,$32,$66,$FE,$00),
    ($3C,$30,$30,$30,$30,$30,$3C,$00),
    ($C0,$60,$30,$18,$0C,$06,$02,$00),
    ($3C,$0C,$0C,$0C,$0C,$0C,$3C,$00),
    ($10,$38,$6C,$C6,$00,$00,$00,$00),
    ($00,$00,$00,$00,$00,$00,$00,$FF),
    ($30,$18,$0C,$00,$00,$00,$00,$00),
    ($00,$00,$78,$0C,$7C,$CC,$76,$00),
    ($E0,$60,$7C,$66,$66,$66,$DC,$00),
    ($00,$00,$7C,$C6,$C0,$C6,$7C,$00),
    ($1C,$0C,$7C,$CC,$CC,$CC,$76,$00),
    ($00,$00,$7C,$C6,$FE,$C0,$7C,$00),
    ($38,$6C,$60,$F0,$60,$60,$F0,$00),
    ($00,$00,$76,$CC,$CC,$7C,$0C,$F8),
    ($E0,$60,$6C,$76,$66,$66,$E6,$00),
    ($18,$00,$38,$18,$18,$18,$3C,$00),
    ($06,$00,$0E,$06,$06,$66,$66,$3C),
    ($E0,$60,$66,$6C,$78,$6C,$E6,$00),
    ($38,$18,$18,$18,$18,$18,$3C,$00),
    ($00,$00,$EC,$FE,$D6,$C6,$C6,$00),
    ($00,$00,$DC,$66,$66,$66,$66,$00),
    ($00,$00,$7C,$C6,$C6,$C6,$7C,$00),
    ($00,$00,$DC,$66,$66,$7C,$60,$F0),
    ($00,$00,$76,$CC,$CC,$7C,$0C,$1E),
    ($00,$00,$DC,$76,$60,$60,$F0,$00),
    ($00,$00,$7C,$C0,$7C,$06,$FC,$00),
    ($10,$30,$7C,$30,$30,$34,$18,$00),
    ($00,$00,$CC,$CC,$CC,$CC,$76,$00),
    ($00,$00,$C6,$C6,$6C,$38,$10,$00),
    ($00,$00,$C6,$D6,$FE,$6C,$6C,$00),
    ($00,$00,$C6,$6C,$38,$6C,$C6,$00),
    ($00,$00,$C6,$C6,$C6,$7E,$06,$FC),
    ($00,$00,$FE,$8C,$18,$32,$FE,$00),
    ($0E,$18,$18,$70,$18,$18,$0E,$00),
    ($18,$18,$18,$18,$18,$18,$18,$00),
    ($70,$18,$18,$0E,$18,$18,$70,$00),
    ($76,$DC,$00,$00,$00,$00,$00,$00),
    ($00,$00,$00,$00,$00,$00,$00,$00)  {127 DEL}
  );

{ ================================================================ }
{ Estado de la app                                                  }
{ ================================================================ }

type
  TAppState = record
    ImagePath: string;
    OrigPixels: TPixelArray;
    OrigW, OrigH: Integer;
    QuantPixels: TPixelArray;
    QuantW, QuantH: Integer;
    OrigTex, QuantTex: PSDL_Texture;
    Mode: Integer;
    SizeIndex: Integer;
    TargetWidth: Integer;
    CellSize: Integer;
    Compression: Integer;
    Zoom: Single;
    ExportMenu: Boolean;
    Running: Boolean;
    FileSize: Int64;
    HtmlRawSize: Int64;
    HtmlCompSize: Int64;
    ScrMode: Boolean;
    ScrPixels: TPixelArray;
    ScrTex: PSDL_Texture;
  end;

var
  Win: PSDL_Window;
  Ren: PSDL_Renderer;
  State: TAppState;

{ ================================================================ }
{ Paleta y color                                                    }
{ ================================================================ }

function NearestColor(R, G, B: Byte; const Pal: array of TColor3): TColor3;
var
  I, Best, D, BestDist: Integer;
begin
  BestDist := MaxInt;
  Best := 0;
  for I := 0 to High(Pal) do
  begin
    D := Sqr(Integer(R) - Pal[I].R) +
         Sqr(Integer(G) - Pal[I].G) +
         Sqr(Integer(B) - Pal[I].B);
    if D < BestDist then
    begin
      BestDist := D;
      Best := I;
    end;
  end;
  Result := Pal[Best];
end;

function RgbToHex(C: TColor3): string;
var
  RH, RL, GH, GL, BH, BL: Integer;
begin
  RH := C.R shr 4; RL := C.R and $F;
  GH := C.G shr 4; GL := C.G and $F;
  BH := C.B shr 4; BL := C.B and $F;
  if (RH = RL) and (GH = GL) and (BH = BL) then
    Result := Format('#%X%X%X', [RH, GH, BH])
  else
    Result := Format('#%02X%02X%02X', [C.R, C.G, C.B]);
end;

{ ================================================================ }
{ Imagen                                                            }
{ ================================================================ }

function LoadImageFile(const Path: string; out W, H: Integer): TPixelArray;
var
  Img: TFPMemoryImage;
  Reader: TFPCustomImageReader;
  X, Y: Integer;
  FPCol: TFPColor;
  Ext: string;
begin
  Result := nil;
  Ext := LowerCase(ExtractFileExt(Path));
  if (Ext = '.png') then Reader := TFPReaderPNG.Create
  else if (Ext = '.jpg') or (Ext = '.jpeg') then Reader := TFPReaderJPEG.Create
  else if (Ext = '.bmp') then Reader := TFPReaderBMP.Create
  else Exit;

  Img := TFPMemoryImage.Create(0, 0);
  try
    Img.LoadFromFile(Path, Reader);
    W := Img.Width;
    H := Img.Height;
    SetLength(Result, W * H);
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        FPCol := Img.Colors[X, Y];
        Result[Y * W + X].R := FPCol.Red shr 8;
        Result[Y * W + X].G := FPCol.Green shr 8;
        Result[Y * W + X].B := FPCol.Blue shr 8;
      end;
  finally
    Img.Free;
    Reader.Free;
  end;
end;

function ResizeImage(const Src: TPixelArray; SW, SH, DW, DH: Integer): TPixelArray;
var
  X, Y, X0, Y0, X1, Y1, C: Integer;
  SX, SY, FX, FY: Double;
  V00, V10, V01, V11, V: Double;
begin
  SetLength(Result, DW * DH);
  for Y := 0 to DH - 1 do
  begin
    SY := Y * SH / DH;
    Y0 := Trunc(SY);
    Y1 := Min(Y0 + 1, SH - 1);
    FY := SY - Y0;
    for X := 0 to DW - 1 do
    begin
      SX := X * SW / DW;
      X0 := Trunc(SX);
      X1 := Min(X0 + 1, SW - 1);
      FX := SX - X0;
      for C := 0 to 2 do
      begin
        case C of
          0: begin V00:=Src[Y0*SW+X0].R; V10:=Src[Y0*SW+X1].R; V01:=Src[Y1*SW+X0].R; V11:=Src[Y1*SW+X1].R; end;
          1: begin V00:=Src[Y0*SW+X0].G; V10:=Src[Y0*SW+X1].G; V01:=Src[Y1*SW+X0].G; V11:=Src[Y1*SW+X1].G; end;
          2: begin V00:=Src[Y0*SW+X0].B; V10:=Src[Y0*SW+X1].B; V01:=Src[Y1*SW+X0].B; V11:=Src[Y1*SW+X1].B; end;
        end;
        V := V00*(1-FX)*(1-FY) + V10*FX*(1-FY) + V01*(1-FX)*FY + V11*FX*FY;
        case C of
          0: Result[Y*DW+X].R := Round(V);
          1: Result[Y*DW+X].G := Round(V);
          2: Result[Y*DW+X].B := Round(V);
        end;
      end;
    end;
  end;
end;

procedure QuantizeImage(var Pixels: TPixelArray; Mode: Integer);
var
  I: Integer;
begin
  for I := 0 to High(Pixels) do
    case Mode of
      MODE_GRAY: Pixels[I] := NearestColor(Pixels[I].R, Pixels[I].G, Pixels[I].B, PALETTE_GRAY);
      MODE_BW:   Pixels[I] := NearestColor(Pixels[I].R, Pixels[I].G, Pixels[I].B, PALETTE_BW);
    else         Pixels[I] := NearestColor(Pixels[I].R, Pixels[I].G, Pixels[I].B, PALETTE_16);
    end;
end;

{ ================================================================ }
{ Textura SDL2 desde pixels                                         }
{ ================================================================ }

function PixelsToTexture(const Pixels: TPixelArray; W, H: Integer): PSDL_Texture;
var
  Tex: PSDL_Texture;
  Raw: array of Byte;
  I: Integer;
begin
  SetLength(Raw, W * H * 3);
  for I := 0 to W * H - 1 do
  begin
    Raw[I*3]   := Pixels[I].R;
    Raw[I*3+1] := Pixels[I].G;
    Raw[I*3+2] := Pixels[I].B;
  end;
  Tex := SDL_CreateTexture(Ren, SDL_PIXELFORMAT_RGB24,
           SDL_TEXTUREACCESS_STATIC, W, H);
  if Tex <> nil then
    SDL_UpdateTexture(Tex, nil, @Raw[0], W * 3);
  Result := Tex;
end;

{ ================================================================ }
{ Carga de archivos .scr del ZX Spectrum                            }
{ ================================================================ }

const
  ZX_PAL_NORMAL: array[0..7] of TColor3 = (
    (R:0;G:0;B:0),     (R:0;G:0;B:170),   (R:170;G:0;B:0),     (R:170;G:0;B:170),
    (R:0;G:170;B:0),   (R:0;G:170;B:170), (R:170;G:170;B:0),   (R:170;G:170;B:170)
  );
  ZX_PAL_BRIGHT: array[0..7] of TColor3 = (
    (R:0;G:0;B:0),     (R:0;G:0;B:255),   (R:255;G:0;B:0),     (R:255;G:0;B:255),
    (R:0;G:255;B:0),   (R:0;G:255;B:255), (R:255;G:255;B:0),   (R:255;G:255;B:255)
  );

function LoadSCRFile(const Path: string; out Pixels: TPixelArray): Boolean;
var
  F: File;
  Data: array[0..6911] of Byte;
  BytesRead: Integer;
  Y, Col, Bit, Offset: Integer;
  ByteVal, Attr, Ink, Paper, Bright: Byte;
  C: TColor3;
  PxIdx: Integer;
begin
  Result := False;
  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  BlockRead(F, Data, 6912, BytesRead);
  CloseFile(F);
  if BytesRead <> 6912 then Exit;

  SetLength(Pixels, 256 * 192);

  for Y := 0 to 191 do
  begin
    Offset := ((Y and $C0) shl 5) or ((Y and $07) shl 8) or ((Y and $38) shl 2);
    for Col := 0 to 31 do
    begin
      ByteVal := Data[Offset + Col];
      Attr := Data[6144 + (Y div 8) * 32 + Col];
      Ink := Attr and 7;
      Paper := (Attr shr 3) and 7;
      Bright := (Attr shr 6) and 1;

      for Bit := 0 to 7 do
      begin
        if (ByteVal and ($80 shr Bit)) <> 0 then
        begin
          if Bright = 1 then C := ZX_PAL_BRIGHT[Ink]
          else C := ZX_PAL_NORMAL[Ink];
        end
        else
        begin
          if Bright = 1 then C := ZX_PAL_BRIGHT[Paper]
          else C := ZX_PAL_NORMAL[Paper];
        end;
        PxIdx := Y * 256 + Col * 8 + Bit;
        Pixels[PxIdx] := C;
      end;
    end;
  end;
  Result := True;
end;

{ ================================================================ }
{ Dialogos nativos (osascript)                                      }
{ ================================================================ }

function OpenFileDialog: string;
var
  P: TextFile;
  Line: string;
begin
  Result := '';
  AssignFile(P, '');
  {$I-}
  Assign(P, '/dev/stdin');
  {$I+}
 
  with TProcess.Create(nil) do
  try
    Executable := '/usr/bin/osascript';
    Parameters.Add('-e');
    Parameters.Add('set f to choose file with prompt "Cargar imagen" of type {"public.image","public.data"}');
    Parameters.Add('-e');
    Parameters.Add('return POSIX path of f');
    Options := [poWaitOnExit, poUsePipes];
    Execute;
    if Output.NumBytesAvailable > 0 then
    begin
      SetLength(Line, Output.NumBytesAvailable);
      Output.Read(Line[1], Length(Line));
      Result := Trim(Line);
    end;
  finally
    Free;
  end;
end;

function SaveFileDialog(const DefaultName, Ext: string): string;
var
  Line: string;
begin
  Result := '';
  with TProcess.Create(nil) do
  try
    Executable := '/usr/bin/osascript';
    Parameters.Add('-e');
    Parameters.Add('set f to choose file name with prompt "Exportar" default name "' + DefaultName + '"');
    Parameters.Add('-e');
    Parameters.Add('return POSIX path of f');
    Options := [poWaitOnExit, poUsePipes];
    Execute;
    if Output.NumBytesAvailable > 0 then
    begin
      SetLength(Line, Output.NumBytesAvailable);
      Output.Read(Line[1], Length(Line));
      Result := Trim(Line);
    end;
  finally
    Free;
  end;
  if (Result <> '') and (Pos(Ext, Result) = 0) then
    Result := Result + Ext;
end;

{ ================================================================ }
{ Exportacion                                                       }
{ ================================================================ }

procedure ExportHTML(const Pixels: TPixelArray; W, H, CellSz: Integer; const Path: string);
var
  F: TextFile;
  X, Y: Integer;
begin
  AssignFile(F, Path);
  Rewrite(F);
  WriteLn(F, '<table cellpadding="0" cellspacing="0">');
  for Y := 0 to H - 1 do
  begin
    Write(F, '<tr>');
    for X := 0 to W - 1 do
      Write(F, Format('<td width="%d" height="%d" bgcolor="%s"></td>',
            [CellSz, CellSz, RgbToHex(Pixels[Y*W+X])]));
    WriteLn(F, '</tr>');
  end;
  WriteLn(F, '</table>');
  CloseFile(F);
end;

procedure ExportSCR(const Pixels: TPixelArray; W, H: Integer; const Path: string);
type
  TZXAttr = record Idx, Bright: Byte; end;
var
  Bitmap: array[0..6143] of Byte;
  Attrs: array[0..767] of Byte;
  F: File;
  BX, BY, DX, DY, I, K, Best, BestC, Cnt: Integer;
  Colors: array[0..63] of TColor3;
  Counts: array[0..63] of Integer;
  Unique: Integer;
  C, PaperC, InkC: TColor3;
  ByteVal: Byte;
  PY, Offset: Integer;
  DP, DI: Integer;
begin
  if (W <> 256) or (H <> 192) then Exit;
  FillChar(Bitmap, SizeOf(Bitmap), 0);
  FillChar(Attrs, SizeOf(Attrs), 0);

  for BY := 0 to 23 do
    for BX := 0 to 31 do
    begin
      Unique := 0;
      FillChar(Counts, SizeOf(Counts), 0);
      for DY := 0 to 7 do
        for DX := 0 to 7 do
        begin
          C := Pixels[(BY*8+DY)*256 + BX*8+DX];
          K := -1;
          for I := 0 to Unique - 1 do
            if (Colors[I].R = C.R) and (Colors[I].G = C.G) and (Colors[I].B = C.B) then
            begin K := I; Break; end;
          if K >= 0 then Inc(Counts[K])
          else if Unique < 64 then
          begin
            Colors[Unique] := C;
            Counts[Unique] := 1;
            Inc(Unique);
          end;
        end;

     
      Best := 0; BestC := 0;
      for I := 0 to Unique - 1 do
        if Counts[I] > BestC then begin BestC := Counts[I]; Best := I; end;
      PaperC := Colors[Best];
      Counts[Best] := 0;
      BestC := 0; Best := 0;
      for I := 0 to Unique - 1 do
        if Counts[I] > BestC then begin BestC := Counts[I]; Best := I; end;
      InkC := Colors[Best];
      if Unique = 1 then InkC := PaperC;

      Attrs[BY*32+BX] := $40;

      for DY := 0 to 7 do
      begin
        ByteVal := 0;
        for DX := 0 to 7 do
        begin
          C := Pixels[(BY*8+DY)*256 + BX*8+DX];
          if (C.R = InkC.R) and (C.G = InkC.G) and (C.B = InkC.B) then
            ByteVal := ByteVal or ($80 shr DX)
          else if not ((C.R = PaperC.R) and (C.G = PaperC.G) and (C.B = PaperC.B)) then
          begin
            DI := Sqr(Integer(C.R)-InkC.R) + Sqr(Integer(C.G)-InkC.G) + Sqr(Integer(C.B)-InkC.B);
            DP := Sqr(Integer(C.R)-PaperC.R) + Sqr(Integer(C.G)-PaperC.G) + Sqr(Integer(C.B)-PaperC.B);
            if DI < DP then ByteVal := ByteVal or ($80 shr DX);
          end;
        end;
        PY := BY * 8 + DY;
        Offset := ((PY and $C0) shl 5) or ((PY and $07) shl 8) or ((PY and $38) shl 2) or BX;
        Bitmap[Offset] := ByteVal;
      end;
    end;

  AssignFile(F, Path);
  Rewrite(F, 1);
  BlockWrite(F, Bitmap, 6144);
  BlockWrite(F, Attrs, 768);
  CloseFile(F);
end;

procedure ExportBMP(const Pixels: TPixelArray; W, H: Integer; const Path: string);
var
  Img: TFPMemoryImage;
  Writer: TFPWriterBMP;
  X, Y: Integer;
  FPCol: TFPColor;
begin
  Img := TFPMemoryImage.Create(W, H);
  Writer := TFPWriterBMP.Create;
  try
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        FPCol.Red := Pixels[Y*W+X].R shl 8;
        FPCol.Green := Pixels[Y*W+X].G shl 8;
        FPCol.Blue := Pixels[Y*W+X].B shl 8;
        FPCol.Alpha := $FFFF;
        Img.Colors[X, Y] := FPCol;
      end;
    Img.SaveToFile(Path, Writer);
  finally
    Writer.Free;
    Img.Free;
  end;
end;

{ ================================================================ }
{ Export GIF (via unit GIFWriter)                                    }
{ ================================================================ }

procedure ExportGIF(const Pixels: TPixelArray; W, H: Integer;
                     const Pal: array of TColor3; const Path: string);
var
  GifPx: TGIFPixels;
  GifPal: array of TGIFColor;
  I: Integer;
begin
  // Convertir TColor3 -> TGIFColor (misma estructura, tipos distintos)
  SetLength(GifPx, Length(Pixels));
  for I := 0 to High(Pixels) do
  begin
    GifPx[I].R := Pixels[I].R;
    GifPx[I].G := Pixels[I].G;
    GifPx[I].B := Pixels[I].B;
  end;
  SetLength(GifPal, Length(Pal));
  for I := 0 to High(Pal) do
  begin
    GifPal[I].R := Pal[I].R;
    GifPal[I].G := Pal[I].G;
    GifPal[I].B := Pal[I].B;
  end;
  WriteGIF(GifPx, W, H, GifPal, Path);
end;

{ ================================================================ }
{ Dibujo SDL2                                                       }
{ ================================================================ }

procedure DrawChar(X, Y: Integer; Ch: Char; R, G, B: Byte);
var
  Idx, Row, Col: Integer;
  Bits: Byte;
begin
  Idx := Ord(Ch) - 32;
  if (Idx < 0) or (Idx > 95) then Exit;
  SDL_SetRenderDrawColor(Ren, R, G, B, 255);
  for Row := 0 to 7 do
  begin
    Bits := FONT_8X8[Idx, Row];
    for Col := 0 to 7 do
      if (Bits and ($80 shr Col)) <> 0 then
        SDL_RenderDrawPoint(Ren, X + Col, Y + Row);
  end;
end;

procedure DrawText(X, Y: Integer; const S: string; R, G, B: Byte; Scale: Integer);
var
  I, Idx, Row, Col: Integer;
  Bits: Byte;
  Rect: TSDL_Rect;
begin
  for I := 1 to Length(S) do
  begin
    if Scale <= 1 then
      DrawChar(X + (I-1)*8, Y, S[I], R, G, B)
    else
    begin
      Idx := Ord(S[I]) - 32;
      if (Idx < 0) or (Idx > 95) then Continue;
      SDL_SetRenderDrawColor(Ren, R, G, B, 255);
      for Row := 0 to 7 do
      begin
        Bits := FONT_8X8[Idx, Row];
        for Col := 0 to 7 do
          if (Bits and ($80 shr Col)) <> 0 then
          begin
            Rect.x := X + (I-1)*8*Scale + Col*Scale;
            Rect.y := Y + Row*Scale;
            Rect.w := Scale;
            Rect.h := Scale;
            SDL_RenderFillRect(Ren, @Rect);
          end;
      end;
    end;
  end;
end;

procedure DrawSeparator(Y: Integer);
var R: TSDL_Rect;
begin
  SDL_SetRenderDrawColor(Ren, 0, 170, 170, 255);
  R.x := 0; R.y := Y; R.w := WIN_W; R.h := SEP_H;
  SDL_RenderFillRect(Ren, @R);
end;

procedure DrawHeader;
begin
  DrawText(MARGIN, 12, 'SPECTRUMIFY v0.1', 85, 255, 255, 2);
  DrawText(WIN_W - 13*8 - MARGIN, 18, '(c) 2026 JGF', 85, 85, 85, 1);
end;

procedure DrawControlItem(var X: Integer; Y: Integer; const Key, Lab: string);
begin
  DrawText(X, Y, Key, 85, 255, 85, 1);
  Inc(X, Length(Key) * 8);
  DrawText(X, Y, Lab, 255, 255, 255, 1);
  Inc(X, Length(Lab) * 8);
end;

procedure DrawControls;
var
  X, Y: Integer;
begin
  X := MARGIN;
  Y := WIN_H - CONTROLS_H + 10;
  DrawControlItem(X, Y, '[L]', 'OAD  ');
  DrawControlItem(X, Y, '[E]', 'XPORT  ');
  DrawControlItem(X, Y, '[M]', 'ODE  ');
  DrawControlItem(X, Y, '[S]', 'IZE  ');
  DrawControlItem(X, Y, '[+/-]', ' ZOOM  ');
  DrawControlItem(X, Y, '[C]', 'OMPRESS  ');
  DrawControlItem(X, Y, '[Q]', 'UIT');
end;

procedure DrawPreview;
var
  HalfW, AvailH, ImgY: Integer;
  Scale: Single;
  NW, NH, CX, CY: Integer;
  Dst, Clip: TSDL_Rect;
begin
  if (State.OrigTex = nil) and (State.QuantTex = nil) then
  begin
    DrawText(WIN_W div 2 - 15*8, PREVIEW_Y + PREVIEW_H div 2,
             'Pulsa [L] para cargar', 85, 85, 85, 1);
    Exit;
  end;

  HalfW := (WIN_W - MARGIN * 3) div 2;
  AvailH := PREVIEW_H - MARGIN * 2 - 16;
  ImgY := PREVIEW_Y + 16;

  DrawText(MARGIN, PREVIEW_Y + 2, 'ORIGINAL', 85, 85, 85, 1);
  DrawText(MARGIN * 2 + HalfW, PREVIEW_Y + 2, 'PIXEL-ART', 85, 255, 85, 1);

 
  if State.OrigTex <> nil then
  begin
    Scale := Min(HalfW / State.OrigW, AvailH / State.OrigH);
    NW := Round(State.OrigW * Scale);
    NH := Round(State.OrigH * Scale);
    Dst.x := MARGIN + (HalfW - NW) div 2;
    Dst.y := ImgY + (AvailH - NH) div 2;
    Dst.w := NW; Dst.h := NH;
    SDL_RenderCopy(Ren, State.OrigTex, nil, @Dst);
  end;

 
  if State.QuantTex <> nil then
  begin
    Scale := Min(HalfW / State.QuantW, AvailH / State.QuantH) * State.Zoom;
    NW := Round(State.QuantW * Scale);
    NH := Round(State.QuantH * Scale);
    CX := MARGIN * 2 + HalfW + (HalfW - NW) div 2;
    CY := ImgY + (AvailH - NH) div 2;
    Clip.x := MARGIN * 2 + HalfW;
    Clip.y := ImgY; Clip.w := HalfW; Clip.h := AvailH;
    SDL_RenderSetClipRect(Ren, @Clip);
    Dst.x := CX; Dst.y := CY; Dst.w := NW; Dst.h := NH;
    SDL_RenderCopy(Ren, State.QuantTex, nil, @Dst);
    SDL_RenderSetClipRect(Ren, nil);
  end;
end;

function FormatBytes(N: Int64): string;
begin
  if N < 1024 then Result := Format('%d B', [N])
  else if N < 1024*1024 then Result := Format('%.1f KB', [N/1024.0])
  else Result := Format('%.2f MB', [N/(1024.0*1024.0)]);
end;

procedure DrawStatus;
var
  S: string;
  Pct: Integer;
begin
  S := Format('MODO: %s    SIZE: %s (%d)    ZOOM: %.1fx    CELDA: %d',
       [MODE_NAMES[State.Mode], SIZE_NAMES[State.SizeIndex],
        State.TargetWidth, State.Zoom, State.CellSize]);
  DrawText(MARGIN, PREVIEW_Y + PREVIEW_H + SEP_H + 4, S, 255, 255, 85, 1);

  if (State.FileSize > 0) and (State.HtmlRawSize > 0) then
  begin
    Pct := Round(100 * (State.HtmlRawSize - State.HtmlCompSize) / State.HtmlRawSize);
    S := Format('COMPRESION: %s    PNG: %s    HTML: %s > %s (-%d%%)',
         [COMP_NAMES[State.Compression], FormatBytes(State.FileSize),
          FormatBytes(State.HtmlRawSize), FormatBytes(State.HtmlCompSize), Pct]);
  end
  else
    S := Format('COMPRESION: %s', [COMP_NAMES[State.Compression]]);
  DrawText(MARGIN, PREVIEW_Y + PREVIEW_H + SEP_H + 20, S, 255, 255, 85, 1);
end;

procedure DrawScrViewer;
var
  AvailW, AvailH, NW, NH, CX, CY: Integer;
  Scale: Single;
  Dst, Border: TSDL_Rect;
  S, FB: string;
begin
  // Header con colores secretos
  DrawText(MARGIN, 12, 'SCR VIEWER', 255, 85, 85, 2);
  DrawText(WIN_W - 15*8 - MARGIN, 18, 'ZX Spectrum 48K', 170, 0, 170, 1);

  // Separadores magenta
  SDL_SetRenderDrawColor(Ren, 170, 0, 170, 255);
  Dst.x := 0; Dst.y := HEADER_H; Dst.w := WIN_W; Dst.h := SEP_H;
  SDL_RenderFillRect(Ren, @Dst);
  Dst.y := WIN_H - CONTROLS_H - SEP_H;
  SDL_RenderFillRect(Ren, @Dst);

  // Imagen SCR centrada
  if State.ScrTex <> nil then
  begin
    AvailW := WIN_W - MARGIN * 2;
    AvailH := PREVIEW_H - MARGIN * 2;
    Scale := AvailW / 256.0;
    if AvailH / 192.0 < Scale then Scale := AvailH / 192.0;
    NW := Round(256 * Scale);
    NH := Round(192 * Scale);
    CX := (WIN_W - NW) div 2;
    CY := PREVIEW_Y + (PREVIEW_H - NH) div 2;

    // Borde magenta
    SDL_SetRenderDrawColor(Ren, 170, 0, 170, 255);
    Border.x := CX - 2; Border.y := CY - 2;
    Border.w := NW + 4; Border.h := NH + 4;
    SDL_RenderDrawRect(Ren, @Border);

    Dst.x := CX; Dst.y := CY; Dst.w := NW; Dst.h := NH;
    SDL_RenderCopy(Ren, State.ScrTex, nil, @Dst);
  end;

  // Info
  FB := FormatBytes(State.FileSize);
  S := '256x192  6,912 bytes  ' + FB;
  DrawText(MARGIN, WIN_H - CONTROLS_H - SEP_H - 20, S, 255, 85, 255, 1);

  // Controles
  DrawText(MARGIN, WIN_H - CONTROLS_H + 10, '[L]', 85, 255, 85, 1);
  DrawText(MARGIN + 24, WIN_H - CONTROLS_H + 10, 'OAD  ', 0, 170, 0, 1);
  DrawText(MARGIN + 64, WIN_H - CONTROLS_H + 10, '[E]', 85, 255, 85, 1);
  DrawText(MARGIN + 88, WIN_H - CONTROLS_H + 10, 'XPORT  ', 0, 170, 0, 1);
  DrawText(MARGIN + 144, WIN_H - CONTROLS_H + 10, '[Q]', 85, 255, 85, 1);
  DrawText(MARGIN + 168, WIN_H - CONTROLS_H + 10, 'UIT', 0, 170, 0, 1);
end;

procedure DrawExportMenu;
var
  BoxW, BoxH, BoxX, BoxY: Integer;
  R: TSDL_Rect;
begin
  BoxW := 380; BoxH := 160;
  BoxX := (WIN_W - BoxW) div 2;
  BoxY := PREVIEW_Y + (PREVIEW_H - BoxH) div 2;

  SDL_SetRenderDrawColor(Ren, 0, 0, 0, 255);
  R.x := BoxX; R.y := BoxY; R.w := BoxW; R.h := BoxH;
  SDL_RenderFillRect(Ren, @R);
  SDL_SetRenderDrawColor(Ren, 0, 170, 170, 255);
  SDL_RenderDrawRect(Ren, @R);

  DrawText(BoxX+20, BoxY+12, 'EXPORTAR COMO:', 85, 255, 255, 1);
  DrawText(BoxX+20, BoxY+40, '[H]  HTML  -  Tabla pixel-art', 255, 255, 255, 1);
  DrawText(BoxX+20, BoxY+60, '[S]  SCR   -  Nativo ZX Spectrum', 255, 255, 255, 1);
  DrawText(BoxX+20, BoxY+80, '[G]  GIF   -  Imagen retro (1987)', 255, 255, 255, 1);
  DrawText(BoxX+20, BoxY+115, '[ESC] Cancelar', 85, 85, 85, 1);
end;

{ ================================================================ }
{ Logica de la app                                                  }
{ ================================================================ }

procedure CalcDimensions(OrigW, OrigH, TargetW: Integer; out OutW, OutH: Integer);
var
  Ratio: Double;
begin
  if TargetW <= 0 then begin OutW := OrigW; OutH := OrigH; Exit; end;
  Ratio := OrigW / OrigH;
  OutW := TargetW;
  OutH := Max(1, Round(TargetW / Ratio));
end;

function EstimateAggressiveSize: Int64;
var
  Runs, X, Y, I0, I1: Integer;
begin
  Runs := 0;
  for Y := 0 to State.QuantH - 1 do
    for X := 0 to State.QuantW - 1 do
    begin
      if X = 0 then begin Inc(Runs); Continue; end;
      I0 := Y * State.QuantW + X - 1;
      I1 := Y * State.QuantW + X;
      if (State.QuantPixels[I0].R <> State.QuantPixels[I1].R) or
         (State.QuantPixels[I0].G <> State.QuantPixels[I1].G) or
         (State.QuantPixels[I0].B <> State.QuantPixels[I1].B) then
        Inc(Runs);
    end;
  Result := Int64(Runs) * 38 + State.QuantH * 30 + 42;
end;

procedure EstimateHtmlSizes;
var
  Cells: Integer;
begin
  if Length(State.QuantPixels) = 0 then Exit;
  Cells := State.QuantW * State.QuantH;
  State.HtmlRawSize := Int64(Cells) * 45 + State.QuantH * 9 + 40;
  case State.Compression of
    0: State.HtmlCompSize := State.HtmlRawSize * 97 div 100;
    1: begin
         State.HtmlCompSize := EstimateAggressiveSize;
       end;
    2: State.HtmlCompSize := State.HtmlRawSize;
  end;
end;

procedure UpdatePreview;
begin
  if Length(State.OrigPixels) = 0 then Exit;

  if State.QuantTex <> nil then SDL_DestroyTexture(State.QuantTex);

  CalcDimensions(State.OrigW, State.OrigH, State.TargetWidth,
                  State.QuantW, State.QuantH);
  State.QuantPixels := ResizeImage(State.OrigPixels,
                        State.OrigW, State.OrigH,
                        State.QuantW, State.QuantH);
  QuantizeImage(State.QuantPixels, State.Mode);
  State.QuantTex := PixelsToTexture(State.QuantPixels, State.QuantW, State.QuantH);
  EstimateHtmlSizes;
end;

procedure DoLoadImage;
var
  Path, Ext: string;
  F: File;
  ScrPx: TPixelArray;
begin
  Path := OpenFileDialog;
  if Path = '' then Exit;

  State.ImagePath := Path;
  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult = 0 then
  begin
    State.FileSize := FileSize(F);
    CloseFile(F);
  end;

  // Detectar .scr
  Ext := LowerCase(ExtractFileExt(Path));
  if Ext = '.scr' then
  begin
    if LoadSCRFile(Path, ScrPx) then
    begin
      State.ScrMode := True;
      State.ScrPixels := ScrPx;
      if State.ScrTex <> nil then SDL_DestroyTexture(State.ScrTex);
      State.ScrTex := PixelsToTexture(ScrPx, 256, 192);
      // Limpiar estado normal
      SetLength(State.OrigPixels, 0);
      SetLength(State.QuantPixels, 0);
      if State.OrigTex <> nil then begin SDL_DestroyTexture(State.OrigTex); State.OrigTex := nil; end;
      if State.QuantTex <> nil then begin SDL_DestroyTexture(State.QuantTex); State.QuantTex := nil; end;
    end;
    Exit;
  end;

  // Imagen normal
  State.ScrMode := False;
  State.OrigPixels := LoadImageFile(Path, State.OrigW, State.OrigH);
  if Length(State.OrigPixels) = 0 then Exit;

  if State.OrigTex <> nil then SDL_DestroyTexture(State.OrigTex);
  State.OrigTex := PixelsToTexture(State.OrigPixels, State.OrigW, State.OrigH);
  State.Zoom := 1.0;
  UpdatePreview;
end;

procedure DoExport(Fmt: Integer);
var
  Base, Suffix, DefName, Path: string;
  ScrPx: TPixelArray;
begin
  if Length(State.QuantPixels) = 0 then Exit;
  Base := ChangeFileExt(ExtractFileName(State.ImagePath), '');
  Suffix := MODE_SUFFIX[State.Mode];

  case Fmt of
    0: begin
         DefName := Base + Suffix + '.html';
         Path := SaveFileDialog(DefName, '.html');
         if Path <> '' then
           ExportHTML(State.QuantPixels, State.QuantW, State.QuantH, State.CellSize, Path);
       end;
    1: begin
         DefName := Base + Suffix + '.scr';
         Path := SaveFileDialog(DefName, '.scr');
         if Path <> '' then
         begin
           ScrPx := ResizeImage(State.OrigPixels, State.OrigW, State.OrigH, 256, 192);
           QuantizeImage(ScrPx, State.Mode);
           ExportSCR(ScrPx, 256, 192, Path);
         end;
       end;
    2: begin
         DefName := Base + Suffix + '.gif';
         Path := SaveFileDialog(DefName, '.gif');
         if Path <> '' then
         begin
           case State.Mode of
             MODE_GRAY: ExportGIF(State.QuantPixels, State.QuantW, State.QuantH, PALETTE_GRAY, Path);
             MODE_BW:   ExportGIF(State.QuantPixels, State.QuantW, State.QuantH, PALETTE_BW, Path);
           else         ExportGIF(State.QuantPixels, State.QuantW, State.QuantH, PALETTE_16, Path);
           end;
         end;
       end;
  end;
end;

procedure DoExportScrGif;
var
  BaseName, DefName, ExPath: string;
begin
  BaseName := ChangeFileExt(ExtractFileName(State.ImagePath), '');
  DefName := BaseName + '.gif';
  ExPath := SaveFileDialog(DefName, '.gif');
  if ExPath <> '' then
    ExportGIF(State.ScrPixels, 256, 192, PALETTE_16, ExPath);
end;

{ ================================================================ }
{ Main                                                              }
{ ================================================================ }

var
  Ev: TSDL_Event;

begin
  if SDL_Init(SDL_INIT_VIDEO) < 0 then
  begin
    WriteLn(StdErr, 'SDL_Init: ', SDL_GetError);
    Halt(1);
  end;

  Win := SDL_CreateWindow('Spectrumify v0.1 [Pascal]',
           SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
           WIN_W, WIN_H, SDL_WINDOW_SHOWN);
  Ren := SDL_CreateRenderer(Win, -1,
           SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);

  State.Mode := MODE_16;
  State.SizeIndex := 1;
  State.TargetWidth := SIZES[1];
  State.CellSize := 3;
  State.Zoom := 1.0;
  State.Running := True;

  while State.Running do
  begin
    while SDL_PollEvent(@Ev) = 1 do
    begin
      if Ev.type_ = SDL_QUITEV then State.Running := False;
      if Ev.type_ = SDL_KEYDOWN then
      begin
        if State.ExportMenu then
        begin
          case Ev.key.keysym.sym of
            SDLK_h: begin State.ExportMenu := False; DoExport(0); end;
            SDLK_s: begin State.ExportMenu := False; DoExport(1); end;
            SDLK_g: begin State.ExportMenu := False; DoExport(2); end;
            SDLK_ESCAPE: State.ExportMenu := False;
          end;
          Continue;
        end;

        // Modo SCR: solo L, E (exporta BMP directo) y Q
        if State.ScrMode then
        begin
          case Ev.key.keysym.sym of
            SDLK_q: State.Running := False;
            SDLK_l: DoLoadImage;
            SDLK_e: if Length(State.ScrPixels) > 0 then
                       DoExportScrGif;
          end;
          Continue;
        end;

        case Ev.key.keysym.sym of
          SDLK_q: State.Running := False;
          SDLK_l: DoLoadImage;
          SDLK_e: if Length(State.OrigPixels) > 0 then State.ExportMenu := True;
          SDLK_m: begin
                    State.Mode := (State.Mode + 1) mod 3;
                    UpdatePreview;
                  end;
          SDLK_s: begin
                    State.SizeIndex := (State.SizeIndex + 1) mod 3;
                    State.TargetWidth := SIZES[State.SizeIndex];
                    State.Zoom := 1.0;
                    UpdatePreview;
                  end;
          SDLK_c: begin
                    State.Compression := (State.Compression + 1) mod 3;
                    EstimateHtmlSizes;
                  end;
          SDLK_EQUALS, SDLK_PLUS, SDLK_KP_PLUS:
            if State.Zoom < 8.0 then State.Zoom := State.Zoom + 0.5;
          SDLK_MINUS, SDLK_KP_MINUS:
            if State.Zoom > 0.5 then State.Zoom := State.Zoom - 0.5;
        end;
      end;
    end;

   
    SDL_SetRenderDrawColor(Ren, 0, 0, 0, 255);
    SDL_RenderClear(Ren);

    if State.ScrMode then
      DrawScrViewer
    else
    begin
      DrawHeader;
      DrawSeparator(HEADER_H);
      DrawPreview;
      DrawSeparator(PREVIEW_Y + PREVIEW_H);
      DrawStatus;
      DrawSeparator(WIN_H - CONTROLS_H - SEP_H);
      DrawControls;
      if State.ExportMenu then DrawExportMenu;
    end;

    SDL_RenderPresent(Ren);
  end;

  if State.OrigTex <> nil then SDL_DestroyTexture(State.OrigTex);
  if State.QuantTex <> nil then SDL_DestroyTexture(State.QuantTex);
  if State.ScrTex <> nil then SDL_DestroyTexture(State.ScrTex);
  SDL_DestroyRenderer(Ren);
  SDL_DestroyWindow(Win);
  SDL_Quit;
end.
