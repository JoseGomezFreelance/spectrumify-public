unit GIFWriter;
{
  GIFWriter — Encoder GIF minimo para Free Pascal
  Frame unico, paleta indexada, compresion LZW completa.
  Sin dependencias externas.

  (c) 2026 JGF / Spectrumify project
  Licencia: MIT / Dominio publico

  Uso:
    uses GIFWriter;
    var Pixels: TGIFPixels;
    var Pal: array[0..15] of TGIFColor;
    // ... llenar pixels y paleta ...
    WriteGIF(Pixels, Ancho, Alto, Pal, 'salida.gif');
}

{$mode objfpc}{$H+}

interface

type
  TGIFColor = record R, G, B: Byte; end;
  TGIFPixels = array of TGIFColor;

procedure WriteGIF(const Pixels: TGIFPixels; W, H: Integer;
                    const Palette: array of TGIFColor;
                    const FileName: string);

implementation

procedure WriteGIF(const Pixels: TGIFPixels; W, H: Integer;
                    const Palette: array of TGIFColor;
                    const FileName: string);
var
  F: File;
  NumColors, MinCodeSize, ClearCode, EOICode: Integer;
  TableSize, CodeSize, BitPos: Integer;
  I, X, PalIdx: Integer;
  Indices: array of Byte;
  DictPrefix: array[0..4095] of Integer;
  DictAppend: array[0..4095] of Integer;
  OutBytes: array of Byte;
  OutLen: Integer;
  BitBuf: LongWord;
  CurCode, NextByte: Integer;

  procedure InitDict;
  var J: Integer;
  begin
    for J := 0 to (1 shl MinCodeSize) - 1 do
    begin
      DictPrefix[J] := -1;
      DictAppend[J] := J;
    end;
    TableSize := EOICode + 1;
    CodeSize := MinCodeSize + 1;
  end;

  procedure EmitCode(Code: Integer);
  begin
    BitBuf := BitBuf or (LongWord(Code) shl BitPos);
    Inc(BitPos, CodeSize);
    while BitPos >= 8 do
    begin
      if OutLen >= Length(OutBytes) then
        SetLength(OutBytes, OutLen + 4096);
      OutBytes[OutLen] := BitBuf and $FF;
      Inc(OutLen);
      BitBuf := BitBuf shr 8;
      Dec(BitPos, 8);
    end;
  end;

  function FindInDict(Prefix, Append: Integer): Integer;
  var J: Integer;
  begin
    for J := EOICode + 1 to TableSize - 1 do
      if (DictPrefix[J] = Prefix) and (DictAppend[J] = Append) then
        Exit(J);
    Result := -1;
  end;

  procedure WriteByte(B: Byte);
  begin
    BlockWrite(F, B, 1);
  end;

  procedure WriteWord(AW: Word);
  begin
    WriteByte(Lo(AW));
    WriteByte(Hi(AW));
  end;

begin
  // Determinar numero de colores (potencia de 2)
  NumColors := Length(Palette);
  if NumColors <= 4 then MinCodeSize := 2
  else if NumColors <= 16 then MinCodeSize := 4
  else MinCodeSize := 8;

  NumColors := 1 shl MinCodeSize;
  ClearCode := NumColors;
  EOICode := ClearCode + 1;

  // Mapear pixeles a indices de paleta
  SetLength(Indices, W * H);
  for I := 0 to W * H - 1 do
  begin
    PalIdx := 0;
    for X := 0 to High(Palette) do
      if (Palette[X].R = Pixels[I].R) and (Palette[X].G = Pixels[I].G) and
         (Palette[X].B = Pixels[I].B) then
      begin
        PalIdx := X;
        Break;
      end;
    Indices[I] := PalIdx;
  end;

  // LZW encode
  SetLength(OutBytes, 4096);
  OutLen := 0;
  BitBuf := 0;
  BitPos := 0;

  InitDict;
  EmitCode(ClearCode);

  CurCode := Indices[0];
  for I := 1 to W * H - 1 do
  begin
    NextByte := Indices[I];
    X := FindInDict(CurCode, NextByte);
    if X >= 0 then
      CurCode := X
    else
    begin
      EmitCode(CurCode);
      if TableSize < 4096 then
      begin
        DictPrefix[TableSize] := CurCode;
        DictAppend[TableSize] := NextByte;
        Inc(TableSize);
        if TableSize > (1 shl CodeSize) then
          if CodeSize < 12 then Inc(CodeSize);
      end
      else
      begin
        EmitCode(ClearCode);
        InitDict;
      end;
      CurCode := NextByte;
    end;
  end;
  EmitCode(CurCode);
  EmitCode(EOICode);

  // Flush remaining bits
  if BitPos > 0 then
  begin
    if OutLen >= Length(OutBytes) then
      SetLength(OutBytes, OutLen + 1);
    OutBytes[OutLen] := BitBuf and $FF;
    Inc(OutLen);
  end;

  // Write GIF file
  AssignFile(F, FileName);
  Rewrite(F, 1);

  // Header
  BlockWrite(F, 'GIF89a', 6);

  // Logical Screen Descriptor
  WriteWord(W);
  WriteWord(H);
  WriteByte($80 or ((MinCodeSize - 1) shl 4) or (MinCodeSize - 1));
  WriteByte(0); // bg color
  WriteByte(0); // pixel aspect

  // Global Color Table
  for I := 0 to NumColors - 1 do
  begin
    if I <= High(Palette) then
    begin
      WriteByte(Palette[I].R);
      WriteByte(Palette[I].G);
      WriteByte(Palette[I].B);
    end
    else
    begin
      WriteByte(0); WriteByte(0); WriteByte(0);
    end;
  end;

  // Image Descriptor
  WriteByte($2C);
  WriteWord(0); WriteWord(0);
  WriteWord(W); WriteWord(H);
  WriteByte(0);

  // LZW data
  WriteByte(MinCodeSize);

  // Sub-blocks (max 255 bytes each)
  I := 0;
  while I < OutLen do
  begin
    X := OutLen - I;
    if X > 255 then X := 255;
    WriteByte(X);
    BlockWrite(F, OutBytes[I], X);
    Inc(I, X);
  end;

  WriteByte(0);   // block terminator
  WriteByte($3B); // GIF trailer

  CloseFile(F);
end;

end.
