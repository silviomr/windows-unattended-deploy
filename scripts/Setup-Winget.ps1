<#
.SYNOPSIS
    Instalacao de programas adicionais via winget.
    Chamado automaticamente pelo Setup-PostInstall.ps1 se existir na mesma pasta.
    Pode tambem ser executado manualmente.

.COMO ADICIONAR UM PROGRAMA
    1. Descubra o ID do app:  winget search "nome do programa"
    2. Adicione uma linha na lista $Apps abaixo:
       @{ Id = "Publisher.AppName"; Nome = "Nome legivel" }
    3. Salve o arquivo. Na proxima execucao o programa sera instalado.

.EXEMPLOS DE IDs COMUNS
    Google.Chrome              Notepad++.Notepad++
    Mozilla.Firefox            VideoLAN.VLC
    Microsoft.VisualStudioCode Zoom.Zoom
    7zip.7zip                  Adobe.Acrobat.Reader.64-bit
    TeamViewer.TeamViewer      WinRAR.WinRAR
#>

# ============================================================
# LISTA DE APPS - adicione ou remova conforme necessario
# ============================================================
$Apps = @(
    @{ Id = "VideoLAN.VLC";                  Nome = "VLC Media Player"    },
    @{ Id = "Adobe.Acrobat.Reader.64-bit";   Nome = "Adobe Acrobat Reader"},
    @{ Id = "Zoom.Zoom";                     Nome = "Zoom"                }
    # @{ Id = "Mozilla.Firefox";             Nome = "Firefox"             },
    # @{ Id = "Microsoft.VisualStudioCode";  Nome = "VS Code"             },
    # @{ Id = "Notepad++.Notepad++";         Nome = "Notepad++"           }
)
# ============================================================

# --- Auto-elevacao ---
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TempDir = "C:\Windows\Temp\PostInstall"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$logFile = "$TempDir\Winget_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile -Append | Out-Null

function Write-Step { param($msg) Write-Host ""; Write-Host "[>>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [!!] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  [--] $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Instalacao via Winget - Silver Solucoes" -ForegroundColor Magenta
Write-Host "  $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

# --- Verificar se winget esta disponivel ---
Write-Step "Verificando winget"
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCmd) {
    Write-Fail "winget nao encontrado. Execute apos o primeiro logon do Windows."
    Stop-Transcript | Out-Null
    exit 1
}
$wingetVer = & winget --version 2>&1
Write-OK "winget disponivel: $wingetVer"

# Forca aceite dos termos na primeira execucao para evitar prompt interativo
# Em instalacoes novas o winget pode travar aqui sem isso
Write-Info "Aceitando termos do winget (primeira execucao)..."
& winget list --accept-source-agreements 2>&1 | Out-Null

# --- Instalar apps da lista ---
Write-Step "Instalando $($Apps.Count) programa(s)"

$sucessos = 0
$falhas   = 0

foreach ($app in $Apps) {
    Write-Info "Instalando: $($app.Nome) [$($app.Id)]"

    $result = & winget install `
        --id $app.Id `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --scope machine `
        2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-OK "$($app.Nome) instalado com sucesso."
        $sucessos++
    } elseif ($LASTEXITCODE -eq -1978335189) {
        # Codigo 0x8A150021 = ja instalado
        Write-OK "$($app.Nome) ja esta instalado - pulando."
        $sucessos++
    } else {
        Write-Fail "$($app.Nome) falhou (ExitCode: $LASTEXITCODE)"
        Write-Info ($result -join " | ")
        $falhas++
    }
}

# --- Resumo ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Winget concluido: $sucessos OK, $falhas falha(s)" -ForegroundColor Magenta
Write-Host "  Log: $logFile" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Stop-Transcript | Out-Null
