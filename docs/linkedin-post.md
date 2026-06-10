# Post LinkedIn — Windows Unattended Deploy

---

🖥️ **Mídia de instalação do Windows que se configura sozinha — do zero ao pronto em ~15 minutos, sem um clique**

Sempre que precisava entregar um PC novo, o processo era o mesmo: instalar o Windows, esperar, clicar em "próximo" várias vezes, instalar Chrome, AnyDesk, 7-Zip, RustDesk, configurar o relay, copiar drivers, ajustar papel de parede e tela de bloqueio... facilmente 1 hora de trabalho repetitivo por máquina.

Resolvi automatizar tudo de uma vez.

---

🔧 **O que a mídia faz automaticamente:**

✅ Instala o Windows 11 sem nenhuma interação humana (autounattend.xml + GPT/UEFI)
✅ Remove bloatware: OneDrive, Xbox apps, Cortana, Teams consumer, Widgets
✅ Aplica papel de parede e tela de bloqueio corporativos
✅ Instala Google Chrome (MSI Enterprise — sem stub, sem surpresa)
✅ Instala e configura o AnyDesk
✅ Instala o 7-Zip (versão detectada automaticamente no site oficial)
✅ Instala o RustDesk já apontando pro meu servidor de relay próprio
✅ Instala drivers .inf e .exe de qualquer pasta "Drivers/" em qualquer mídia conectada
✅ Detecta e instala o agente do Tactical RMM (workstation ou server, pelo SKU do Windows)
✅ Apps adicionais via winget em lista configurável
✅ Log completo salvo automaticamente em C:\Windows\Temp\PostInstall\

---

🗂️ **Como funciona na prática:**

A mídia é uma ISO do Windows com três arquivos extras na raiz:
→ autounattend.xml (responde tudo que o setup pergunta)
→ Setup-PostInstall.ps1 (instala programas e configura o sistema)
→ Setup-Winget.ps1 (apps extras — só editar a lista)

Para drivers: basta criar uma pasta "Drivers/" no pendrive. O script varre todos os drives conectados automaticamente.

Para o Tactical RMM: joga o .exe na raiz do pendrive. O script detecta se é workstation ou server e instala o agente certo.

---

💡 **Detalhe técnico que me custou tempo:**

O instalador padrão do Chrome é um stub — ele termina rápido, mas o processo filho continua instalando em background. Em contexto SYSTEM (autounattend), o stub encerrava e o script continuava sem que o Chrome estivesse instalado.

A solução: usar o **MSI Enterprise standalone** do Google, que é atômico e não depende de subprocessos. Um detalhe pequeno que faz toda a diferença em automações.

---

📁 Publiquei o repositório no GitHub com os scripts e documentação completa:

👉 github.com/silvioribeiroti/windows-unattended-deploy

Se trabalha com implantação de Windows em escala corporativa, pode ser útil como ponto de partida.

---

#WindowsAdmin #SysAdmin #Automação #PowerShell #TI #InfraEstrutura #SilverSoluções #Windows11 #RustDesk #TacticalRMM #DevOps
