# 🖥️ Windows Unattended Deploy

Pipeline completo de instalação automatizada do Windows 11 para ambientes corporativos.  
Desenvolvido e mantido por **Silver Soluções em TI**.

---

## 📋 O que este projeto faz

- **Instalação 100% autônoma** via `autounattend.xml` — sem clique algum durante o setup
- **Papel de parede e tela de bloqueio** personalizados automaticamente pós-instalação
- **Drivers** instalados automaticamente a partir de qualquer mídia conectada (pasta `Drivers/`)
- **Programas essenciais** instalados e configurados: Google Chrome, AnyDesk, 7-Zip, RustDesk
- **RustDesk pré-configurado** com seu servidor de relay próprio
- **Tactical RMM Agent** detectado e instalado automaticamente (workstation ou server)
- **Bloatware removido** via comandos integrados ao `autounattend.xml`
- **Apps extras via winget** configuráveis em lista simples (`Setup-Winget.ps1`)
- **Log completo** gerado em `C:\Windows\Temp\PostInstall\`

---

## 📁 Estrutura da mídia de instalação

```
📀 Raiz da mídia (ISO/Pendrive)
├── autounattend.xml              ← Responde o setup do Windows automaticamente
├── Setup-PostInstall.ps1         ← Instala programas, drivers, configura tudo
├── Setup-Winget.ps1              ← Apps extras via winget (editável)
├── Executar-PostInstall.bat      ← Launcher manual (clique com botão direito > Executar como admin)
├── trmm-silver-site-workstation-amd64.exe  ← Agente Tactical RMM (workstation)
├── trmm-silver-site-server-amd64.exe       ← Agente Tactical RMM (server)
└── Drivers/                      ← (opcional) Pasta com drivers .inf e/ou .exe
    ├── rede/
    │   └── driver.inf
    └── video/
        └── setup.exe
```

```
$OEM$\$1\Windows\Web\Wallpaper\
└── desktop.jpg                  ← Papel de parede corporativo
```

---

## ⚙️ Configuração antes de usar

Edite as variáveis no topo de `Setup-PostInstall.ps1`:

```powershell
$RustDeskRelay     = "rustdesk.suaempresa.com"
$RustDeskKey       = "SUA_CHAVE_PUBLICA_AQUI"
$DriversFolderName = "Drivers"   # Nome da pasta de drivers a procurar
```

---

## 🚀 Como gerar a mídia

1. Baixe a ISO do Windows 11 no site oficial da Microsoft
2. Abra com **AnyBurn** (recomendado — evita conflitos com XMLs do Rufus)
3. Adicione os arquivos deste repositório na raiz da ISO
4. Adicione a estrutura `$OEM$` com o papel de parede da empresa
5. Grave a ISO em um pendrive ou use via boot PXE/virtual

> ⚠️ **Caso use o Rufus** para montar esta mídia — Desmarque tudo na aba "Customize Windows Installation", pois ele gera seu próprio `autounattend.xml` e pode conflitar.

---

## 📦 Programas instalados automaticamente

| Programa | Método | Observação |
|---|---|---|
| Google Chrome | MSI Enterprise | Instalador standalone, sem stub |
| AnyDesk | EXE silencioso | Inicia com o Windows |
| 7-Zip | EXE (versão detectada automaticamente) | Fallback para versão fixa |
| RustDesk | GitHub Releases (latest) | Configurado com relay próprio |
| VLC, Adobe Reader, Zoom | winget | Configurável via `Setup-Winget.ps1` |

---

## 🔧 Drivers — como funciona

O script varre **todos os drives conectados** procurando uma pasta chamada `Drivers/`.  
A ordem de busca é:

1. Drive onde o script está sendo executado (mídia de instalação)
2. Todos os drives prontos (fixo, removível, rede, CD)
3. Fallback: `C:\Drivers`

Suporte a:
- **`.inf`** — instalados via `pnputil /add-driver /subdirs /install`
- **`.exe`** na raiz da pasta — executados com flags silenciosas `/s /S /silent /quiet`

Comando para fazer backup dos seus drivers:
- pnputil /export-driver * C:\Drivers

---

## 🖼️ Personalização visual

| Item | Caminho na mídia |
|---|---|
| Papel de parede | `$OEM$\$1\Windows\Web\Wallpaper\desktop.jpg` |
| Tela de bloqueio | `$OEM$\$1\Windows\Web\lockscreen.jpg` |

---

## 🗑️ Bloatware removido

O `autounattend.xml` remove automaticamente durante o setup:

- OneDrive Consumer
- Xbox apps (GameBar, GameOverlay, etc.)
- Microsoft Teams (consumer)
- Cortana
- Widgets do Windows 11
- Apps de mídia desnecessários

---

## 📊 Logs

Todos os logs são gravados em:

```
C:\Windows\Temp\PostInstall\
├── PostInstall_YYYYMMDD_HHmmss.log
└── Winget_YYYYMMDD_HHmmss.log
```

---

## 🏢 Sobre

**Silver Soluções em TI**  
Vitória da Conquista — Bahia  
[silversolucoes.com](https://silversolucoes.com) | contato@silversolucoes.com  
LinkedIn: [linkedin.com/in/silvioribeiroti](https://linkedin.com/in/silvioribeiroti)
