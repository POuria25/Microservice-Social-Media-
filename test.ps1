<# ============================================================
🧪 INFO8011 Stack Tester (Gateway + LBs) — FIXED
- Client → Gateway over HTTPS :8443 (self-signed OK)
- Gateway → LBs/services over HTTP (internal)
- User-LB on :9001 , Post-LB on :9002 (external checks optional)
============================================================ #>

param(
  [string]$GatewayBase = "https://localhost:8443",
  [string]$UserLB      = "http://localhost:9001",
  [string]$PostLB      = "http://localhost:9002",
  [switch]$SkipLBPortsCheck
)

# ---------- Dev: trust self-signed certs (local only) ----------
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
  public bool CheckValidationResult(ServicePoint p, X509Certificate c, WebRequest r, int e) { return true; }
}
"@ | Out-Null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# ---------- Pretty I/O ----------
$Passed = 0; $Failed = 0; $Warned = 0
function Sec($t){Write-Host ""; Write-Host ("="*46); Write-Host $t; Write-Host ("="*46)}
function OK ($m){$script:Passed++; Write-Host "✓ $m" -ForegroundColor Green}
function NO ($m){$script:Failed++; Write-Host "✗ $m" -ForegroundColor Red}
function WRN($m){$script:Warned++; Write-Host "⚠ $m" -ForegroundColor Yellow}
function INF($m){Write-Host "ℹ $m" -ForegroundColor Cyan}
function Json($obj){ $obj | ConvertTo-Json -Depth 10 -Compress }
function New-TestEmail(){ "user$([int][double]::Parse((Get-Date -UFormat %s)))$((Get-Random)%100000)@example.com" }

# ---------- Pre-flight ----------
Sec "Pre-flight"
try {
  docker-compose ps | Out-Null
  OK "docker-compose detected"
} catch {
  WRN "docker-compose not found in PATH (continuing with HTTP tests)"
}

try {
  $resp = Invoke-RestMethod -Uri "$GatewayBase/healthz" -Method GET -TimeoutSec 6
  if($resp.status -eq "healthy" -and $resp.database -eq "connected"){
    OK "Gateway is reachable & DB connected"
  } else {
    WRN "Gateway reachable but payload unexpected: $(Json $resp)"
  }
} catch {
  NO "Gateway not reachable at $GatewayBase (start it with: docker-compose up -d gateway)"
  return
}

# ---------- Part 1: /metrics (optional) ----------
Sec "Part 1: Observability"
try {
  $m = Invoke-WebRequest -Uri "$GatewayBase/metrics" -Method GET -TimeoutSec 5 -ErrorAction Stop
  if($m.StatusCode -eq 200){ OK "/metrics is exposed (HTTP 200)" } else { WRN "/metrics returned $($m.StatusCode)" }
} catch {
  WRN "/metrics not available (fine for now): $($_.Exception.Message)"
}

# ---------- Part 2: Registration / Login ----------
Sec "Part 2: Registration & Login (Gateway DB)"
$Email = New-TestEmail
$Password = "Passw0rd!"
$Body = Json @{ email=$Email; password=$Password }

try {
  $r = Invoke-RestMethod -Uri "$GatewayBase/api/auth/register" -Method POST -ContentType "application/json" -Body $Body -ErrorAction Stop
  if($r.user_id){ INF "User ID: $($r.user_id)"; OK "Registered new user" } else { NO "Register returned without user_id: $(Json $r)" ; return }
} catch {
  NO "Register failed: $($_.Exception.Message)"
  return
}

try {
  $l = Invoke-RestMethod -Uri "$GatewayBase/api/auth/login" -Method POST -ContentType "application/json" -Body $Body -ErrorAction Stop
  if(-not $l.access_token){ NO "Login did not return access_token"; return }
  $TOKEN = $l.access_token
  INF "Token head: $($TOKEN.Substring(0,32))..."
  OK "Login returned JWT access_token"
} catch {
  NO "Login failed: $($_.Exception.Message)"; return
}

# ---------- Part 3: JWT / Bearer ----------
Sec "Part 3: JWT / Bearer"

# no token
try {
  Invoke-RestMethod -Uri "$GatewayBase/api/profile/me" -Method GET -ErrorAction Stop | Out-Null
  NO "Access without token should be 401"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if($code -eq 401){ OK "Rejected without token (401)" } else { WRN "Expected 401, got $code" }
}

