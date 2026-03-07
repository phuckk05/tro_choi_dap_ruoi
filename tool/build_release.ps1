# Build optimized release artifacts with symbol separation.
# Run from workspace root: .\tool\build_release.ps1

$ErrorActionPreference = 'Stop'

$symbolDir = "build\symbols"
if (-not (Test-Path $symbolDir)) {
  New-Item -Path $symbolDir -ItemType Directory | Out-Null
}

flutter build apk --release --split-per-abi --obfuscate --split-debug-info=$symbolDir --tree-shake-icons
flutter build appbundle --release --obfuscate --split-debug-info=$symbolDir --tree-shake-icons

Write-Host "Release builds completed. Symbols are in $symbolDir"
