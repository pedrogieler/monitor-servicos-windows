#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(5, 100)][int]$ItensPorPagina = 28,
    [ValidateRange(0, 3600)][int]$IntervaloSegundos = 0,
    [switch]$NaoInterativo,
    [switch]$SomenteFuncoes
)

$ErrorActionPreference = 'Stop'

function Get-MonitorSnapshot {
    @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
        Select-Object Name, DisplayName, State, StartMode |
        Sort-Object Name)
}

function Get-MonitorAuditReason {
    param([string]$Name)
    # Uma correspondencia indica apenas um uso que merece ser confirmado.
    switch ($Name) {
        'Fax'             { return 'Confirmar se o computador utiliza fax.' }
        'MapsBroker'      { return 'Confirmar se utiliza mapas baixados para uso offline.' }
        'RetailDemo'      { return 'Confirmar se esta em demonstracao de loja.' }
        'WMPNetworkSvc'   { return 'Confirmar se compartilha midia pela rede.' }
        'XblAuthManager'  { return 'Confirmar uso de jogos e autenticacao Xbox.' }
        'XblGameSave'     { return 'Confirmar uso de salvamento de jogos Xbox.' }
        'XboxNetApiSvc'   { return 'Confirmar uso dos recursos de rede Xbox.' }
        'XboxGipSvc'      { return 'Confirmar uso de acessorios e recursos Xbox.' }
        default          { return '' }
    }
}

