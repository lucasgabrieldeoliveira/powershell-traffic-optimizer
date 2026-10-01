# Script PowerShell - Manutenção Periódica do Sistema
# Executa tarefas de manutenção em loop infinito com intervalo configurável

param(
    [int]$IntervaloSegundos = 300,  # Padrão: 5 minutos
    [string]$LogPath = "C:\Logs\manutencao.log"
)

# ========== FUNÇÕES AUXILIARES ==========

function Escrever-Log {
    param(
        [string]$Mensagem,
        [string]$Tipo = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cores = @{
        "Info" = "Green"
        "Erro" = "Red"
        "Aviso" = "Yellow"
        "Debug" = "Cyan"
    }
    
    $logMensagem = "[$timestamp] [$Tipo] $Mensagem"
    Write-Host $logMensagem -ForegroundColor $cores[$Tipo]
    
    # Criar diretório de log se não existir
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
    }
    
    # Adicionar ao arquivo de log
    Add-Content -Path $LogPath -Value $logMensagem
}

function Limpar-ArquivosTemporarios {
    try {
        $tempPath = [System.IO.Path]::GetTempPath()
        $arquivos = Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
        
        $quantidadeRemovida = 0
        foreach ($arquivo in $arquivos) {
            Remove-Item -Path $arquivo.FullName -Force -ErrorAction SilentlyContinue
            $quantidadeRemovida++
        }
        
        Escrever-Log "Limpeza de temporários: $quantidadeRemovida arquivos removidos (com mais de 7 dias)" "Info"
    }
    catch {
        Escrever-Log "Erro ao limpar temporários: $_" "Erro"
    }
}

function Verificar-EspacoEmDisco {
    try {
        $discos = Get-Volume | Where-Object { $_.DriveLetter -ne $null }
        
        Escrever-Log "=== Verificação de Espaço em Disco ===" "Debug"
        
        foreach ($disco in $discos) {
            $percentualUso = [math]::Round(($disco.Size - $disco.SizeRemaining) / $disco.Size * 100, 2)
            $status = if ($percentualUso -gt 90) { "Aviso" } else { "Info" }
            
            Escrever-Log "Disco $($disco.DriveLetter): $percentualUso% uso (Livre: $([math]::Round($disco.SizeRemaining/1GB, 2))GB)" $status
        }
    }
    catch {
        Escrever-Log "Erro ao verificar espaço em disco: $_" "Erro"
    }
}

function Verificar-Servicos-Criticos {
    try {
        $servicosCriticos = @("Spooler", "winlogon", "WinDefend")
        
        Escrever-Log "=== Verificação de Serviços Críticos ===" "Debug"
        
        foreach ($servico in $servicosCriticos) {
            $svc = Get-Service -Name $servico -ErrorAction SilentlyContinue
            
            if ($svc) {
                if ($svc.Status -eq "Running") {
                    Escrever-Log "Serviço $servico: ✓ Executando" "Info"
                }
                else {
                    Escrever-Log "Serviço $servico: ✗ Parado (tentando reiniciar...)" "Aviso"
                    Start-Service -Name $servico -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch {
        Escrever-Log "Erro ao verificar serviços: $_" "Erro"
    }
}

function Monitorar-CPU-Memoria {
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        $memoria = Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue
        
        if ($cpu) {
            $valorCpu = [math]::Round(($cpu.CounterSamples[0].CookedValue), 2)
            $statusCpu = if ($valorCpu -gt 80) { "Aviso" } else { "Info" }
            Escrever-Log "CPU: $valorCpu%" $statusCpu
        }
        
        if ($memoria) {
            $valorMemoria = [math]::Round(($memoria.CounterSamples[0].CookedValue), 2)
            $statusMemoria = if ($valorMemoria -gt 85) { "Aviso" } else { "Info" }
            Escrever-Log "Memória: $valorMemoria%" $statusMemoria
        }
    }
    catch {
        Escrever-Log "Erro ao monitorar CPU/Memória: $_" "Erro"
    }
}

function Limpar-EventLog {
    try {
        $logs = Get-EventLog -List | Select-Object -ExpandProperty Log
        
        foreach ($log in $logs) {
            $tamanho = (Get-EventLog -LogName $log).Count
            if ($tamanho -gt 1000) {
                Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
                Escrever-Log "EventLog '$log' limpo ($tamanho entradas removidas)" "Info"
            }
        }
    }
    catch {
        Escrever-Log "Erro ao limpar EventLog: $_" "Erro"
    }
}

function Gerar-Relatorio-Saude {
    try {
        $relatorio = @"
============================================
RELATÓRIO DE SAÚDE DO SISTEMA
Data/Hora: $(Get-Date)
============================================
Computador: $env:COMPUTERNAME
Usuário: $env:USERNAME
Sistema Operacional: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
Uptime: $((Get-Date) - (Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime))
============================================
"@
        Escrever-Log $relatorio "Debug"
    }
    catch {
        Escrever-Log "Erro ao gerar relatório: $_" "Erro"
    }
}

# ========== LOOP PRINCIPAL ==========

Escrever-Log "=====================================" "Debug"
Escrever-Log "Iniciando Manutenção Periódica do Sistema" "Info"
Escrever-Log "Intervalo: $IntervaloSegundos segundos" "Info"
Escrever-Log "Log: $LogPath" "Info"
Escrever-Log "=====================================" "Debug"

$contador = 0

while ($true) {
    try {
        $contador++
        Escrever-Log "--- Ciclo #$contador iniciado ---" "Debug"
        
        # Executar tarefas de manutenção
        Gerar-Relatorio-Saude
        Monitorar-CPU-Memoria
        Verificar-EspacoEmDisco
        Verificar-Servicos-Criticos
        Limpar-ArquivosTemporarios
        Limpar-EventLog
        
        Escrever-Log "--- Ciclo #$contador concluído ---" "Debug"
        Escrever-Log "Próxima execução em $IntervaloSegundos segundos`n" "Info"
        
        # Aguardar intervalo
        Start-Sleep -Seconds $IntervaloSegundos
    }
    catch {
        Escrever-Log "Erro no loop principal: $_" "Erro"
        Start-Sleep -Seconds 60  # Aguardar 1 minuto antes de tentar novamente
    }
}
