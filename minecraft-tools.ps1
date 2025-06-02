# Minecraft Server Management Tools
# Functions for importing, listing, and deleting plugins, mods, misc files,
# verifying operator files, checking cache files, and Kubernetes operations

# Define server directory paths (adjust these to match your server setup)
$serverRoot = ".\server" # Change this to your actual server location
$pluginsDir = Join-Path -Path $serverRoot -ChildPath "plugins"
$modsDir = Join-Path -Path $serverRoot -ChildPath "mods"
$miscDir = Join-Path -Path $serverRoot -ChildPath "misc" # For server icon etc.
$opFile = Join-Path -Path $serverRoot -ChildPath "ops.json"
$cacheDir = Join-Path -Path $serverRoot -ChildPath "cache"

# Kubernetes configuration (adjust these to match your setup)
$kubeNamespace = "minecraft-server-ns"
$kubePod = "minecraft-server-0"
$kubeContainer = "minecraft-server-container"
$kubeDataPath = "/data"

# Make sure directories exist
function Ensure-DirectoriesExist {
    if (-not (Test-Path -Path $serverRoot)) {
        Write-Host "Error: Server root directory does not exist at $serverRoot" -ForegroundColor Red
        Write-Host "Please update the script with the correct server location." -ForegroundColor Red
        exit 1
    }

    $directories = @($pluginsDir, $modsDir, $miscDir, $cacheDir)
    foreach ($dir in $directories) {
        if (-not (Test-Path -Path $dir)) {
            Write-Host "Creating directory: $dir" -ForegroundColor Yellow
            New-Item -Path $dir -ItemType Directory | Out-Null
        }
    }
}

# Function to import files
function Import-MinecraftFiles {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("plugins", "mods", "misc")]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    $targetDir = switch ($Type) {
        "plugins" { $pluginsDir }
        "mods" { $modsDir }
        "misc" { $miscDir }
    }

    if (-not (Test-Path -Path $SourcePath)) {
        Write-Host "Error: Source path does not exist: $SourcePath" -ForegroundColor Red
        return
    }

    if (Test-Path -Path $SourcePath -PathType Leaf) {
        # Single file import
        $fileName = Split-Path -Path $SourcePath -Leaf
        $targetPath = Join-Path -Path $targetDir -ChildPath $fileName
        
        Copy-Item -Path $SourcePath -Destination $targetPath
        Write-Host "Imported file: $fileName to $targetDir" -ForegroundColor Green
    } 
    else {
        # Directory import
        $files = Get-ChildItem -Path $SourcePath -File
        foreach ($file in $files) {
            $targetPath = Join-Path -Path $targetDir -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $targetPath
            Write-Host "Imported file: $($file.Name) to $targetDir" -ForegroundColor Green
        }
        Write-Host "Imported $($files.Count) files to $targetDir" -ForegroundColor Green
    }
}

# Function to list files
function Get-MinecraftFiles {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("plugins", "mods", "misc", "all")]
        [string]$Type
    )

    switch ($Type) {
        "all" {
            Write-Host "=== Plugins ===" -ForegroundColor Cyan
            if (Test-Path -Path $pluginsDir) {
                Get-ChildItem -Path $pluginsDir -File | Format-Table Name, Length, LastWriteTime
            }
            
            Write-Host "=== Mods ===" -ForegroundColor Cyan
            if (Test-Path -Path $modsDir) {
                Get-ChildItem -Path $modsDir -File | Format-Table Name, Length, LastWriteTime
            }
            
            Write-Host "=== Misc Files ===" -ForegroundColor Cyan
            if (Test-Path -Path $miscDir) {
                Get-ChildItem -Path $miscDir -File | Format-Table Name, Length, LastWriteTime
            }
        }
        "plugins" {
            Write-Host "=== Plugins ===" -ForegroundColor Cyan
            if (Test-Path -Path $pluginsDir) {
                Get-ChildItem -Path $pluginsDir -File | Format-Table Name, Length, LastWriteTime
            } else {
                Write-Host "No plugins directory found." -ForegroundColor Yellow
            }
        }
        "mods" {
            Write-Host "=== Mods ===" -ForegroundColor Cyan
            if (Test-Path -Path $modsDir) {
                Get-ChildItem -Path $modsDir -File | Format-Table Name, Length, LastWriteTime
            } else {
                Write-Host "No mods directory found." -ForegroundColor Yellow
            }
        }
        "misc" {
            Write-Host "=== Misc Files ===" -ForegroundColor Cyan
            if (Test-Path -Path $miscDir) {
                Get-ChildItem -Path $miscDir -File | Format-Table Name, Length, LastWriteTime
            } else {
                Write-Host "No misc directory found." -ForegroundColor Yellow
            }
        }
    }
}

