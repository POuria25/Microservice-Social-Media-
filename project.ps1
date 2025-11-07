param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

function Show-Help {
    Write-Host ""
    Write-Host "Available commands:" -ForegroundColor Cyan
    Write-Host "  .\project.ps1 build           - Build all Docker images" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 up              - Start all services in background" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 down            - Stop all services" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 logs            - Show logs for all services" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 gateway-logs    - Show logs for gateway only" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 follow          - Follow all logs in real-time" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 clean           - Stop services and remove volumes" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 restart         - Restart all services" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 status          - Show status of all containers" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 test-db         - Verify gateway database table exists" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Gateway specific:" -ForegroundColor Cyan
    Write-Host "  .\project.ps1 build-gateway   - Build only gateway" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 up-gateway      - Start only gateway" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 rebuild-gateway - Rebuild and restart gateway" -ForegroundColor Yellow
    Write-Host "  .\project.ps1 check-gateway   - Check if gateway compiles" -ForegroundColor Yellow
    Write-Host ""
}

function Build-All {
    Write-Host "Building all Docker images..." -ForegroundColor Green
    docker-compose build
}

function Build-Gateway {
    Write-Host "Building gateway..." -ForegroundColor Green
    docker-compose build gateway
}

function Start-All {
    Write-Host "Starting all services..." -ForegroundColor Green
    docker-compose up -d
    Write-Host "Services started! Use '.\project.ps1 logs' to view logs" -ForegroundColor Cyan
    Write-Host "Use '.\project.ps1 status' to check container status" -ForegroundColor Cyan
}

function Start-Gateway {
    Write-Host "Starting gateway and gateway-db..." -ForegroundColor Green
    docker-compose up -d gateway
    Write-Host "Gateway started! Use '.\project.ps1 gateway-logs' to view logs" -ForegroundColor Cyan
}

function Stop-All {
    Write-Host "Stopping all services..." -ForegroundColor Green
    docker-compose down
}

function Show-Logs {
    Write-Host "Showing logs (last 50 lines):" -ForegroundColor Green
    docker-compose logs --tail=50
}

function Show-GatewayLogs {
    Write-Host "Gateway logs (last 50 lines):" -ForegroundColor Green
    docker-compose logs --tail=50 gateway
    Write-Host ""
    Write-Host "Gateway-DB logs (last 20 lines):" -ForegroundColor Green
    docker-compose logs --tail=20 gateway-db
}

function Follow-Logs {
    Write-Host "Following all logs (Ctrl+C to stop)..." -ForegroundColor Green
    docker-compose logs -f
}

function Follow-GatewayLogs {
    Write-Host "Following gateway logs (Ctrl+C to stop)..." -ForegroundColor Green
    docker-compose logs -f gateway
}

function Clean-All {
    Write-Host "WARNING: This will delete all database data!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to confirm"
    if ($confirm -eq "yes") {
        docker-compose down -v
        Write-Host "All services stopped and volumes removed" -ForegroundColor Green
    } else {
        Write-Host "Cancelled" -ForegroundColor Yellow
    }
}

function Restart-All {
    Write-Host "Restarting all services..." -ForegroundColor Green
    docker-compose restart
    Write-Host "Services restarted!" -ForegroundColor Cyan
}

function Show-Status {
    Write-Host "Container status:" -ForegroundColor Green
    docker-compose ps
}

function Test-Database {
    Write-Host "Checking if users table exists in gateway database..." -ForegroundColor Green
    docker-compose exec gateway-db psql -U postgres -d gateway -c "\d users"
    Write-Host ""
    Write-Host "If you see the table structure above, Sub-Problem 1.1 is complete! ✓" -ForegroundColor Cyan
}

function Rebuild-Gateway {
    Write-Host "Rebuilding and restarting gateway..." -ForegroundColor Green
    docker-compose build gateway
    docker-compose up -d gateway
    Write-Host "Gateway rebuilt and restarted!" -ForegroundColor Cyan
    Write-Host "Showing logs..." -ForegroundColor Green
    Start-Sleep -Seconds 2
    docker-compose logs --tail=30 gateway
}

function Rebuild-All {
    Write-Host "Full rebuild: stopping, building, starting..." -ForegroundColor Green
    docker-compose down
    docker-compose build
    docker-compose up -d
    Write-Host "Waiting for services to start..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    Show-Status
    Write-Host ""
    Write-Host "Recent logs:" -ForegroundColor Green
    docker-compose logs --tail=20
}

function Check-Gateway {
    Write-Host "Checking if gateway compiles..." -ForegroundColor Green
    docker-compose build gateway
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Gateway builds successfully!" -ForegroundColor Green
    } else {
        Write-Host "✗ Gateway build failed - check errors above" -ForegroundColor Red
    }
}

# Main command routing
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "build" { Build-All }
    "build-gateway" { Build-Gateway }
    "up" { Start-All }
    "up-gateway" { Start-Gateway }
    "down" { Stop-All }
    "logs" { Show-Logs }
    "gateway-logs" { Show-GatewayLogs }
    "follow" { Follow-Logs }
    "follow-gateway" { Follow-GatewayLogs }
    "clean" { Clean-All }
    "restart" { Restart-All }
    "status" { Show-Status }
    "test-db" { Test-Database }
    "rebuild-gateway" { Rebuild-Gateway }
    "rebuild-all" { Rebuild-All }
    "check-gateway" { Check-Gateway }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}