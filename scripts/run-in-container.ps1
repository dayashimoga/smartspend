# PowerShell script to execute Flutter / Dart commands inside Podman container
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CmdArgs
)

$Workspace = "/mnt/h/smartspend"
$Image = "ghcr.io/cirruslabs/flutter:stable"

$argList = @("run", "--rm", "-v", "flutter-pub-cache:/root/.pub-cache", "-v", "${Workspace}:/workspace", "-w", "/workspace", $Image, $Command) + $CmdArgs

wsl -d podman-machine-default -u root podman @argList
