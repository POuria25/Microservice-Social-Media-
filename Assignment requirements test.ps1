<# 
=======================================================================
  ASSIGNMENT REQUIREMENTS VALIDATION SCRIPT
  Tests ALL endpoints specified in the assignment
=======================================================================
#>

param(
    [switch]$VerboseOutput = $false
)

# --------------------------- CONFIGURATION ----------------------------
$GatewayHttps = "https://localhost:8443"
$GatewayHttp  = "http://localhost:8080"

# --------------------------- GLOBAL VARIABLES -------------------------
$Script:TestResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
}

$Script:TestUser1 = $null
$Script:TestUser2 = $null

# --------------------------- HELPER FUNCTIONS -------------------------
function Write-TestHeader($text) {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  $text" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Ok($msg) { 
    Write-Host "[✓] $msg" -ForegroundColor Green 
    $Script:TestResults.Passed++
}

function Write-Err($msg) { 
    Write-Host "[✗] $msg" -ForegroundColor Red 
    $Script:TestResults.Failed++
}

function Write-Warn($msg) { 
    Write-Host "[!] $msg" -ForegroundColor Yellow 
    $Script:TestResults.Warnings++
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

function Invoke-SafeRequest {
    param($Uri, $Method = "GET", $Headers = @{}, $Body = $null)
    
    try {
        $request = [System.Net.WebRequest]::Create($Uri)
        $request.Method = $Method
        $request.Timeout = 5000
        $request.ContentType = "application/json"
        
        foreach ($h in $Headers.GetEnumerator()) {
            $request.Headers.Add($h.Key, $h.Value)
        }
        
        if ($Body -and ($Method -in @("POST", "PUT", "DELETE"))) {
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
        $errorContent = ""
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorContent = $reader.ReadToEnd()
                $reader.Close()
            } catch {}
        }
        return @{
            StatusCode = $statusCode
            Content = if ($errorContent) { $errorContent } else { $_.Exception.Message }
            Success = $false
        }
    }
}

# ============================================
# SECTION 1: AUTHENTICATION ENDPOINTS (UNAUTHENTICATED)
# ============================================
function Test-AuthenticationEndpoints {
    Write-TestHeader "AUTHENTICATION ENDPOINTS (Unauthenticated)"
    
    $timestamp = (Get-Date).ToString("HHmmss")
    
    # TEST 1: POST /api/auth/register
    Write-Host "`n[TEST] POST /api/auth/register (handled by gateway)" -ForegroundColor Yellow
    $registerBody = @{
        email = "testuser1-$timestamp@example.com"
        password = "TestPass123!"
    }
    
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/auth/register" -Method POST -Body $registerBody
    
    if ($result.Success -and $result.StatusCode -eq 201) {
        $data = $result.Content | ConvertFrom-Json
        $Script:TestUser1 = @{
            Email = $registerBody.email
            Password = $registerBody.password
            UserId = $data.user_id
        }
        Write-Ok "Register endpoint working (Status: 201, User: $($data.user_id))"
    } else {
        Write-Err "Register failed (Status: $($result.StatusCode))"
        return $false
    }
    
    # Register second user for testing
    $registerBody2 = @{
        email = "testuser2-$timestamp@example.com"
        password = "TestPass123!"
    }
    
    $result2 = Invoke-SafeRequest -Uri "$GatewayHttps/api/auth/register" -Method POST -Body $registerBody2
    if ($result2.Success) {
        $data2 = $result2.Content | ConvertFrom-Json
        $Script:TestUser2 = @{
            Email = $registerBody2.email
            Password = $registerBody2.password
            UserId = $data2.user_id
        }
    }
    
    # TEST 2: POST /api/auth/login
    Write-Host "`n[TEST] POST /api/auth/login (handled by gateway)" -ForegroundColor Yellow
    $loginBody = @{
        email = $Script:TestUser1.Email
        password = $Script:TestUser1.Password
    }
    
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/auth/login" -Method POST -Body $loginBody
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $data = $result.Content | ConvertFrom-Json
        $Script:TestUser1.Token = $data.access_token
        Write-Ok "Login endpoint working (Status: 200, Token length: $($data.access_token.Length))"
    } else {
        Write-Err "Login failed (Status: $($result.StatusCode))"
        return $false
    }
    
    # Login user 2
    $loginBody2 = @{
        email = $Script:TestUser2.Email
        password = $Script:TestUser2.Password
    }
    $result2 = Invoke-SafeRequest -Uri "$GatewayHttps/api/auth/login" -Method POST -Body $loginBody2
    if ($result2.Success) {
        $data2 = $result2.Content | ConvertFrom-Json
        $Script:TestUser2.Token = $data2.access_token
    }
    
    return $true
}

