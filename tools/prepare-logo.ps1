param(
    [string]$InputPath = "$PSScriptRoot\..\images\SVV_Logo.png"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path "$PSScriptRoot\..").Path
$source = [System.Drawing.Image]::FromFile((Resolve-Path $InputPath).Path)
$canvas = [System.Drawing.Bitmap]::new(1920, 1080, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)

try {
    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $scale = [Math]::Min((1920 * 0.60) / $source.Width, (1080 * 0.60) / $source.Height)
    $width = [int][Math]::Round($source.Width * $scale)
    $height = [int][Math]::Round($source.Height * $scale)
    $x = [int][Math]::Floor((1920 - $width) / 2)
    $y = [int][Math]::Floor((1080 - $height) / 2)
    $graphics.DrawImage($source, $x, $y, $width, $height)
    $canvas.Save("$root\kiosk\boot-splash.png", [System.Drawing.Imaging.ImageFormat]::Png)
    Copy-Item -LiteralPath (Resolve-Path $InputPath).Path -Destination "$root\kiosk\logo.png" -Force
    Write-Host "Bootlogo erstellt: ${width}x${height} Pixel bei ${x},${y}."
}
finally {
    $graphics.Dispose()
    $canvas.Dispose()
    $source.Dispose()
}
