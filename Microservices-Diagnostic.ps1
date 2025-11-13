<# 
=======================================================================
  COMPREHENSIVE MICROSERVICES DIAGNOSTIC & TESTING SUITE
  - Complete system health check
  - Gateway, Feed Service, Load Balancers, Prometheus
  - Authentication flow testing
  - Metrics and monitoring validation
  - Automated fixes and traffic generation
======================================================================= 
#>

param(
    [switch]$FixRules = $false,
    [int]$TrafficCount = 50,
    [switch]$QuickTest = $false
)

# --------------------------- CONFIGURATION ----------------------------
$GatewayHttps = "https://localhost:8443"
$GatewayHttp  = "http://localhost:8080"
$UserLB       = "http://localhost:9001"
$PostLB       = "http://localhost:9002"
$FeedHost     = "http://localhost:5000"
$Prometheus   = "http://localhost:9090"

$RegisterPath = "/api/auth/register"
$LoginPath    = "/api/auth/login"
$MePath       = "/api/profile/me"
$FeedPath     = "/api/feed"
$HealthzPath  = "/healthz"
$MetricsPath  = "/metrics"

# --------------------------- GLOBAL VARIABLES -------------------------
$Script:TestResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
}

$Script:CurrentToken = $null
$Script:CurrentUserId = $null

# --------------------------- HELPER FUNCTIONS -------------------------
function Write-Info  ($msg) { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Ok     ($msg) { Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Warn   ($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err    ($msg) { Write-Host "[x] $msg" -ForegroundColor Red }

function Test-Result {
    param([bool]$Success, [string]$Message, [switch]$Warning)
    
    if ($Warning) {
        Write-Warn $Message
        $Script:TestResults.Warnings++
    } elseif ($Success) {
        Write-Ok $Message
        $Script:TestResults.Passed++
    } else {
        Write-Err $Message
        $Script:TestResults.Failed++
    }
}

# Trust self-signed certificates
if (-not ("TrustAllCertsPolicy" -as [type])) {
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint p, X509Certificate c, WebRequest r, int e) { return true; }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
}

function Invoke-SafeWebRequest {
    param($Uri, $Method = "GET", $Headers = @{}, $Body = $null, $Timeout = 10)
    
    try {
        $request = [System.Net.WebRequest]::Create($Uri)
        $request.Method = $Method
        $request.Timeout = $Timeout * 1000
        $request.ContentType = "application/json"
        
        foreach ($header in $Headers.GetEnumerator()) {
            $request.Headers.Add($header.Key, $header.Value)
        }
        
        if ($Body -and ($Method -eq "POST" -or $Method -eq "PUT")) {
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json))
            $request.ContentLength = $bodyBytes.Length
            $stream = $request.GetRequestStream()
            $stream.Write($bodyBytes, 0, $bodyBytes.Length)
            $stream.Close()
        }
        
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Close()
        
        return @{
            StatusCode = [int]$response.StatusCode
            Content = $content
            Success = $true
        }
    }
    catch [System.Net.WebException] {
        $statusCode = 0
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        return @{
            StatusCode = $statusCode
            Content = $_.Exception.Message
            Success = $false
        }
    }
    catch {
        return @{
            StatusCode = 0
            Content = $_.Exception.Message
            Success = $false
        }
    }
}

function Test-Endpoint {
    param($Url, $ExpectedService, $Method = "GET", $Headers = @{}, $Body = $null)
    
    $result = Invoke-SafeWebRequest -Uri $Url -Method $Method -Headers $Headers -Body $Body
    $success = $result.Success -and $result.StatusCode -eq 200
    
    Test-Result -Success $success -Message "$ExpectedService - $Url (Status: $($result.StatusCode))"
    return $result
}

function Test-DockerContainer {
    param($ContainerName, $ServiceName)
    
    $status = docker ps --filter "name=$ContainerName" --filter "status=running" --format "{{.Status}}"
    $isRunning = [bool]$status
    
    Test-Result -Success $isRunning -Message "$ServiceName container - $(if($isRunning) {$status} else {'Not running'})"
    return $isRunning
}

function Get-ContainerLogs {
    param($ContainerName, $Lines = 10)
    
    try {
        return docker logs $ContainerName --tail $Lines 2>&1
    }
    catch {
        return "Could not retrieve logs: $($_.Exception.Message)"
    }
}

