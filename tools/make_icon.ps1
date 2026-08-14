# Generates assets/app.ico (16/24/32/48/64 as 32-bit BMP entries, 256 as PNG entry)
# and assets/logo-256.png. Design: vibration waves on a dark disc, crossed by a red
# prohibition ring + slash.
param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\assets")
)

Add-Type -AssemblyName System.Drawing

$OutDir = [System.IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force $OutDir | Out-Null

function New-LogoBitmap([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $c = $s / 2.0

    $discColor = [System.Drawing.Color]::FromArgb(255, 33, 40, 48)    # dark slate
    $waveColor = [System.Drawing.Color]::FromArgb(255, 232, 234, 237) # off-white
    $redColor  = [System.Drawing.Color]::FromArgb(255, 229, 57, 53)   # signal red

    # Dark disc
    $rDisc = 0.47 * $s
    $discBrush = New-Object System.Drawing.SolidBrush($discColor)
    $g.FillEllipse($discBrush, $c - $rDisc, $c - $rDisc, 2 * $rDisc, 2 * $rDisc)

    # Vibration glyph: center dot + three arcs each side
    $waveWidth = [Math]::Max(1.0, 0.05 * $s)
    $wavePen = New-Object System.Drawing.Pen($waveColor, $waveWidth)
    $wavePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wavePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $rDot = 0.06 * $s
    $waveBrush = New-Object System.Drawing.SolidBrush($waveColor)
    $g.FillEllipse($waveBrush, $c - $rDot, $c - $rDot, 2 * $rDot, 2 * $rDot)
    foreach ($rw in @(0.15, 0.23, 0.31)) {
        $r = $rw * $s
        # right side ")))"
        $g.DrawArc($wavePen, $c - $r, $c - $r, 2 * $r, 2 * $r, -35, 70)
        # left side "((("
        $g.DrawArc($wavePen, $c - $r, $c - $r, 2 * $r, 2 * $r, 145, 70)
    }

    # Prohibition ring + slash (top-left to bottom-right)
    $rRing = 0.40 * $s
    $redWidth = [Math]::Max(1.0, 0.085 * $s)
    $redPen = New-Object System.Drawing.Pen($redColor, $redWidth)
    $g.DrawEllipse($redPen, $c - $rRing, $c - $rRing, 2 * $rRing, 2 * $rRing)
    $d = $rRing / [Math]::Sqrt(2)
    $g.DrawLine($redPen, $c - $d, $c - $d, $c + $d, $c + $d)

    $g.Dispose()
    $wavePen.Dispose(); $redPen.Dispose(); $discBrush.Dispose(); $waveBrush.Dispose()
    return $bmp
}

# 32-bit BMP (DIB) icon entry: BITMAPINFOHEADER + bottom-up BGRA pixels + empty AND mask
function Get-DibBytes([System.Drawing.Bitmap]$bmp) {
    $s = $bmp.Width
    $maskRowBytes = [int](([Math]::Floor(($s + 31) / 32)) * 4)
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter($ms)
    $w.Write([uint32]40)          # biSize
    $w.Write([int32]$s)           # biWidth
    $w.Write([int32](2 * $s))     # biHeight (image + mask)
    $w.Write([uint16]1)           # biPlanes
    $w.Write([uint16]32)          # biBitCount
    $w.Write([uint32]0)           # biCompression
    $w.Write([uint32]($s * $s * 4 + $maskRowBytes * $s))
    $w.Write([int32]0); $w.Write([int32]0); $w.Write([uint32]0); $w.Write([uint32]0)
    for ($y = $s - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $s; $x++) {
            $p = $bmp.GetPixel($x, $y)
            $w.Write([byte]$p.B); $w.Write([byte]$p.G); $w.Write([byte]$p.R); $w.Write([byte]$p.A)
        }
    }
    $mask = New-Object byte[] ($maskRowBytes * $s)  # all zero: opacity comes from alpha
    $w.Write($mask)
    $w.Flush()
    return $ms.ToArray()
}

function Get-PngBytes([System.Drawing.Bitmap]$bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    return $ms.ToArray()
}

$entries = @()
foreach ($s in @(16, 24, 32, 48, 64)) {
    $bmp = New-LogoBitmap $s
    # [byte[]] cast is load-bearing: functions return Object[], which BinaryWriter
    # would otherwise bind to Write(Boolean) and emit a single byte.
    $entries += , @{ Size = $s; Data = [byte[]](Get-DibBytes $bmp) }
    $bmp.Dispose()
}
$bmp256 = New-LogoBitmap 256
$entries += , @{ Size = 256; Data = [byte[]](Get-PngBytes $bmp256) }
$bmp256.Save((Join-Path $OutDir "logo-256.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp256.Dispose()

$icoPath = Join-Path $OutDir "app.ico"
$fs = [System.IO.File]::Create($icoPath)
$w = New-Object System.IO.BinaryWriter($fs)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$entries.Count)
$offset = 6 + 16 * $entries.Count
foreach ($e in $entries) {
    $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }
    $w.Write([byte]$dim); $w.Write([byte]$dim)
    $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$e.Data.Length)
    $w.Write([uint32]$offset)
    $offset += $e.Data.Length
}
foreach ($e in $entries) { $w.Write([byte[]]$e.Data) }
$w.Flush(); $fs.Close()

Write-Host "Wrote $icoPath ($((Get-Item $icoPath).Length) bytes) and logo-256.png"