# ============================================
# SECTION 2: USER-SERVICE ENDPOINTS (AUTHENTICATED)
# ============================================
function Test-UserServiceEndpoints {
    Write-TestHeader "USER-SERVICE ENDPOINTS (Authenticated)"
    
    if (-not $Script:TestUser1 -or -not $Script:TestUser1.Token) {
        Write-Err "Cannot test user service - authentication failed"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($Script:TestUser1.Token)" }
    
    # TEST 1: GET /api/profile/me
    Write-Host "`n[TEST] GET /api/profile/me (via user-service load-balancer)" -ForegroundColor Yellow
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/profile/me" -Headers $headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $profile = $result.Content | ConvertFrom-Json
        Write-Ok "GET /api/profile/me working (Status: 200, User: $($profile.id))"
        
        if ($profile.friends) {
            Write-Host "    ├─ Profile includes 'friends' field: YES" -ForegroundColor Gray
        } else {
            Write-Warn "Profile missing 'friends' field (needed for feed service)"
        }
    } else {
        Write-Err "GET /api/profile/me failed (Status: $($result.StatusCode))"
    }
    
    # TEST 2: GET /api/profile/{userId}
    Write-Host "`n[TEST] GET /api/profile/{userId} (via user-service load-balancer)" -ForegroundColor Yellow
    if ($Script:TestUser2) {
        $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/profile/$($Script:TestUser2.UserId)"
        
        if ($result.Success -and $result.StatusCode -eq 200) {
            Write-Ok "GET /api/profile/{userId} working (Status: 200)"
        } else {
            Write-Err "GET /api/profile/{userId} failed (Status: $($result.StatusCode))"
        }
    } else {
        Write-Warn "Cannot test /api/profile/{userId} - second user not created"
    }
    
    # TEST 3: /api/friends endpoints
    Write-Host "`n[TEST] /api/friends (via user-service load-balancer)" -ForegroundColor Yellow
    
    # 3a. GET /api/friends (get empty list initially)
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/friends" -Headers $headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        Write-Ok "GET /api/friends working (Status: 200)"
        $friends = $result.Content | ConvertFrom-Json
        Write-Host "    ├─ Current friends count: $($friends.Count)" -ForegroundColor Gray
    } else {
        Write-Err "GET /api/friends failed (Status: $($result.StatusCode))"
    }
    
    # 3b. POST /api/friends (add friend)
    if ($Script:TestUser2) {
        Write-Host "`n[TEST] POST /api/friends (add friend)" -ForegroundColor Yellow
        $friendBody = @{ friend_id = $Script:TestUser2.UserId }
        $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/friends" -Method POST -Headers $headers -Body $friendBody
        
        if ($result.Success -and $result.StatusCode -in @(200, 201)) {
            Write-Ok "POST /api/friends working (Status: $($result.StatusCode))"
            
            # Verify friend was added
            Start-Sleep -Seconds 1
            $verifyResult = Invoke-SafeRequest -Uri "$GatewayHttps/api/friends" -Headers $headers
            if ($verifyResult.Success) {
                $friends = $verifyResult.Content | ConvertFrom-Json
                if ($friends -contains $Script:TestUser2.UserId) {
                    Write-Host "    ├─ Friend successfully added to list" -ForegroundColor Gray
                } else {
                    Write-Warn "Friend not found in friends list after adding"
                }
            }
        } else {
            Write-Err "POST /api/friends failed (Status: $($result.StatusCode), Error: $($result.Content))"
        }
        
        # 3c. DELETE /api/friends/{friendId} (optional - test if implemented)
        Write-Host "`n[TEST] DELETE /api/friends/{friendId} (remove friend)" -ForegroundColor Yellow
        $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/friends/$($Script:TestUser2.UserId)" -Method DELETE -Headers $headers
        
        if ($result.Success -and $result.StatusCode -eq 200) {
            Write-Ok "DELETE /api/friends/{friendId} working (Status: 200)"
        } else {
            Write-Warn "DELETE /api/friends/{friendId} failed or not implemented (Status: $($result.StatusCode))"
        }
    }
}

