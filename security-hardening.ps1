# Script para reforçar a segurança do servidor Minecraft

# Configurações globais
$kubeNamespace = "minecraft-server-ns"
$kubePod = "minecraft-server-0"
$kubeContainer = "minecraft-server-container"
$serverDataPath = "/data"

# Caminhos de arquivos importantes
$whitelistFile = "$serverDataPath/whitelist.json"
$opsFile = "$serverDataPath/ops.json"
$serverPropertiesFile = "$serverDataPath/server.properties"
$bannedPlayersFile = "$serverDataPath/banned-players.json"
$bannedIpsFile = "$serverDataPath/banned-ips.json"
$logsDir = "$serverDataPath/logs"

function Test-KubernetesPod {
    try {
        $podStatus = kubectl get pod $kubePod -n $kubeNamespace -o jsonpath="{.status.phase}" 2>&1
        return ($podStatus -eq "Running")
    }
    catch {
        Write-Host "Erro ao verificar o pod: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-SecurityMenu {
    Clear-Host
    Write-Host "===== Minecraft Security Hardening =====" -ForegroundColor Cyan
    Write-Host "1. Gerenciar whitelist" -ForegroundColor White
    Write-Host "2. Verificar e reforçar configuração de OPs" -ForegroundColor White
    Write-Host "3. Configurar proteção anti-griefing" -ForegroundColor White
    Write-Host "4. Verificar logs de segurança" -ForegroundColor White
    Write-Host "5. Configurar plugin EasyAuth" -ForegroundColor White
    Write-Host "6. Atualizar server.properties" -ForegroundColor White
    Write-Host "7. Gerenciar banimentos (players/IPs)" -ForegroundColor White
    Write-Host "8. Verificar mods/plugins instalados" -ForegroundColor White 
    Write-Host "9. Testar vulnerabilidades comuns" -ForegroundColor White
    Write-Host "0. Sair" -ForegroundColor White
    Write-Host "=======================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" { Manage-Whitelist }
        "2" { Verify-OPs }
        "3" { Configure-AntiGriefing }
        "4" { Check-SecurityLogs }
        "5" { Configure-EasyAuth }
        "6" { Update-ServerProperties }
        "7" { Manage-Bans }
        "8" { Verify-Plugins }
        "9" { Test-CommonVulnerabilities }
        "0" { return }
        default { 
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-SecurityMenu
        }
    }
}

function Manage-Whitelist {
    Clear-Host
    Write-Host "===== Gerenciamento de Whitelist =====" -ForegroundColor Cyan
    
    if (-not (Test-KubernetesPod)) {
        Write-Host "O pod do servidor não está disponível" -ForegroundColor Red
        Pause
        Show-SecurityMenu
        return
    }
    
    Write-Host "Opções de whitelist:" -ForegroundColor Yellow
    Write-Host "1. Listar jogadores na whitelist" -ForegroundColor White
    Write-Host "2. Adicionar jogador à whitelist" -ForegroundColor White
    Write-Host "3. Remover jogador da whitelist" -ForegroundColor White
    Write-Host "4. Verificar configuração de whitelist" -ForegroundColor White
    Write-Host "5. Habilitar/reforçar whitelist" -ForegroundColor White
    Write-Host "0. Voltar" -ForegroundColor White
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" {
            Write-Host "Listando jogadores na whitelist..." -ForegroundColor Yellow
            $whitelist = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "cat $whitelistFile 2>/dev/null || echo '[]'"
            Write-Host $whitelist -ForegroundColor Green
            Pause
            Manage-Whitelist
        }
        "2" {
            $playerName = Read-Host "Digite o nome do jogador para adicionar à whitelist"
            if ($playerName) {
                $rconCommand = "whitelist add $playerName"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- rcon-cli "$rconCommand"
                Write-Host $result -ForegroundColor Green
            }
            Pause
            Manage-Whitelist
        }
        "3" {
            $playerName = Read-Host "Digite o nome do jogador para remover da whitelist"
            if ($playerName) {
                $rconCommand = "whitelist remove $playerName"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- rcon-cli "$rconCommand"
                Write-Host $result -ForegroundColor Green
            }
            Pause
            Manage-Whitelist
        }
        "4" {
            Write-Host "Verificando configuração de whitelist..." -ForegroundColor Yellow
            $serverProps = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "grep -E 'white-?list|enforce' $serverPropertiesFile 2>/dev/null || echo 'Arquivo não encontrado'"
            Write-Host $serverProps -ForegroundColor Green
            Pause
            Manage-Whitelist
        }
        "5" {
            Write-Host "Habilitando e reforçando whitelist..." -ForegroundColor Yellow
            $commands = @(
                "rcon-cli 'whitelist on'",
                "sed -i 's/white-list=.*/white-list=true/' $serverPropertiesFile 2>/dev/null || echo 'Falha ao atualizar white-list'",
                "sed -i 's/enforce-whitelist=.*/enforce-whitelist=true/' $serverPropertiesFile 2>/dev/null || echo 'Falha ao atualizar enforce-whitelist'"
            )
            
            foreach ($cmd in $commands) {
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $cmd
                Write-Host $result -ForegroundColor Green
            }
            
            Write-Host "Whitelist habilitada e reforçada!" -ForegroundColor Green
            Pause
            Manage-Whitelist
        }
        "0" { Show-SecurityMenu }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Manage-Whitelist
        }
    }
}

