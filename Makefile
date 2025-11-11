# Makefile for INFO8011 Microservices Project

.PHONY: help build up down logs clean restart status test-db gateway-logs all-logs

# Default target - show help
help:
	@echo "Available commands:"
	@echo "  make build          - Build all Docker images"
	@echo "  make up             - Start all services in background"
	@echo "  make down           - Stop all services"
	@echo "  make logs           - Show logs for all services"
	@echo "  make gateway-logs   - Show logs for gateway only"
	@echo "  make all-logs       - Follow all logs in real-time"
	@echo "  make clean          - Stop services and remove volumes (deletes data!)"
	@echo "  make restart        - Restart all services"
	@echo "  make status         - Show status of all containers"
	@echo "  make test-db        - Verify gateway database table exists"
	@echo ""
	@echo "Gateway specific:"
	@echo "  make build-gateway  - Build only gateway"
	@echo "  make up-gateway     - Start only gateway"
	@echo "  make rebuild-gateway - Rebuild and restart gateway"

# Build all images
build:
	@echo "Building all Docker images..."
	docker-compose build

# Build only gateway
build-gateway:
	@echo "Building gateway..."
	docker-compose build gateway

# Start all services in background (detached mode)
up:
	@echo "Starting all services..."
	docker-compose up -d
	@echo "Services started! Use 'make logs' to view logs"
	@echo "Use 'make status' to check container status"

# Start only gateway
up-gateway:
	@echo "Starting gateway and gateway-db..."
	docker-compose up -d gateway
	@echo "Gateway started! Use 'make gateway-logs' to view logs"

# Stop all services
down:
	@echo "Stopping all services..."
	docker-compose down

# Show logs for all services (last 50 lines)
logs:
	docker-compose logs --tail=50

# Show logs for gateway only
gateway-logs:
	@echo "Gateway logs (last 50 lines):"
	docker-compose logs --tail=50 gateway
	@echo ""
	@echo "Gateway-DB logs (last 20 lines):"
	docker-compose logs --tail=20 gateway-db

# Follow all logs in real-time
all-logs:
	docker-compose logs -f

# Follow gateway logs in real-time
follow-gateway:
	docker-compose logs -f gateway

# Stop services and remove volumes (WARNING: deletes all data!)
clean:
	@echo "WARNING: This will delete all database data!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	docker-compose down -v
	@echo "All services stopped and volumes removed"

# Restart all services
restart:
	@echo "Restarting all services..."
	docker-compose restart
	@echo "Services restarted!"

# Show status of all containers
status:
	@echo "Container status:"
	docker-compose ps

# Test if gateway database table exists
test-db:
	@echo "Checking if users table exists in gateway database..."
	docker-compose exec gateway-db psql -U postgres -d gateway -c "\d users"
	@echo ""
	@echo "If you see the table structure above, Sub-Problem 1.1 is complete! ✓"

# Rebuild and restart gateway (useful during development)
rebuild-gateway:
	@echo "Rebuilding and restarting gateway..."
	docker-compose build gateway
	docker-compose up -d gateway
	@echo "Gateway rebuilt and restarted!"
	@echo "Showing logs..."
	@sleep 2
	docker-compose logs --tail=30 gateway

# Full rebuild (stop, rebuild, start, show logs)
rebuild-all:
	@echo "Full rebuild: stopping, building, starting..."
	docker-compose down
	docker-compose build
	docker-compose up -d
	@echo "Waiting for services to start..."
	@sleep 3
	@make status
	@echo ""
	@echo "Recent logs:"
	docker-compose logs --tail=20

# Quick check - build gateway and show if it compiles
check-gateway:
	@echo "Checking if gateway compiles..."
	docker-compose build gateway
	@if [ $$? -eq 0 ]; then \
		echo "✓ Gateway builds successfully!"; \
	else \
		echo "✗ Gateway build failed - check errors above"; \
	fi