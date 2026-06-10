<#
.SYNOPSIS
    Script de pos-instalacao do Windows
    Instala: Google Chrome, AnyDesk, 7-Zip, RustDesk
    Configura: Servidor Relay do RustDesk
    Instala: Drivers encontrados automaticamente em qualquer drive

.NOTES
    Compativel com execucao via autounattend.xml (contexto SYSTEM, sem desktop)
    Tambem pode ser executado manualmente: clique direito > "Executar com PowerShell"
#>

# ============================================================
# CONFIGURACOES - ajuste antes de usar
# ============================================================
$RustDeskRelay = "SEU_SERVIDOR_AQUI"
$RustDeskKey   = "SUA_CHAVE_AQUI"
$DriversFolderName = "Drivers"
$TempDir           = "C:\Windows\Temp\PostInstall"
# ============================================================

# --- Auto-elevacao (quando executado manualmente) ---
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- TLS 1.2 obrigatorio para downloads modernos ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Forca o uso do SystemDrive como TempDir (seguro em SYSTEM/autounattend) ---
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# --- Log ---
$logFile = "$TempDir\PostInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile -Append | Out-Null

function Write-Step { param($msg) Write-Host ""; Write-Host "[>>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [!!] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  [--] $msg" -ForegroundColor Yellow }

# ============================================================
# Download com retry (substitui WebClient sem retry)
# ============================================================
function Download-File {
    param(
        [string]$Url,
        [string]$Dest,
        [int]$Tentativas = 3,
        [int]$TimeoutSec = 120
    )
    for ($i = 1; $i -le $Tentativas; $i++) {
        try {
            Write-Info "Download ($i/$Tentativas): $Url"
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "PostInstall-Script/2.0")
            $wc.DownloadFile($Url, $Dest)
            if ((Test-Path $Dest) -and (Get-Item $Dest).Length -gt 0) {
                Write-OK "Download OK: $(Split-Path $Dest -Leaf) ($(([math]::Round((Get-Item $Dest).Length/1MB,1))) MB)"
                return $true
            }
            Write-Fail "Arquivo vazio apos download."
        } catch {
            Write-Fail "Tentativa $i falhou: $_"
            if ($i -lt $Tentativas) { Start-Sleep -Seconds 5 }
        }
    }
    return $false
}

# ============================================================
# Instalacao silenciosa com timeout configuravel
# ============================================================
function Install-Silent {
    param(
        [string]$Exe,
        [string]$Arguments,
        [string]$Nome,
        [int]$TimeoutSec = 300   # AUMENTADO: 5 min padrao (Chrome precisa de tempo)
    )

    if (-not (Test-Path $Exe)) {
        Write-Fail "Instalador nao encontrado: $Exe"
        return $false
    }

    Write-Info "Instalando $Nome (timeout: ${TimeoutSec}s)..."

    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -NoNewWindow
    $finished = $p.WaitForExit($TimeoutSec * 1000)

    if (-not $finished) {
        Write-Fail "${Nome}: timeout apos $TimeoutSec segundos."
        try { $p.Kill() } catch {}
        return $false
    }

    Write-OK "$Nome instalado (ExitCode: $($p.ExitCode))"
    return $true
}

# ============================================================
# Verifica instalacao via registro
# ============================================================
function Is-Installed {
    param([string]$Name)
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $found = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
             Where-Object { $_.DisplayName -like "*$Name*" }
    return ($null -ne $found)
}