function Verify-OPs {
    Clear-Host
    Write-Host "===== Verificação de OPs (Operadores) =====" -ForegroundColor Cyan
    
    if (-not (Test-KubernetesPod)) {
        Write-Host "O pod do servidor não está disponível" -ForegroundColor Red
        Pause
        Show-SecurityMenu
        return
    }
    
    Write-Host "Listando operadores atuais:" -ForegroundColor Yellow
    $ops = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "cat $opsFile 2>/dev/null || echo '[]'"
    Write-Host $ops -ForegroundColor Green
    
    Write-Host "`nOpções para gerenciamento de OPs:" -ForegroundColor Yellow
    Write-Host "1. Remover todos os operadores (resetar)" -ForegroundColor White
    Write-Host "2. Adicionar operador (com nível especificado)" -ForegroundColor White
    Write-Host "3. Remover operador específico" -ForegroundColor White
    Write-Host "4. Definir permissões de operador (server.properties)" -ForegroundColor White
    Write-Host "0. Voltar" -ForegroundColor White
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" {
            $confirmation = Read-Host "ATENÇÃO! Isso removerá TODOS os operadores. Digite 'CONFIRMAR' para prosseguir"
            if ($confirmation -eq "CONFIRMAR") {
                Write-Host "Removendo todos os operadores..." -ForegroundColor Yellow
                $emptyOps = "[]"
                kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "echo '$emptyOps' > $opsFile"
                Write-Host "Todos os operadores foram removidos!" -ForegroundColor Green
            } else {
                Write-Host "Operação cancelada" -ForegroundColor Yellow
            }
            Pause
            Verify-OPs
        }
        "2" {
            $playerName = Read-Host "Digite o nome do jogador para adicionar como operador"
            $opLevel = Read-Host "Digite o nível de permissão (1-4, recomendado: 4 para admin completo)"
            
            if ($playerName -and $opLevel) {
                $rconCommand = "op $playerName $opLevel"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- rcon-cli "$rconCommand"
                Write-Host $result -ForegroundColor Green
            }
            Pause
            Verify-OPs
        }
        "3" {
            $playerName = Read-Host "Digite o nome do jogador para remover do status de operador"
            if ($playerName) {
                $rconCommand = "deop $playerName"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- rcon-cli "$rconCommand"
                Write-Host $result -ForegroundColor Green
            }
            Pause
            Verify-OPs
        }
        "4" {
            $opLevel = Read-Host "Digite o nível de permissão padrão para operadores (1-4, recomendado: 4)"
            if ($opLevel -ge 1 -and $opLevel -le 4) {
                $updateCmd = "sed -i 's/op-permission-level=.*/op-permission-level=$opLevel/' $serverPropertiesFile"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $updateCmd
                Write-Host "Nível de permissão de operador definido para $opLevel" -ForegroundColor Green
            } else {
                Write-Host "Nível de permissão inválido. Use um valor entre 1 e 4." -ForegroundColor Red
            }
            Pause
            Verify-OPs
        }
        "0" { Show-SecurityMenu }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Verify-OPs
        }
    }
}

