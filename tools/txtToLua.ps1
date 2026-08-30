param (
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (!(Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath"
    exit 1
}

$text = Get-Content $FilePath -Raw

# Escape backslashes first (important)
$text = $text -replace '\\', '\\\\'

# Escape double quotes
$text = $text -replace '"', '\"'

# Replace newlines with \n
$text = $text -replace "`r?`n", '\n'

# Wrap as Lua string
$luaString = '"' + $text + '"'

Write-Output $luaString