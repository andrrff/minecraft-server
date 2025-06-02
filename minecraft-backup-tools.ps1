# Script PowerShell para gerenciar backups do servidor Minecraft em Kubernetes
# Funções incluídas:
#  - Listar backups disponíveis
#  - Verificar detalhes de um backup específico
#  - Copiar um backup para máquina local
#  - Criar um backup manualmente

$NAMESPACE = "minecraft-server-ns"
$BACKUP_DIR = "/backups"
$LOCAL_BACKUP_DIR = ".\minecraft-backups"
$TEMP_POD_NAME = "backup-explorer"

# Função para encontrar o pod de backup mais recente ou criar um pod temporário
function Get-BackupPod {
    Write-Host "Buscando pods de backup..." -ForegroundColor Cyan
    
    # Verificar se algum job de backup está em execução
    $BACKUP_POD = kubectl get pods -n $NAMESPACE -l job-name -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if (-not $BACKUP_POD) {
        Write-Host "Nenhum pod de backup ativo encontrado." -ForegroundColor Yellow
        
        # Verificar se o pod temporário já existe
        $podExists = kubectl get pod $TEMP_POD_NAME -n $NAMESPACE --no-headers 2>$null
        
        if ($podExists) {
            Write-Host "Pod temporário já existe. Usando o existente." -ForegroundColor Yellow
            $BACKUP_POD = $TEMP_POD_NAME
        }
        else {
            Write-Host "Criando pod temporário..." -ForegroundColor Yellow
            
            # Criar um pod temporário que tenha acesso ao volume de backup
            $overrideJson = @"
{
    "spec": {
        "volumes": [
            {
                "name": "backup-storage",
                "persistentVolumeClaim": {
                    "claimName": "minecraft-backup-storage"
                }
            }
        ],
        "containers": [
            {
                "name": "backup-explorer",
                "image": "bitnami/minideb:latest",
                "command": ["sleep", "3600"],
                "volumeMounts": [
                    {
                        "name": "backup-storage",
                        "mountPath": "/backups"
                    }
                ]
            }
        ]
    }
}
"@
            
            kubectl run $TEMP_POD_NAME --image=bitnami/minideb:latest --restart=Never -n $NAMESPACE --overrides=$overrideJson
            
            # Esperar até que o pod esteja pronto
            Write-Host "Aguardando pod temporário iniciar..." -ForegroundColor Cyan
            Start-Sleep -Seconds 5  # Espera inicial para o pod ser criado
            
            $podReady = $false
            $attempts = 0
            $maxAttempts = 12  # 60 segundos (12 x 5)
            
            while (-not $podReady -and $attempts -lt $maxAttempts) {
                $status = kubectl get pod $TEMP_POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>$null
                
                if ($status -eq "Running") {
                    $podReady = $true
                }
                else {
                    $attempts++ 
                    Write-Host "Aguardando pod ficar pronto... ($attempts/$maxAttempts)" -ForegroundColor Cyan
                    Start-Sleep -Seconds 5
                }
            }
            
            if (-not $podReady) {
                Write-Host "Tempo limite excedido ao aguardar o pod ficar pronto." -ForegroundColor Red
                return $null
            }
            
            $BACKUP_POD = $TEMP_POD_NAME
        }
    }
    
    Write-Host "Usando pod: $BACKUP_POD" -ForegroundColor Green
    Write-Host ""
    
    return $BACKUP_POD
}

# Função para limpar o pod temporário
function Remove-TempPod {
    param (
        [string]$podName
    )
    
    if ($podName -eq $TEMP_POD_NAME) {
        Write-Host "Removendo pod temporário..." -ForegroundColor Cyan
        kubectl delete pod $podName -n $NAMESPACE | Out-Null
        if ($?) {
            Write-Host "Pod temporário removido com sucesso." -ForegroundColor Green
        }
        else {
            Write-Host "Falha ao remover o pod temporário." -ForegroundColor Red
        }
    }
}