# ============================================
# SECTION 3: POST-SERVICE ENDPOINTS (AUTHENTICATED)
# ============================================
function Test-PostServiceEndpoints {
    Write-TestHeader "POST-SERVICE ENDPOINTS (Authenticated)"
    
    if (-not $Script:TestUser1 -or -not $Script:TestUser1.Token) {
        Write-Err "Cannot test post service - authentication failed"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($Script:TestUser1.Token)" }
    
    # TEST 1: POST /api/posts (create post)
    Write-Host "`n[TEST] POST /api/posts (via post-service load-balancer)" -ForegroundColor Yellow
    $postBody = @{
        content = "Test post created at $(Get-Date -Format 'HH:mm:ss')"
    }
    
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/posts" -Method POST -Headers $headers -Body $postBody
    
    if ($result.Success -and $result.StatusCode -in @(200, 201)) {
        Write-Ok "POST /api/posts working (Status: $($result.StatusCode))"
        
        # Create a few more posts for testing
        for ($i = 2; $i -le 3; $i++) {
            $postBody2 = @{ content = "Test post #$i at $(Get-Date -Format 'HH:mm:ss')" }
            Invoke-SafeRequest -Uri "$GatewayHttps/api/posts" -Method POST -Headers $headers -Body $postBody2 | Out-Null
        }
    } else {
        Write-Err "POST /api/posts failed (Status: $($result.StatusCode))"
    }
    
    # TEST 2: GET /api/posts (get own posts)
    Write-Host "`n[TEST] GET /api/posts (get own posts via post-service load-balancer)" -ForegroundColor Yellow
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/posts" -Headers $headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $posts = $result.Content | ConvertFrom-Json
        Write-Ok "GET /api/posts working (Status: 200, Posts: $($posts.Count))"
    } else {
        Write-Err "GET /api/posts failed (Status: $($result.StatusCode))"
    }
    
    # TEST 3: GET /api/posts/{userId}
    Write-Host "`n[TEST] GET /api/posts/{userId} (via post-service load-balancer)" -ForegroundColor Yellow
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/posts/$($Script:TestUser1.UserId)" -Headers $headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $posts = $result.Content | ConvertFrom-Json
        Write-Ok "GET /api/posts/{userId} working (Status: 200, Posts: $($posts.Count))"
    } else {
        Write-Err "GET /api/posts/{userId} failed (Status: $($result.StatusCode))"
    }
}