# --------------------------- TEST PHASES ------------------------------
function Test-PreFlight {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║             PRE-FLIGHT CHECKS             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Docker availability
    try {
        docker --version | Out-Null
        Test-Result -Success $true -Message "Docker is available"
    } catch {
        Test-Result -Success $false -Message "Docker not found"
        exit 1
    }
    
    try {
        docker-compose --version | Out-Null
        Test-Result -Success $true -Message "Docker Compose is available"
    } catch {
        Test-Result -Success $false -Message "Docker Compose not found"
    }
}

function Test-Containers {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            CONTAINER STATUS               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $containers = @(
        @{Name = "gateway"; Service = "Gateway"},
        @{Name = "feed-service"; Service = "Feed Service"},
        @{Name = "load-balancer"; Service = "Load Balancer"},
        @{Name = "prometheus"; Service = "Prometheus"},
        @{Name = "user-service-1"; Service = "User Service 1"},
        @{Name = "post-service-1"; Service = "Post Service 1"}
    )
    
    $allRunning = $true
    foreach ($container in $containers) {
        $isRunning = Test-DockerContainer -ContainerName $container.Name -ServiceName $container.Service
        if (-not $isRunning) { $allRunning = $false }
    }
    
    if (-not $allRunning) {
        Write-Warn "Some containers are not running. Attempting to restart..."
        docker-compose up -d 2>&1 | Out-Null
        Write-Host "Waiting 15 seconds for startup..." -NoNewline
        Start-Sleep -Seconds 15
        Write-Host " Done" -ForegroundColor Green
    }
    
    # Show container summary
    Write-Host "`nContainer Summary:" -ForegroundColor Yellow
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1 | Out-String | Write-Host
}

function Test-Gateway {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║               GATEWAY TESTS               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # HTTPS Health Check
    $healthResult = Test-Endpoint -Url "$GatewayHttps$HealthzPath" -ExpectedService "Gateway HTTPS Health"
    
    # HTTP Metrics
    $metricsResult = Test-Endpoint -Url "$GatewayHttp$MetricsPath" -ExpectedService "Gateway HTTP Metrics"
    if ($metricsResult.Success -and $metricsResult.Content -match "gateway_requests_total") {
        Write-Ok "Gateway metrics contain expected metrics"
    } elseif ($metricsResult.Success) {
        Write-Warn "Gateway metrics accessible but missing expected metrics"
    }
    
    # Check Gateway Logs for Errors
    Write-Host "`nGateway Logs (last 10 lines):" -ForegroundColor Yellow
    $gatewayLogs = Get-ContainerLogs -ContainerName "gateway" -Lines 10
    $gatewayLogs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Internal connectivity test
    Write-Host "`nInternal Connectivity:" -ForegroundColor Yellow
    try {
        $internalTest = docker exec gateway wget -q -O- http://localhost:8080/metrics 2>&1
        if ($internalTest -match "gateway_requests_total") {
            Write-Ok "Gateway internal HTTP server working"
        } else {
            Write-Err "Gateway internal HTTP server not responding correctly"
        }
    } catch {
        Write-Err "Gateway internal test failed: $($_.Exception.Message)"
    }
}

function Test-AuthenticationFlow {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           AUTHENTICATION FLOW             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $testEmail = "testuser_$timestamp@example.com"
    $testPassword = "TestPassword123!"
    
    # Registration
    Write-Host "Registration: " -NoNewline
    $registerBody = @{ email = $testEmail; password = $testPassword }
    $registerResult = Invoke-SafeWebRequest -Uri "$GatewayHttps$RegisterPath" -Method "POST" -Body $registerBody
    
    if ($registerResult.Success -and $registerResult.StatusCode -eq 201) {
        $registerData = $registerResult.Content | ConvertFrom-Json
        $Script:CurrentUserId = $registerData.user_id
        Write-Ok "User registered: $($Script:CurrentUserId)"
    } else {
        Write-Err "Registration failed: $($registerResult.Content)"
        return $false
    }
    
    # Login
    Write-Host "Login: " -NoNewline
    $loginBody = @{ email = $testEmail; password = $testPassword }
    $loginResult = Invoke-SafeWebRequest -Uri "$GatewayHttps$LoginPath" -Method "POST" -Body $loginBody
    
    if ($loginResult.Success -and $loginResult.StatusCode -eq 200) {
        $loginData = $loginResult.Content | ConvertFrom-Json
        $Script:CurrentToken = $loginData.access_token
        Write-Ok "Login successful (token length: $($Script:CurrentToken.Length))"
    } else {
        Write-Err "Login failed: $($loginResult.Content)"
        return $false
    }
    
    # Profile Access
    if ($Script:CurrentToken) {
        Write-Host "Profile Access: " -NoNewline
        $profileResult = Invoke-SafeWebRequest -Uri "$GatewayHttps$MePath" -Method "GET" -Headers @{ Authorization = "Bearer $Script:CurrentToken" }
        
        if ($profileResult.Success -and $profileResult.StatusCode -eq 200) {
            Write-Ok "Profile access successful"
        } else {
            Write-Warn "Profile access failed: $($profileResult.StatusCode)"
        }
    }
    
    return $true
}

