Function Send-Data {
    <#
    .SYNOPSIS
    Sends data to a specified endpoint using an Azure access token.
    .DESCRIPTION
    This function sends data to a specified endpoint using an Azure access token. The access token is obtained using the Get-AzAccessToken cmdlet.
    .PARAMETER body
    The data to be sent to the endpoint.
    .EXAMPLE
    $body = @{
        "key1" = "value1"
        "key2" = "value2"
    }
    Send-Data -body $body
    .NOTES
    This function requires the Get-AzAccessToken cmdlet to be installed. It also requires the $env:dataCollectionEndpoint environment variable to be set to the desired endpoint URL.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [object]$body
    )

    $uri = "$env:DATA_COLLECTION_ENDPOINT"
    $token = Get-AzAccessToken -ResourceUrl https://monitor.azure.com

    $requestHeader = @{
        "Token"          = ($token.token | ConvertTo-SecureString -AsPlainText -Force)
        "Authentication" = 'OAuth'
        "Method"         = 'POST'
        "ContentType"    = 'application/json'
    }

    try {
        Invoke-RestMethod -Uri "$uri" -Body $body @requestHeader
    }
    catch {
        Write-Warning "Unable to sent data. Validate if the account '$($token.UserId)' has Access to the Data Collection Rule"
    }

}

function Get-NormalizedUri {
    param(
        [Parameter()]
        [string]$Host = $env:KEEPIT_HOST,

        [Parameter()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Host)) {
        Write-Error 'KEEPIT_HOST is not configured.'
        return $null
    }

    $normalizedHost = $Host.Trim().TrimEnd('/')
    if ($normalizedHost -match '^https?://') {
        $normalizedHost = $normalizedHost -replace '^https?://', ''
    }

    $baseUri = "https://$normalizedHost"
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $baseUri
    }

    $normalizedPath = $Path.Trim()
    if ($normalizedPath.StartsWith('/')) {
        return "$baseUri$normalizedPath"
    }

    return "$baseUri/$normalizedPath"
}

