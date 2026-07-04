# 修复 pdfx 在 Visual Studio 2026 / 新版 CMake 下的 Windows 构建问题。
$ErrorActionPreference = "Stop"
$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$pdfxDirs = Get-ChildItem -Path (Join-Path $pubCache "pdfx-*") -Directory -ErrorAction SilentlyContinue

if (-not $pdfxDirs) {
    Write-Error "未找到 pdfx 包，请先运行 flutter pub get"
}

foreach ($pdfxDir in $pdfxDirs) {
    $template = Join-Path $pdfxDir.FullName "windows\DownloadProject.CMakeLists.cmake.in"
    if (Test-Path $template) {
        $content = Get-Content -Path $template -Raw
        $updated = $content -replace 'cmake_minimum_required\(VERSION 2\.8\.12\)', 'cmake_minimum_required(VERSION 3.14)'
        if ($content -ne $updated) {
            Set-Content -Path $template -Value $updated -NoNewline
            Write-Host "已修复 CMake 模板: $template"
        } else {
            Write-Host "CMake 模板已是最新: $template"
        }
    }

    $cmakeLists = Join-Path $pdfxDir.FullName "windows\CMakeLists.txt"
    if (-not (Test-Path $cmakeLists)) {
        continue
    }

    $cmake = Get-Content -Path $cmakeLists -Raw
    if ($cmake -match 'PDFIUM_LOCAL_DIR') {
        Write-Host "pdfx 本地缓存逻辑已存在: $cmakeLists"
        continue
    }

    $oldBlock = @'
# Download pdfium
include(../windows/DownloadProject.cmake)
download_project(
  PROJ
  pdfium
  URL
  ${PDFIUM_URL}
  DOWNLOAD_EXTRACT_TIMESTAMP
  FALSE
)
'@

    $newBlock = @'
# Download pdfium, or use a local cache when GitHub download is unavailable.
if(DEFINED PDFIUM_LOCAL_DIR AND EXISTS "${PDFIUM_LOCAL_DIR}/PDFiumConfig.cmake")
  set(pdfium_SOURCE_DIR "${PDFIUM_LOCAL_DIR}")
else()
  include(../windows/DownloadProject.cmake)
  download_project(
    PROJ
    pdfium
    URL
    ${PDFIUM_URL}
    DOWNLOAD_EXTRACT_TIMESTAMP
    FALSE
  )
endif()
'@

    if (-not $cmake.Contains($oldBlock)) {
        Write-Warning "未找到可替换的 pdfx 下载逻辑: $cmakeLists"
        continue
    }

    $cmake = $cmake.Replace($oldBlock, $newBlock)
    Set-Content -Path $cmakeLists -Value $cmake -NoNewline
    Write-Host "已启用本地 pdfium 缓存: $cmakeLists"
}