function Test-FeedService {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║             FEED SERVICE TESTS            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Direct health check (if port is mapped)
    Write-Host "Direct Feed Service Health: " -NoNewline
    $directHealth = Invoke-SafeWebRequest -Uri "$FeedHost/health"
    if ($directHealth.Success) {
        Write-Ok "Direct access: $($directHealth.Content)"
    } else {
        Write-Warn "Direct access not available (port may not be mapped)"
    }
    
    # Through gateway
    if ($Script:CurrentToken) {
        Write-Host "Feed via Gateway: " -NoNewline
        $feedResult = Invoke-SafeWebRequest -Uri "$GatewayHttps$FeedPath" -Method "GET" -Headers @{ Authorization = "Bearer $Script:CurrentToken" }
        
        if ($feedResult.Success -and $feedResult.StatusCode -eq 200) {
            $feedData = $feedResult.Content | ConvertFrom-Json
            Write-Ok "Feed accessible - $($feedData.Count) posts"
            
            if ($feedData.Count -gt 0) {
                Write-Host "Sample post:" -ForegroundColor Cyan
                $feedData[0] | Format-List | Out-String | Write-Host
            }
        } else {
            Write-Warn "Feed access failed: $($feedResult.StatusCode) - $($feedResult.Content)"
        }
    } else {
        Write-Warn "Skipping feed test - no authentication token"
    }
    
    # Internal connectivity
    Write-Host "Internal Connectivity:" -ForegroundColor Yellow
    try {
        $internalHealth = docker exec feed-service wget -q -O- http://localhost:5000/health 2>&1
        if ($internalHealth) {
            Write-Ok "Feed service internal health: $internalHealth"
        } else {
            Write-Err "Feed service internal health check failed"
        }
    } catch {
        Write-Err "Feed service internal test failed"
    }
}

function Test-LoadBalancers {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            LOAD BALANCER TESTS            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # User Load Balancer
    Write-Host "User Load Balancer: " -NoNewline
    $userLBResult = Invoke-SafeWebRequest -Uri "$UserLB/health"
    if ($userLBResult.Success) {
        Write-Ok "User LB responding"
    } else {
        Write-Warn "User LB not accessible externally"
    }
    
    # Post Load Balancer
    Write-Host "Post Load Balancer: " -NoNewline
    $postLBResult = Invoke-SafeWebRequest -Uri "$PostLB/health"
    if ($postLBResult.Success) {
        Write-Ok "Post LB responding"
    } else {
        Write-Warn "Post LB not accessible externally"
    }
    
    # Internal connectivity from feed service
    Write-Host "Internal LB Connectivity from Feed Service:" -ForegroundColor Yellow
    try {
        $userLBInternal = docker exec feed-service wget -q -O- http://load-balancer:9001/health 2>&1
        $postLBInternal = docker exec feed-service wget -q -O- http://load-balancer:9002/health 2>&1
        
        if ($userLBInternal) { Write-Ok "  User LB internal: Accessible" } else { Write-Warn "  User LB internal: May not have /health endpoint" }
        if ($postLBInternal) { Write-Ok "  Post LB internal: Accessible" } else { Write-Warn "  Post LB internal: May not have /health endpoint" }
    } catch {
        Write-Warn "  Internal LB connectivity tests inconclusive"
    }
}