function Get-AuthHeader {
    if ([string]::IsNullOrWhiteSpace($env:KEEPIT_LOGIN) -or [string]::IsNullOrWhiteSpace($env:KEEPIT_PASSWORD)) {
        Write-Error 'KEEPIT_LOGIN or KEEPIT_PASSWORD is not configured.'
        return $null
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$($env:KEEPIT_LOGIN)`:$($env:KEEPIT_PASSWORD)")
    $AuthHeader = 'Basic ' + [Convert]::ToBase64String($bytes)

    $headers = @{
        Accept        = 'application/vnd.keepit.v4+xml'
        Authorization = $AuthHeader
    }

    $baseUri = Get-NormalizedUri
    if ($null -eq $baseUri) {
        return $null
    }

    try {
        $response = Invoke-WebRequest -Uri $baseUri -Headers $headers
        if (!([string]::IsNullOrWhiteSpace($response))) {
            Write-Host "Keepit login test succeeded. HTTP $($response.StatusCode)"
            return $headers
        }

        return $null
    }
    catch {
        $statusCodeText = if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { [string][int]$_.Exception.Response.StatusCode } else { 'unknown' }

        Write-Error 'Response body:'
        # Write-Error (Get-ResponseBodyFromError -ErrorRecord $_)
        Write-Error "Keepit login test failed. HTTP $statusCodeText"
        return $null
    }
}

function Get-KeepItAuditLogs {
    param(
        [Parameter()]
        [string]$LookbackMinutes,

        [Parameter()]
        [object]$AuthHeader
    )

    # Support either direct minute values (e.g. "5") or NCRONTAB schedules (e.g. "0 */5 * * * *").
    $resolvedLookbackMinutes = 5
    $rawLookback = $LookbackMinutes

    if ([string]::IsNullOrWhiteSpace($rawLookback)) {
        $rawLookback = $env:KEEPIT_LOOKBACK
    }

    if (-not [string]::IsNullOrWhiteSpace($rawLookback)) {
        $minutesValue = 0
        if ([int]::TryParse($rawLookback, [ref]$minutesValue) -and $minutesValue -gt 0) {
            $resolvedLookbackMinutes = $minutesValue
        }
        else {
            $cronParts = $rawLookback.Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($cronParts.Count -eq 6 -and $cronParts[1] -match '^\*/(\d+)$') {
                $stepMinutes = [int]$Matches[1]
                if ($stepMinutes -gt 0) {
                    $resolvedLookbackMinutes = $stepMinutes
                }
            }
            else {
                Write-Warning "Unable to parse KEEPIT_LOOKBACK value '$rawLookback'. Falling back to $resolvedLookbackMinutes minute(s)."
            }
        }
    }

    $ToTime = (Get-Date -AsUTC).ToString('yyyy-MM-ddTHH:mm:ssZ')
    # $FromTime = (Get-Date -AsUTC).AddMinutes(-$resolvedLookbackMinutes).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $FromTime = (Get-Date -AsUTC).AddMinutes(-14400).ToString('yyyy-MM-ddTHH:mm:ssZ')

    $uri = Get-NormalizedUri -Path '/audit/filter/pretty'
    if ($null -eq $uri) {
        return $null
    }
    $body = '<filter><account>{0}</account><from>{1}</from><to>{2}</to></filter>' -f $env:KEEPIT_ACCOUNT, $FromTime, $ToTime

    if ($null -eq $AuthHeader) {
        Write-Error 'Auth header is empty. Aborting Keepit audit request.'
        return $null
    }

    $Params = @{
        Uri         = $uri
        Method      = 'Put'
        Headers     = $AuthHeader
        Body        = $body
        ContentType = 'application/xml'
        TimeoutSec  = 60
    }

    try {
        Write-Verbose "Get-KeepItAuditLogs: Sending request to Keepit API..."

        $response = Invoke-WebRequest @Params

        if (!([string]::IsNullOrWhiteSpace($response))) {
            return $response
        }

        return $null
    }
    catch {
        Write-Error 'Response body:'
        Write-Error (Get-ResponseBodyFromError -ErrorRecord $_)
        return $null
    }
}

function Get-XmlChildValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Xml,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $node = $Xml.SelectSingleNode("$Name")
    if ($null -eq $node -or $null -eq $node.InnerText) {
        return ''
    }

    return $node.InnerText
}

function Convert-KeepitRecord {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$RecordXml
    )

    $metadata = @{}
    $metadataNodes = $RecordXml.SelectNodes('metadata/parameter')

    if ($null -ne $metadataNodes) {
        foreach ($parameter in $metadataNodes) {
            $keyNode = $parameter.SelectSingleNode('key')
            $valueNode = $parameter.SelectSingleNode('value')

            $key = if ($null -ne $keyNode -and $null -ne $keyNode.InnerText) { $keyNode.InnerText } else { '' }
            $value = if ($null -ne $valueNode -and $null -ne $valueNode.InnerText) { $valueNode.InnerText } else { '' }

            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $metadata[$key] = $value
            }
        }
    }

    $timeGeneratedText = Get-XmlChildValue -Xml $RecordXml -Name 'time'
    $timeStamp = $null
    $uploadTime = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

    if (-not [string]::IsNullOrWhiteSpace($timeGeneratedText)) {
        try {
            $timeStamp = [DateTimeOffset]::Parse($timeGeneratedText).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        catch {
            # If the source timestamp cannot be parsed, leave it null and use upload time as a safe fallback.
            $timeStamp = $null
        }
    }

    # if ([string]::IsNullOrWhiteSpace($timeStamp)) {
    #     $timeGenerated = $uploadTime
    # }

    [pscustomobject]@{
        EventStartTime = $timeStamp
        uploadtime    = $uploadTime
        account       = Get-XmlChildValue -Xml $RecordXml -Name 'account'
        connector     = Get-XmlChildValue -Xml $RecordXml -Name 'device'
        acl           = Get-XmlChildValue -Xml $RecordXml -Name 'acl'
        method        = Get-XmlChildValue -Xml $RecordXml -Name 'method'
        user          = Get-XmlChildValue -Xml $RecordXml -Name 'token'
        ipaddress     = Get-XmlChildValue -Xml $RecordXml -Name 'client-ip'
        event         = Get-XmlChildValue -Xml $RecordXml -Name 'message'
        metadata      = $metadata
    }
}

function Convert-KeepitAuditLogs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlText
    )

    $root = [xml]$XmlText
    $records = @()

    foreach ($record in $root.SelectNodes('//record')) {
        $records += Convert-KeepitRecord -RecordXml $record
    }

    return $records
}

function Get-ResponseBodyFromError {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $ErrorRecord.Exception.Message
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -eq $stream) {
            return $ErrorRecord.Exception.Message
        }

        $reader = [System.IO.StreamReader]::new($stream)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    catch {
        return $ErrorRecord.Exception.Message
    }
}