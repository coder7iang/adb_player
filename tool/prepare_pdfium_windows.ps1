# 下载并解压 pdfium 到 windows/third_party/pdfium，供 pdfx 插件本地使用。
param(
    [string]$Version = "4690",
    [string]$Arch = "x64"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$targetDir = Join-Path $projectRoot "windows\third_party\pdfium"
$cacheDir = Join-Path $projectRoot "windows\third_party\cache"
$tgz = Join-Path $cacheDir "pdfium-win-$Arch.tgz"

if (Test-Path (Join-Path $targetDir "PDFiumConfig.cmake")) {
    Write-Host "pdfium 已就绪: $targetDir"
    exit 0
}

New-Item -ItemType Directory -Force -Path $cacheDir, $targetDir | Out-Null

$urls = @(
    "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$Version/pdfium-win-$Arch.tgz",
    "https://ghfast.top/https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$Version/pdfium-win-$Arch.tgz",
    "https://mirror.ghproxy.com/https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$Version/pdfium-win-$Arch.tgz"
)

$downloaded = $false
foreach ($url in $urls) {
    Write-Host "尝试下载: $url"
    Remove-Item $tgz -Force -ErrorAction SilentlyContinue
    curl.exe -L --retry 3 --connect-timeout 30 --max-time 600 --http1.1 -o $tgz $url
    if ((Test-Path $tgz) -and ((Get-Item $tgz).Length -gt 1MB)) {
        Write-Host "下载成功: $([math]::Round((Get-Item $tgz).Length / 1MB, 1)) MB"
        $downloaded = $true
        break
    }
}

if (-not $downloaded) {
    Write-Error @"
pdfium 下载失败。请手动下载后解压到:
  $targetDir

下载地址:
  https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$Version/pdfium-win-$Arch.tgz

解压后目录中应包含 PDFiumConfig.cmake。
"@
}

$extractRoot = Join-Path $cacheDir "extract"
Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

tar -xzf $tgz -C $extractRoot
$inner = Get-ChildItem $extractRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "PDFiumConfig.cmake") } | Select-Object -First 1
if ($inner) {
    $sourceDir = $inner.FullName
} elseif (Test-Path (Join-Path $extractRoot "PDFiumConfig.cmake")) {
    $sourceDir = $extractRoot
} else {
    Write-Error "解压 pdfium 失败，未找到 PDFiumConfig.cmake"
}

Remove-Item $targetDir -Recurse -Force -ErrorAction SilentlyContinue
if ($sourceDir -eq $extractRoot) {
    Move-Item $sourceDir $targetDir
} else {
    Move-Item $sourceDir $targetDir
}
Write-Host "pdfium 已安装到: $targetDir"