# Function to delete files
function Remove-MinecraftFiles {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("plugins", "mods", "misc")]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $targetDir = switch ($Type) {
        "plugins" { $pluginsDir }
        "mods" { $modsDir }
        "misc" { $miscDir }
    }

    $filePath = Join-Path -Path $targetDir -ChildPath $FileName
    
    if (Test-Path -Path $filePath) {
        Remove-Item -Path $filePath -Force
        Write-Host "Deleted file: $FileName from $targetDir" -ForegroundColor Green
    } 
    else {
        Write-Host "Error: File not found: $filePath" -ForegroundColor Red
    }
}

# Function to check operator file
function Get-OperatorFile {
    if (Test-Path -Path $opFile) {
        Write-Host "=== Operator File Content ===" -ForegroundColor Cyan
        $opContent = Get-Content -Path $opFile -Raw | ConvertFrom-Json
        
        foreach ($op in $opContent) {
            Write-Host "UUID: $($op.uuid)" -ForegroundColor Yellow
            Write-Host "Name: $($op.name)" -ForegroundColor Yellow
            Write-Host "Level: $($op.level)" -ForegroundColor Yellow
            Write-Host "Bypass permission check: $($op.bypassesPlayerLimit)" -ForegroundColor Yellow
            Write-Host "-----------------------------------" -ForegroundColor Gray
        }
    } 
    else {
        Write-Host "Operator file not found at: $opFile" -ForegroundColor Red
    }
}

# Function to check cache files
function Get-CacheFiles {
    if (Test-Path -Path $cacheDir) {
        Write-Host "=== Cache Files ===" -ForegroundColor Cyan
        $cacheFiles = Get-ChildItem -Path $cacheDir -Recurse -File
        
        if ($cacheFiles.Count -eq 0) {
            Write-Host "No cache files found." -ForegroundColor Yellow
            return
        }
        
        $totalSize = 0
        foreach ($file in $cacheFiles) {
            $totalSize += $file.Length
        }
        
        $cacheFiles | Format-Table Name, Length, LastWriteTime
        Write-Host "Total cache size: $($totalSize / 1MB) MB" -ForegroundColor Yellow
        
        $response = Read-Host "Would you like to clear the cache? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            Remove-Item -Path "$cacheDir\*" -Recurse -Force
            Write-Host "Cache cleared successfully!" -ForegroundColor Green
        }
    } 
    else {
        Write-Host "Cache directory not found at: $cacheDir" -ForegroundColor Red
    }
}

