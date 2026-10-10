param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../../.ai-apps/embedroid')
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$upstream = Join-Path $PSScriptRoot 'upstream'
$hashes = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'upstream-sha256.json') | ConvertFrom-Json

# Fail closed when importing a different release; never silently patch a new
# bundle whose transport or protocol may have changed.
foreach ($file in $hashes.PSObject.Properties) {
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $upstream $file.Name)).Hash
    if ($actual -ine $file.Value) { throw "Upstream modificado: $($file.Name)" }
}

$bundle = [IO.File]::ReadAllText((Join-Path $upstream 'dist/extension.js'))
$old = 'Xe.randomBytes(4).toString("hex")'
$replacement = 'require("../scid.cjs").generateScid()'
if (($bundle.Split(@($old), [StringSplitOptions]::None).Length - 1) -ne 2) {
    throw 'Se esperaban exactamente dos generadores scid de EmbeDroid 1.0.2.'
}
$bundle = $bundle.Replace($old, $replacement)

$output = [IO.Path]::GetFullPath($OutputDirectory)
$extension = Join-Path $output 'extension'
New-Item -ItemType Directory -Force -Path (Join-Path $extension 'dist') | Out-Null
Copy-Item -LiteralPath (Join-Path $upstream 'media') -Destination $extension -Recurse -Force
Copy-Item -LiteralPath (Join-Path $upstream 'LICENSE.txt') -Destination $extension -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'scid.cjs') -Destination $extension -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $extension 'readme.md') -Force
[IO.File]::WriteAllText((Join-Path $extension 'dist/extension.js'), $bundle, $utf8)

$manifest = Get-Content -Raw -LiteralPath (Join-Path $upstream 'package.json') | ConvertFrom-Json
$manifest.name = 'ai-apps-embedroid'
$manifest.publisher = 'magullodev'
$manifest.version = '1.0.3'
$manifest.displayName = 'EmbeDroid - AI-APPS maintained'
$manifest.description = 'EmbeDroid 1.0.2 con identificadores scrcpy de 31 bits; distribución mantenida en AI-APPS.'
$manifest.repository.url = 'https://github.com/magullodev-stack/ai-apps.git'
$manifest.bugs.url = 'https://github.com/magullodev-stack/ai-apps/issues'
$manifest.homepage = 'https://github.com/magullodev-stack/ai-apps/tree/dev/scripts/embedroid'
foreach ($name in @('__metadata', 'scripts', 'devDependencies', 'dependencies')) {
    $manifest.PSObject.Properties.Remove($name)
}
[IO.File]::WriteAllText((Join-Path $extension 'package.json'), ($manifest | ConvertTo-Json -Depth 30), $utf8)

$vsixManifest = @'
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="ai-apps-embedroid" Version="1.0.3" Publisher="magullodev" />
    <DisplayName>EmbeDroid - AI-APPS maintained</DisplayName>
    <Description xml:space="preserve">EmbeDroid 1.0.2 with 31-bit scrcpy identifiers.</Description>
    <Tags>android,emulator,scrcpy</Tags><Categories>Other</Categories><GalleryFlags>Public</GalleryFlags>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.85.0" /></Properties>
    <License>extension/LICENSE.txt</License><Icon>extension/media/icon.png</Icon>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code" /></Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/readme.md" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Content.License" Path="extension/LICENSE.txt" Addressable="true" />
  </Assets>
</PackageManifest>
'@
$contentTypes = @'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="js" ContentType="application/javascript" />
  <Default Extension="cjs" ContentType="application/javascript" />
  <Default Extension="css" ContentType="text/css" />
  <Default Extension="txt" ContentType="text/plain" />
  <Default Extension="md" ContentType="text/markdown" />
  <Default Extension="svg" ContentType="image/svg+xml" />
  <Default Extension="png" ContentType="image/png" />
  <Default Extension="jar" ContentType="application/java-archive" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
</Types>
'@

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$vsix = Join-Path $output 'ai-apps-embedroid-1.0.3.vsix'
$stream = [IO.File]::Open($vsix, [IO.FileMode]::Create)
$zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in @{ 'extension.vsixmanifest' = $vsixManifest; '[Content_Types].xml' = $contentTypes }.GetEnumerator()) {
        $writer = New-Object IO.StreamWriter($zip.CreateEntry($entry.Key).Open(), $utf8)
        try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
    }
    foreach ($file in Get-ChildItem -LiteralPath $extension -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($extension.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, "extension/$relative") | Out-Null
    }
}
finally { $zip.Dispose(); $stream.Dispose() }
Write-Output $vsix
