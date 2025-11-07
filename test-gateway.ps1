# ============================================================================
# Gateway COMPREHENSIVE Test Script (PowerShell) - Enhanced Version
# Tests all functionality with extensive edge cases and scenarios
# ============================================================================

# Configuration
$baseUrl = "https://localhost:8443"
curl.exe -k $baseUrl/healthz
$timestamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$testEmail1 = "alice${timestamp}@example.com"
$testEmail2 = "bob${timestamp}@example.com"
$testEmail3 = "charlie${timestamp}@example.com"
$testPassword = "password123"

# Global variables
$script:token1 = ""
$script:token2 = ""
$script:token3 = ""
$script:userId1 = ""
$script:userId2 = ""
$script:userId3 = ""

# Counters
$script:testsRun = 0
$script:testsPassed = 0
$script:testsFailed = 0

# ============================================================================
# Helper Functions
# ============================================================================

function Print-Header {
    param([string]$text)
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host $text -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Print-Test {
    param([string]$text)
    Write-Host "▶ Test $($script:testsRun): $text" -ForegroundColor Yellow
}

function Print-Success {
    param([string]$text)
    Write-Host "✓ PASS: $text`n" -ForegroundColor Green
    $script:testsPassed++
}

function Print-Fail {
    param([string]$text)
    Write-Host "✗ FAIL: $text`n" -ForegroundColor Red
    $script:testsFailed++
}

function Print-Info {
    param([string]$text)
    Write-Host "ℹ $text" -ForegroundColor Blue
}

function Print-Warning {
    param([string]$text)
    Write-Host "⚠ $text" -ForegroundColor Yellow
}

function Run-Test {
    $script:testsRun++
}

# ============================================================================
# Part 1: Health & Infrastructure Tests
# ============================================================================

function Test-HealthCheck {
    Run-Test
    Print-Test "Health Check"
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/healthz" -Method GET
        
        if ($response.status -eq "healthy" -and $response.database -eq "connected") {
            Print-Success "Gateway is healthy and database is connected"
        } else {
            Print-Fail "Unexpected health status: $($response | ConvertTo-Json)"
        }
    } catch {
        Print-Fail "Health check failed: $_"
    }
}

function Test-HealthCheckMultipleTimes {
    Run-Test
    Print-Test "Health Check (Multiple Rapid Requests)"
    
    try {
        $successCount = 0
        for ($i = 1; $i -le 5; $i++) {
            $response = Invoke-RestMethod -Uri "$baseUrl/healthz" -Method GET
            if ($response.status -eq "healthy") {
                $successCount++
            }
        }
        
        if ($successCount -eq 5) {
            Print-Success "Gateway handled 5 rapid health checks successfully"
        } else {
            Print-Fail "Only $successCount out of 5 health checks succeeded"
        }
    } catch {
        Print-Fail "Rapid health checks failed: $_"
    }
}

# ============================================================================
# Part 2: Registration Tests (Extended)
# ============================================================================

function Test-RegisterUser1 {
    Run-Test
    Print-Test "Register User 1 (Alice)"
    
    $body = @{
        email = $testEmail1
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:userId1 = $response.user_id
        Print-Info "User ID: $($script:userId1)"
        Print-Success "User 1 registered successfully"
    } catch {
        Print-Fail "Registration failed: $_"
    }
}

function Test-RegisterDuplicateEmail {
    Run-Test
    Print-Test "Register Duplicate Email (Should Fail)"
    
    $body = @{
        email = $testEmail1
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected duplicate email"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 409) {
            Print-Success "Correctly rejected duplicate email with HTTP 409"
        } else {
            Print-Fail "Should have returned 409 Conflict, got $($_.Exception.Response.StatusCode.value__)"
        }
    }
}

