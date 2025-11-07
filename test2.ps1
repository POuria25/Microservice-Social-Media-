<#
.SYNOPSIS
    Checks gateway and load balancer health via HTTPS connectivity.

.DESCRIPTION
    This script tests HTTPS endpoints for gateways and load balancers, checking:
    - Connectivity status
    - Response time
    - HTTP status code
    - SSL certificate validity
    - Certificate expiration date

.PARAMETER Endpoints
    Array of URLs to test (gateways/load balancers)

.PARAMETER TimeoutSeconds
    Timeout for each request in seconds (default: 10)

.PARAMETER ExportResults
    Path to export results as CSV

.EXAMPLE
    .\Check-HTTPSEndpoints.ps1 -Endpoints "https://gateway1.example.com","https://lb1.example.com"

.EXAMPLE
    .\Check-HTTPSEndpoints.ps1 -Endpoints "https://api.example.com" -TimeoutSeconds 5 -ExportResults "results.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$Endpoints = @(
    "https://192.168.1.1",
    "https://10.0.0.5",
    "https://google.com"
),
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 10,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportResults
)

# Function to test HTTPS endpoint
function Test-HTTPSEndpoint {
    param(
        [string]$Url,
        [int]$Timeout
    )
    
    $result = [PSCustomObject]@{
        Endpoint = $Url
        Status = "Unknown"
        StatusCode = $null
        ResponseTime = $null
        SSLValid = $false
        CertificateExpiry = $null
        DaysUntilExpiry = $null
        CertificateIssuer = $null
        ErrorMessage = $null
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Measure response time
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Create web request
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Timeout = $Timeout * 1000
        $request.Method = "GET"
        $request.AllowAutoRedirect = $true
        
        # Get response
        try {
            $response = $request.GetResponse()
            $stopwatch.Stop()
            
            $result.StatusCode = [int]$response.StatusCode
            $result.ResponseTime = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
            $result.Status = "Success"
            
            $response.Close()
        }
        catch [System.Net.WebException] {
            $stopwatch.Stop()
            
            if ($_.Exception.Response) {
                $result.StatusCode = [int]$_.Exception.Response.StatusCode
                $result.ResponseTime = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
                $result.Status = "HTTP Error"
                $result.ErrorMessage = $_.Exception.Message
            }
            else {
                $result.Status = "Failed"
                $result.ErrorMessage = $_.Exception.Message
            }
        }
        
        # Check SSL Certificate
        try {
            $uri = [System.Uri]$Url
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($uri.Host, 443)
            
            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({$true}))
            $sslStream.AuthenticateAsClient($uri.Host)
            
            $certificate = $sslStream.RemoteCertificate
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
            
            $result.SSLValid = $true
            $result.CertificateExpiry = $cert.NotAfter
            $result.DaysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
            $result.CertificateIssuer = $cert.Issuer
            
            $sslStream.Close()
            $tcpClient.Close()
        }
        catch {
            $result.SSLValid = $false
            if (-not $result.ErrorMessage) {
                $result.ErrorMessage = "SSL Error: $($_.Exception.Message)"
            }
        }
    }
    catch {
        $result.Status = "Failed"
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

# Function to display results with color coding
function Show-Results {
    param($Results)
    
    Write-Host "`n===================================" -ForegroundColor Cyan
    Write-Host "   HTTPS Endpoint Health Check" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    foreach ($result in $Results) {
        Write-Host "Endpoint: " -NoNewline
        Write-Host $result.Endpoint -ForegroundColor Yellow
        Write-Host "  Status: " -NoNewline
        
        switch ($result.Status) {
            "Success" { Write-Host $result.Status -ForegroundColor Green }
            "Failed" { Write-Host $result.Status -ForegroundColor Red }
            "HTTP Error" { Write-Host $result.Status -ForegroundColor Yellow }
            default { Write-Host $result.Status -ForegroundColor Gray }
        }
        
        if ($result.StatusCode) {
            Write-Host "  HTTP Code: $($result.StatusCode)"
        }
        
        if ($result.ResponseTime) {
            Write-Host "  Response Time: $($result.ResponseTime) ms"
        }
        
        Write-Host "  SSL Valid: " -NoNewline
        if ($result.SSLValid) {
            Write-Host "Yes" -ForegroundColor Green
            Write-Host "  Certificate Expiry: $($result.CertificateExpiry)"
            Write-Host "  Days Until Expiry: " -NoNewline
            
            if ($result.DaysUntilExpiry -lt 30) {
                Write-Host $result.DaysUntilExpiry -ForegroundColor Red
            }
            elseif ($result.DaysUntilExpiry -lt 60) {
                Write-Host $result.DaysUntilExpiry -ForegroundColor Yellow
            }
            else {
                Write-Host $result.DaysUntilExpiry -ForegroundColor Green
            }
            
            Write-Host "  Certificate Issuer: $($result.CertificateIssuer)"
        }
        else {
            Write-Host "No" -ForegroundColor Red
        }
        
        if ($result.ErrorMessage) {
            Write-Host "  Error: " -NoNewline
            Write-Host $result.ErrorMessage -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

# Main execution
Write-Host "Starting HTTPS endpoint checks..." -ForegroundColor Cyan
Write-Host "Testing $($Endpoints.Count) endpoint(s) with $TimeoutSeconds second timeout`n" -ForegroundColor Gray

$results = @()

foreach ($endpoint in $Endpoints) {
    Write-Host "Testing: $endpoint..." -ForegroundColor Gray
    $testResult = Test-HTTPSEndpoint -Url $endpoint -Timeout $TimeoutSeconds
    $results += $testResult
}

# Display results
Show-Results -Results $results

# Summary
$successCount = ($results | Where-Object { $_.Status -eq "Success" }).Count
$failedCount = ($results | Where-Object { $_.Status -eq "Failed" -or $_.Status -eq "HTTP Error" }).Count

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Total Endpoints: $($results.Count)"
Write-Host "Successful: " -NoNewline
Write-Host $successCount -ForegroundColor Green
Write-Host "Failed: " -NoNewline
Write-Host $failedCount -ForegroundColor Red

# Export results if requested
if ($ExportResults) {
    try {
        $results | Export-Csv -Path $ExportResults -NoTypeInformation
        Write-Host "`nResults exported to: $ExportResults" -ForegroundColor Green
    }
    catch {
        Write-Host "`nFailed to export results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Return results object
return $results