# ============================================================
# Busca pasta Drivers em todos os drives
# ============================================================
function Find-DriversFolder {
    param([string]$FolderName)

    # 1. Drive do script (se rodando de pendrive/ISO)
    if ($PSScriptRoot) {
        $scriptDrive = Split-Path -Qualifier $PSScriptRoot
        $candidate = Join-Path ($scriptDrive + "\") $FolderName
        if (Test-Path $candidate) { Write-OK "Drivers em: $candidate"; return $candidate }
    }

    # 2. Todos os drives prontos
    $drives = [System.IO.DriveInfo]::GetDrives() |
              Where-Object { $_.IsReady -and $_.DriveType -in @('Fixed','Removable','Network','CDRom') }

    foreach ($drive in $drives) {
        if ($drive.RootDirectory.FullName -eq ($env:SystemDrive + "\")) { continue }
        $candidate = Join-Path $drive.RootDirectory.FullName $FolderName
        if (Test-Path $candidate) { Write-OK "Drivers em: $candidate"; return $candidate }
    }

    # 3. Fallback C:\Drivers
    $fallback = Join-Path $env:SystemDrive $FolderName
    if (Test-Path $fallback) { Write-OK "Drivers em: $fallback"; return $fallback }

    return $null
}

# ============================================================
# Banner
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Pos-Instalacao Windows - Silver Solucoes em TI" -ForegroundColor Magenta
Write-Host "  $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta


# ============================================================
# 1. GOOGLE CHROME
# FIX: chrome_installer.exe e um stub que baixa e instala em background.
#      O processo pai encerra rapido, mas o filho (GoogleUpdate) continua.
#      Solucao: usar o instalador Enterprise (MSI/standalone) que e atomico
#               e nao depende de subprocessos.
# ============================================================
Write-Step "Google Chrome"

if (Is-Installed "Google Chrome") {
    Write-OK "Chrome ja instalado - pulando."
} else {
    $installer = "$TempDir\ChromeEnterprise.msi"

    # Instalador Enterprise standalone (64-bit) - nao e stub, nao precisa de subprocesso
    $chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

    if (Download-File -Url $chromeUrl -Dest $installer -TimeoutSec 180) {
        # msiexec com /qn = totalmente silencioso, sem janela
        Install-Silent -Exe "msiexec.exe" `
                       -Arguments "/i `"$installer`" /qn /norestart ALLUSERS=1" `
                       -Nome "Google Chrome" `
                       -TimeoutSec 300
    }
}


# ============================================================
# 2. ANYDESK
# ============================================================
Write-Step "AnyDesk"

if (Is-Installed "AnyDesk") {
    Write-OK "AnyDesk ja instalado - pulando."
} else {
    $installer = "$TempDir\AnyDeskSetup.exe"
    $anyArgs   = "--install `"$env:ProgramFiles\AnyDesk`" --start-with-win --create-shortcuts"

    if (Download-File -Url "https://download.anydesk.com/AnyDesk.exe" -Dest $installer) {
        Install-Silent -Exe $installer -Arguments $anyArgs -Nome "AnyDesk" -TimeoutSec 120
    }
}


# ============================================================
# 3. 7-ZIP
# FIX: URL hardcoded quebra quando sai nova versao.
#      Solucao: buscar a versao atual via API do 7-zip.org ou usar URL generica.
#      Como o site nao tem API, usamos winget (disponivel no Win11/Win10 atualizado)
#      com fallback para URL conhecida.
# ============================================================
Write-Step "7-Zip"

if (Is-Installed "7-Zip") {
    Write-OK "7-Zip ja instalado - pulando."
} else {
    # Tenta descobrir a versao mais recente via pagina de downloads
    $sevenZipUrl = $null
    try {
        Write-Info "Consultando versao atual do 7-Zip..."
        $page = Invoke-WebRequest -Uri "https://www.7-zip.org/download.html" -UseBasicParsing -TimeoutSec 20
        $match = [regex]::Match($page.Content, 'href="(a/7z\d+-x64\.exe)"')
        if ($match.Success) {
            $sevenZipUrl = "https://www.7-zip.org/" + $match.Groups[1].Value
            Write-Info "Versao encontrada: $sevenZipUrl"
        }
    } catch {
        Write-Fail "Falha ao consultar site do 7-Zip: $_"
    }

    # Fallback para versao conhecida
    if (-not $sevenZipUrl) {
        $sevenZipUrl = "https://www.7-zip.org/a/7z2407-x64.exe"
        Write-Info "Usando URL de fallback: $sevenZipUrl"
    }

    $installer = "$TempDir\7zip-setup.exe"
    if (Download-File -Url $sevenZipUrl -Dest $installer) {
        Install-Silent -Exe $installer -Arguments "/S" -Nome "7-Zip" -TimeoutSec 60
    }
}


# ============================================================
# 4. RUSTDESK
# FIX PRINCIPAL: A API do GitHub pode estar lenta/indisponivel durante o OOBE.
#   - Aumentado timeout da API para 15s
#   - Filtro de asset corrigido: busca o .exe nao-debug e nao-sciter
#   - URL de fallback atualizada para versao recente conhecida
#   - Timeout de instalacao aumentado para 180s (instalador e lento)
#   - Wait apos instalacao aumentado de 10s para 20s
#   - Reinicio do RustDesk via servico (nao Start-Process) para compatibilidade SYSTEM
# ============================================================
Write-Step "RustDesk"

if (-not (Is-Installed "RustDesk")) {
    $installer = "$TempDir\rustdesk-setup.exe"
    $rdUrl     = $null

    Write-Info "Consultando ultima versao do RustDesk no GitHub..."
    try {
        $apiUrl  = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
        $headers = @{ "User-Agent" = "PostInstall-Script/2.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 15

        # Busca .exe 64-bit que NAO seja debug nem sciter (esses nao instalam silenciosamente)
        $asset = $release.assets |
                 Where-Object { $_.name -match "x86_64.*\.exe$" -and
                                $_.name -notmatch "debug" -and
                                $_.name -notmatch "sciter" } |
                 Select-Object -First 1

        if ($asset) {
            $rdUrl = $asset.browser_download_url
            Write-Info "RustDesk $($release.tag_name): $($asset.name)"
        } else {
            throw "Nenhum asset x86_64.exe valido encontrado."
        }
    } catch {
        Write-Fail "API GitHub: $_"
        Write-Info "Usando URL de fallback..."
        # Atualize esta URL quando sair nova versao estavel
        $rdUrl = "https://github.com/rustdesk/rustdesk/releases/download/1.3.8/rustdesk-1.3.8-x86_64.exe"
    }

    if (Download-File -Url $rdUrl -Dest $installer -TimeoutSec 180) {
        Install-Silent -Exe $installer -Arguments "--silent-install" -Nome "RustDesk" -TimeoutSec 180
        Write-Info "Aguardando servico do RustDesk iniciar..."
        Start-Sleep -Seconds 20
    }
}


# ============================================================
# CONFIGURACAO DO RUSTDESK
# ============================================================
Write-Step "Configurando RustDesk"

# --- Encerrar processos e servico antes de editar configs ---
Write-Info "Encerrando RustDesk..."
Get-Process rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Stop-Service -Name "RustDesk" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# --- Gravar RustDesk2.toml em todos os perfis relevantes ---
$toml = @"
rendezvous_server = "$RustDeskRelay"
nat_type = 1
serial = 0

[options]
custom-rendezvous-server = "$RustDeskRelay"
relay-server = "$RustDeskRelay"
key = "$RustDeskKey"
"@

$configPaths = @(
    "$env:APPDATA\RustDesk\config",
    "C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config",
    "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config"
)

foreach ($dir in $configPaths) {
    try {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Set-Content -Path "$dir\RustDesk2.toml" -Value $toml -Encoding UTF8
        Write-OK "Config gravada: $dir\RustDesk2.toml"
    } catch {
        Write-Fail "Falha ao gravar config em $dir : $_"
    }
}

# --- Reiniciar via servico ---
# Usa sc.exe em vez de Start-Service para evitar os avisos verbose do PowerShell
# ("Aguardando que o servico seja iniciado") que poluem o log sem indicar erro real.
Write-Info "Iniciando servico RustDesk..."

# Aguarda o SCM registrar o servico (pode demorar alguns segundos apos instalacao)
$svcReady = $false
for ($i = 1; $i -le 6; $i++) {
    $svc = Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue
    if ($svc) { $svcReady = $true; break }
    Write-Info "Aguardando registro do servico... ($i/6)"
    Start-Sleep -Seconds 5
}

if (-not $svcReady) {
    Write-Fail "Servico RustDesk nao encontrado apos 30s - verifique se a instalacao foi concluida."
} else {
    # sc.exe start nao gera os avisos de "aguardando" do PowerShell
    $scOut = & sc.exe start RustDesk 2>&1
    Start-Sleep -Seconds 5

    $svc.Refresh()
    if ($svc.Status -eq "Running") {
        Write-OK "Servico RustDesk em execucao."
    } elseif ($svc.Status -eq "StartPending") {
        Write-OK "Servico RustDesk iniciando (StartPending) - normal em primeiro uso."
    } else {
        Write-Fail "Servico RustDesk nao iniciou (status: $($svc.Status))."
        Write-Info "Saida do sc.exe: $scOut"
    }
}


# ============================================================
# 5. DRIVERS
# ============================================================
Write-Step "Drivers - procurando pasta '$DriversFolderName'"

$DriversPath = Find-DriversFolder -FolderName $DriversFolderName

if ($null -eq $DriversPath) {
    Write-Info "Pasta '$DriversFolderName' nao encontrada - etapa ignorada."
} else {
    # INF via pnputil
    Write-Info "Instalando drivers .inf via pnputil: $DriversPath"
    $pnpResult = & pnputil.exe /add-driver "$DriversPath\*.inf" /subdirs /install 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Drivers .inf instalados."
    } else {
        Write-Fail "pnputil exit code $LASTEXITCODE"
    }
    Write-Info ($pnpResult -join "`n")

    # EXE na raiz da pasta Drivers
    $exeDrivers = Get-ChildItem -Path $DriversPath -Filter "*.exe" -Depth 1 -ErrorAction SilentlyContinue
    if ($exeDrivers.Count -gt 0) {
        Write-Info "$($exeDrivers.Count) driver(s) .exe encontrado(s)."
        foreach ($exe in $exeDrivers) {
            Write-Info "Executando: $($exe.Name)"
            $p = Start-Process -FilePath $exe.FullName -ArgumentList "/s /S /silent /quiet" -Wait -PassThru -NoNewWindow
            Write-OK "$($exe.Name) - ExitCode: $($p.ExitCode)"
        }
    }
}


# ============================================================
# 6. SETUP-WINGET (opcional - se existir na mesma pasta)
# ============================================================
Write-Step "Verificando Setup-Winget.ps1"

$wingetScript = $null

# Determina o diretorio do script atual
# $PSScriptRoot funciona quando executado como arquivo; fallback para split do MyInvocation
if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
    $wingetScript = Join-Path $PSScriptRoot "Setup-Winget.ps1"
} elseif ($MyInvocation.MyCommand.Path) {
    $wingetScript = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "Setup-Winget.ps1"
}

if ($wingetScript -and (Test-Path $wingetScript)) {
    Write-OK "Setup-Winget.ps1 encontrado - executando..."
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wingetScript
        Write-OK "Setup-Winget.ps1 concluido."
    } catch {
        Write-Fail "Erro ao executar Setup-Winget.ps1: $_"
    }
} else {
    Write-Info "Setup-Winget.ps1 nao encontrado na mesma pasta - etapa ignorada."
    Write-Info "Crie o arquivo '$wingetScript' para ativar instalacoes extras via winget."
}



# ============================================================
# 7. TACTICAL RMM AGENT (opcional)
#
# COMO USAR:
#   1. No painel do Tactical RMM, gere o instalador do agente (.exe)
#   2. Coloque o .exe na RAIZ de qualquer drive conectado ao PC:
#      - Raiz da midia de instalacao do Windows (ISO/pendrive)
#      - Pendrive separado
#      - Qualquer particao fixa
#   3. O script varre todos os drives automaticamente, igual ao mecanismo
#      de busca de drivers, e instala o primeiro que encontrar
#   4. Se nao encontrar nenhum, continua sem erro
#
# NOMES RECONHECIDOS: qualquer .exe contendo "trmm" ou "tactical" no nome
#   Exemplos: trmm-silver-site-workstation-amd64.exe
#             trmm-silver-site-server-amd64.exe
#
# NOTA: o instalador expira em 30 dias. Basta substituir o .exe na midia.
# ============================================================
Write-Step "Tactical RMM Agent"

function Find-TacticalInstaller {
    $drives = [System.IO.DriveInfo]::GetDrives() |
              Where-Object { $_.IsReady -and
                             $_.DriveType -in @('Fixed','Removable','Network','CDRom') }

    foreach ($drive in $drives) {
        # Varre a raiz do drive (nao recursivo - o EXE fica na raiz da midia)
        $found = Get-ChildItem -Path $drive.RootDirectory.FullName -Filter "*.exe" `
                               -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "trmm|tactical" } |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

        if ($found) {
            Write-OK "Encontrado em $($drive.RootDirectory.FullName): $($found.Name)"
            return $found
        }
    }
    return $null
}

# Detecta automaticamente workstation ou server pelo SKU do Windows
$osSku = (Get-WmiObject Win32_OperatingSystem).OperatingSystemSKU
# SKUs de servidor: 7 (Standard), 8 (Datacenter), 12 (Datacenter Core), 13 (Standard Core)
# e outros acima de 6 que nao sao Desktop
$isServer = $osSku -in @(7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 29)
$perfilAlvo = if ($isServer) { "server" } else { "workstation" }
Write-Info "Perfil detectado: $perfilAlvo (SKU: $osSku)"

$tacticalInstaller = $null
$drives = [System.IO.DriveInfo]::GetDrives() |
          Where-Object { $_.IsReady -and
                         $_.DriveType -in @('Fixed','Removable','Network','CDRom') }

foreach ($drive in $drives) {
    # Tenta primeiro o EXE do perfil correto (workstation ou server)
    $found = Get-ChildItem -Path $drive.RootDirectory.FullName -Filter "*.exe" `
                           -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match "trmm|tactical" } |
             Sort-Object @{
                 # Prioriza o EXE que contenha o perfil correto no nome
                 Expression = { if ($_.Name -match $perfilAlvo) { 0 } else { 1 } }
             }, LastWriteTime -Descending |
             Select-Object -First 1

    if ($found) {
        Write-OK "Instalador encontrado: $($drive.RootDirectory.FullName)$($found.Name)"
        $tacticalInstaller = $found
        break
    }
}

if ($tacticalInstaller) {
    # O EXE gerado pelo Tactical ja tem servidor/token embutidos
    # /S = silent install
    $p = Start-Process -FilePath $tacticalInstaller.FullName `
                       -ArgumentList "/S" `
                       -Wait -PassThru -NoNewWindow `
                       -ErrorAction SilentlyContinue

    if ($p -and $p.ExitCode -eq 0) {
        Write-OK "Tactical RMM Agent instalado com sucesso."
    } elseif ($p) {
        Write-Info "Tactical RMM Agent - ExitCode: $($p.ExitCode) (pode ser instalacao ja existente)."
    } else {
        Write-Fail "Falha ao iniciar o instalador do Tactical RMM."
    }
} else {
    Write-Info "Nenhum instalador do Tactical RMM encontrado em nenhum drive - etapa ignorada."
}

# ============================================================
# RESUMO FINAL
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Concluido! $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor Magenta
Write-Host "  Log: $logFile" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Stop-Transcript | Out-Null