function Test-Prometheus {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║             PROMETHEUS TESTS              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Basic health
    Write-Host "Prometheus Health: " -NoNewline
    $healthResult = Invoke-SafeWebRequest -Uri "$Prometheus/-/healthy"
    if ($healthResult.Success) {
        Write-Ok "Healthy"
    } else {
        Write-Err "Unhealthy"
    }
    
    # Targets
    Write-Host "Prometheus Targets: " -NoNewline
    $targetsResult = Invoke-SafeWebRequest -Uri "$Prometheus/api/v1/targets"
    if ($targetsResult.Success) {
        $targetsData = $targetsResult.Content | ConvertFrom-Json
        $gatewayTarget = $targetsData.data.activeTargets | Where-Object { $_.labels.job -eq "gateway" }
        
        if ($gatewayTarget -and $gatewayTarget.health -eq "up") {
            Write-Ok "Gateway target UP"
        } else {
            Write-Err "Gateway target DOWN: $($gatewayTarget.lastError)"
        }
    } else {
        Write-Err "Could not fetch targets"
    }
    
    # Rules validation
    if ($FixRules) {
        Write-Host "Validating Rules: " -NoNewline
        $rulesPath = "prometheus/rules.yml"
        if (Test-Path $rulesPath) {
            try {
                $validation = docker run --rm -v "${PWD}/prometheus/rules.yml:/tmp/rules.yml" prom/prometheus:latest promtool check rules /tmp/rules.yml 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "Rules valid"
                } else {
                    Write-Err "Rules invalid: $validation"
                }
            } catch {
                Write-Err "Rules validation failed"
            }
        } else {
            Write-Warn "rules.yml not found"
        }
    }
    
    # Query metrics
    Write-Host "Metrics Queries:" -ForegroundColor Yellow
    $queries = @(
        @{Name = "Total Requests"; Query = "sum(gateway_requests_total)"},
        @{Name = "Requests by Method"; Query = "gateway:requests_by_method:total"},
        @{Name = "Average Latency"; Query = "gateway:request_latency:avg"}
    )
    
    foreach ($query in $queries) {
        Write-Host "  $($query.Name): " -NoNewline
        $result = Invoke-SafeWebRequest -Uri "$Prometheus/api/v1/query?query=$($query.Query)"
        if ($result.Success) {
            $data = $result.Content | ConvertFrom-Json
            if ($data.data.result.Count -gt 0) {
                Write-Ok "Data found ($($data.data.result.Count) results)"
            } else {
                Write-Warn "No data"
            }
        } else {
            Write-Err "Query failed"
        }
    }
}

function Generate-Traffic {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           TRAFFIC GENERATION              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    if ($TrafficCount -le 0) { return }
    
    Write-Host "Generating $TrafficCount requests to gateway..." -ForegroundColor Yellow
    $successCount = 0
    
    for ($i = 1; $i -le $TrafficCount; $i++) {
        $result = Invoke-SafeWebRequest -Uri "$GatewayHttps$HealthzPath" -Timeout 2
        if ($result.Success) { $successCount++ }
        
        if ($i % 10 -eq 0) {
            Write-Host "  Progress: $i/$TrafficCount" -ForegroundColor Gray
        }
    }
    
    $successRate = [math]::Round(($successCount / $TrafficCount) * 100, 1)
    Write-Host "Traffic Results: $successCount/$TrafficCount successful ($successRate%)" -ForegroundColor $(if ($successRate -ge 90) { "Green" } else { "Yellow" })
    
    # Wait for Prometheus to scrape
    Write-Host "Waiting 15 seconds for metrics collection..." -NoNewline
    Start-Sleep -Seconds 15
    Write-Host " Done" -ForegroundColor Green
}

