$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\src\Monitor-Servicos.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }

# A publicacao oferece consultas, nunca comandos de controle de servicos.
$forbidden = '^(?:(?:Start|Stop|Restart|Suspend|Resume|Set|New|Remove)-Service|Set-CimInstance|Invoke-CimMethod|Invoke-Expression|sc(?:\.exe)?|net(?:\.exe)?|reg(?:\.exe)?)$'
$commands = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)
foreach ($command in $commands) {
    if ($command.GetCommandName() -match $forbidden) { throw ('Comando de alteracao encontrado: ' + $command.GetCommandName()) }
}
. $source -SomenteFuncoes

function Assert-True($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}
$services = @(
    [pscustomobject]@{ Name='Fax'; DisplayName='Fax'; State='Stopped'; StartMode='Manual' },
    [pscustomobject]@{ Name='Spooler'; DisplayName='Fila de impressao'; State='Running'; StartMode='Auto' },
    [pscustomobject]@{ Name='Literal[1]'; DisplayName='Teste de busca'; State='Running'; StartMode='Auto' }
)
Assert-True (@(Get-MonitorFilteredServices $services 'Executando').Count -eq 2) 'Filtro executando incorreto.'
Assert-True (@(Get-MonitorFilteredServices $services 'Parados').Count -eq 1) 'Filtro parados incorreto.'
Assert-True (@(Get-MonitorFilteredServices $services 'Auditoria').Count -eq 1) 'Auditoria incorreta.'
Assert-True (@(Get-MonitorFilteredServices $services 'Todos' '[').Count -eq 1) 'Busca deve tratar caracteres como texto literal.'
Assert-True (@(Get-MonitorFilteredServices $services 'Todos' 'FILA').Count -eq 1) 'Busca deve ignorar diferenca de maiusculas.'
Assert-True (-not (Get-MonitorAuditReason 'Spooler')) 'Um servico nao catalogado nao deve receber classificacao automatica.'

$page = Get-MonitorPage $services 99 2
Assert-True ($page.Index -eq 1 -and $page.Count -eq 2 -and $page.Items.Count -eq 1) 'Ultima pagina incorreta.'
Assert-True ((Get-MonitorPage $services -1 2).Index -eq 0) 'Pagina negativa deve voltar para a primeira.'
$empty = Get-MonitorPage @() 0 28
Assert-True ($empty.Count -eq 1 -and $empty.Items.Count -eq 0) 'Lista vazia deve manter uma pagina valida.'

$changed = @([pscustomobject]@{ Name='Fax'; State='Running' })
$changes = Get-MonitorChanges $services $changed
Assert-True ($changes.ContainsKey('Fax') -and $changes.Count -eq 1) 'Mudanca de estado nao detectada.'
Assert-True ((Get-MonitorChanges $null $services).Count -eq 0) 'Primeira consulta nao deve sinalizar mudancas.'
Assert-True ((Get-MonitorChanges $services $services).Count -eq 0) 'Estados iguais nao devem sinalizar mudancas.'

$live = @(Get-MonitorSnapshot)
Assert-True ($live.Count -gt 0) 'Consulta real de servicos retornou vazia.'
Assert-True ([bool]$live[0].Name) 'Consulta deve fornecer o nome do servico.'
Write-Host ('Validacao concluida: sintaxe, filtros, paginacao, mudancas e consulta de {0} servicos.' -f $live.Count)
