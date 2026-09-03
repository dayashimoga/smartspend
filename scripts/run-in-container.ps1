# PowerShell script to execute commands inside Podman container
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$ExecCommand
)

$Workspace = "/mnt/h/smartspend"
$Image = "ghcr.io/cirruslabs/flutter:stable"

wsl -d podman-machine-default -u root podman run --rm -v "flutter-pub-cache:/root/.pub-cache" -v "${Workspace}:/workspace" -w "/workspace" $Image sh -c "$ExecCommand"
