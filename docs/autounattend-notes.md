# autounattend.xml

O arquivo `autounattend.xml` deve ser colocado na **raiz da mídia de instalação**.

Por conter configurações específicas da empresa (nome de usuário, senha de administrador local,
chave de produto, etc.), **não está incluído neste repositório público**.

## O que ele faz

- Seleciona a edição do Windows automaticamente (por índice de imagem)
- Particiona o disco em GPT/UEFI sem interação
- Cria conta de usuário local sem conta Microsoft
- Aceita os termos de licença automaticamente
- Remove bloatware via `Remove-AppxPackage` no primeiro logon
- Executa `FirstLogon.ps1` que dispara o `Setup-PostInstall.ps1`
- Configura papel de parede e tela de bloqueio corporativos

## Como gerar o seu

Use o [Schneegans Unattend Generator](https://schneegans.de/windows/unattend-generator/)
como base e adapte as seções `<FirstLogonCommands>` e `<RunSynchronousCommand>` conforme
os scripts deste repositório.

## Estrutura mínima do FirstLogon.ps1

```powershell
# C:\Windows\Setup\Scripts\FirstLogon.ps1
# Chamado pelo autounattend.xml no primeiro logon

# Papel de parede
$wallpaper = "C:\Windows\Web\Wallpaper\desktop.jpg"
if (Test-Path $wallpaper) {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaper
    RUNDLL32.EXE user32.dll, UpdatePerUserSystemParameters
}

# Tela de bloqueio
$lockscreen = "C:\Windows\Web\lockscreen.jpg"
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name LockScreenImage -Value $lockscreen

# Executa pós-instalação
$script = "D:\Setup-PostInstall.ps1"
if (Test-Path $script) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
}
```
