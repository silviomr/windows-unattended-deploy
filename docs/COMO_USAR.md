# 📖 Como Usar — Passo a Passo

## Pré-requisitos

- ISO do Windows 11 (baixe no site oficial da Microsoft)
- [AnyBurn](https://www.anyburn.com/download.php) instalado
- Pendrive de pelo menos 8 GB

---

## 1. Configure os scripts

Abra `scripts/Setup-PostInstall.ps1` e edite o bloco de configuração no topo:

```powershell
$RustDeskRelay     = "rustdesk.suaempresa.com"   # seu servidor
$RustDeskKey       = "SUA_CHAVE_AQUI"             # chave pública do servidor
$DriversFolderName = "Drivers"                    # nome da pasta de drivers
```

---

## 2. Prepare a pasta de drivers (opcional)

Crie uma pasta chamada `Drivers/` na raiz do pendrive com os drivers necessários:

```
Drivers/
├── rede/
│   └── driver.inf
├── video/
│   └── setup.exe
└── chipset/
    └── chipset.inf
```

O script detecta `.inf` e `.exe` automaticamente.

---

## 3. Adicione o agente Tactical RMM (opcional)

Baixe o instalador gerado no painel do Tactical RMM e coloque **na raiz** do pendrive:

```
trmm-silver-site-workstation-amd64.exe
```

O script detecta automaticamente se é workstation ou server pelo SKU do Windows.

> ⚠️ O instalador do Tactical RMM expira em **30 dias**. Renove conforme necessário.

---

## 4. Monte a ISO com AnyBurn

1. Abra o AnyBurn
2. Clique em **"Edit Image File"**
3. Selecione a ISO do Windows 11
4. Adicione na raiz da ISO:
   - `autounattend.xml` (gerado para sua empresa — veja `docs/autounattend-notes.md`)
   - `scripts/Setup-PostInstall.ps1`
   - `scripts/Setup-Winget.ps1`
   - `scripts/Executar-PostInstall.bat`
   - `trmm-silver-site-workstation-amd64.exe` (se usar)
5. Adicione a estrutura `$OEM$\$1\Windows\Web\Wallpaper\` com sua imagem corporativa
6. Adicione a estrutura `$OEM$\$1\Windows\Web\` com sua imagem de bloqueio corporativa
7. Salve como nova ISO ou grave direto no pendrive

---

## 5. Boot e instalação

1. Configure o PC para bootar pelo pendrive (F12 / F2 / DEL)
2. O setup do Windows inicia e **se auto-responde completamente**
3. Ao chegar na área de trabalho, o script de pós-instalação roda automaticamente
4. Após concluir, o PC estará pronto para uso

---

## 6. Execução manual (se necessário)

Se precisar rodar o script em um Windows já instalado:

```
Executar-PostInstall.bat  →  clique com botão direito → "Executar como administrador"
```

---

## Solução de problemas

| Problema | Solução |
|---|---|
| Script não roda automaticamente | Verifique se o `autounattend.xml` está na raiz da mídia e não em subpasta |
| Chrome não instala | Verifique conexão com internet — o MSI Enterprise é baixado em runtime |
| RustDesk sem relay | Confirme `$RustDeskRelay` e `$RustDeskKey` no script |
| Drivers não encontrados | Verifique se a pasta se chama exatamente `Drivers` (sensível ao case no path) |
| Log de erro | Verifique `C:\Windows\Temp\PostInstall\PostInstall_*.log` |