function Configure-AntiGriefing {
    Clear-Host
    Write-Host "===== Configuração Anti-Griefing =====" -ForegroundColor Cyan
    
    Write-Host "Opções anti-griefing:" -ForegroundColor Yellow
    Write-Host "1. Aumentar proteção de spawn" -ForegroundColor White
    Write-Host "2. Verificar/Instalar plugins de proteção" -ForegroundColor White
    Write-Host "3. Configurar regiões protegidas (WorldGuard)" -ForegroundColor White
    Write-Host "4. Configurar logs de interações (CoreProtect)" -ForegroundColor White
    Write-Host "5. Verificar plugins de rollback de griefing" -ForegroundColor White
    Write-Host "0. Voltar" -ForegroundColor White
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" {
            $spawnProtection = Read-Host "Digite o raio de proteção do spawn (16-64, recomendado: 32)"
            if ([int]$spawnProtection -ge 16) {
                Write-Host "Configurando proteção de spawn para $spawnProtection blocos..." -ForegroundColor Yellow
                $updateCmd = "sed -i 's/spawn-protection=.*/spawn-protection=$spawnProtection/' $serverPropertiesFile"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $updateCmd
                Write-Host "Proteção de spawn atualizada com sucesso!" -ForegroundColor Green
            }
            Pause
            Configure-AntiGriefing
        }
        "2" {
            # Aqui adicionaríamos código para verificar plugins recomendados como:
            # - CoreProtect
            # - WorldGuard
            # - GriefPrevention
            # - LWC (proteção de baús)
            Write-Host "Plugins de proteção recomendados:" -ForegroundColor Yellow
            Write-Host "- CoreProtect: Registra todas as interações para reversão" -ForegroundColor Cyan
            Write-Host "- WorldGuard: Permite definir regiões protegidas" -ForegroundColor Cyan
            Write-Host "- GriefPrevention: Sistema automático de claims para jogadores" -ForegroundColor Cyan
            Write-Host "- LockSecurity: Proteção de baús e blocos" -ForegroundColor Cyan
            
            Write-Host "`nPor favor use o gerenciador de plugins para instalar estes plugins" -ForegroundColor Green
            Pause
            Configure-AntiGriefing
        }
        "3" {
            # Aqui adicionaríamos configuração de WorldGuard
            Write-Host "Para configurar WorldGuard, use os seguintes comandos in-game:" -ForegroundColor Yellow
            Write-Host "/rg define area_protegida" -ForegroundColor Cyan
            Write-Host "/rg flag area_protegida build deny" -ForegroundColor Cyan
            Write-Host "/rg flag area_protegida block-break deny" -ForegroundColor Cyan
            Write-Host "/rg flag area_protegida block-place deny" -ForegroundColor Cyan
            Pause
            Configure-AntiGriefing
        }
        "4" {
            Write-Host "Para configurar CoreProtect, use os seguintes comandos in-game:" -ForegroundColor Yellow
            Write-Host "/co i - Ativar modo de inspeção" -ForegroundColor Cyan
            Write-Host "/co rollback t:24h r:100 u:username - Reverter griefing" -ForegroundColor Cyan
            Pause
            Configure-AntiGriefing
        }
        "5" {
            # Verificação de plugins de rollback
            Write-Host "Verificando plugins de rollback instalados..." -ForegroundColor Yellow
            $pluginsCmd = "ls -la $serverDataPath/plugins/ | grep -E 'CoreProtect|LogBlock|Prism'"
            $plugins = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $pluginsCmd
            Write-Host $plugins -ForegroundColor Green
            Pause
            Configure-AntiGriefing
        }
        "0" { Show-SecurityMenu }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Configure-AntiGriefing
        }
    }
}