# Function to copy files to Kubernetes container
function Copy-ToKubernetesContainer {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("plugins", "mods", "misc", "custom")]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $false)]
        [string]$CustomDestinationPath
    )
    
    # Check if kubectl is installed
    try {
        $null = kubectl version --client
    } catch {
        Write-Host "Error: kubectl is not installed or not in PATH" -ForegroundColor Red
        return
    }
    
    # Verify source file exists
    if (-not (Test-Path -Path $SourcePath)) {
        Write-Host "Error: Source path does not exist: $SourcePath" -ForegroundColor Red
        return
    }
    
    # Determine destination path in container
    $isDirectory = (Test-Path -Path $SourcePath -PathType Container)
    
    if ($Type -eq "custom" -and -not [string]::IsNullOrEmpty($CustomDestinationPath)) {
        $destinationPath = $CustomDestinationPath
    } else {
        $targetDir = switch ($Type) {
            "plugins" { "$kubeDataPath/plugins" }
            "mods" { "$kubeDataPath/mods" }
            "misc" { $kubeDataPath }
        }
        
        if ($isDirectory) {
            $sourceDirName = Split-Path -Path $SourcePath -Leaf
            $destinationPath = "$targetDir"
        } else {
            $fileName = Split-Path -Path $SourcePath -Leaf
            $destinationPath = "$targetDir/$fileName"
        }
    }
    
    # Create destination directory first if needed
    $destDir = if ($isDirectory) { $destinationPath } else { Split-Path -Path $destinationPath -Parent }
    $mkdirCmd = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- mkdir -p $destDir"
    
    Write-Host "Creating directory if needed: $mkdirCmd" -ForegroundColor Yellow
    try {
        Invoke-Expression $mkdirCmd | Out-Null
    } catch {
        Write-Host "Warning: Could not create directory, but will try to continue: $_" -ForegroundColor Yellow
    }
    
    # Form the kubectl cp command
    $kubeCommand = if ($isDirectory) {
        $sourceDirName = Split-Path -Path $SourcePath -Leaf
        # For directories, make sure we copy the contents to the right location
        "kubectl cp $SourcePath $kubeNamespace/$kubePod`:$destDir -c $kubeContainer"
    } else {
        "kubectl cp $SourcePath $kubeNamespace/$kubePod`:$destinationPath -c $kubeContainer"
    }
    
    Write-Host "Executing: $kubeCommand" -ForegroundColor Yellow
    
    # Execute the command
    $success = $true
    try {
        $output = Invoke-Expression $kubeCommand 2>&1
        
        # Check if there was an error in the output
        if ($output -match "error|failed|command terminated with exit code [1-9]") {
            $success = $false
            Write-Host "Error in command output: $output" -ForegroundColor Red
        }
    } catch {
        $success = $false
        Write-Host "Error executing command: $_" -ForegroundColor Red
    }
    
    # Verify the copy operation
    if ($success) {
        # For directories, list contents to verify they were copied
        if ($isDirectory) {
            $checkCommand = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- ls -la $destDir"
            Write-Host "Verifying copy operation: $checkCommand" -ForegroundColor Yellow
            try {
                $checkResult = Invoke-Expression $checkCommand
                if ($checkResult) {
                    Write-Host "Files copied successfully. Directory contents:" -ForegroundColor Green
                    Write-Host $checkResult -ForegroundColor Gray
                } else {
                    Write-Host "Warning: Copy may have failed - directory appears empty" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Warning: Could not verify copy operation: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Successfully copied $SourcePath to Kubernetes container" -ForegroundColor Green
        }
    } else {
        Write-Host "Failed to copy $SourcePath to Kubernetes container" -ForegroundColor Red
    }
}

# Function to delete directories in the Kubernetes container
function Remove-KubernetesDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("plugins", "mods", "both", "config")]
        [string]$DirectoryType
    )
    
    Write-Host "=== Delete Kubernetes Directories ===" -ForegroundColor Cyan
    
    # List of directories to delete based on selection
    $directoriesToDelete = @()
    switch ($DirectoryType) {
        "plugins" { $directoriesToDelete += "$kubeDataPath/plugins" }
        "mods" { $directoriesToDelete += "$kubeDataPath/mods" }`
        "config" { $directoriesToDelete += "$kubeDataPath/config" }
        "both" { 
            $directoriesToDelete += "$kubeDataPath/plugins"
            $directoriesToDelete += "$kubeDataPath/mods" 
        }
    }
    
    # Confirm deletion
    Write-Host "You are about to delete the following directories:" -ForegroundColor Yellow
    foreach ($dir in $directoriesToDelete) {
        Write-Host "- $dir" -ForegroundColor Yellow
    }
    $confirmation = Read-Host "Are you sure you want to proceed? (Y/N)"
    
    if ($confirmation -ne "Y" -and $confirmation -ne "y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    # Delete each directory and recreate empty ones
    foreach ($dir in $directoriesToDelete) {
        Write-Host "Deleting $dir..." -ForegroundColor Yellow
        
        # List contents before deletion (if exists)
        $checkCommand = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- ls -la $dir 2>/dev/null || echo 'Directory does not exist'"
        Write-Host "Checking directory contents before deletion:" -ForegroundColor Yellow
        try {
            $checkResult = Invoke-Expression $checkCommand
            Write-Host $checkResult -ForegroundColor Gray
        } catch {
            Write-Host "Warning: Could not check directory contents: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Delete the directory
        $deleteCommand = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- rm -rf $dir"
        try {
            Invoke-Expression $deleteCommand
            Write-Host "Successfully deleted $dir" -ForegroundColor Green
        } catch {
            Write-Host "Error deleting directory ${dir}: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
        
        # Recreate empty directory
        $createCommand = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- mkdir -p $dir"
        try {
            Invoke-Expression $createCommand
            Write-Host "Successfully created empty directory $dir" -ForegroundColor Green
        } catch {
            Write-Host "Error creating directory ${dir}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "Operation completed." -ForegroundColor Green
}

# Function to configure Kubernetes settings
function Set-KubernetesSettings {
    Write-Host "=== Kubernetes Configuration ===" -ForegroundColor Cyan
    
    $newNamespace = Read-Host "Enter Kubernetes namespace (current: $kubeNamespace)"
    if (-not [string]::IsNullOrEmpty($newNamespace)) {
        $script:kubeNamespace = $newNamespace
    }
    
    $newPod = Read-Host "Enter Kubernetes pod name (current: $kubePod)"
    if (-not [string]::IsNullOrEmpty($newPod)) {
        $script:kubePod = $newPod
    }
    
    $newContainer = Read-Host "Enter Kubernetes container name (current: $kubeContainer)"
    if (-not [string]::IsNullOrEmpty($newContainer)) {
        $script:kubeContainer = $newContainer
    }
    
    $newDataPath = Read-Host "Enter container data path (current: $kubeDataPath)"
    if (-not [string]::IsNullOrEmpty($newDataPath)) {
        $script:kubeDataPath = $newDataPath
    }
    
    Write-Host "Kubernetes settings updated successfully!" -ForegroundColor Green
}

# Function to list Kubernetes resources
function Get-KubernetesResources {
    Write-Host "=== Kubernetes Resources ===" -ForegroundColor Cyan
    
    Write-Host "Checking namespaces..." -ForegroundColor Yellow
    kubectl get namespaces
    
    Write-Host "`nChecking pods in namespace $kubeNamespace..." -ForegroundColor Yellow
    try {
        kubectl get pods -n $kubeNamespace
    } catch {
        Write-Host "Error getting pods: $_" -ForegroundColor Red
    }
    
    Write-Host "`nWould you like to check the pod details? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        try {
            kubectl describe pod $kubePod -n $kubeNamespace
        } catch {
            Write-Host "Error describing pod: $_" -ForegroundColor Red
        }
    }
}

