package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	postgresURL := os.Getenv("GATEWAY_POSTGRES_DSN")
	if postgresURL == "" {
		log.Fatal("GATEWAY_POSTGRES_DSN environment variable not set")
	}

	if err := initializeDatabase(postgresURL); err != nil {
		log.Fatalf("Database initialization failed: %v", err)
	}
	defer db.Close()

	log.Println("Database initialized successfully")

	if err := initializeProxies(); err != nil {
		log.Fatalf("Proxy initialization failed: %v", err)
	}

	log.Println("All systems initialized")

	go func() {
		log.Println("HTTP redirect :8080 -> https://localhost:8443")
		_ = http.ListenAndServe(":8080", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "https://localhost:8443"+r.URL.RequestURI(), http.StatusMovedPermanently)
		}))
	}()

	router := setupRoutes()

	// TLS configuration
	certFile := "/app/certs/server.crt"
	keyFile := "/app/certs/server.key"
	port := "8443"
	log.Printf("\n=== Gateway Server Starting ===")
	log.Printf("Port: %s", port)
	log.Printf("\nPublic Endpoints:")
	log.Printf("  POST http://localhost:%s/api/auth/register", port)
	log.Printf("  POST http://localhost:%s/api/auth/login", port)
	log.Printf("  GET  http://localhost:%s/healthz", port)
	log.Printf("\nProtected Endpoints (require JWT):")
	log.Printf("  GET/POST http://localhost:%s/api/profile/me", port)
	log.Printf("  GET      http://localhost:%s/api/profile/{userId}", port)
	log.Printf("  GET/POST/DELETE http://localhost:%s/api/friends", port)
	log.Printf("  GET/POST http://localhost:%s/api/posts/me", port)
	log.Printf("  GET      http://localhost:%s/api/posts/{userId}", port)
	log.Printf("  GET      http://localhost:%s/api/feed", port)
	log.Printf("\n===============================\n")

	if err := http.ListenAndServeTLS(":"+port, certFile, keyFile, router); err != nil {
		log.Fatalf("Error starting TLS server: %v", err)
	}
}
