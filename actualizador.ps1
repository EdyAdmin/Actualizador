[CmdletBinding()]
param(
    [array]$Actualizaciones = @(
    @{ Command = 'rustup.exe'; Args = 'update'; Timeout = 300 }
    @{ Command = 'winget.exe'; Args = 'upgrade --all --silent --disable-interactivity --accept-package-agreements --accept-source-agreements --include-unknown'; Timeout = 3600 }
)
)

Set-StrictMode -Version 3.0

$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $PSScriptRoot 'ultima_actualizacion.log'
[System.IO.File]::WriteAllText($LogFile, '', [System.Text.UTF8Encoding]::new($false))

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Level = 'INFO'
    )

    $Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $FormattedLines = @(
        $Message -split '\r\n|\n|\r' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object {
                "$Time [$Level]: $_"
            }
    )

    if ($FormattedLines.Count -gt 0) {
        $Text = ($FormattedLines -join "`r`n") + "`r`n"

        [System.IO.File]::AppendAllText(
            $LogFile,
            $Text,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

function Invoke-Process {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string]$Arguments = '',
        [int]$TimeoutSeconds = 300
    )

    $started = $false
    $timedOut = $false

    $psi = [System.Diagnostics.ProcessStartInfo]::new($FilePath, $Arguments)
    $psi.WorkingDirectory = $PSScriptRoot
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    try {
        Write-Log "Ejecutando: $FilePath $Arguments"

        [void]$process.Start()
        $started = $true
        $process.StandardInput.Close()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Write-Log "TIMEOUT en $FilePath. Terminando procesos..." -Level 'ERROR'
            $timedOut = $true
            $script:HadErrors = $true
            $taskkill = Join-Path $env:WINDIR 'System32\taskkill.exe'
            if (Test-Path $taskkill) {
                & $taskkill /PID $process.Id /T /F 2>$null | Out-Null
            }
            if (-not $process.WaitForExit(10000)) {
                try {
                    $process.Kill()
                }
                catch {
                    Write-Log "No se pudo terminar el proceso: $($_.Exception.Message)" -Level 'ERROR'
                }
            }
            if (-not $process.WaitForExit(5000)) {
                throw "No se pudo confirmar el cierre de $FilePath."
            }
        }

        if ($stdoutTask.Wait(10000)) {
            if (-not [string]::IsNullOrWhiteSpace($stdoutTask.Result)) {
                Write-Log "STDOUT:`r`n$($stdoutTask.Result.TrimEnd())"
            }
        } else {
            Write-Log "No se pudo recuperar STDOUT de $FilePath" -Level 'WARN'
        }

        if ($stderrTask.Wait(10000)) {
            if (-not [string]::IsNullOrWhiteSpace($stderrTask.Result)) {
                Write-Log "STDERR:`r`n$($stderrTask.Result.TrimEnd())"
            }
        } else {
            Write-Log "No se pudo recuperar STDERR de $FilePath" -Level 'WARN'
        }

        if ($timedOut) {
            Write-Log "Proceso terminado por superar el tiempo máximo: $FilePath" -Level 'ERROR'
        }
        elseif ($process.ExitCode -eq 0) {
            Write-Log "Actualización completada: $FilePath"
        }
        else {
            $script:HadErrors = $true
            Write-Log "La actualización ha fallado. Código: $($process.ExitCode)" -Level 'ERROR'
        }

    } catch{
        $script:HadErrors = $true
        Write-Log "Error ejecutando $FilePath : $($_.Exception.Message)" -Level 'ERROR'
    } finally {
        if ($started) {
            try {
                if (-not $process.HasExited) {
                    Write-Log "Limpiando proceso todavía activo: $FilePath" -Level 'WARN'

                    $taskkill = Join-Path $env:WINDIR 'System32\taskkill.exe'

                    if (Test-Path -LiteralPath $taskkill) {
                        & $taskkill /PID $process.Id /T /F 2>$null | Out-Null
                    }

                    if (-not $process.WaitForExit(5000)) {
                        $process.Kill()

                        if (-not $process.WaitForExit(5000)) {
                            throw "No se pudo terminar $FilePath."
                        }
                    }
                }
            }
            catch {
                $script:HadErrors = $true
                Write-Log "Error durante la limpieza de $FilePath : $($_.Exception.Message)" -Level 'ERROR'
            }
        }

        $process.Dispose()
    }
}

$script:HadErrors = $false

Write-Log "===== INICIO DE ACTUALIZACION ====="

foreach ($app in $Actualizaciones) {
    $cmd = Get-Command $app.Command -CommandType Application -ErrorAction SilentlyContinue
    if($cmd) {
        Invoke-Process -FilePath $cmd.Source -Arguments $app.Args -TimeoutSeconds $app.Timeout
    } else {
        $script:HadErrors = $true
        Write-Log "No se encontró $($app.Command), omitiendo..." -Level "ERROR"
    }
}

Write-Log "===== FINAL DE ACTUALIZACION ====="

if ($script:HadErrors) {
    exit 1
}

exit 0