# Function to restart the Minecraft server in Kubernetes
function Restart-MinecraftServer {
    Write-Host "=== Restart Minecraft Server ===" -ForegroundColor Cyan
    
    Write-Host "Current Kubernetes settings:" -ForegroundColor Yellow
    Write-Host "Namespace: $kubeNamespace" -ForegroundColor Yellow
    Write-Host "Pod: $kubePod" -ForegroundColor Yellow
    Write-Host "Container: $kubeContainer" -ForegroundColor Yellow
    
    Write-Host "`nRestart options:" -ForegroundColor Cyan
    Write-Host "1. Restart container (soft restart)" -ForegroundColor White
    Write-Host "2. Delete pod (hard restart - pod will be recreated by StatefulSet)" -ForegroundColor White
    Write-Host "0. Cancel" -ForegroundColor White
    
    $choice = Read-Host "Enter your choice"
    
    switch ($choice) {
        "1" {
            Write-Host "Performing soft restart of container..." -ForegroundColor Yellow
            try {
                # Execute kubectl command to restart just the container
                $restartCommand = "kubectl exec -n $kubeNamespace $kubePod -c $kubeContainer -- /bin/sh -c 'kill 1'"
                Write-Host "Executing: $restartCommand" -ForegroundColor Yellow
                Invoke-Expression $restartCommand
                Write-Host "Restart command sent. Container should restart momentarily." -ForegroundColor Green
            }
            catch {
                Write-Host "Error restarting container: $_" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "Performing hard restart (deleting pod)..." -ForegroundColor Yellow
            $confirm = Read-Host "Are you sure you want to delete the pod? This will cause downtime until Kubernetes recreates it. (Y/N)"
            
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                try {
                    # Delete the pod to force recreation by the StatefulSet controller
                    $deleteCommand = "kubectl delete pod $kubePod -n $kubeNamespace"
                    Write-Host "Executing: $deleteCommand" -ForegroundColor Yellow
                    Invoke-Expression $deleteCommand
                    Write-Host "Pod deleted. Kubernetes will recreate it shortly." -ForegroundColor Green
                    
                    # Wait and check status
                    Start-Sleep -Seconds 5
                    Write-Host "Checking pod status..." -ForegroundColor Yellow
                    Invoke-Expression "kubectl get pod $kubePod -n $kubeNamespace"
                }
                catch {
                    Write-Host "Error deleting pod: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "Pod deletion cancelled." -ForegroundColor Yellow
            }
        }
        "0" {
            Write-Host "Restart cancelled." -ForegroundColor Yellow
        }
        default {
            Write-Host "Invalid option selected." -ForegroundColor Red
        }
    }
}

# Main menu function
function Show-MainMenu {
    Clear-Host
    Write-Host "===== Minecraft Server Tools =====" -ForegroundColor Cyan
    Write-Host "1. Import files (plugins, mods, misc)" -ForegroundColor White
    Write-Host "2. List files" -ForegroundColor White
    Write-Host "3. Delete files" -ForegroundColor White
    Write-Host "4. Check operator file" -ForegroundColor White
    Write-Host "5. Check cache files" -ForegroundColor White
    Write-Host "6. Copy file to Kubernetes container" -ForegroundColor Green
    Write-Host "7. Configure Kubernetes settings" -ForegroundColor Green
    Write-Host "8. List Kubernetes resources" -ForegroundColor Green
    Write-Host "9. Restart Minecraft server" -ForegroundColor Green
    Write-Host "10. Delete directories in Kubernetes" -ForegroundColor Green
    Write-Host "0. Exit" -ForegroundColor White
    Write-Host "=================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Enter your choice"
    
    switch ($choice) {
        "1" { 
            $type = Read-Host "Enter file type (plugins, mods, misc)"
            $sourcePath = Read-Host "Enter source path (file or directory)"
            Import-MinecraftFiles -Type $type -SourcePath $sourcePath
            Pause
            Show-MainMenu
        }
        "2" { 
            $type = Read-Host "Enter file type to list (plugins, mods, misc, all)"
            Get-MinecraftFiles -Type $type
            Pause
            Show-MainMenu
        }
        "3" { 
            $type = Read-Host "Enter file type to delete from (plugins, mods, misc)"
            $fileName = Read-Host "Enter file name to delete"
            Remove-MinecraftFiles -Type $type -FileName $fileName
            Pause
            Show-MainMenu
        }
        "4" { 
            Get-OperatorFile
            Pause
            Show-MainMenu
        }
        "5" { 
            Get-CacheFiles
            Pause
            Show-MainMenu
        }
        "6" { 
            Write-Host "Current K8s settings: Namespace=$kubeNamespace, Pod=$kubePod, Container=$kubeContainer" -ForegroundColor Cyan
            $type = Read-Host "Enter file type (plugins, mods, misc, custom)"
            $sourcePath = Read-Host "Enter source file path"
            
            if ($type -eq "custom") {
                $customPath = Read-Host "Enter custom destination path in container"
                Copy-ToKubernetesContainer -Type $type -SourcePath $sourcePath -CustomDestinationPath $customPath
            } else {
                Copy-ToKubernetesContainer -Type $type -SourcePath $sourcePath
            }
            
            Pause
            Show-MainMenu
        }
        "7" {
            Set-KubernetesSettings
            Pause
            Show-MainMenu
        }
        "8" {
            Get-KubernetesResources
            Pause
            Show-MainMenu
        }
        "9" {
            Restart-MinecraftServer
            Pause
            Show-MainMenu
        }
        "10" {
            $dirType = Read-Host "Enter directory type to delete (plugins, mods, both)"
            Remove-KubernetesDirectory -DirectoryType $dirType
            Pause
            Show-MainMenu
        }
        "0" { 
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 
        }
        default { 
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Pause
            Show-MainMenu
        }
    }
}

# Start the script
Ensure-DirectoriesExist
Show-MainMenu
