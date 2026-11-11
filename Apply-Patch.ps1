param([string]$Source, [string]$Output)
$ErrorActionPreference = 'Stop'
try {
 if (!$Source) { $Source = (Read-Host 'Original Japanese ISO path').Trim('"') }
 $Source = (Resolve-Path -LiteralPath $Source).Path
 if (!$Output) { $Output = Join-Path (Split-Path -Parent $Source) 'Lord of Apocalypse - Korean v0.5.iso' }
 $Output = [IO.Path]::GetFullPath($Output)
 if (Test-Path -LiteralPath $Output) { throw 'Output already exists. Choose another output name.' }
 if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant() -ne '3a4d63713880dfb67ade00b6a912ac4975847cec06b1ab341b65963f328e1c93') { throw 'Wrong source ISO. A clean supported Japanese ISO is required.' }
 $delta = Join-Path $PSScriptRoot 'loa-ko-v0.5.delta.gz'
 if ((Get-FileHash -LiteralPath $delta -Algorithm SHA256).Hash.ToLowerInvariant() -ne '392826a73e941e5df1641cf104b6e9ece148683a4a9d16094da2c2a5488b4eda') { throw 'Patch checksum mismatch.' }
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
public static class LoaPatch05 {
 public static void Apply(string source,string target,string patch) {
  using(var input=File.OpenRead(source))
  using(var output=new FileStream(target,FileMode.CreateNew,FileAccess.ReadWrite,FileShare.None)) {
   input.CopyTo(output);
   using(var file=File.OpenRead(patch))
   using(var zip=new GZipStream(file,CompressionMode.Decompress))
   using(var reader=new BinaryReader(zip)) {
    if(System.Text.Encoding.ASCII.GetString(reader.ReadBytes(8))!="LOAKR005") throw new Exception("Invalid delta header");
    long lastEnd=0;
    while(true) {
     long offset=reader.ReadInt64();uint size=reader.ReadUInt32();
     if(offset==-1) {if(size!=0 || reader.BaseStream.ReadByte()!=-1) throw new Exception("Invalid delta end");break;}
     if(offset<lastEnd || size==0 || size>65536 || offset>output.Length-size) throw new Exception("Invalid delta bounds");
     byte[] delta=reader.ReadBytes((int)size);if(delta.Length!=size)throw new Exception("Truncated delta");
     byte[] data=new byte[size];output.Position=offset;int got=0;
     while(got<data.Length) {int n=output.Read(data,got,data.Length-got);if(n==0)throw new Exception("Truncated ISO");got+=n;}
     for(int i=0;i<data.Length;i++)data[i]^=delta[i];
     output.Position=offset;output.Write(data,0,data.Length);lastEnd=offset+size;
    }
   }
  }
 }
}
'@
 $partial = $Output + '.partial'
 if (Test-Path -LiteralPath $partial) { throw 'A partial output already exists. Rename it before retrying.' }
 Write-Host 'Applying patch. The original ISO is preserved...'
 [LoaPatch05]::Apply($Source,$partial,$delta)
 if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant() -ne '9186495574ab17032b27927c485a4377e29626bdb7b824e88ed781b1d2ab91b4') { throw 'Output checksum mismatch. Do not use the partial file.' }
 Move-Item -LiteralPath $partial -Destination $Output
 Write-Host "SUCCESS: $Output"
 exit 0
} catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