function Check-SecurityLogs {
    Clear-Host
    Write-Host "===== Análise de Logs de Segurança =====" -ForegroundColor Cyan
    
    Write-Host "Opções de logs:" -ForegroundColor Yellow
    Write-Host "1. Verificar tentativas de login (últimas 50 linhas)" -ForegroundColor White
    Write-Host "2. Verificar comandos de operador (últimas 50 linhas)" -ForegroundColor White
    Write-Host "3. Verificar atividades suspeitas" -ForegroundColor White
    Write-Host "4. Exportar logs para análise local" -ForegroundColor White
    Write-Host "0. Voltar" -ForegroundColor White
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" {
            Write-Host "Verificando tentativas de login..." -ForegroundColor Yellow
            $logCmd = "grep -i 'logged in with entity' $logsDir/latest.log | tail -50"
            $loginLogs = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $logCmd
            Write-Host $loginLogs -ForegroundColor Green
            Pause
            Check-SecurityLogs
        }
        "2" {
            Write-Host "Verificando comandos de operador..." -ForegroundColor Yellow
            $opCmd = "grep -i 'issued server command' $logsDir/latest.log | tail -50"
            $opLogs = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $opCmd
            Write-Host $opLogs -ForegroundColor Green
            Pause
            Check-SecurityLogs
        }
        "3" {
            Write-Host "Verificando atividades suspeitas..." -ForegroundColor Yellow
            $suspiciousCmd = "grep -i -E 'op|permission|level|gamemode|give|summon' $logsDir/latest.log | tail -50"
            $suspiciousLogs = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $suspiciousCmd
            Write-Host $suspiciousLogs -ForegroundColor Green
            Pause
            Check-SecurityLogs
        }
        "4" {
            $localPath = Read-Host "Digite o caminho local para salvar os logs (ex: C:\logs)"
            if (-not (Test-Path -Path $localPath)) {
                New-Item -ItemType Directory -Path $localPath | Out-Null
            }
            
            Write-Host "Exportando logs para análise local..." -ForegroundColor Yellow
            # Fix the variable syntax by adding curly braces around $kubePod
            $podPath = "$kubeNamespace/${kubePod}:$logsDir/latest.log"
            $localLogPath = "$localPath\minecraft-latest.log"
            kubectl cp $podPath $localLogPath
            
            Write-Host "Logs exportados para: $localLogPath" -ForegroundColor Green
            Pause
            Check-SecurityLogs
        }
        "0" { Show-SecurityMenu }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Check-SecurityLogs
        }
    }
}

function Configure-EasyAuth {
    Clear-Host
    Write-Host "===== Configuração do EasyAuth =====" -ForegroundColor Cyan
    
    Write-Host "Verificando se o EasyAuth está instalado..." -ForegroundColor Yellow
    $easyAuthCheck = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "ls -la $serverDataPath/plugins/EasyAuth* 2>/dev/null || echo 'Não encontrado'"
    
    if ($easyAuthCheck -like "*Não encontrado*") {
        Write-Host "EasyAuth não parece estar instalado!" -ForegroundColor Red
        Write-Host "Por favor, instale o plugin EasyAuth manualmente e tente novamente." -ForegroundColor Yellow
        Pause
        Show-SecurityMenu
        return
    }
    
    Write-Host "EasyAuth detectado. Opções de configuração:" -ForegroundColor Green
    Write-Host "1. Verificar configuração atual" -ForegroundColor White
    Write-Host "2. Habilitar autenticação obrigatória" -ForegroundColor White
    Write-Host "3. Configurar tempo de sessão" -ForegroundColor White
    Write-Host "4. Definir limite de tentativas de login" -ForegroundColor White
    Write-Host "0. Voltar" -ForegroundColor White
    
    $choice = Read-Host "Digite sua escolha"
    
    switch ($choice) {
        "1" {
            Write-Host "Verificando configuração atual do EasyAuth..." -ForegroundColor Yellow
            $configCmd = "cat $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null || echo 'Arquivo de configuração não encontrado'"
            $config = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $configCmd
            Write-Host $config -ForegroundColor Green
            Pause
            Configure-EasyAuth
        }
        "2" {
            Write-Host "Habilitando autenticação obrigatória..." -ForegroundColor Yellow
            $updateCmd = @"
sed -i 's/forceLogin:.*/forceLogin: true/' $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null;
sed -i 's/allowMovement:.*/allowMovement: false/' $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null;
sed -i 's/allowCommands:.*/allowCommands: false/' $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null;
echo "Configuração atualizada"
"@
            $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $updateCmd
            Write-Host $result -ForegroundColor Green
            Pause
            Configure-EasyAuth
        }
        "3" {
            $sessionTime = Read-Host "Digite o tempo de sessão em minutos (0-1440, recomendado: 60)"
            if ([int]$sessionTime -ge 0 -and [int]$sessionTime -le 1440) {
                Write-Host "Configurando tempo de sessão para $sessionTime minutos..." -ForegroundColor Yellow
                $updateCmd = "sed -i 's/sessionTime:.*/sessionTime: $sessionTime/' $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $updateCmd
                Write-Host "Tempo de sessão atualizado!" -ForegroundColor Green
            }
            Pause
            Configure-EasyAuth
        }
        "4" {
            $maxTries = Read-Host "Digite o limite de tentativas de login (1-10, recomendado: 3)"
            if ([int]$maxTries -ge 1 -and [int]$maxTries -le 10) {
                Write-Host "Configurando limite de tentativas para $maxTries..." -ForegroundColor Yellow
                $updateCmd = "sed -i 's/maxTries:.*/maxTries: $maxTries/' $serverDataPath/plugins/EasyAuth/config.yml 2>/dev/null"
                $result = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $updateCmd
                Write-Host "Limite de tentativas atualizado!" -ForegroundColor Green
            }
            Pause
            Configure-EasyAuth
        }
        "0" { Show-SecurityMenu }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Configure-EasyAuth
        }
    }
}

