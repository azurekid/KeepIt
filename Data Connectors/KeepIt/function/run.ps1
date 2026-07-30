# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

$results = @()

$headers = Get-AuthHeader
$response = Get-KeepItAuditLogs -LookbackMinutes $env:KEEPIT_LOOKBACK -Headers $headers
$parsedRecords = Convert-KeepitAuditLogs -XmlText $response.Content

if ($parsedRecords -eq $null) {
    Write-Verbose "No records were parsed. Exiting."
    exit 0
} else {
    Write-Verbose "Parsed $($parsedRecords.Count) record(s)."
    Write-Verbose $parsedRecords
}

if ($parsedRecords.count -gt 0) {
    Write-Verbose "Sending $($parsedRecords.count) new records"
    Send-Data -body ($parsedRecords | ConvertTo-Json -AsArray)
}

#clear the temp folder
Remove-Item $env:temp\* -Recurse -Force -ErrorAction SilentlyContinue