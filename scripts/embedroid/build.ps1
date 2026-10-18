param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../../.ai-apps/embedroid')
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$upstream = Join-Path $PSScriptRoot 'upstream'
$hashes = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'upstream-sha256.json') | ConvertFrom-Json

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

function Replace-ExactlyOnce([string]$Text, [string]$Old, [string]$New) {
    if (($Text.Split(@($Old), [StringSplitOptions]::None).Length - 1) -ne 1) {
        throw 'El punto de integración multiemulador no coincide con el upstream fijado.'
    }
    return $Text.Replace($Old, $New)
}
$bundle = Replace-ExactlyOnce $bundle 'a=new $e(s,t,i,e)' 'a=require("../sessions.cjs").createViews($e,s,t,i,e)'
$bundle = Replace-ExactlyOnce $bundle 'f&&await a.open(f)' 'f&&(d?.session?await a.openSession({...d.session,serial:f},!!d.reconnect):await a.open(f))'
$bundle = Replace-ExactlyOnce $bundle 'e.info("Embedded Android Emulator activated.");async function h' 'e.info("Embedded Android Emulator activated.");return {openSession:(session,reconnect)=>a.openSession(session,reconnect),closeSession:serial=>a.close(serial),listSessions:()=>a.listSessions(),restoredCount:()=>a.restoredCount};async function h'

$output = [IO.Path]::GetFullPath($OutputDirectory)
$extension = Join-Path $output 'extension'
New-Item -ItemType Directory -Force -Path (Join-Path $extension 'dist') | Out-Null
Copy-Item -LiteralPath (Join-Path $upstream 'media') -Destination $extension -Recurse -Force
Copy-Item -LiteralPath (Join-Path $upstream 'LICENSE.txt') -Destination $extension -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'scid.cjs') -Destination $extension -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'sessions.cjs') -Destination $extension -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'boot-ready.cjs') -Destination $extension -Force
$webviewPath = Join-Path $extension 'media/webview.js'
$webview = [IO.File]::ReadAllText($webviewPath)
$webview = Replace-ExactlyOnce $webview 'case"config":' 'case"session":x.setState({serial:t.session.serial});break;case"config":'
$webview = Replace-ExactlyOnce $webview 'case"config":w=t.wsUrl' 'case"config":if(v){v.onclose=null;v.close()}try{d?.close()}catch{}d=void 0;h=!1;g&&(clearTimeout(g),g=void 0);w=t.wsUrl'
$webview = Replace-ExactlyOnce $webview 'function u(e){' 'function u(e){x.postMessage({type:"streamError"});'
$webview = Replace-ExactlyOnce $webview 'function N(e){' 'var renderedFrames=0,lastFrameReport=0;function N(e){renderedFrames++;if(Date.now()-lastFrameReport>=1000){lastFrameReport=Date.now();x.postMessage({type:"frame",frames:renderedFrames})}'
[IO.File]::WriteAllText($webviewPath, $webview, $utf8)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $extension 'readme.md') -Force
[IO.File]::WriteAllText((Join-Path $extension 'dist/extension.js'), $bundle, $utf8)

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $upstream 'package.json') | ConvertFrom-Json
$manifest.name = 'ai-apps-embedroid'
$manifest.publisher = 'magullodev'
$manifest.version = '1.1.1'
$manifest.displayName = 'EmbeDroid - AI-APPS maintained'
$manifest.description = 'EmbeDroid con sesiones multiemulador restaurables e identificadores scrcpy de 31 bits.'
$manifest.activationEvents += 'onWebviewPanel:embedroid.embedded'
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
    <Identity Language="en-US" Id="ai-apps-embedroid" Version="1.1.1" Publisher="magullodev" />
    <DisplayName>EmbeDroid - AI-APPS maintained</DisplayName>
    <Description xml:space="preserve">Multi-emulator EmbeDroid with restored sessions and 31-bit scrcpy identifiers.</Description>
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
$vsix = Join-Path $output 'ai-apps-embedroid-1.1.1.vsix'
$stream = [IO.File]::Open($vsix, [IO.FileMode]::Create)
$zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
$fixedTimestamp = [DateTimeOffset]'2000-01-01T00:00:00+00:00'
try {
    foreach ($entry in ([ordered]@{ 'extension.vsixmanifest' = $vsixManifest; '[Content_Types].xml' = $contentTypes }).GetEnumerator()) {
        $zipEntry = $zip.CreateEntry($entry.Key)
        $zipEntry.LastWriteTime = $fixedTimestamp
        $writer = New-Object IO.StreamWriter($zipEntry.Open(), $utf8)
        try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
    }
    foreach ($file in Get-ChildItem -LiteralPath $extension -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($extension.Length + 1).Replace('\', '/')
        $zipEntry = $zip.CreateEntry("extension/$relative")
        $zipEntry.LastWriteTime = $fixedTimestamp
        $inputStream = [IO.File]::OpenRead($file.FullName)
        $entryStream = $zipEntry.Open()
        try { $inputStream.CopyTo($entryStream) }
        finally { $entryStream.Dispose(); $inputStream.Dispose() }
    }
}
finally { $zip.Dispose(); $stream.Dispose() }
Write-Output $vsix