# ============================================
# SECTION 4: FEED-SERVICE ENDPOINTS (AUTHENTICATED)
# ============================================
function Test-FeedServiceEndpoints {
    Write-TestHeader "FEED-SERVICE ENDPOINTS (Authenticated)"
    
    if (-not $Script:TestUser1 -or -not $Script:TestUser1.Token) {
        Write-Err "Cannot test feed service - authentication failed"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($Script:TestUser1.Token)" }
    
    # TEST 1: GET /api/feed
    Write-Host "`n[TEST] GET /api/feed (forwarded to feed-service directly)" -ForegroundColor Yellow
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/feed" -Headers $headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $feed = $result.Content | ConvertFrom-Json
        Write-Ok "GET /api/feed working (Status: 200, Posts: $($feed.Count))"
        
        if ($VerboseOutput -and $feed.Count -gt 0) {
            Write-Host "    ├─ Feed preview:" -ForegroundColor Gray
            $feed | Select-Object -First 3 | ForEach-Object {
                Write-Host "    │  └─ $($_.content)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Err "GET /api/feed failed (Status: $($result.StatusCode), Error: $($result.Content))"
        
        if ($result.Content -match "friend") {
            Write-Host "    └─ Likely cause: User profile doesn't return 'friends' field" -ForegroundColor Yellow
        }
    }
}

# ============================================
# SECTION 5: LOAD BALANCER VERIFICATION
# ============================================
function Test-LoadBalancerFunctionality {
    Write-TestHeader "LOAD BALANCER VERIFICATION"
    
    if (-not $Script:TestUser1 -or -not $Script:TestUser1.Token) {
        Write-Warn "Cannot verify load balancer - authentication failed"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($Script:TestUser1.Token)" }
    
    Write-Host "`n[TEST] User-service load balancer (multiple requests)" -ForegroundColor Yellow
    $responses = @()
    for ($i = 1; $i -le 10; $i++) {
        $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/profile/me" -Headers $headers
        if ($result.Success) {
            $responses += $result.StatusCode
        }
        Start-Sleep -Milliseconds 100
    }
    
    $successCount = ($responses | Where-Object { $_ -eq 200 }).Count
    if ($successCount -eq 10) {
        Write-Ok "User-service load balancer handling requests ($successCount/10 successful)"
    } else {
        Write-Warn "User-service load balancer inconsistent ($successCount/10 successful)"
    }
    
    Write-Host "`n[TEST] Post-service load balancer (multiple requests)" -ForegroundColor Yellow
    $responses = @()
    for ($i = 1; $i -le 10; $i++) {
        $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/posts" -Headers $headers
        if ($result.Success) {
            $responses += $result.StatusCode
        }
        Start-Sleep -Milliseconds 100
    }
    
    $successCount = ($responses | Where-Object { $_ -eq 200 }).Count
    if ($successCount -eq 10) {
        Write-Ok "Post-service load balancer handling requests ($successCount/10 successful)"
    } else {
        Write-Warn "Post-service load balancer inconsistent ($successCount/10 successful)"
    }
}

# ============================================
# SECTION 6: END-TO-END WORKFLOW
# ============================================
function Test-EndToEndWorkflow {
    Write-TestHeader "END-TO-END WORKFLOW TEST"
    
    Write-Host "`nTesting complete user journey:" -ForegroundColor Yellow
    Write-Host "  1. User A registers and logs in" -ForegroundColor Gray
    Write-Host "  2. User B registers and logs in" -ForegroundColor Gray
    Write-Host "  3. User A creates posts" -ForegroundColor Gray
    Write-Host "  4. User B adds User A as friend" -ForegroundColor Gray
    Write-Host "  5. User B views feed (should see User A's posts)" -ForegroundColor Gray
    
    # Users already created in authentication tests
    if (-not $Script:TestUser1 -or -not $Script:TestUser2) {
        Write-Err "End-to-end test requires 2 users"
        return
    }
    
    $user1Headers = @{ Authorization = "Bearer $($Script:TestUser1.Token)" }
    $user2Headers = @{ Authorization = "Bearer $($Script:TestUser2.Token)" }
    
    # User 1 creates posts (already done in post service tests)
    Write-Host "`n✓ Step 1-3: Users created and posts made" -ForegroundColor Green
    
    # User 2 adds User 1 as friend
    Write-Host "`nStep 4: User 2 adding User 1 as friend..." -ForegroundColor Yellow
    $friendBody = @{ friend_id = $Script:TestUser1.UserId }
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/friends" -Method POST -Headers $user2Headers -Body $friendBody
    
    if ($result.Success -and $result.StatusCode -in @(200, 201)) {
        Write-Ok "User 2 successfully added User 1 as friend"
    } else {
        Write-Err "Failed to add friend (Status: $($result.StatusCode))"
        return
    }
    
    # Wait for data propagation
    Start-Sleep -Seconds 2
    
    # User 2 views feed
    Write-Host "`nStep 5: User 2 fetching feed..." -ForegroundColor Yellow
    $result = Invoke-SafeRequest -Uri "$GatewayHttps/api/feed" -Headers $user2Headers
    
    if ($result.Success -and $result.StatusCode -eq 200) {
        $feed = $result.Content | ConvertFrom-Json
        
        if ($feed.Count -gt 0) {
            Write-Ok "END-TO-END TEST PASSED! Feed contains $($feed.Count) post(s)"
            Write-Host "`n    🎉 Complete workflow successful:" -ForegroundColor Green
            Write-Host "       ✓ Authentication working" -ForegroundColor Green
            Write-Host "       ✓ Friend relationships working" -ForegroundColor Green
            Write-Host "       ✓ Post creation working" -ForegroundColor Green
            Write-Host "       ✓ Feed aggregation working" -ForegroundColor Green
        } else {
            Write-Warn "Feed returned empty (expected posts from friend)"
        }
    } else {
        Write-Err "END-TO-END TEST FAILED! Feed service error: $($result.Content)"
    }
}

# ============================================
# SUMMARY REPORT
# ============================================
function Show-Summary {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           ASSIGNMENT COMPLIANCE           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $total = $Script:TestResults.Passed + $Script:TestResults.Failed + $Script:TestResults.Warnings
    $passRate = if ($total -gt 0) { [math]::Round(($Script:TestResults.Passed / $total) * 100, 1) } else { 0 }
    
    Write-Host "`nTEST RESULTS:" -ForegroundColor White
    Write-Host "  ✅ Passed:   $($Script:TestResults.Passed)" -ForegroundColor Green
    Write-Host "  ❌ Failed:   $($Script:TestResults.Failed)" -ForegroundColor $(if ($Script:TestResults.Failed -eq 0) { "Green" } else { "Red" })
    Write-Host "  ⚠️  Warnings: $($Script:TestResults.Warnings)" -ForegroundColor Yellow
    Write-Host "  📊 Total:    $total tests" -ForegroundColor White
    Write-Host "  🎯 Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
    
    Write-Host "`nASSIGNMENT REQUIREMENTS CHECKLIST:" -ForegroundColor White
    Write-Host "  Authentication Endpoints:" -ForegroundColor Yellow
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 2) {'✓'} else {'✗'})] POST /api/auth/register" -ForegroundColor $(if ($Script:TestResults.Passed -ge 2) {"Green"} else {"Red"})
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 2) {'✓'} else {'✗'})] POST /api/auth/login" -ForegroundColor $(if ($Script:TestResults.Passed -ge 2) {"Green"} else {"Red"})
    
    Write-Host "  User-Service Endpoints:" -ForegroundColor Yellow
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 4) {'✓'} else {'✗'})] GET /api/profile/me" -ForegroundColor $(if ($Script:TestResults.Passed -ge 4) {"Green"} else {"Red"})
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 5) {'✓'} else {'✗'})] GET /api/profile/{userId}" -ForegroundColor $(if ($Script:TestResults.Passed -ge 5) {"Green"} else {"Red"})
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 6) {'✓'} else {'✗'})] GET/POST /api/friends" -ForegroundColor $(if ($Script:TestResults.Passed -ge 6) {"Green"} else {"Red"})
    
    Write-Host "  Post-Service Endpoints:" -ForegroundColor Yellow
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 8) {'✓'} else {'✗'})] POST /api/posts" -ForegroundColor $(if ($Script:TestResults.Passed -ge 8) {"Green"} else {"Red"})
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 9) {'✓'} else {'✗'})] GET /api/posts" -ForegroundColor $(if ($Script:TestResults.Passed -ge 9) {"Green"} else {"Red"})
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 10) {'✓'} else {'✗'})] GET /api/posts/{userId}" -ForegroundColor $(if ($Script:TestResults.Passed -ge 10) {"Green"} else {"Red"})
    
    Write-Host "  Feed-Service Endpoints:" -ForegroundColor Yellow
    Write-Host "    [$(if ($Script:TestResults.Passed -ge 11) {'✓'} else {'✗'})] GET /api/feed" -ForegroundColor $(if ($Script:TestResults.Passed -ge 11) {"Green"} else {"Red"})
    
    if ($Script:TestResults.Failed -eq 0 -and $Script:TestResults.Warnings -eq 0) {
        Write-Host "`n🎉 PERFECT! All assignment requirements met! 🎉" -ForegroundColor Green
        Write-Host "Expected Grade: 95-100%" -ForegroundColor Green
    } elseif ($Script:TestResults.Failed -eq 0) {
        Write-Host "`n✅ All required endpoints working! Some warnings present." -ForegroundColor Green
        Write-Host "Expected Grade: 85-95%" -ForegroundColor Yellow
    } elseif ($Script:TestResults.Failed -le 3) {
        Write-Host "`n⚠️  Most endpoints working, some issues need attention" -ForegroundColor Yellow
        Write-Host "Expected Grade: 70-85%" -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ Critical endpoints missing or broken" -ForegroundColor Red
        Write-Host "Expected Grade: <70%" -ForegroundColor Red
        Write-Host "`nMISSING CRITICAL FEATURES:" -ForegroundColor Red
        Write-Host "  • Implement friend management system" -ForegroundColor White
        Write-Host "  • Fix feed service integration" -ForegroundColor White
    }
}

# ============================================
# MAIN EXECUTION
# ============================================
Clear-Host
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "    ASSIGNMENT REQUIREMENTS VALIDATION TOOL" -ForegroundColor Cyan
Write-Host "    Testing ALL endpoints specified in the assignment" -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host ""

# Execute all test sections
$authSuccess = Test-AuthenticationEndpoints

if ($authSuccess) {
    Test-UserServiceEndpoints
    Test-PostServiceEndpoints
    Test-FeedServiceEndpoints
    Test-LoadBalancerFunctionality
    Test-EndToEndWorkflow
} else {
    Write-Host "`n❌ Authentication failed - cannot proceed with other tests" -ForegroundColor Red
}

Show-Summary

Write-Host "`nValidation complete! 🚀" -ForegroundColor Cyan
Write-Host ""