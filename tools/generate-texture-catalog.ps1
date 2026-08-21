# Regenera level_designs/texture-catalog.json a partir de las carpetas reales
# de assets/textures/packs/: un pack por carpeta, una entrada por PNG.
#
# Uso (desde la raiz del proyecto):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\generate-texture-catalog.ps1
#
# Los ids siguen el contrato del editor (tests/level_editor_smoke_test.mjs):
# minusculas y guiones, con la forma material/nombre-01. Las cadenas con tildes
# se arman con codigos de caracter porque PowerShell 5.1 lee este archivo como
# ANSI y corromperia los literales UTF-8.

$root = Split-Path $PSScriptRoot -Parent
$packsDir = Join-Path $root "assets\textures\packs"
$outPath = Join-Path $root "level_designs\texture-catalog.json"

$packLabels = [ordered]@{
  "Bricks"   = "Ladrillos"
  "Dirt"     = "Tierra"
  "Elements" = "Elementos"
  "Floor"    = "Pisos"
  "Grass"    = "Pasto"
  "Metal"    = "Metal"
  "Misc"     = "Varios"
  "Plaster"  = "Revoque"
  "Roofs"    = "Techos"
  "Stains"   = "Manchas"
  "Stone"    = "Piedra"
  "Tile"     = "Baldosas"
  "Wall"     = "Paredes"
  "Wood"     = "Madera"
}

$iAcute = [char]0xED; $oAcute = [char]0xF3; $uAcute = [char]0xFA
$emDash = [char]0x2014; $middleDot = [char]0x00B7

$description = "Texturas disponibles para las superficies de cada sala. Lo leen la herramienta (para ofrecer la lista) y TextureCatalog en Godot (para armar los materiales), as$iAcute que es la ${uAcute}nica fuente de la relaci${oAcute}n identificador -> archivo. Generado por tools/generate-texture-catalog.ps1 desde las carpetas de assets/textures/packs/."
$license = "Screaming Brain Studios $emDash CC0 / dominio p${uAcute}blico. Ver third_party/VERSIONS.md."

$packLines = @()
$textureLines = @()

foreach ($folder in $packLabels.Keys) {
  $dir = Join-Path $packsDir $folder
  if (-not (Test-Path $dir)) { Write-Error "Falta la carpeta $folder"; exit 1 }
  $packId = $folder.ToLower()
  $label = $packLabels[$folder]
  $packLines += ('    {{ "id": "{0}", "label": "{1}" }}' -f $packId, $label)

  $pngs = Get-ChildItem $dir -File -Filter *.png | Sort-Object Name
  if ($pngs.Count -eq 0) { Write-Error "La carpeta $folder no tiene PNGs"; exit 1 }
  foreach ($png in $pngs) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($png.Name)
    $short = $stem -replace '-256x256$', ''
    $texId = "$packId/" + ($short.ToLower() -replace '_', '-')
    $texLabel = "$label $middleDot " + ($short -replace '_', ' ')
    $resPath = "res://assets/textures/packs/$folder/$($png.Name)"
    $textureLines += ('    {{ "id": "{0}", "pack": "{1}", "label": "{2}", "path": "{3}", "tile": 2.0 }}' -f $texId, $packId, $texLabel, $resPath)
  }
}

$json = @"
{
  "schemaVersion": 2,
  "description": "$description",
  "license": "$license",
  "packs": [
$($packLines -join ",`n")
  ],
  "textures": [
$($textureLines -join ",`n")
  ]
}
"@

[IO.File]::WriteAllText($outPath, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("texture-catalog.json regenerado: {0} packs, {1} texturas." -f $packLines.Count, $textureLines.Count)
