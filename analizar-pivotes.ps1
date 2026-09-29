param(
    [Parameter(Mandatory = $true)]
    [string]$Ruta,
    [string]$Original,
    [string]$Salida = 'resumen-pivotes.md'
)
$ErrorActionPreference = 'Stop'

function Key([string]$value) {
    return [regex]::Replace($value.Trim().ToLowerInvariant(), '\s+', ' ')
}

function Leer-Llamadas([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "No existe el archivo: $path" }
    $calls = [System.Collections.Generic.List[object]]::new()
    $current = $null
    $lines = Get-Content -LiteralPath $path
    foreach ($line in $lines) {
        if ($line -match '^## Llamada\s+\d+/\d+') {
            if ($null -ne $current) {
                if ($current.Count -ne 10) {
                    throw "Se esperaban 10 filas en la llamada $($calls.Count + 1) de $path; hay $($current.Count)."
                }
                $calls.Add($current.ToArray())
            }
            $current = [System.Collections.Generic.List[object]]::new()
            continue
        }
        if ($line -match '^## Comparaci') { break }
        if ($null -eq $current -or -not $line.StartsWith('|')) { continue }
        $cells = [regex]::Split($line, '(?<!\\)\|')
        if ($cells.Length -ne 4) { continue }
        $p = $cells[1].Trim()
        $r = $cells[2].Trim()
        if ($p -eq 'Campo de conocimiento' -or $p -eq '---') { continue }
        if (-not $p -or -not $r) { continue }
        $current.Add([pscustomobject]@{ P = $p; R = $r })
    }
    if ($null -ne $current) {
        if ($current.Count -ne 10) {
            throw "Se esperaban 10 filas en la llamada $($calls.Count + 1) de $path; hay $($current.Count)."
        }
        $calls.Add($current.ToArray())
    }
    if ($calls.Count -eq 0 -or $calls.Count % 10 -ne 0) {
        throw "Se necesitan lotes completos de 10 llamadas. Se encontraron $($calls.Count) en $path."
    }
    $lastCost = @($lines | Where-Object { $_ -match '^Acumulado:' } | Select-Object -Last 1)
    $cost = ''
    if ($lastCost.Count -gt 0 -and $lastCost[0] -match ';\s*([\d.,]+)\s*USD') {
        $cost = $Matches[1]
    }
    return [pscustomobject]@{ Calls = $calls.ToArray(); Cost = $cost; Path = $path }
}

function Pivote([string]$raw) {
    # Algunas filas contienen "Geografia — ¿pregunta?" en la columna P.
    # Solo retiramos una pregunta si comienza por un signo de apertura claro.
    if ($raw -match '^(.*?)\s+[—–-]\s*¿') { return $Matches[1].Trim() }
    return $raw.Trim()
}

function Md([string]$value) {
    return $value.Replace('|', '\|').Replace([char]13, ' ').Replace([char]10, ' ')
}

$packs = [System.Collections.Generic.List[object]]::new()
$runs = [System.Collections.Generic.List[object]]::new()
$index = 1

if ($Original) {
    $baseline = Leer-Llamadas $Original
    if ($baseline.Calls.Count -ne 10) { throw 'El test original debe contener exactamente 10 llamadas.' }
    $packs.Add([pscustomobject]@{ Lote = 'B0'; Calls = $baseline.Calls })
    $runs.Add($baseline)
}

$newRun = Leer-Llamadas $Ruta
$runs.Add($newRun)
for ($start = 0; $start -lt $newRun.Calls.Count; $start += 10) {
    $ten = [System.Collections.Generic.List[object]]::new()
    for ($j = 0; $j -lt 10; $j++) { $ten.Add($newRun.Calls[$start + $j]) }
    $packs.Add([pscustomobject]@{ Lote = "B$index"; Calls = $ten.ToArray() })
    $index++
}

$seenP = @{}
$seenR = @{}
$frequencyP = @{}
$namesP = @{}
$firstP = @{}
$lotsP = @{}
$freqR = @{}
$namesR = @{}
$observations = [System.Collections.Generic.List[object]]::new()
$perFieldPack = [System.Collections.Generic.List[object]]::new()
$summary = [System.Collections.Generic.List[object]]::new()
$prevPackP = @{}
$questionFields = 0