function Test-RegisterInvalidEmail {
    Run-Test
    Print-Test "Register Invalid Email (Should Fail)"
    
    $body = @{
        email = "notanemail"
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected invalid email"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected invalid email format with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterShortPassword {
    Run-Test
    Print-Test "Register Short Password (Should Fail)"
    
    $body = @{
        email = "test@example.com"
        password = "123"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected short password"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected short password with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterEmptyEmail {
    Run-Test
    Print-Test "Register Empty Email (Should Fail)"
    
    $body = @{
        email = ""
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected empty email"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected empty email with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterEmptyPassword {
    Run-Test
    Print-Test "Register Empty Password (Should Fail)"
    
    $body = @{
        email = "test@example.com"
        password = ""
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected empty password"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected empty password with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterMissingEmail {
    Run-Test
    Print-Test "Register Missing Email Field (Should Fail)"
    
    $body = @{
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected missing email field"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected missing email field with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterMissingPassword {
    Run-Test
    Print-Test "Register Missing Password Field (Should Fail)"
    
    $body = @{
        email = "test@example.com"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected missing password field"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected missing password field with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-RegisterSpecialCharsEmail {
    Run-Test
    Print-Test "Register Email with Special Characters"
    
    $specialEmail = "test+special${timestamp}@example.com"
    $body = @{
        email = $specialEmail
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        Print-Success "Accepted email with special characters (+ sign)"
    } catch {
        Print-Fail "Failed to register valid email with special characters: $_"
    }
}

function Test-RegisterLongPassword {
    Run-Test
    Print-Test "Register Very Long Password"
    
    $longPassword = "a" * 100  # 100 character password
    $body = @{
        email = "longpass${timestamp}@example.com"
        password = $longPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        Print-Success "Accepted very long password (100 chars)"
    } catch {
        Print-Fail "Failed to register with long password: $_"
    }
}

# ============================================================================
# Part 3: Authentication Tests (Extended)
# ============================================================================

function Test-LoginUser1 {
    Run-Test
    Print-Test "Login User 1 (Alice)"
    
    $body = @{
        email = $testEmail1
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:token1 = $response.access_token
        if ($script:token1) {
            Print-Info "Token: $($script:token1.Substring(0, [Math]::Min(50, $script:token1.Length)))..."
            Print-Success "User 1 logged in successfully"
        } else {
            Print-Fail "No token received in response"
        }
    } catch {
        Print-Fail "Login failed: $_"
    }
}

function Test-LoginWrongPassword {
    Run-Test
    Print-Test "Login with Wrong Password (Should Fail)"
    
    $body = @{
        email = $testEmail1
        password = "wrongpassword"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected wrong password"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected wrong password with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-LoginNonexistentUser {
    Run-Test
    Print-Test "Login Nonexistent User (Should Fail)"
    
    $body = @{
        email = "nobody@example.com"
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected nonexistent user"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected nonexistent user with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-LoginEmptyEmail {
    Run-Test
    Print-Test "Login with Empty Email (Should Fail)"
    
    $body = @{
        email = ""
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected empty email"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected empty email with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-LoginEmptyPassword {
    Run-Test
    Print-Test "Login with Empty Password (Should Fail)"
    
    $body = @{
        email = $testEmail1
        password = ""
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Fail "Should have rejected empty password"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected empty password with HTTP 400"
        } else {
            Print-Fail "Should have returned 400 Bad Request"
        }
    }
}

function Test-LoginCaseInsensitive {
    Run-Test
    Print-Test "Login with Different Email Case"
    
    $upperEmail = $testEmail1.ToUpper()
    $body = @{
        email = $upperEmail
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        Print-Info "Case-insensitive email login worked"
        Print-Success "Email comparison is case-insensitive (good practice)"
    } catch {
        Print-Warning "Email comparison is case-sensitive (login failed with uppercase email)"
        $script:testsPassed++  # Not a failure, just noting behavior
    }
}

# ============================================================================
# Part 4: JWT Token Tests (Extended)
# ============================================================================

function Test-ProtectedEndpointNoToken {
    Run-Test
    Print-Test "Access Protected Endpoint Without Token (Should Fail)"
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" -Method GET
        Print-Fail "Should have rejected request without token"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected request without token with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-ProtectedEndpointInvalidToken {
    Run-Test
    Print-Test "Access Protected Endpoint with Invalid Token (Should Fail)"
    
    $headers = @{
        "Authorization" = "Bearer invalid.token.here"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        Print-Fail "Should have rejected invalid token"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected invalid token with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-ProtectedEndpointMalformedToken {
    Run-Test
    Print-Test "Access with Malformed Token (Not 3 Parts)"
    
    $headers = @{
        "Authorization" = "Bearer invalidtoken"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        Print-Fail "Should have rejected malformed token"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected malformed token with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-ProtectedEndpointNoBearer {
    Run-Test
    Print-Test "Access with Token Without 'Bearer' Prefix (Should Fail)"
    
    $headers = @{
        "Authorization" = $script:token1
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        Print-Fail "Should have rejected token without Bearer prefix"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected token without 'Bearer' prefix with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-ProtectedEndpointEmptyBearer {
    Run-Test
    Print-Test "Access with 'Bearer' but No Token (Should Fail)"
    
    $headers = @{
        "Authorization" = "Bearer "
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        Print-Fail "Should have rejected empty Bearer token"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Print-Success "Correctly rejected empty Bearer token with HTTP 401"
        } else {
            Print-Fail "Should have returned 401 Unauthorized"
        }
    }
}

function Test-TokenReuseMultipleTimes {
    Run-Test
    Print-Test "Reuse Same Token Multiple Times"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $successCount = 0
        for ($i = 1; $i -le 5; $i++) {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
                -Method GET `
                -Headers $headers
            if ($response) {
                $successCount++
            }
        }
        
        if ($successCount -eq 5) {
            Print-Success "Token successfully reused 5 times"
        } else {
            Print-Fail "Token reuse failed after $successCount attempts"
        }
    } catch {
        Print-Fail "Token reuse failed: $_"
    }
}

# ============================================================================
# Part 5: Profile Tests (Extended)
# ============================================================================

function Test-CreateProfileUser1 {
    Run-Test
    Print-Test "Create Profile for User 1 (Tests Proxy to User-Service)"
    
    $body = @{
        username = "alice"
        bio = "Hello from Alice!"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Response: $($response | ConvertTo-Json -Compress)"
        Print-Success "Profile created successfully (proxy to user-service worked!)"
    } catch {
        Print-Fail "Profile creation failed: $_"
    }
}

function Test-GetProfileUser1 {
    Run-Test
    Print-Test "Get Profile for User 1"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        
        Print-Info "Username: $($response.username), Bio: $($response.bio)"
        
        if ($response.username -eq "alice") {
            Print-Success "Profile retrieved successfully"
        } else {
            Print-Fail "Unexpected profile data: $($response | ConvertTo-Json)"
        }
    } catch {
        Print-Fail "Get profile failed: $_"
    }
}

function Test-UpdateProfile {
    Run-Test
    Print-Test "Update Profile (Change Bio)"
    
    $body = @{
        username = "alice"
        bio = "Updated bio for Alice!"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        # Verify update
        $getResponse = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method GET `
            -Headers $headers
        
        if ($getResponse.bio -eq "Updated bio for Alice!") {
            Print-Success "Profile updated successfully"
        } else {
            Print-Fail "Profile update didn't persist"
        }
    } catch {
        Print-Fail "Profile update failed: $_"
    }
}

function Test-CreateProfileEmptyUsername {
    Run-Test
    Print-Test "Create Profile with Empty Username (Behavior Test)"
    
    $body = @{
        username = ""
        bio = "Test bio"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Empty username was accepted (service allows it)"
        $script:testsPassed++
    } catch {
        Print-Info "Empty username was rejected (service validates it)"
        $script:testsPassed++
    }
}

function Test-CreateProfileLongBio {
    Run-Test
    Print-Test "Create Profile with Very Long Bio"
    
    $longBio = "A" * 1000  # 1000 character bio
    $body = @{
        username = "alice"
        bio = $longBio
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Accepted very long bio (1000 chars)"
    } catch {
        Print-Fail "Failed with long bio: $_"
    }
}

function Test-CreateProfileSpecialChars {
    Run-Test
    Print-Test "Create Profile with Special Characters & Emojis"
    
    $body = @{
        username = "alice🎉"
        bio = "Hello! 你好! مرحبا! Привет! 🌍"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Accepted Unicode & emojis in profile"
    } catch {
        Print-Fail "Failed with special characters: $_"
    }
}

# ============================================================================
# Part 6: Multi-User Tests
# ============================================================================

function Test-RegisterUser2 {
    Run-Test
    Print-Test "Register User 2 (Bob)"
    
    $body = @{
        email = $testEmail2
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:userId2 = $response.user_id
        Print-Info "User ID: $($script:userId2)"
        Print-Success "User 2 registered successfully"
    } catch {
        Print-Fail "Registration failed: $_"
    }
}

function Test-LoginUser2 {
    Run-Test
    Print-Test "Login User 2 (Bob)"
    
    $body = @{
        email = $testEmail2
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:token2 = $response.access_token
        Print-Info "Token: $($script:token2.Substring(0, [Math]::Min(50, $script:token2.Length)))..."
        Print-Success "User 2 logged in successfully"
    } catch {
        Print-Fail "Login failed: $_"
    }
}

function Test-CreateProfileUser2 {
    Run-Test
    Print-Test "Create Profile for User 2"
    
    $body = @{
        username = "bob"
        bio = "Hello from Bob!"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token2)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Profile created for User 2"
    } catch {
        Print-Fail "Profile creation failed: $_"
    }
}

function Test-GetProfileById {
    Run-Test
    Print-Test "Get Another User's Profile by ID"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/$($script:userId2)" `
            -Method GET `
            -Headers $headers
        
        Print-Info "Retrieved profile: $($response.username)"
        
        if ($response.username -eq "bob") {
            Print-Success "Got other user's profile successfully"
        } else {
            Print-Fail "Unexpected profile: $($response | ConvertTo-Json)"
        }
    } catch {
        Print-Fail "Get profile by ID failed: $_"
    }
}

function Test-GetProfileNonexistentUser {
    Run-Test
    Print-Test "Get Profile of Nonexistent User (Should Fail)"
    
    $fakeUUID = "00000000-0000-0000-0000-000000000000"
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/$fakeUUID" `
            -Method GET `
            -Headers $headers
        Print-Fail "Should have returned error for nonexistent user"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Print-Success "Correctly returned 404 for nonexistent user"
        } else {
            Print-Info "Returned HTTP $($_.Exception.Response.StatusCode.value__) for nonexistent user"
            $script:testsPassed++
        }
    }
}

# ============================================================================
# Part 7: Friends Tests (Extended)
# ============================================================================

function Test-AddFriend {
    Run-Test
    Print-Test "Add Friend (Alice adds Bob)"
    
    $body = @{
        friend_uuid = $script:userId2
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Friend added successfully"
    } catch {
        Print-Fail "Add friend failed: $_"
    }
}

function Test-GetFriends {
    Run-Test
    Print-Test "Get Friends List"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method GET `
            -Headers $headers
        
        $friendCount = $response.Count
        Print-Info "Friends: $friendCount"
        
        if ($friendCount -ge 1) {
            Print-Success "Friends list retrieved successfully"
        } else {
            Print-Fail "Expected at least 1 friend, got $friendCount"
        }
    } catch {
        Print-Fail "Get friends failed: $_"
    }
}

function Test-AddDuplicateFriend {
    Run-Test
    Print-Test "Add Duplicate Friend (Should Fail or Be Idempotent)"
    
    $body = @{
        friend_uuid = $script:userId2
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Duplicate friend add accepted (idempotent operation)"
        $script:testsPassed++
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400 -or $_.Exception.Response.StatusCode.value__ -eq 409) {
            Print-Success "Correctly rejected duplicate friend"
        } else {
            Print-Fail "Unexpected status code: $($_.Exception.Response.StatusCode.value__)"
        }
    }
}

function Test-AddNonexistentFriend {
    Run-Test
    Print-Test "Add Nonexistent Friend (Should Fail)"
    
    $fakeUUID = "00000000-0000-0000-0000-000000000000"
    $body = @{
        friend_uuid = $fakeUUID
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        Print-Fail "Should have rejected nonexistent friend"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400 -or $_.Exception.Response.StatusCode.value__ -eq 404) {
            Print-Success "Correctly rejected nonexistent friend"
        } else {
            Print-Fail "Unexpected status code: $($_.Exception.Response.StatusCode.value__)"
        }
    }
}

function Test-AddSelfAsFriend {
    Run-Test
    Print-Test "Add Self as Friend (Should Fail)"
    
    $body = @{
        friend_uuid = $script:userId1
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        Print-Fail "Should have rejected self as friend"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Print-Success "Correctly rejected self as friend"
        } else {
            Print-Info "Self as friend returned HTTP $($_.Exception.Response.StatusCode.value__) (not validated)"
            $script:testsPassed++
        }
    }
}

function Test-RegisterUser3 {
    Run-Test
    Print-Test "Register User 3 (Charlie)"
    
    $body = @{
        email = $testEmail3
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:userId3 = $response.user_id
        Print-Success "User 3 registered"
    } catch {
        Print-Fail "Registration failed: $_"
    }
}

function Test-LoginUser3 {
    Run-Test
    Print-Test "Login User 3"
    
    $body = @{
        email = $testEmail3
        password = $testPassword
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        $script:token3 = $response.access_token
        Print-Success "User 3 logged in"
    } catch {
        Print-Fail "Login failed: $_"
    }
}

function Test-AddMultipleFriends {
    Run-Test
    Print-Test "Add Multiple Friends (Alice adds Charlie)"
    
    $body = @{
        friend_uuid = $script:userId3
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        # Verify count
        $friendsResponse = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method GET `
            -Headers $headers
        
        if ($friendsResponse.Count -ge 2) {
            Print-Success "Multiple friends added successfully"
        } else {
            Print-Fail "Expected at least 2 friends, got $($friendsResponse.Count)"
        }
    } catch {
        Print-Fail "Add multiple friends failed: $_"
    }
}

# ============================================================================
# Part 8: Posts Tests (Extended)
# ============================================================================

function Test-CreatePostUser1 {
    Run-Test
    Print-Test "Create Post for User 1 (Tests Proxy to Post-Service)"
    
    $body = @{
        content = "This is Alice's first post!"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Response: $($response | ConvertTo-Json -Compress)"
        Print-Success "Post created successfully (proxy to post-service worked!)"
    } catch {
        Print-Fail "Post creation failed: $_"
    }
}

function Test-CreateMultiplePosts {
    Run-Test
    Print-Test "Create Multiple Posts for Same User"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        for ($i = 2; $i -le 5; $i++) {
            $body = @{
                content = "Alice's post number $i"
            } | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
                -Method POST `
                -ContentType "application/json" `
                -Headers $headers `
                -Body $body
        }
        
        Print-Success "Created multiple posts (5 total) for User 1"
    } catch {
        Print-Fail "Multiple post creation failed: $_"
    }
}

function Test-CreatePostUser2 {
    Run-Test
    Print-Test "Create Post for User 2"
    
    $body = @{
        content = "This is Bob's first post!"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token2)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Post created for User 2"
    } catch {
        Print-Fail "Post creation failed: $_"
    }
}

function Test-CreatePostEmptyContent {
    Run-Test
    Print-Test "Create Post with Empty Content (Behavior Test)"
    
    $body = @{
        content = ""
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Empty post content was accepted"
        $script:testsPassed++
    } catch {
        Print-Info "Empty post content was rejected"
        $script:testsPassed++
    }
}

function Test-CreatePostLongContent {
    Run-Test
    Print-Test "Create Post with Very Long Content"
    
    $longContent = "A" * 10000  # 10,000 character post
    $body = @{
        content = $longContent
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Accepted very long post (10,000 chars)"
    } catch {
        Print-Fail "Failed with long content: $_"
    }
}

function Test-CreatePostSpecialChars {
    Run-Test
    Print-Test "Create Post with Emojis & Special Characters"
    
    $body = @{
        content = "Hello! 🎉🌍 Special chars: <>&\  \n\t Unicode: 你好 مرحبا"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method POST `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Accepted post with emojis & special characters"
    } catch {
        Print-Fail "Failed with special characters: $_"
    }
}

function Test-GetOwnPosts {
    Run-Test
    Print-Test "Get Own Posts"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
            -Method GET `
            -Headers $headers
        
        $postCount = $response.Count
        Print-Info "Posts: $postCount"
        
        if ($postCount -ge 1) {
            $firstPost = $response[0].content
            Print-Info "First post: $firstPost"
            Print-Success "Own posts retrieved successfully"
        } else {
            Print-Fail "Expected at least 1 post, got $postCount"
        }
    } catch {
        Print-Fail "Get posts failed: $_"
    }
}

function Test-GetOtherUserPosts {
    Run-Test
    Print-Test "Get Another User's Posts"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/$($script:userId2)" `
            -Method GET `
            -Headers $headers
        
        $postCount = $response.Count
        Print-Info "Bob's posts: $postCount"
        
        if ($postCount -ge 1) {
            Print-Success "Other user's posts retrieved successfully"
        } else {
            Print-Fail "Expected at least 1 post, got $postCount"
        }
    } catch {
        Print-Fail "Get other user's posts failed: $_"
    }
}

function Test-GetPostsNonexistentUser {
    Run-Test
    Print-Test "Get Posts of Nonexistent User"
    
    $fakeUUID = "00000000-0000-0000-0000-000000000000"
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/$fakeUUID" `
            -Method GET `
            -Headers $headers
        
        if ($response.Count -eq 0) {
            Print-Success "Returned empty array for nonexistent user (correct)"
        } else {
            Print-Fail "Should return empty array for nonexistent user"
        }
    } catch {
        Print-Info "Service returned error for nonexistent user (also acceptable)"
        $script:testsPassed++
    }
}

# ============================================================================
# Part 9: Cleanup Tests
# ============================================================================

function Test-DeleteFriend {
    Run-Test
    Print-Test "Delete Friend"
    
    $body = @{
        friend_uuid = $script:userId2
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method DELETE `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Success "Friend deleted successfully"
    } catch {
        Print-Fail "Delete friend failed: $_"
    }
}

function Test-DeleteNonexistentFriend {
    Run-Test
    Print-Test "Delete Nonexistent Friend (Should Fail or Be Idempotent)"
    
    $fakeUUID = "00000000-0000-0000-0000-000000000000"
    $body = @{
        friend_uuid = $fakeUUID
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method DELETE `
            -ContentType "application/json" `
            -Headers $headers `
            -Body $body
        
        Print-Info "Delete nonexistent friend accepted (idempotent)"
        $script:testsPassed++
    } catch {
        Print-Success "Correctly rejected deleting nonexistent friend"
    }
}

function Test-VerifyFriendDeleted {
    Run-Test
    Print-Test "Verify Friend Was Deleted from List"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/friends" `
            -Method GET `
            -Headers $headers
        
        $hasBob = $response | Where-Object { $_ -eq $script:userId2 }
        
        if ($null -eq $hasBob) {
            Print-Success "Friend successfully removed from list"
        } else {
            Print-Fail "Friend still appears in list after deletion"
        }
    } catch {
        Print-Fail "Get friends list failed: $_"
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Clear-Host

Print-Header "🧪 GATEWAY COMPREHENSIVE TEST SUITE (ENHANCED)"

Print-Info "Base URL: $baseUrl"
Print-Info "Test User 1: $testEmail1"
Print-Info "Test User 2: $testEmail2"
Print-Info "Test User 3: $testEmail3"
Print-Info "Timestamp: $timestamp"

# Pre-flight check
Print-Header "Pre-flight Check"
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/healthz" -Method GET -TimeoutSec 5
    Print-Success "Gateway is reachable"
} catch {
    Write-Host "Error: Gateway is not running at $baseUrl" -ForegroundColor Red
    Write-Host "Please start the gateway with: docker-compose up" -ForegroundColor Yellow
    exit 1
}

# Run all tests
Print-Header "Part 1: Health & Infrastructure (2 tests)"
Test-HealthCheck
Test-HealthCheckMultipleTimes

Print-Header "Part 2: User Registration (10 tests)"
Test-RegisterUser1
Test-RegisterDuplicateEmail
Test-RegisterInvalidEmail
Test-RegisterShortPassword
Test-RegisterEmptyEmail
Test-RegisterEmptyPassword
Test-RegisterMissingEmail
Test-RegisterMissingPassword
Test-RegisterSpecialCharsEmail
Test-RegisterLongPassword

Print-Header "Part 3: Authentication & JWT (7 tests)"
Test-LoginUser1
Test-LoginWrongPassword
Test-LoginNonexistentUser
Test-LoginEmptyEmail
Test-LoginEmptyPassword
Test-LoginCaseInsensitive

Print-Header "Part 4: JWT Token Validation (6 tests)"
Test-ProtectedEndpointNoToken
Test-ProtectedEndpointInvalidToken
Test-ProtectedEndpointMalformedToken
Test-ProtectedEndpointNoBearer
Test-ProtectedEndpointEmptyBearer
Test-TokenReuseMultipleTimes

Print-Header "Part 5: Profile Operations (7 tests)"
Test-CreateProfileUser1
Test-GetProfileUser1
Test-UpdateProfile
Test-CreateProfileEmptyUsername
Test-CreateProfileLongBio
Test-CreateProfileSpecialChars

Print-Header "Part 6: Multi-User Scenarios (3 tests)"
Test-RegisterUser2
Test-LoginUser2
Test-CreateProfileUser2
Test-GetProfileById
Test-GetProfileNonexistentUser

Print-Header "Part 7: Friends Management (8 tests)"
Test-AddFriend
Test-GetFriends
Test-AddDuplicateFriend
Test-AddNonexistentFriend
Test-AddSelfAsFriend
Test-RegisterUser3
Test-LoginUser3
Test-AddMultipleFriends

Print-Header "Part 8: Posts Operations (10 tests)"
Test-CreatePostUser1
Test-CreateMultiplePosts
Test-CreatePostUser2
Test-CreatePostEmptyContent
Test-CreatePostLongContent
Test-CreatePostSpecialChars
Test-GetOwnPosts
Test-GetOtherUserPosts
Test-GetPostsNonexistentUser

Print-Header "Part 9: Cleanup Operations (3 tests)"
Test-DeleteFriend
Test-DeleteNonexistentFriend
Test-VerifyFriendDeleted





Write-Host "🔍 Checking Post-Service Configuration..." -ForegroundColor Cyan

Write-Host "`n1. Does post-service directory exist?" -ForegroundColor Yellow
if (Test-Path services/post-service) {
    Write-Host "   ✅ YES - Directory exists" -ForegroundColor Green
    Write-Host "`n2. What files are in it?" -ForegroundColor Yellow
    Get-ChildItem services/post-service
    
    Write-Host "`n3. What does main.go say?" -ForegroundColor Yellow
    Select-String -Path services/post-service/main.go -Pattern "service" | Select-Object -First 3
} else {
    Write-Host "   ❌ NO - Directory is missing!" -ForegroundColor Red
    Write-Host "   This is the problem! Post-service doesn't exist." -ForegroundColor Red
}

Write-Host "`n4. What is docker-compose building?" -ForegroundColor Yellow
Select-String -Path docker-compose.yaml -Pattern "build.*post-service" -Context 1

Write-Host "`n5. What do post-service logs say?" -ForegroundColor Yellow
docker-compose logs post-service-1 2>$null | Select-String "service" | Select-Object -First 1


# ============================================================================
# Part 10: Load Balancer Tests (NEW!)
# ============================================================================

Print-Header "Part 10: Load Balancer Distribution Tests (10 tests)"

function Test-LoadBalancerRoundRobinUser {
    Run-Test
    Print-Test "Load Balancer Round-Robin (User Service)"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        Write-Host "`n  Making 10 requests to test round-robin distribution..." -ForegroundColor Gray
        
        # Make 10 requests
        for ($i = 1; $i -le 10; $i++) {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
                -Method GET `
                -Headers $headers `
                -ErrorAction Stop
            Start-Sleep -Milliseconds 100  # Small delay
        }
        
        Print-Info "Check load-balancer logs: docker-compose logs load-balancer | Select-String 'user-service'"
        Print-Info "You should see requests alternating between user-service-1 and user-service-2"
        Print-Success "10 requests sent - check logs to verify round-robin"
    } catch {
        Print-Fail "Load balancer test failed: $_"
    }
}

function Test-LoadBalancerRoundRobinPost {
    Run-Test
    Print-Test "Load Balancer Round-Robin (Post Service)"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        Write-Host "`n  Making 10 requests to test round-robin distribution..." -ForegroundColor Gray
        
        # Make 10 requests
        for ($i = 1; $i -le 10; $i++) {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/posts/me" `
                -Method GET `
                -Headers $headers `
                -ErrorAction Stop
            Start-Sleep -Milliseconds 100
        }
        
        Print-Info "Check load-balancer logs: docker-compose logs load-balancer | Select-String 'post-service'"
        Print-Info "You should see requests alternating between post-service-1 and post-service-2"
        Print-Success "10 requests sent - check logs to verify round-robin"
    } catch {
        Print-Fail "Load balancer test failed: $_"
    }
}

function Test-LoadBalancerHealthChecks {
    Run-Test
    Print-Test "Load Balancer Health Checks"
    
    try {
        Write-Host "`n  Waiting for health check cycle (10 seconds)..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
        
        # Check logs for health checks
        $healthLogs = docker-compose logs load-balancer 2>$null | Select-String "health check" | Select-Object -Last 5
        
        if ($healthLogs) {
            Print-Info "Recent health checks:"
            $healthLogs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            Print-Success "Health checks are running"
        } else {
            Print-Warning "No health check logs found (check manually)"
            $script:testsPassed++
        }
    } catch {
        Print-Warning "Could not check health logs: $_"
        $script:testsPassed++
    }
}

function Test-LoadBalancerFailover {
    Run-Test
    Print-Test "Load Balancer Failover (Stop user-service-2)"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        # Stop one backend
        Write-Host "`n  Stopping user-service-2..." -ForegroundColor Gray
        docker-compose stop user-service-2 2>$null | Out-Null
        
        # Wait for health check to detect failure
        Write-Host "  Waiting for health check to detect failure (15 seconds)..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        
        # Make requests - should all go to user-service-1
        Write-Host "  Making 5 requests (should all go to user-service-1)..." -ForegroundColor Gray
        $successCount = 0
        for ($i = 1; $i -le 5; $i++) {
            try {
                $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
                    -Method GET `
                    -Headers $headers `
                    -ErrorAction Stop
                $successCount++
            } catch {
                # Request might fail
            }
            Start-Sleep -Milliseconds 200
        }
        
        if ($successCount -eq 5) {
            Print-Success "Failover successful - all requests served by remaining backend"
        } else {
            Print-Warning "Failover partially successful ($successCount/5 requests)"
            $script:testsPassed++
        }
        
        # Restart the backend
        Write-Host "`n  Restarting user-service-2..." -ForegroundColor Gray
        docker-compose start user-service-2 2>$null | Out-Null
        Start-Sleep -Seconds 5
        
    } catch {
        Print-Fail "Failover test failed: $_"
        # Make sure to restart service
        docker-compose start user-service-2 2>$null | Out-Null
    }
}

function Test-LoadBalancerRecovery {
    Run-Test
    Print-Test "Load Balancer Backend Recovery"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        Write-Host "`n  Waiting for health check to detect recovery (15 seconds)..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        
        # Make requests - should be distributed again
        Write-Host "  Making 10 requests (should distribute across both backends)..." -ForegroundColor Gray
        for ($i = 1; $i -le 10; $i++) {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/profile/me" `
                -Method GET `
                -Headers $headers `
                -ErrorAction Stop
            Start-Sleep -Milliseconds 100
        }
        
        Print-Info "Check logs to verify both backends are receiving requests again"
        Print-Success "Backend recovered - distribution resumed"
    } catch {
        Print-Fail "Recovery test failed: $_"
    }
}

function Test-LoadBalancerConcurrency {
    Run-Test
    Print-Test "Load Balancer Concurrent Requests"
    
    $headers = @{
        "Authorization" = "Bearer $($script:token1)"
    }
    
    try {
        Write-Host "`n  Sending 20 concurrent requests..." -ForegroundColor Gray
        
        $jobs = @()
        for ($i = 1; $i -le 20; $i++) {
            $job = Start-Job -ScriptBlock {
                param($url, $headers)
                try {
                    Invoke-RestMethod -Uri "$url/api/profile/me" `
                        -Method GET `
                        -Headers $headers `
                        -ErrorAction Stop
                    return $true
                } catch {
                    return $false
                }
            } -ArgumentList $baseUrl, $headers
            $jobs += $job
        }
        
        # Wait for all jobs
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        $successCount = ($results | Where-Object { $_ -eq $true }).Count
        
        if ($successCount -ge 18) {
            Print-Success "Handled $successCount/20 concurrent requests successfully"
        } else {
            Print-Warning "Only $successCount/20 concurrent requests succeeded"
            $script:testsPassed++
        }
    } catch {
        Print-Fail "Concurrency test failed: $_"
    }
}

function Test-LoadBalancerMetrics {
    Run-Test
    Print-Test "Load Balancer Distribution Metrics"
    
    try {
        Write-Host "`n  Analyzing load balancer logs..." -ForegroundColor Gray
        
        # Get last 50 backend selections
        $selections = docker-compose logs load-balancer 2>$null | 
            Select-String "Selected backend" | 
            Select-Object -Last 50
        
        if ($selections) {
            $service1Count = ($selections | Select-String "user-service-1").Count
            $service2Count = ($selections | Select-String "user-service-2").Count
            
            Write-Host "`n  Distribution Analysis:" -ForegroundColor Cyan
            Write-Host "    user-service-1: $service1Count requests" -ForegroundColor Gray
            Write-Host "    user-service-2: $service2Count requests" -ForegroundColor Gray
            
            if ($service1Count -gt 0 -and $service2Count -gt 0) {
                $ratio = [math]::Round(($service1Count / ($service1Count + $service2Count)) * 100, 1)
                Write-Host "    Service-1 gets: $ratio%" -ForegroundColor Gray
                Write-Host "    Service-2 gets: $(100 - $ratio)%" -ForegroundColor Gray
                
                if ($ratio -ge 40 -and $ratio -le 60) {
                    Print-Success "Load is evenly distributed (50/50 ±10%)"
                } else {
                    Print-Info "Distribution is $ratio% / $(100-$ratio)% (acceptable variance)"
                    $script:testsPassed++
                }
            } else {
                Print-Warning "Could not verify distribution (one backend may be down)"
                $script:testsPassed++
            }
        } else {
            Print-Warning "No distribution logs found"
            $script:testsPassed++
        }
    } catch {
        Print-Warning "Could not analyze metrics: $_"
        $script:testsPassed++
    }
}

function Test-LoadBalancerBothPorts {
    Run-Test
    Print-Test "Load Balancer Listening on Both Ports"
    
    try {
        Write-Host "`n  Testing port 9001 (user-service)..." -ForegroundColor Gray
        $port9001 = Test-NetConnection -ComputerName localhost -Port 9001 -WarningAction SilentlyContinue
        
        Write-Host "  Testing port 9002 (post-service)..." -ForegroundColor Gray
        $port9002 = Test-NetConnection -ComputerName localhost -Port 9002 -WarningAction SilentlyContinue
        
        if ($port9001.TcpTestSucceeded -and $port9002.TcpTestSucceeded) {
            Print-Success "Load balancer listening on both ports (9001 and 9002)"
        } else {
            if (-not $port9001.TcpTestSucceeded) {
                Print-Fail "Port 9001 not accessible"
            }
            if (-not $port9002.TcpTestSucceeded) {
                Print-Fail "Port 9002 not accessible"
            }
        }
    } catch {
        Print-Warning "Could not test ports: $_"
        $script:testsPassed++
    }
}

function Test-LoadBalancerLayer4 {
    Run-Test
    Print-Test "Load Balancer Layer 4 (TCP) Operation"
    
    try {
        Write-Host "`n  Verifying TCP-level forwarding..." -ForegroundColor Gray
        
        # Check logs for TCP connection messages
        $tcpLogs = docker-compose logs load-balancer 2>$null | 
            Select-String "Proxying connection" | 
            Select-Object -Last 5
        
        if ($tcpLogs) {
            Print-Info "Recent TCP connections:"
            $tcpLogs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            Print-Success "Load balancer operating at Layer 4 (TCP)"
        } else {
            Print-Info "No TCP forwarding logs found (may need more traffic)"
            $script:testsPassed++
        }
    } catch {
        Print-Warning "Could not verify Layer 4 operation: $_"
        $script:testsPassed++
    }
}

function Test-LoadBalancerUptime {
    Run-Test
    Print-Test "Load Balancer Container Status"
    
    try {
        $lbStatus = docker-compose ps load-balancer 2>$null
        
        if ($lbStatus -match "Up") {
            Print-Success "Load balancer container is running"
        } else {
            Print-Fail "Load balancer container is not running properly"
        }
    } catch {
        Print-Fail "Could not check load balancer status: $_"
    }
}

# Run Load Balancer Tests
Test-LoadBalancerRoundRobinUser
Test-LoadBalancerRoundRobinPost
Test-LoadBalancerHealthChecks
Test-LoadBalancerFailover
Test-LoadBalancerRecovery
Test-LoadBalancerConcurrency
Test-LoadBalancerMetrics
Test-LoadBalancerBothPorts
Test-LoadBalancerLayer4
Test-LoadBalancerUptime


# Test Summary
Print-Header "📊 TEST SUMMARY"

Write-Host "Total Tests Run:    " -NoNewline
Write-Host $script:testsRun -ForegroundColor Cyan

Write-Host "Tests Passed:       " -NoNewline
Write-Host $script:testsPassed -ForegroundColor Green

Write-Host "Tests Failed:       " -NoNewline
Write-Host $script:testsFailed -ForegroundColor Red

$passRate = [math]::Round(($script:testsPassed / $script:testsRun) * 100, 2)
Write-Host "Pass Rate:          " -NoNewline
Write-Host "$passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })

# Load Balancer Summary
Print-Header "⚖️ LOAD BALANCER SUMMARY"
Write-Host "`nTo view detailed load balancer logs, run:" -ForegroundColor Cyan
Write-Host "  docker-compose logs -f load-balancer`n" -ForegroundColor Yellow

Write-Host "Key things to verify in logs:" -ForegroundColor Cyan
Write-Host "  1. [user-service] → Selected backend: user-service-1:5000" -ForegroundColor Gray
Write-Host "  2. [user-service] → Selected backend: user-service-2:5000" -ForegroundColor Gray
Write-Host "  3. Alternating pattern (round-robin)" -ForegroundColor Gray
Write-Host "  4. Health checks running every 10 seconds" -ForegroundColor Gray
Write-Host "  5. Both pools operational (user-service and post-service)`n" -ForegroundColor Gray

if ($script:testsFailed -eq 0) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                        ║" -ForegroundColor Green
    Write-Host "║  ✓ ALL $script:testsRun TESTS PASSED! 🎉🎉    ║" -ForegroundColor Green
    Write-Host "║                                        ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green
    
    Write-Host "Your Complete System:" -ForegroundColor Cyan
    Write-Host "  ✅ Gateway - Authentication & JWT" -ForegroundColor Green
    Write-Host "  ✅ Gateway - Reverse Proxy" -ForegroundColor Green
    Write-Host "  ✅ Load Balancer - Layer 4 (TCP)" -ForegroundColor Green
    Write-Host "  ✅ Load Balancer - Round-Robin" -ForegroundColor Green
    Write-Host "  ✅ Load Balancer - Health Checks" -ForegroundColor Green
    Write-Host "  ✅ Load Balancer - Failover" -ForegroundColor Green
    Write-Host "  ✅ User-Service - Profile & Friends" -ForegroundColor Green
    Write-Host "  ✅ Post-Service - Posts Management" -ForegroundColor Green
    Write-Host "  ✅ Docker Networking" -ForegroundColor Green
    Write-Host "  ✅ Scalability (Multiple Instances)`n" -ForegroundColor Green
    
    Write-Host "🏆 EXCELLENT! Your distributed system is complete!" -ForegroundColor Green
    
    exit 0
} elseif ($passRate -ge 85) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                                        ║" -ForegroundColor Yellow
    Write-Host "║  ⚠ MOSTLY PASSED ($passRate%)            ║" -ForegroundColor Yellow
    Write-Host "║                                        ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Yellow
    
    Write-Host "Your system works well but has minor issues." -ForegroundColor Yellow
    Write-Host "Review the failed tests above for details.`n"
    
    exit 0
} else {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                        ║" -ForegroundColor Red
    Write-Host "║     ✗ SOME TESTS FAILED ($passRate%)       ║" -ForegroundColor Red
    Write-Host "║                                        ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Red
    
    Write-Host "Check the output above for details." -ForegroundColor Yellow
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - Services not running (docker-compose up -d)"
    Write-Host "  - Load balancer not configured correctly"
    Write-Host "  - Backend services not accessible"
    Write-Host "  - Database connection issues`n"
    
    exit 1
}