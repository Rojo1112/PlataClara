# Genera los íconos de PlataClara (1024 px, sin esquinas redondeadas: iOS las aplica solo).
# Uso: powershell -ExecutionPolicy Bypass -File scripts/generar-iconos.ps1
Add-Type -AssemblyName System.Drawing

$destino = Join-Path $PSScriptRoot "..\PlataClara\Assets.xcassets\AppIcon.appiconset"
New-Item -ItemType Directory -Force -Path $destino | Out-Null
$destino = (Resolve-Path $destino).Path

function Color($hex, $alpha = 255) {
    [System.Drawing.Color]::FromArgb($alpha, [Convert]::ToInt32($hex.Substring(1,2),16), [Convert]::ToInt32($hex.Substring(3,2),16), [Convert]::ToInt32($hex.Substring(5,2),16))
}

function Icono($archivo, $fondo, $marca, $punto, $alphaPunto) {
    $lado = 1024
    $s = $lado / 100.0
    $bmp = New-Object System.Drawing.Bitmap $lado, $lado
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear((Color $fondo))

    # Asta de la P, con extremos redondeados
    $x = 30 * $s; $y = 23.5 * $s; $w = 9 * $s; $h = 56.5 * $s; $d = $w
    $ruta = New-Object System.Drawing.Drawing2D.GraphicsPath
    $ruta.AddArc($x, $y, $d, $d, 180, 180)
    $ruta.AddArc($x, $y + $h - $d, $d, $d, 0, 180)
    $ruta.CloseFigure()
    $pincel = New-Object System.Drawing.SolidBrush (Color $marca)
    $g.FillPath($pincel, $ruta)

    # Aro (la moneda)
    $lapiz = New-Object System.Drawing.Pen (Color $marca), (9 * $s)
    $g.DrawEllipse($lapiz, (54 - 16) * $s, (44 - 16) * $s, 32 * $s, 32 * $s)

    # Punto del centro
    $pPunto = New-Object System.Drawing.SolidBrush (Color $punto $alphaPunto)
    $g.FillEllipse($pPunto, (54 - 5.5) * $s, (44 - 5.5) * $s, 11 * $s, 11 * $s)

    $bmp.Save((Join-Path $destino $archivo), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

Icono "icon.png"        "#0E7C66" "#FFFFFF" "#BFF0E1" 255
Icono "icon-dark.png"   "#0B1513" "#5FD8B7" "#FFFFFF" 255
Icono "icon-tinted.png" "#2B3532" "#E6ECE9" "#E6ECE9" 140
Write-Output "Íconos generados en $destino"