foreach ($pack in $packs) {
    $pThis = @{}
    $rThis = @{}
    $firstThis = @{}
    $currentNames = @{}
    $rDuplicateRows = 0
    $rPreviouslySeen = 0
    $ordinal = 0
    foreach ($call in $pack.Calls) {
        $ordinal++
        $position = 0
        foreach ($item in $call) {
            $position++
            $p = Pivote $item.P
            if ($p -ne $item.P) { $questionFields++ }
            $pk = Key $p
            $rk = Key $item.R
            $currentNames[$pk] = $p
            if (-not $namesP.ContainsKey($pk)) { $namesP[$pk] = $p }
            if (-not $namesR.ContainsKey($rk)) { $namesR[$rk] = $item.R }
            if (-not $pThis.ContainsKey($pk)) { $pThis[$pk] = 0 }
            if (-not $frequencyP.ContainsKey($pk)) { $frequencyP[$pk] = 0 }
            if (-not $freqR.ContainsKey($rk)) { $freqR[$rk] = 0 }
            $pThis[$pk]++
            $frequencyP[$pk]++
            $freqR[$rk]++
            if ($position -eq 1) {
                if (-not $firstP.ContainsKey($pk)) { $firstP[$pk] = 0 }
                if (-not $firstThis.ContainsKey($pk)) { $firstThis[$pk] = 0 }
                $firstP[$pk]++
                $firstThis[$pk]++
            }
            if ($rThis.ContainsKey($rk)) { $rDuplicateRows++ }
            else { $rThis[$rk] = $true }
            if ($seenR.ContainsKey($rk)) { $rPreviouslySeen++ }
            $observations.Add([pscustomobject]@{
                Lote = $pack.Lote
                Llamada = $ordinal
                Posicion = $position
                CampoOriginal = $item.P
                P = $p
                R = $item.R
            })
        }
    }
    $newP = 0
    $sharedPrev = 0
    foreach ($pk in $pThis.Keys) {
        if (-not $seenP.ContainsKey($pk)) { $newP++ }
        if ($prevPackP.ContainsKey($pk)) { $sharedPrev++ }
        if (-not $lotsP.ContainsKey($pk)) { $lotsP[$pk] = 0 }
        $lotsP[$pk]++
        $perFieldPack.Add([pscustomobject]@{
            Lote = $pack.Lote
            P = $currentNames[$pk]
            Frecuencia = $pThis[$pk]
            PrimeraPosicion = $(if ($firstThis.ContainsKey($pk)) { $firstThis[$pk] } else { 0 })
        })
        $seenP[$pk] = $true
    }
    foreach ($rk in $rThis.Keys) { $seenR[$rk] = $true }
    $sorted = @($pThis.Keys | Sort-Object -Property @{ Expression = { $pThis[$_] }; Descending = $true }, @{ Expression = { $_ }; Descending = $false })
    $top = @($sorted | Select-Object -First 3 | ForEach-Object {
        "$($currentNames[$_]) ($($pThis[$_]))"
    }) -join '; '
    $summary.Add([pscustomobject]@{
        Lote = $pack.Lote
        PDistintos = $pThis.Count
        PNuevos = $newP
        PAcumulados = $seenP.Count
        PCompartidosConAnterior = $sharedPrev
        RDistintas = $rThis.Count
        RRepetidasDentro = $rDuplicateRows
        RYaVistasAntes = $rPreviouslySeen
        TopP = $top
    })
    $prevPackP = $pThis
}

