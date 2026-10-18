# 将应用图标裁成微信风格圆角，并生成 Windows ICO
Add-Type -AssemblyName System.Drawing

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -ErrorAction SilentlyContinue
if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Get-RoundedBitmap {
    param(
        [System.Drawing.Bitmap]$Source,
        [double]$RadiusRatio = 0.22
    )
    $w = $Source.Width
    $h = $Source.Height
    $radius = [int]([Math]::Min($w, $h) * $RadiusRatio)
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($w - $d - 1, 0, $d, $d, 270, 90)
    $path.AddArc($w - $d - 1, $h - $d - 1, $d, $d, 0, 90)
    $path.AddArc(0, $h - $d - 1, $d, $d, 90, 90)
    $path.CloseFigure()

    $g.SetClip($path)
    $g.DrawImage($Source, 0, 0, $w, $h)
    $g.ResetClip()
    $g.Dispose()
    $path.Dispose()
    return $bmp
}

function Save-MultiSizeIco {
    param(
        [System.Drawing.Bitmap]$Source,
        [string]$Path,
        [int[]]$Sizes = @(16, 32, 48, 64, 128, 256)
    )

    $streams = New-Object System.Collections.Generic.List[byte[]]
    $entries = @()
    $offset = 6 + (16 * $Sizes.Count)

    foreach ($size in $Sizes) {
        $resized = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $rg = [System.Drawing.Graphics]::FromImage($resized)
        $rg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $rg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $rg.Clear([System.Drawing.Color]::Transparent)
        $rg.DrawImage($Source, 0, 0, $size, $size)
        $rg.Dispose()

        $ms = New-Object System.IO.MemoryStream
        $resized.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $ms.ToArray()
        $ms.Dispose()
        $resized.Dispose()

        $streams.Add($pngBytes)
        $entries += [pscustomobject]@{
            Width  = if ($size -ge 256) { 0 } else { $size }
            Height = if ($size -ge 256) { 0 } else { $size }
            Size   = $pngBytes.Length
            Offset = $offset
        }
        $offset += $pngBytes.Length
    }

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter $fs
    # ICONDIR
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$Sizes.Count)
    foreach ($e in $entries) {
        $bw.Write([byte]$e.Width)
        $bw.Write([byte]$e.Height)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$e.Size)
        $bw.Write([uint32]$e.Offset)
    }
    foreach ($bytes in $streams) {
        $bw.Write($bytes)
    }
    $bw.Dispose()
    $fs.Dispose()
}

$pngPath = Join-Path $root "images\app_icon.png"
$trayPath = Join-Path $root "images\tray_icon.png"
$icoPaths = @(
    (Join-Path $root "images\app_icon.ico"),
    (Join-Path $root "windows\runner\resources\app_icon.ico")
)

$src = [System.Drawing.Bitmap]::FromFile($pngPath)
$rounded = Get-RoundedBitmap -Source $src
$src.Dispose()

# 先写到临时文件再替换，避免文件锁
$tmpPng = Join-Path $env:TEMP "adb_player_app_icon_rounded.png"
$rounded.Save($tmpPng, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item -Force $tmpPng $pngPath
Write-Host "saved $pngPath"

$traySrc = [System.Drawing.Bitmap]::FromFile($trayPath)
$trayRounded = Get-RoundedBitmap -Source $traySrc
$traySrc.Dispose()
$tmpTray = Join-Path $env:TEMP "adb_player_tray_icon_rounded.png"
$trayRounded.Save($tmpTray, [System.Drawing.Imaging.ImageFormat]::Png)
$trayRounded.Dispose()
Copy-Item -Force $tmpTray $trayPath
Write-Host "saved $trayPath"

foreach ($ico in $icoPaths) {
    Save-MultiSizeIco -Source $rounded -Path $ico
    Write-Host "saved $ico"
}

$rounded.Dispose()
Write-Host "done"