# Função para listar os backups disponíveis
function List-Backups {
    $BACKUP_POD = Get-BackupPod
    
    if (-not $BACKUP_POD) {
        Write-Host "Não foi possível obter um pod para listar backups." -ForegroundColor Red
        return
    }
    
    Write-Host "Listando backups disponíveis:" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    
    $backupList = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c "ls -lh $BACKUP_DIR | grep minecraft-backup" 2>$null
    if ($?) {
        if ($backupList) {
            Write-Host $backupList
        }
        else {
            Write-Host "Nenhum backup encontrado." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Erro ao listar backups." -ForegroundColor Red
    }
    
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host "Total de espaço utilizado pelos backups:" -ForegroundColor Green
    $diskUsage = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c "du -sh $BACKUP_DIR" 2>$null
    if ($?) {
        Write-Host $diskUsage
    }
    else {
        Write-Host "Erro ao verificar espaço em disco." -ForegroundColor Red
    }
    
    # Limpar pod temporário se foi criado agora
    Remove-TempPod -podName $BACKUP_POD
}

# Função para verificar detalhes de um backup específico
function Show-BackupDetails {
    param (
        [string]$BackupFile
    )
    
    if (-not $BackupFile) {
        Write-Host "Por favor, especifique o nome do arquivo de backup." -ForegroundColor Yellow
        Write-Host "Exemplo: $($MyInvocation.MyCommand.Name) show minecraft-backup-20230615-120000.tar.gz"
        return
    }
    
    $BACKUP_POD = Get-BackupPod
    
    if (-not $BACKUP_POD) {
        Write-Host "Não foi possível obter um pod para verificar detalhes do backup." -ForegroundColor Red
        return
    }
    
    Write-Host "Detalhes do backup: $BackupFile" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    
    # Verificar se o arquivo existe
    $fileCheckCmd = "if [ -f '$BACKUP_DIR/$BackupFile' ]; then echo 'true'; else echo 'false'; fi"
    $FILE_EXISTS = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c $fileCheckCmd 2>$null
    
    if (-not $FILE_EXISTS) {
        Write-Host "Erro ao verificar se o arquivo existe. O pod pode não estar respondendo." -ForegroundColor Red
        Remove-TempPod -podName $BACKUP_POD
        return
    }
    
    if ($FILE_EXISTS.Trim() -ne "true") {
        Write-Host "Arquivo de backup não encontrado: $BackupFile" -ForegroundColor Yellow
        Write-Host "Use o comando 'list' para ver os backups disponíveis."
        
        # Limpar pod temporário
        Remove-TempPod -podName $BACKUP_POD
        return
    }
    
    # Mostrar informações detalhadas sobre o backup
    $fileInfo = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c "ls -lh $BACKUP_DIR/$BackupFile" 2>$null
    if ($?) {
        Write-Host $fileInfo
    }
    else {
        Write-Host "Erro ao obter informações do arquivo." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Conteúdo do arquivo (listagem dos primeiros 10 itens):" -ForegroundColor Cyan
    $fileContents = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c "tar -tvf $BACKUP_DIR/$BackupFile | head -10" 2>$null
    if ($?) {
        Write-Host $fileContents
        Write-Host "... (mais arquivos não mostrados)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Erro ao listar conteúdo do arquivo." -ForegroundColor Red
    }
    
    # Limpar pod temporário
    Remove-TempPod -podName $BACKUP_POD
}

# Função para copiar um backup para a máquina local
function Copy-BackupFile {
    param (
        [string]$BackupFile
    )
    
    if (-not $BackupFile) {
        Write-Host "Por favor, especifique o nome do arquivo de backup." -ForegroundColor Yellow
        Write-Host "Exemplo: $($MyInvocation.MyCommand.Name) copy minecraft-backup-20230615-120000.tar.gz"
        return
    }
    
    $BACKUP_POD = Get-BackupPod
    
    if (-not $BACKUP_POD) {
        Write-Host "Não foi possível obter um pod para copiar o backup." -ForegroundColor Red
        return
    }
    
    # Verificar se o arquivo existe
    $fileCheckCmd = "if [ -f '$BACKUP_DIR/$BackupFile' ]; then echo 'true'; else echo 'false'; fi"
    $FILE_EXISTS = kubectl exec -n $NAMESPACE $BACKUP_POD -- bash -c $fileCheckCmd 2>$null
    
    if (-not $FILE_EXISTS) {
        Write-Host "Erro ao verificar se o arquivo existe. O pod pode não estar respondendo." -ForegroundColor Red
        Remove-TempPod -podName $BACKUP_POD
        return
    }
    
    if ($FILE_EXISTS.Trim() -ne "true") {
        Write-Host "Arquivo de backup não encontrado: $BackupFile" -ForegroundColor Yellow
        Write-Host "Use o comando 'list' para ver os backups disponíveis."
        
        # Limpar pod temporário
        Remove-TempPod -podName $BACKUP_POD
        return
    }
    
    # Criar diretório local se não existir
    if (-not (Test-Path -Path $LOCAL_BACKUP_DIR)) {
        New-Item -ItemType Directory -Path $LOCAL_BACKUP_DIR | Out-Null
    }
    
    Write-Host "Copiando backup para máquina local..." -ForegroundColor Cyan
    Write-Host "Isso pode levar algum tempo dependendo do tamanho do backup." -ForegroundColor Yellow
    
    # Copiar o backup para a máquina local
    $srcPath = "$NAMESPACE/$BACKUP_POD`:$BACKUP_DIR/$BackupFile"
    $destPath = "$LOCAL_BACKUP_DIR\$BackupFile"
    
    kubectl cp $srcPath $destPath 2>$null
    
    if ($?) {
        Write-Host "Backup copiado com sucesso para: $destPath" -ForegroundColor Green
    }
    else {
        Write-Host "Falha ao copiar o backup." -ForegroundColor Red
    }
    
    # Limpar pod temporário
    Remove-TempPod -podName $BACKUP_POD
}

# Função para criar um backup manualmente
function Create-Backup {
    Write-Host "Iniciando criação de backup manual..." -ForegroundColor Cyan
    
    # Gerar timestamp para o nome do job e do arquivo de backup
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupJobName = "minecraft-manual-backup-$timestamp"
    $backupFileName = "minecraft-backup-$timestamp.tar.gz"
    $configMapName = "backup-script-$timestamp"
    
    # Criar um job de backup temporário
    Write-Host "Criando job de backup..." -ForegroundColor Yellow
    
    # 1. Criar o ConfigMap com o script de backup - versão com melhor tratamento de arquivos
    $backupScript = @'
#!/bin/bash
set -e
echo "Iniciando backup manual em $(date)..."
BACKUP_FILE="/backups/FILENAME_PLACEHOLDER"
SOURCE_DIR="/minecraft-data"
echo "Preparando backup..."

# Mudar para o diretório de origem
cd "$SOURCE_DIR"

# Método mais simples e direto - backupear tudo de uma vez
echo "Criando arquivo de backup..."
tar -cf "$BACKUP_FILE" --exclude="./sys" --exclude="./proc" --exclude="./dev" \
    --exclude="./run" --exclude="./tmp" --exclude="./lost+found" \
    --exclude="*.log" --exclude="*.gz" --exclude="*.zip" \
    --warning=no-file-changed .

# Verificar resultado
RESULT=$?
if [ $RESULT -eq 0 ] || [ $RESULT -eq 1 ]; then
  # tar retorna 1 quando alguns arquivos foram alterados durante o processo
  # o que é normal para um servidor em execução
  echo "Backup concluído com sucesso: $BACKUP_FILE"
  ls -lh "$BACKUP_FILE"
  exit 0
else
  echo "Falha ao criar backup! Código de erro: $RESULT"
  exit 1
fi
'@

    # Substituir o placeholder pelo nome real do arquivo
    $backupScript = $backupScript.Replace("FILENAME_PLACEHOLDER", $backupFileName)
    
    $configMapYaml = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configMapName
  namespace: $NAMESPACE
data:
  backup.sh: |
$(($backupScript -split "`n" | ForEach-Object { "    $_" }) -join "`n")
"@
    
    # Salvar o ConfigMap YAML em um arquivo temporário e aplicá-lo
    $configMapFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $configMapFile -Value $configMapYaml -Encoding utf8
    
    try {
        $configMapResult = kubectl apply -f $configMapFile 2>&1
        if (-not $?) {
            Write-Host "Falha ao criar o ConfigMap para o script de backup:" -ForegroundColor Red
            Write-Host $configMapResult -ForegroundColor Red
            Remove-Item $configMapFile -Force
            return
        }
        
        # 2. Criar o Job que usa o ConfigMap
        $backupJobYaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: $backupJobName
  namespace: $NAMESPACE
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      containers:
      - name: backup-container
        image: bitnami/minideb:latest
        command: ["/bin/bash", "/scripts/backup.sh"]
        volumeMounts:
        - name: minecraft-data-source
          mountPath: /minecraft-data
          readOnly: true
        - name: backup-storage
          mountPath: /backups
        - name: backup-script
          mountPath: /scripts
      restartPolicy: Never
      volumes:
      - name: minecraft-data-source
        persistentVolumeClaim:
          claimName: minecraft-data-minecraft-server-0
      - name: backup-storage
        persistentVolumeClaim:
          claimName: minecraft-backup-storage
      - name: backup-script
        configMap:
          name: $configMapName
          defaultMode: 0755
"@
        
        # Salvar o Job YAML em um arquivo temporário e aplicá-lo
        $jobFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $jobFile -Value $backupJobYaml -Encoding utf8
        
        $jobResult = kubectl apply -f $jobFile 2>&1
        if (-not $?) {
            Write-Host "Falha ao criar o Job de backup:" -ForegroundColor Red
            Write-Host $jobResult -ForegroundColor Red
            Remove-Item $jobFile -Force
            return
        }
        
        # Aguardar o job completar
        Write-Host "Job de backup iniciado. Aguardando conclusão..." -ForegroundColor Cyan
        Write-Host "Este processo pode levar algum tempo dependendo do tamanho do servidor." -ForegroundColor Yellow
        
        $jobCompleted = $false
        $attempts = 0
        $maxAttempts = 120  # 10 minutos (120 x 5s)
        $backupSuccess = $false
        
        while (-not $jobCompleted -and $attempts -lt $maxAttempts) {
            Start-Sleep -Seconds 5
            $jobStatus = kubectl get job $backupJobName -n $NAMESPACE -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            if ($jobStatus) {
                if ($jobStatus.status.succeeded -eq 1) {
                    $jobCompleted = $true
                    $backupSuccess = $true
                }
                elseif ($jobStatus.status.failed -eq 1) {
                    $jobCompleted = $true
                    $backupSuccess = $false
                }
                else {
                    $attempts++
                    Write-Host "Aguardando backup completar... ($attempts/$maxAttempts)" -ForegroundColor Cyan
                }
            }
            else {
                $attempts++
                Write-Host "Aguardando job iniciar... ($attempts/$maxAttempts)" -ForegroundColor Cyan
            }
        }
        
        # Obter logs do job para mostrar ao usuário
        $podName = kubectl get pods -n $NAMESPACE -l job-name=$backupJobName -o jsonpath='{.items[0].metadata.name}' 2>$null
        
        if ($podName) {
            $logs = kubectl logs $podName -n $NAMESPACE 2>$null
        }
        else {
            $logs = "Não foi possível recuperar logs do pod de backup."
        }
        
        # Mostrar resultado
        if ($jobCompleted) {
            if ($backupSuccess) {
                Write-Host "Backup concluído com sucesso!" -ForegroundColor Green
                Write-Host "Arquivo de backup criado: $backupFileName" -ForegroundColor Green
                Write-Host "Detalhes do processo de backup:" -ForegroundColor Cyan
                Write-Host $logs
            } 
            else {
                Write-Host "Falha ao criar backup!" -ForegroundColor Red
                Write-Host "Logs do processo:" -ForegroundColor Red
                Write-Host $logs
            }
        } 
        else {
            Write-Host "Tempo limite excedido ao aguardar a conclusão do backup." -ForegroundColor Red
            Write-Host "O processo pode ainda estar em execução em segundo plano." -ForegroundColor Yellow
            Write-Host "Verifique o status usando: kubectl get jobs -n $NAMESPACE" -ForegroundColor Yellow
        }
        
        # Perguntar se deseja excluir os recursos
        $choice = Read-Host "Deseja limpar o job e o configmap de backup? (S/N)"
        if ($choice -eq "S" -or $choice -eq "s") {
            kubectl delete job $backupJobName -n $NAMESPACE | Out-Null
            kubectl delete configmap $configMapName -n $NAMESPACE | Out-Null
            Write-Host "Recursos de backup removidos." -ForegroundColor Green
        }
        else {
            Write-Host "Os recursos permanecerão no cluster. O job será excluído automaticamente após 5 minutos." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Exceção ao executar o processo de backup:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    finally {
        # Limpar arquivos temporários
        if (Test-Path $configMapFile) {
            Remove-Item $configMapFile -Force
        }
        if (Test-Path $jobFile) {
            Remove-Item $jobFile -Force
        }
    }
}

# Exibir ajuda
function Show-Help {
    Write-Host "Gerenciador de Backups Minecraft Kubernetes" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    
    # Obter nome do script de forma mais robusta
    $scriptName = "minecraft-backup-tools.ps1"
    if ($MyInvocation.MyCommand.Name) {
        $scriptName = $MyInvocation.MyCommand.Name
    } elseif ($MyInvocation.InvocationName) {
        $scriptName = $MyInvocation.InvocationName
    }
    
    Write-Host "Uso: .\$scriptName [comando] [argumentos]"
    Write-Host ""
    Write-Host "Comandos disponíveis:"
    Write-Host "  list                Lista todos os backups disponíveis" -ForegroundColor Green
    Write-Host "  show [arquivo]      Exibe detalhes de um backup específico" -ForegroundColor Green
    Write-Host "  copy [arquivo]      Copia um backup para máquina local" -ForegroundColor Green
    Write-Host "  create              Cria um novo backup manualmente" -ForegroundColor Green
    Write-Host "  help                Exibe esta ajuda" -ForegroundColor Green
    Write-Host ""
    Write-Host "Exemplos:"
    Write-Host "  .\$scriptName list" 
    Write-Host "  .\$scriptName show minecraft-backup-20230615-120000.tar.gz"
    Write-Host "  .\$scriptName copy minecraft-backup-20230615-120000.tar.gz"
    Write-Host "  .\$scriptName create"
}

# Menu principal
switch ($args[0]) {
    "list" {
        List-Backups
    }
    "show" {
        Show-BackupDetails -BackupFile $args[1]
    }
    "copy" {
        Copy-BackupFile -BackupFile $args[1]
    }
    "create" {
        Create-Backup
    }
    "help" {
        Show-Help
    }
    default {
        if ($args[0]) {
            Write-Host "Comando desconhecido: $($args[0])" -ForegroundColor Yellow
        }
        Show-Help
    }
}