function Get-MonitorFilteredServices {
    param([object[]]$Services, [string]$Filter = 'Todos', [string]$Search = '')
    foreach ($service in $Services) {
        if ($Filter -eq 'Executando' -and $service.State -ne 'Running') { continue }
        if ($Filter -eq 'Parados' -and $service.State -ne 'Stopped') { continue }
        if ($Filter -eq 'Auditoria' -and -not (Get-MonitorAuditReason $service.Name)) { continue }
        if ($Search -and
            ([string]$service.Name).IndexOf($Search, [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
            ([string]$service.DisplayName).IndexOf($Search, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $service
    }
}

function Get-MonitorPage {
    param([object[]]$Services, [int]$Page = 0, [int]$PageSize = 28)
    if ($PageSize -lt 1) { throw 'O tamanho da pagina deve ser positivo.' }
    $items = @($Services)
    $pages = [Math]::Max(1, [int][Math]::Ceiling($items.Count / [double]$PageSize))
    $current = [Math]::Max(0, [Math]::Min($Page, $pages - 1))
    [pscustomobject]@{
        Index = $current
        Count = $pages
        Total = $items.Count
        Items = @($items | Select-Object -Skip ($current * $PageSize) -First $PageSize)
    }
}

function Get-MonitorChanges {
    param([object[]]$Previous, [object[]]$Current)
    $changes = @{}
    if ($null -eq $Previous) { return $changes }
    $states = @{}
    foreach ($service in $Previous) { $states[$service.Name] = $service.State }
    foreach ($service in $Current) {
        if (-not $states.ContainsKey($service.Name) -or $states[$service.Name] -ne $service.State) {
            $changes[$service.Name] = $true
        }
    }
    return $changes
}

function Format-MonitorText {
    param([AllowEmptyString()][string]$Text, [int]$Width)
    if ($Text.Length -le $Width) { return $Text }
    return $Text.Substring(0, $Width - 3) + '...'
}

function Show-MonitorPanel {
    param($Services, $View, $Changes, $Updated, $Filter, $Search, $Interval)
    Clear-Host
    Write-Host ('=' * 116) -ForegroundColor Cyan
    Write-Host ' MONITOR DE SERVICOS DO WINDOWS | SOMENTE AUDITORIA' -ForegroundColor Cyan
    Write-Host ('=' * 116) -ForegroundColor Cyan
    $running = @($Services | Where-Object State -eq 'Running').Count
    $stopped = @($Services | Where-Object State -eq 'Stopped').Count
    $autoStopped = @($Services | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -eq 'Stopped' }).Count
    Write-Host (' Atualizado: {0} | Total: {1} | Executando: {2} | Parados: {3} | Auto parados: {4}' -f $Updated.ToString('dd/MM/yyyy HH:mm:ss'), $Services.Count, $running, $stopped, $autoStopped)
    $refresh = if ($Interval -gt 0) { "a cada $Interval s" } else { 'manual' }
    Write-Host (" Filtro: $Filter | Busca: $Search | Atualizacao: $refresh") -ForegroundColor Gray
    Write-Host ' [N/P] Paginas  [R] Atualizar  [T/E/S/A] Todos/Executando/Parados/Auditoria  [F] Buscar  [U] Auto  [Q] Sair' -ForegroundColor Gray
    Write-Host ' Automatico parado pode ser normal. Auditoria indica uso a confirmar; nao recomenda desativacao.' -ForegroundColor DarkYellow
    Write-Host ('-' * 116)
    $lastColumn = if ($Filter -eq 'Auditoria') { 'USO A CONFIRMAR' } else { 'NOME DE EXIBICAO' }
    Write-Host (' {0,-32} {1,-12} {2,-10} {3}' -f 'SERVICO', 'STATUS', 'INICIO', $lastColumn)
    foreach ($service in $View.Items) {
        $reason = Get-MonitorAuditReason $service.Name
        $color = if ($Changes.ContainsKey($service.Name)) { 'Magenta' }
                 elseif ($reason) { 'Yellow' }
                 elseif ($service.State -eq 'Running') { 'Green' }
                 else { 'DarkGray' }
        $detail = if ($Filter -eq 'Auditoria') { $reason } else { [string]$service.DisplayName }
        Write-Host (' {0,-32} {1,-12} {2,-10} {3}' -f (Format-MonitorText $service.Name 32), $service.State, $service.StartMode, (Format-MonitorText $detail 54)) -ForegroundColor $color
    }
    if ($View.Total -eq 0) { Write-Host ' Nenhum servico encontrado para este filtro.' -ForegroundColor Gray }
    Write-Host ('-' * 116)
    Write-Host (' Pagina {0}/{1} | {2} resultados | {3} alteracoes desde a ultima consulta' -f ($View.Index + 1), $View.Count, $View.Total, $Changes.Count) -ForegroundColor Cyan
    Write-Host ' Verde: executando | Amarelo: uso a confirmar | Magenta: estado alterado' -ForegroundColor Gray
}

function Start-ServiceMonitor {
    if ($NaoInterativo -or [Console]::IsInputRedirected) {
        Get-MonitorSnapshot | Format-Table Name, State, StartMode, DisplayName -AutoSize
        return
    }
    $Host.UI.RawUI.WindowTitle = 'Monitor de Servicos do Windows - Auditoria'
    $services = @(Get-MonitorSnapshot)
    $updated = Get-Date
    $changes = @{}
    $filter = 'Todos'
    $search = ''
    $page = 0
    $interval = $IntervaloSegundos
    while ($true) {
        $pageSize = $ItensPorPagina
        try { $pageSize = [Math]::Max(5, [Math]::Min($ItensPorPagina, [Console]::WindowHeight - 12)) } catch {}
        $filtered = @(Get-MonitorFilteredServices $services $filter $search)
        $view = Get-MonitorPage $filtered $page $pageSize
        $page = $view.Index
        Show-MonitorPanel $services $view $changes $updated $filter $search $interval
        $refresh = $false
        while (-not [Console]::KeyAvailable) {
            if ($interval -gt 0 -and ((Get-Date) - $updated).TotalSeconds -ge $interval) {
                $refresh = $true
                break
            }
            Start-Sleep -Milliseconds 100
        }
        if (-not $refresh) {
            $key = [Console]::ReadKey($true).Key.ToString()
            switch ($key) {
                'Q' { return }
                'N' { $page++ }
                'RightArrow' { $page++ }
                'PageDown' { $page++ }
                'P' { $page-- }
                'LeftArrow' { $page-- }
                'PageUp' { $page-- }
                'R' { $refresh = $true }
                'T' { $filter = 'Todos'; $page = 0 }
                'E' { $filter = 'Executando'; $page = 0 }
                'S' { $filter = 'Parados'; $page = 0 }
                'A' { $filter = 'Auditoria'; $page = 0 }
                'F' { $search = Read-Host ' Nome ou parte do nome (Enter limpa a busca)'; $page = 0 }
                'U' { if ($interval -gt 0) { $interval = 0 } else { $interval = 30 } }
            }
        }
        if ($refresh) {
            try {
                Write-Progress -Activity 'Consultando servicos' -Status 'Leitura do sistema' -PercentComplete 30
                $next = @(Get-MonitorSnapshot)
                $changes = Get-MonitorChanges $services $next
                $services = $next
                $updated = Get-Date
            } finally {
                Write-Progress -Activity 'Consultando servicos' -Completed
            }
        }
    }
}

if (-not $SomenteFuncoes) {
    try { Start-ServiceMonitor }
    catch {
        Write-Host ('Erro ao consultar servicos: ' + $_.Exception.Message) -ForegroundColor Red
        if (-not [Console]::IsInputRedirected) { [void](Read-Host 'Pressione Enter para encerrar') }
        exit 1
    }
}
