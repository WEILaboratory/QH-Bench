param(
    [ValidateSet('all', 'en', 'zh')][string]$Language = 'all',
    [ValidateSet('all', 'main', 'main_authors', 'supplementary')][string]$Target = 'all',
    [string]$TexBin = ''
)
$ErrorActionPreference = 'Stop'
if (-not $TexBin) {
    $latexCommand = Get-Command pdflatex -ErrorAction SilentlyContinue
    if ($latexCommand) { $TexBin = Split-Path $latexCommand.Source }
    elseif (Test-Path 'C:\miktex-portable\texmfs\install\miktex\bin\x64\pdflatex.exe') {
        $TexBin = 'C:\miktex-portable\texmfs\install\miktex\bin\x64'
    } else { throw 'Specify -TexBin with the directory containing pdflatex and bibtex.' }
}
$latex = Join-Path $TexBin 'pdflatex.exe'
$bibtex = Join-Path $TexBin 'bibtex.exe'
$languageDirs = @{ en = '英文'; zh = '中文' }
$languages = if ($Language -eq 'all') { @('en', 'zh') } else { @($Language) }
$targets = if ($Target -eq 'all') { @('main', 'main_authors', 'supplementary') } else { @($Target) }
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    $output = & $Program @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $output | Select-Object -Last 45 | Write-Host
        throw "Build failed: $Program $Arguments"
    }
    $output | Select-String 'Output written|Warning|Overfull' | ForEach-Object { Write-Host $_ }
}
foreach ($lang in $languages) {
    Push-Location (Join-Path $PSScriptRoot $languageDirs[$lang])
    try {
        foreach ($entry in $targets) {
            Write-Host "Building $lang/$entry"
            $latexArgs = @('-disable-installer', '-interaction=nonstopmode', '-halt-on-error', '-file-line-error', "$entry.tex")
            Invoke-Checked $latex $latexArgs
            if ($entry -ne 'supplementary' -or $lang -eq 'zh') {
                Invoke-Checked $bibtex @($entry)
            }
            Invoke-Checked $latex $latexArgs
            Invoke-Checked $latex $latexArgs
            if (Select-String -LiteralPath "$entry.log" -SimpleMatch 'Label(s) may have changed' -Quiet) {
                Invoke-Checked $latex $latexArgs
            }
        }
    } finally { Pop-Location }
}