function Test-CommonVulnerabilities {
    Clear-Host
    Write-Host "===== Teste de Vulnerabilidades Comuns =====" -ForegroundColor Cyan
    
    if (-not (Test-KubernetesPod)) {
        Write-Host "O pod do servidor não está disponível" -ForegroundColor Red
        Pause
        Show-SecurityMenu
        return
    }
    
    Write-Host "Iniciando verificações de segurança..." -ForegroundColor Yellow
    Write-Host "Este processo pode levar alguns minutos." -ForegroundColor Yellow
    Write-Host ""
    
    # 1. Verificar configurações críticas de segurança
    Write-Host "1. Verificando configurações críticas..." -ForegroundColor Cyan
    $securityProps = @(
        "online-mode",
        "white-list",
        "enforce-whitelist",
        "spawn-protection",
        "enable-command-block",
        "op-permission-level",
        "enable-query",
        "enable-rcon",
        "prevent-proxy-connections"
    )
    
    $propsCmd = "grep -E '$(($securityProps -join "|"))' $serverPropertiesFile 2>/dev/null || echo 'FALHA'"
    $propSettings = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $propsCmd
    
    if ($propSettings -eq "FALHA") {
        Write-Host "  [ERRO] Não foi possível verificar as configurações do servidor." -ForegroundColor Red
    } else {
        # Verificar configurações críticas
        Write-Host "  Configurações encontradas:" -ForegroundColor Yellow
        Write-Host $propSettings -ForegroundColor Gray
        
        # Analisar configurações e emitir alertas
        if ($propSettings -match "online-mode=false") {
            Write-Host "  [ALERTA] Servidor está em modo offline. Isso possibilita jogadores com nomes falsificados." -ForegroundColor Red
            Write-Host "     → Recomendação: Utilizar plugins de autenticação como EasyAuth." -ForegroundColor Yellow
        }
        
        if ($propSettings -notmatch "white-list=true") {
            Write-Host "  [ALERTA] Whitelist não está ativada. Qualquer pessoa pode entrar no servidor." -ForegroundColor Red
            Write-Host "     → Recomendação: Habilite a whitelist com 'whitelist on'" -ForegroundColor Yellow
        }
        
        if ($propSettings -notmatch "enforce-whitelist=true") {
            Write-Host "  [ALERTA] enforce-whitelist não está ativado. Jogadores podem entrar durante reinicialização." -ForegroundColor Red
            Write-Host "     → Recomendação: Configure enforce-whitelist=true" -ForegroundColor Yellow
        }
        
        if ($propSettings -match "spawn-protection=(0|[1-9]|1[0-5])") {
            Write-Host "  [ALERTA] Proteção de spawn baixa ou desativada. Spawn vulnerável a griefing." -ForegroundColor Red
            Write-Host "     → Recomendação: Aumente para pelo menos 16 blocos." -ForegroundColor Yellow
        }
        
        if ($propSettings -match "enable-command-block=true") {
            Write-Host "  [ALERTA] Blocos de comando estão habilitados. Podem ser usados para exploits." -ForegroundColor Red
            Write-Host "     → Recomendação: Desative se não for necessário." -ForegroundColor Yellow
        }
        
        if ($propSettings -match "enable-query=true") {
            Write-Host "  [ALERTA] Query está habilitado. Pode vazar informações sobre o servidor." -ForegroundColor Red
            Write-Host "     → Recomendação: Desative se não for necessário." -ForegroundColor Yellow
        }
        
        if ($propSettings -match "enable-rcon=true") {
            Write-Host "  [ALERTA] RCON está habilitado. Garanta que a senha é forte e a porta protegida." -ForegroundColor Red
            
            # Verificar senha do RCON
            if ($propSettings -match "rcon.password=(minecraft|admin|server|password|123|minecraft_secure_password)") {
                Write-Host "  [CRÍTICO] Senha de RCON é fraca ou padrão!" -ForegroundColor Red
                Write-Host "     → Recomendação: Defina uma senha forte e única." -ForegroundColor Yellow
            }
        }
        
        if ($propSettings -match "prevent-proxy-connections=false") {
            Write-Host "  [ALERTA] Conexões via proxy estão permitidas. Facilita ataques e evasão de banimentos." -ForegroundColor Red
            Write-Host "     → Recomendação: Configure prevent-proxy-connections=true" -ForegroundColor Yellow
        }
    }
    
    # 2. Verificar permissões de operadores
    Write-Host "`n2. Verificando arquivos de operadores..." -ForegroundColor Cyan
    $opsContent = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c "cat $opsFile 2>/dev/null || echo '[]'"
    
    if ($opsContent -eq "[]") {
        Write-Host "  Nenhum operador encontrado ou arquivo vazio." -ForegroundColor Yellow
    } else {
        try {
            # Tentativa de processar o JSON
            Write-Host "  Operadores encontrados:" -ForegroundColor Yellow
            Write-Host $opsContent -ForegroundColor Gray
            
            # Verificação básica por padrões suspeitos
            if ($opsContent -match '"bypassesPlayerLimit":\s*true') {
                Write-Host "  [ALERTA] Alguns operadores podem contornar o limite de jogadores." -ForegroundColor Red
                Write-Host "     → Recomendação: Revise as permissões." -ForegroundColor Yellow
            }
            
            # Contar número de operadores
            $opCount = ($opsContent.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count
            if ($opCount -gt 2) {
                Write-Host "  [ALERTA] Número elevado de operadores ($opCount) detectado." -ForegroundColor Red
                Write-Host "     → Recomendação: Mantenha apenas operadores confiáveis." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [ERRO] Erro ao processar arquivo de operadores." -ForegroundColor Red
        }
    }
    
    # 3. Verificar plugins de segurança
    Write-Host "`n3. Verificando plugins de segurança..." -ForegroundColor Cyan
    $pluginsCmd = "ls -la $serverDataPath/plugins/ 2>/dev/null || echo 'Nenhum plugin encontrado'"
    $plugins = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $pluginsCmd
    
    # Lista de plugins recomendados para segurança
    $securityPlugins = @(
        "EasyAuth",
        "AuthMe",
        "CoreProtect",
        "WorldGuard",
        "GriefPrevention",
        "LWC",
        "LockSecurity",
        "NoCheatPlus",
        "AntiCheat"
    )
    
    # Verificar plugins de segurança instalados
    $installedSecurityPlugins = @()
    foreach ($plugin in $securityPlugins) {
        if ($plugins -match $plugin) {
            $installedSecurityPlugins += $plugin
        }
    }
    
    if ($installedSecurityPlugins.Count -eq 0) {
        Write-Host "  [ALERTA] Nenhum plugin de segurança conhecido detectado." -ForegroundColor Red
        Write-Host "     → Recomendação: Instale plugins como EasyAuth, CoreProtect e WorldGuard." -ForegroundColor Yellow
    } else {
        Write-Host "  Plugins de segurança encontrados:" -ForegroundColor Green
        foreach ($plugin in $installedSecurityPlugins) {
            Write-Host "  - $plugin" -ForegroundColor Green
        }
        
        # Verificar plugins ausentes importantes
        $missingImportantPlugins = @()
        $criticalPlugins = @("EasyAuth", "AuthMe", "CoreProtect")
        
        foreach ($critPlugin in $criticalPlugins) {
            if ($installedSecurityPlugins -notcontains $critPlugin) {
                $missingImportantPlugins += $critPlugin
            }
        }
        
        if ($missingImportantPlugins.Count -gt 0) {
            Write-Host "  [ALERTA] Plugins críticos de segurança não encontrados:" -ForegroundColor Yellow
            foreach ($missingPlugin in $missingImportantPlugins) {
                Write-Host "  - $missingPlugin" -ForegroundColor Yellow
            }
            Write-Host "     → Recomendação: Instale plugins de autenticação e logging." -ForegroundColor Yellow
        }
    }
    
    # 4. Verificar logs por atividades suspeitas
    Write-Host "`n4. Verificando logs por atividades suspeitas..." -ForegroundColor Cyan
    $suspiciousPatterns = @(
        "grief",
        "hack",
        "exploit",
        "cheat",
        "backdoor",
        "op \w+",
        "permission",
        "gamemode (1|c|creative)",
        "fly",
        "endportal",
        "summon ender_dragon",
        "tellraw",
        "execute"
    )
    
    $grepPattern = ($suspiciousPatterns -join "|")
    $logCheckCmd = "grep -i -E '$grepPattern' $logsDir/latest.log 2>/dev/null | tail -10 || echo 'Nenhuma atividade suspeita encontrada'"
    $suspiciousActivities = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $logCheckCmd
    
    if ($suspiciousActivities -notmatch "Nenhuma atividade suspeita") {
        Write-Host "  [ALERTA] Atividades suspeitas detectadas nos logs:" -ForegroundColor Red
        Write-Host $suspiciousActivities -ForegroundColor Yellow
        Write-Host "     → Recomendação: Investigue essas atividades imediatamente." -ForegroundColor Red
    } else {
        Write-Host "  Nenhuma atividade suspeita detectada nos logs recentes." -ForegroundColor Green
    }
    
    # 5. Verificar portas expostas desnecessariamente
    Write-Host "`n5. Verificando portas expostas..." -ForegroundColor Cyan
    $portsCmd = "kubectl get svc -n $kubeNamespace -o=jsonpath='{range .items[*]}{.metadata.name}{\":\"}{range .spec.ports[*]}{.port}{\" \"}{end}{\"\\n\"}{end}'"
    $exposedPorts = Invoke-Expression $portsCmd 2>$null
    
    if ($exposedPorts) {
        Write-Host "  Portas expostas:" -ForegroundColor Yellow
        Write-Host $exposedPorts -ForegroundColor Gray
        
        # Verificar portas sensíveis expostas
        $sensitivePorts = @(25575, 8123, 27015, 25580)
        foreach ($port in $sensitivePorts) {
            if ($exposedPorts -match $port) {
                Write-Host "  [ALERTA] Porta sensível $port exposta publicamente." -ForegroundColor Red
                Write-Host "     → Recomendação: Restrinja acesso a portas de administração." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  Não foi possível verificar portas expostas." -ForegroundColor Yellow
    }
    
    # 6. Verificar sistema de banimentos
    Write-Host "`n6. Verificando sistema de banimentos..." -ForegroundColor Cyan
    $bannedPlayersCmd = "cat $bannedPlayersFile 2>/dev/null || echo '[]'"
    $bannedIpsCmd = "cat $bannedIpsFile 2>/dev/null || echo '[]'"
    
    $bannedPlayers = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $bannedPlayersCmd
    $bannedIps = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $bannedIpsCmd
    
    if ($bannedPlayers -eq "[]" -and $bannedIps -eq "[]") {
        Write-Host "  [ALERTA] Nenhum jogador ou IP banido encontrado." -ForegroundColor Yellow
        Write-Host "     → Recomendação: Mantenha uma política de banimentos para jogadores problemáticos." -ForegroundColor Yellow
    } else {
        if ($bannedPlayers -ne "[]") {
            Write-Host "  Sistema de banimento de jogadores ativo." -ForegroundColor Green
            
            # Contar jogadores banidos
            $bannedPlayersCount = ($bannedPlayers.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count
            Write-Host "  - $bannedPlayersCount jogadores banidos" -ForegroundColor Green
        }
        
        if ($bannedIps -ne "[]") {
            Write-Host "  Sistema de banimento de IPs ativo." -ForegroundColor Green
            
            # Contar IPs banidos
            $bannedIpsCount = ($bannedIps.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count
            Write-Host "  - $bannedIpsCount IPs banidos" -ForegroundColor Green
        }
    }
    
    # 7. Verificar vulnerabilidades conhecidas na versão do servidor
    Write-Host "`n7. Verificando versão do servidor..." -ForegroundColor Cyan
    $versionCmd = "grep -i 'version=' $serverDataPath/server.properties 2>/dev/null || echo 'Não encontrado'"
    $serverVersion = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $versionCmd
    
    if ($serverVersion -match "Não encontrado") {
        # Tentar determinar a versão de outra forma
        $versionCmd2 = "grep -i 'minecraft server version' $logsDir/latest.log 2>/dev/null | head -1 || echo 'Não encontrado'"
        $serverVersion = kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- bash -c $versionCmd2
    }
    
    if ($serverVersion -match "Não encontrado") {
        Write-Host "  [ALERTA] Não foi possível determinar a versão do servidor." -ForegroundColor Yellow
    } else {
        Write-Host "  Versão do servidor:" -ForegroundColor Yellow
        Write-Host "  $serverVersion" -ForegroundColor Gray
        
        # Verificar se é uma versão antiga
        if ($serverVersion -match "(1\.[0-9]|1\.1[0-6])\b") {
            Write-Host "  [ALERTA] Versão potencialmente desatualizada detectada." -ForegroundColor Red
            Write-Host "     → Recomendação: Atualize para uma versão mais recente para corrigir vulnerabilidades." -ForegroundColor Yellow
        } else {
            Write-Host "  A versão parece ser razoavelmente recente." -ForegroundColor Green
        }
    }
    
    # Relatório final
    Write-Host "`n===== RESUMO DA VERIFICAÇÃO DE SEGURANÇA =====" -ForegroundColor Cyan
    Write-Host "Esta verificação básica não substitui uma auditoria de segurança completa." -ForegroundColor Yellow
    Write-Host "Lembre-se de:" -ForegroundColor Yellow
    Write-Host "1. Manter o servidor e plugins sempre atualizados" -ForegroundColor White
    Write-Host "2. Usar senhas fortes e únicas em todas as configurações" -ForegroundColor White
    Write-Host "3. Implementar autenticação e registros de atividade" -ForegroundColor White
    Write-Host "4. Fazer backups regulares" -ForegroundColor White
    Write-Host "5. Revisar regularmente os logs e lista de operadores" -ForegroundColor White
    Write-Host "6. Limitar privilegios usando o princípio do menor privilégio" -ForegroundColor White
    Write-Host "7. Ativar whitelisting e proteção de regiões" -ForegroundColor White
    
    Pause
    Show-SecurityMenu
}

# Iniciar o menu principal
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "    FERRAMENTA DE SEGURANÇA MINECRAFT" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Verificando conexão com o cluster Kubernetes..." -ForegroundColor Yellow

if (Test-KubernetesPod) {
    Write-Host "Conexão estabelecida com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 1
    Show-SecurityMenu
}
else {
    Write-Host "Falha ao conectar ao cluster Kubernetes." -ForegroundColor Red
    Write-Host "Verifique se o cluster está funcionando e se kubectl está configurado corretamente." -ForegroundColor Yellow
    Pause
}