$allP = @($frequencyP.Keys | Sort-Object -Property @{ Expression = { $frequencyP[$_] }; Descending = $true }, @{ Expression = { $_ }; Descending = $false })
$totalRows = $observations.Count
$singletonP = @($frequencyP.Keys | Where-Object { $frequencyP[$_] -eq 1 }).Count
$twiceP = @($frequencyP.Keys | Where-Object { $frequencyP[$_] -eq 2 }).Count
$repeatedR = @($freqR.Keys | Where-Object { $freqR[$_] -gt 1 })
$repeatCountR = $totalRows - $freqR.Count
$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# Experimento QuizAI - distribucion de pivotes')
$report.Add('')
$report.Add("Archivos: $($runs.Count) | Lotes: $($packs.Count) | Llamadas: $($packs.Count * 10) | Respuestas: $totalRows")
$report.Add("Pivotes textualmente distintos: $($frequencyP.Count) | Respuestas textualmente distintas: $($freqR.Count)")
$report.Add("Pivotes con una aparicion: $singletonP | Con dos apariciones: $twiceP | Repeticiones de respuesta: $repeatCountR")
$report.Add("Campos que incluian una pregunta en P (corregidos para este informe): $questionFields")
$report.Add('Nota: P y R se agrupan por texto normalizado, no por identidad semantica.')
$report.Add('')
$report.Add('## Por lote: descubrimiento, recurrencia y variacion')
$report.Add('| Lote | P diferentes | N nuevos | C acumulados | P comunes con lote anterior | R diferentes | R rep. dentro | R ya vistas antes |')
$report.Add('|---|---:|---:|---:|---:|---:|---:|---:|')
foreach ($s in $summary) {
    $report.Add("| $($s.Lote) | $($s.PDistintos) | $($s.PNuevos) | $($s.PAcumulados) | $($s.PCompartidosConAnterior) | $($s.RDistintas) | $($s.RRepetidasDentro) | $($s.RYaVistasAntes) |")
}
$meanNew = ($summary.ToArray() | Measure-Object -Property PNuevos -Average).Average
$meanDistinct = ($summary.ToArray() | Measure-Object -Property PDistintos -Average).Average
$report.Add('')
$report.Add(('Medias por lote: P diferentes = {0:N2}; P nuevos = {1:N2}.' -f $meanDistinct, $meanNew))
$report.Add('N y C se calculan respecto a todos los lotes anteriores, incluido B0 si se proporciona.')
$report.Add('')
$report.Add('## Tres pivotes mas frecuentes en cada lote')
foreach ($s in $summary) { $report.Add("- $($s.Lote): $($s.TopP)") }
$report.Add('')
$report.Add('## Distribucion global de P')
$report.Add('| P | Apariciones | % del total | Lotes presentes | Veces en posicion 1 |')
$report.Add('|---|---:|---:|---:|---:|')
foreach ($pk in $allP) {
    $percentage = (100.0 * $frequencyP[$pk] / $totalRows).ToString('0.00', [cultureinfo]::InvariantCulture)
    $first = 0
    if ($firstP.ContainsKey($pk)) { $first = $firstP[$pk] }
    $report.Add("| $(Md $namesP[$pk]) | $($frequencyP[$pk]) | $percentage% | $($lotsP[$pk]) | $first |")
}
$report.Add('')
$report.Add('## Respuestas repetidas (primeras 30 por frecuencia)')
$rankedR = @($repeatedR | Sort-Object -Property @{ Expression = { $freqR[$_] }; Descending = $true }, @{ Expression = { $_ }; Descending = $false } | Select-Object -First 30)
if ($rankedR.Count -eq 0) { $report.Add('Ninguna repeticion textual.') }
else {
    foreach ($rk in $rankedR) { $report.Add("- $($namesR[$rk]): $($freqR[$rk]) apariciones") }
}
$report.Add('')
$report.Add('## Coste segun los archivos')
foreach ($run in $runs) {
    if ($run.Cost) { $report.Add("- $($run.Path): $($run.Cost) USD") }
    else { $report.Add("- $($run.Path): no consta coste acumulado.") }
}
$report.Add('')
$report.Add('Los archivos originales se conservan; el CSV de observaciones permite revisar cada P-R sin regenerar respuestas.')

$fullOutput = [System.IO.Path]::GetFullPath($Salida)
$directory = [System.IO.Path]::GetDirectoryName($fullOutput)
if (-not (Test-Path -LiteralPath $directory)) {
    [void](New-Item -ItemType Directory -Force -Path $directory)
}
$stem = [System.IO.Path]::Combine($directory, [System.IO.Path]::GetFileNameWithoutExtension($fullOutput))
$report | Set-Content -LiteralPath $fullOutput -Encoding UTF8
$observations.ToArray() | Export-Csv -LiteralPath "$stem-observaciones.csv" -NoTypeInformation -Encoding UTF8
$perFieldPack.ToArray() | Export-Csv -LiteralPath "$stem-pivotes-por-lote.csv" -NoTypeInformation -Encoding UTF8
Write-Output "Informe: $fullOutput"
Write-Output "Observaciones P-R: $stem-observaciones.csv"
Write-Output "Frecuencias por lote: $stem-pivotes-por-lote.csv"
Write-Output "Lotes: $($packs.Count); llamadas: $($packs.Count * 10); P distintos: $($frequencyP.Count); R distintas: $($freqR.Count)."
