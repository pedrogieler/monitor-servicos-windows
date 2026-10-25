# Monitor de Serviços do Windows

Monitor em terminal para consultar os serviços do Windows, acompanhar mudanças de estado e revisar recursos que talvez não sejam utilizados no computador.

A ferramenta funciona **somente em auditoria**: não inicia, interrompe, desativa ou altera serviços. As observações dependem do uso de cada máquina; um serviço automático parado não é, por si só, um erro.

## Executar

No Windows 10 ou 11, baixe o repositório completo e abra `Monitor_Servicos.bat`. Mantenha a pasta `src` ao lado do arquivo BAT. O monitor utiliza o Windows PowerShell 5.1 e consulta o computador local.

- Paginação com até 28 serviços por tela, ajustada à altura do terminal.
- Filtros por estado, busca por nome e visualização de auditoria.
- Mudanças de estado destacadas em magenta após atualizar.
- Atualização manual por padrão; a tecla `U` alterna a atualização automática a cada 30 segundos.

| Tecla | Ação |
| --- | --- |
| `N` / `P` ou setas | Próxima página / página anterior |
| `R` | Atualizar a consulta |
| `T` / `E` / `S` | Todos / executando / parados |
| `A` | Exibir itens de auditoria e o uso a confirmar |
| `F` | Buscar pelo nome; Enter sem texto limpa a busca |
| `U` | Alternar atualização automática |
| `Q` | Sair |

Para apenas listar os serviços e encerrar:

```bat
Monitor_Servicos.bat -NaoInterativo
```

## Organização e testes

`Monitor_Servicos.bat` inicia o programa; `src/Monitor-Servicos.ps1` contém a consulta e a interface. Os testes verificam paginação, filtros, identificação de mudanças e o caráter de leitura das consultas. O workflow executa esses testes e uma consulta real em um runner Windows.

```powershell
powershell.exe -NoProfile -File .\tests\Test-Monitor.ps1
```