function Show-DetailedDiagnostics {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║           DETAILED DIAGNOSTICS            ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Red
    
    # Gateway detailed check
    Write-Host "`n[Gateway Detailed Analysis]" -ForegroundColor Yellow
    Write-Host "Logs (last 15 lines):" -ForegroundColor Cyan
    Get-ContainerLogs -ContainerName "gateway" -Lines 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    Write-Host "`nProcesses:" -ForegroundColor Cyan
    try {
        docker exec gateway ps aux 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } catch {
        Write-Host "  Could not check processes" -ForegroundColor Red
    }
    
    # Feed Service detailed check
    Write-Host "`n[Feed Service Detailed Analysis]" -ForegroundColor Yellow
    Write-Host "Logs (last 15 lines):" -ForegroundColor Cyan
    Get-ContainerLogs -ContainerName "feed-service" -Lines 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Network connectivity
    Write-Host "`n[Network Connectivity]" -ForegroundColor Yellow
    $connections = @(
        @{From = "gateway"; To = "feed-service"; Port = 5000},
        @{From = "feed-service"; To = "load-balancer"; Port = 9001},
        @{From = "feed-service"; To = "load-balancer"; Port = 9002}
    )
    
    foreach ($conn in $connections) {
        Write-Host "  $($conn.From) → $($conn.To):$($conn.Port) " -NoNewline
        try {
            $test = docker exec $conn.From wget -q -O- "http://$($conn.To):$($conn.Port)/health" 2>$null
            if ($test) {
                Write-Host "✅" -ForegroundColor Green
            } else {
                Write-Host "❌" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌" -ForegroundColor Red
        }
    }
}

function Show-Summary {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║               FINAL SUMMARY               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $totalTests = $Script:TestResults.Passed + $Script:TestResults.Failed + $Script:TestResults.Warnings
    $passRate = if ($totalTests -gt 0) { [math]::Round(($Script:TestResults.Passed / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host "`nOVERALL RESULTS:" -ForegroundColor White
    Write-Host "  ✅ Passed:   $($Script:TestResults.Passed)" -ForegroundColor Green
    Write-Host "  ❌ Failed:   $($Script:TestResults.Failed)" -ForegroundColor $(if ($Script:TestResults.Failed -eq 0) { "Green" } else { "Red" })
    Write-Host "  ⚠️  Warnings: $($Script:TestResults.Warnings)" -ForegroundColor Yellow
    Write-Host "  📊 Total:    $totalTests tests" -ForegroundColor White
    Write-Host "  🎯 Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
    
    Write-Host "`nQUICK ACCESS LINKS:" -ForegroundColor White
    Write-Host "  🔍 Prometheus UI:        http://localhost:9090" -ForegroundColor Cyan
    Write-Host "  📈 Prometheus Targets:   http://localhost:9090/targets" -ForegroundColor Cyan
    Write-Host "  📋 Prometheus Rules:     http://localhost:9090/rules" -ForegroundColor Cyan
    Write-Host "  📊 Gateway Metrics:      http://localhost:8080/metrics" -ForegroundColor Cyan
    Write-Host "  🔐 Gateway API:          https://localhost:8443" -ForegroundColor Cyan
    Write-Host "  📱 User Service Direct:  http://localhost:8001" -ForegroundColor Cyan
    Write-Host "  📝 Post Service Direct:  http://localhost:8002" -ForegroundColor Cyan
    
    if ($Script:TestResults.Failed -gt 0) {
        Write-Host "`n🚨 ISSUES DETECTED:" -ForegroundColor Red
        Write-Host "  1. Check container logs: docker-compose logs <service>" -ForegroundColor White
        Write-Host "  2. Restart services: docker-compose restart" -ForegroundColor White
        Write-Host "  3. Full rebuild: docker-compose down && docker-compose up -d --build" -ForegroundColor White
        Write-Host "  4. Check feed service code for URL format issues" -ForegroundColor White
    }
    
    if ($Script:TestResults.Failed -eq 0 -and $Script:TestResults.Warnings -eq 0) {
        Write-Host "`n🎉 EXCELLENT! All systems are operational! 🎉" -ForegroundColor Green
    } elseif ($Script:TestResults.Failed -eq 0) {
        Write-Host "`n✅ System is functional with some warnings" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Critical issues need attention" -ForegroundColor Red
    }
}

# --------------------------- MAIN EXECUTION ---------------------------
Clear-Host
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "    MICROSERVICES STACK COMPREHENSIVE DIAGNOSTIC TOOL" -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "Starting comprehensive system check..." -ForegroundColor Yellow
Write-Host ""

# Execute test phases
Test-PreFlight

if (-not $QuickTest) {
    Test-Containers
    Test-Gateway
    Test-AuthenticationFlow
    Test-FeedService
    Test-LoadBalancers
    Test-Prometheus
    Generate-Traffic
    
    if ($Script:TestResults.Failed -gt 0) {
        Show-DetailedDiagnostics
    }
} else {
    Write-Host "`n⏩ Quick test mode - running basic checks only" -ForegroundColor Yellow
    Test-Containers
    Test-Gateway
}

Show-Summary


Write-Host "`nDiagnostic complete! 🚀" -ForegroundColor Cyan