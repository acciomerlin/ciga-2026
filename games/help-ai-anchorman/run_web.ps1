# Godot Web 导出运行脚本
# 解决 "Failed to fetch" 错误:浏览器用 file:// 协议无法 fetch WASM/PCK 文件
# 用法:在 help-ai-anchorman 目录下运行 .\run_web.ps1

$ErrorActionPreference = "Stop"
$port = 8060
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $dir)
$gameUrl = "http://localhost:$port/dist/help-ai-anchorman/index.html"

if (-not (Test-Path (Join-Path $workspaceRoot "dist/help-ai-anchorman/index.html"))) {
    throw "请先在仓库根目录运行 tools/export_web.py，生成 Web 导出。"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Help AI Anchorman - Web 运行脚本" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "原因说明:" -ForegroundColor Yellow
Write-Host "  Godot Web 导出包含 .wasm 和 .pck 文件,"
Write-Host "  浏览器在 file:// 协议下无法 fetch 这些文件,"
Write-Host "  会报 'TypeError: Failed to fetch' 错误。"
Write-Host "  必须通过 HTTP 服务器访问才能正常运行。"
Write-Host ""
Write-Host "正在启动本地 HTTP 服务器 (端口 $port)..." -ForegroundColor Green

# 尝试用 Python 启动服务器
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonCmd = "py"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
}

if ($pythonCmd) {
    Write-Host "使用 $pythonCmd 启动服务器..." -ForegroundColor Green
    Write-Host ""
    Write-Host "游戏地址: $gameUrl" -ForegroundColor Magenta
    Write-Host "按 Ctrl+C 停止服务器" -ForegroundColor DarkGray
    Write-Host ""
    # 自动打开浏览器
    Start-Process $gameUrl
    # 启动服务器
    & $pythonCmd (Join-Path $workspaceRoot "tools/serve.py") --port $port
} else {
    Write-Host "[错误] 未找到 Python,请先安装 Python 3.x" -ForegroundColor Red
    Write-Host "下载地址: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "或者使用 Node.js 替代方案:" -ForegroundColor Yellow
    Write-Host "  npx http-server -p $port" -ForegroundColor DarkGray
}
