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

function Get-AuthHeader {

    $KEEPIT_PASSWORD = 'av_ZcB@ReY_8ro#WK(gLv2,='
    $KEEPIT_LOGIN = 'oZV2Z1CjBn17u$mWPvmxH)k@'
    $KEEPIT_HOST = 'de-fr.keepit.com'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$KEEPIT_LOGIN`:$KEEPIT_PASSWORD")
    $AuthHeader = 'Basic ' + [Convert]::ToBase64String($bytes)

    $headers = @{
        Accept        = 'application/vnd.keepit.v4+xml'
        Authorization = $AuthHeader
    }

    try {
        $response = Invoke-WebRequest -Uri "https://$KEEPIT_HOST" -Headers $headers
        if (!([string]::IsNullOrWhiteSpace($response))) {
            Write-Host "Keepit login test succeeded. HTTP $($response.StatusCode)"
            return $headers | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        Write-Error 'Response body:'
        # Write-Error (Get-ResponseBodyFromError -ErrorRecord $_)
        Write-Error "Keepit login test failed. HTTP $statusCode"
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

    $ToTime = (Get-Date -AsUTC).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $FromTime = (Get-Date -AsUTC).AddMinutes(-($LookbackMinutes)).ToString('yyyy-MM-ddTHH:mm:ssZ')

    $uri = 'https://{0}/audit/filter/pretty' -f $env:KEEPIT_HOST
    $body = '<filter><account>{0}</account><from>{1}</from><to>{2}</to></filter>' -f $env:KEEPIT_ACCOUNT, $FromTime, $ToTime

    $Params = @{
        Uri         = $uri
        Method      = 'Put'
        Headers     = $AuthHeader | ConvertFrom-SecureString -AsPlainText | ConvertFrom-Json -AsHashtable
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
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        Write-Error 'Response body:'
        Write-Error (Get-ResponseBodyFromError -ErrorRecord $_)
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
    $timeGenerated = $null
    if (-not [string]::IsNullOrWhiteSpace($timeGeneratedText)) {
        try {
            $timeGenerated = [DateTimeOffset]::Parse($timeGeneratedText).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        catch {
            $timeGenerated = $timeGeneratedText
        }
    }

    [pscustomobject]@{
        TimeGenerated = $timeGenerated
        uploadtime    = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
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