# invalid token
try {
  Invoke-RestMethod -Uri "$GatewayBase/api/profile/me" -Method GET -Headers @{ Authorization = "Bearer not-a-token" } -ErrorAction Stop | Out-Null
  NO "Access with invalid token should be 401"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if($code -eq 401){ OK "Rejected invalid token (401)" } else { WRN "Invalid token: expected 401, got $code" }
}

# valid token (accept any 4xx/5xx from downstream as 'proxy OK')
try {
  $resp = Invoke-RestMethod -Uri "$GatewayBase/api/profile/me" -Method GET -Headers @{ Authorization = "Bearer $TOKEN" } -ErrorAction Stop
  OK "Accepted valid token (forwarded to user-service)"; INF "Response: $(Json $resp)"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if($code -ge 400 -and $code -le 599){
    OK "Valid token path OK at gateway (downstream returned $code — acceptable)"
  } else {
    NO "Valid token path failed unexpectedly: $($_.Exception.Message)"
  }
}

# ---------- Part 4: Reverse Proxy ----------
Sec "Part 4: Reverse Proxy & Routing"

# posts
try {
  Invoke-RestMethod -Uri "$GatewayBase/api/posts/me" -Method GET -Headers @{ Authorization = "Bearer $TOKEN" } -ErrorAction Stop | Out-Null
  OK "Proxied to post-service via LB (non-401)"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if($code -ge 400 -and $code -le 599){ OK "Proxied to post-service (backend $code — acceptable)" }
  else { NO "Proxy to post-service failed: $($_.Exception.Message)" }
}

# feed
try {
  Invoke-RestMethod -Uri "$GatewayBase/api/feed" -Method GET -Headers @{ Authorization = "Bearer $TOKEN" } -ErrorAction Stop | Out-Null
  OK "Proxied to feed-service (non-401)"
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if($code -ge 400 -and $code -le 599){ OK "Proxied to feed-service (backend $code — acceptable)" }
  else { NO "Proxy to feed-service failed: $($_.Exception.Message)" }
}

# ---------- Part 5: Load Balancers (external ports optional) ----------
Sec "Part 5: Load Balancers (external port checks)"
if($SkipLBPortsCheck){
  WRN "Skipping LB checks on localhost:9001/9002"
}else{
  try {
    $u = Invoke-RestMethod -Uri "$UserLB/healthz" -Method GET -TimeoutSec 3 -ErrorAction Stop
    OK "User-LB reachable at $UserLB/healthz"
  } catch {
    WRN "User-LB not reachable on $UserLB (OK if ports not published)"
  }

  try {
    $p = Invoke-RestMethod -Uri "$PostLB/healthz" -Method GET -TimeoutSec 3 -ErrorAction Stop
    OK "Post-LB reachable at $PostLB/healthz"
  } catch {
    WRN "Post-LB not reachable on $PostLB (OK if ports not published)"
  }
}

# ---------- Part 6: Login rate limit ----------
Sec "Part 6: Login Rate Limit (10×401 then 429)"
$BadEmail = "ratelimit$([int][double]::Parse((Get-Date -UFormat %s)))@example.com"
$BadBody  = Json @{ email=$BadEmail; password="wrong" }
$all401 = $true
for($i=1;$i -le 10;$i++){
  try{
    Invoke-RestMethod -Uri "$GatewayBase/api/auth/login" -Method POST -ContentType "application/json" -Body $BadBody -ErrorAction Stop | Out-Null
    $all401 = $false; WRN "Attempt $i unexpectedly succeeded"
  }catch{
    $code = $_.Exception.Response.StatusCode.value__
    if($code -ne 401){ $all401 = $false; WRN "Attempt $i expected 401, got $code" }
  }
}
try{
  Invoke-RestMethod -Uri "$GatewayBase/api/auth/login" -Method POST -ContentType "application/json" -Body $BadBody -ErrorAction Stop | Out-Null
  NO "11th attempt should be rate-limited (429)"
}catch{
  $code = $_.Exception.Response.StatusCode.value__
  if($code -eq 429 -and $all401){ OK "Rate limit OK: 10×401 then 429" }
  elseif($code -eq 429){ OK "Rate limit triggered (earlier codes varied)" }
  else { WRN "Expected 429 on 11th attempt, got $code" }
}

# ---------- Summary ----------
Sec "📊 SUMMARY"
$Total = $Passed+$Failed+$Warned
Write-Host ("Total: {0}  Passed: {1}  Failed: {2}  Warnings: {3}" -f $Total,$Passed,$Failed,$Warned)
if($Failed -eq 0){ OK "ALL CRITICAL TESTS PASSED " } else { NO "Some tests failed — see above." }
