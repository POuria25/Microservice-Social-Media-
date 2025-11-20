package main

import (
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus/promhttp"
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

	feedServiceURL := os.Getenv("FEED_SERVICE_URL")
	if feedServiceURL == "" {
		feedServiceURL = "http://feed-service:5000"
	}

	certFile := "/app/certs/server.crt"
	keyFile := "/app/certs/server.key"
	port := "8443"

	go func() {
		log.Println("Starting HTTP server on :8080")

		http.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
			promhttp.Handler().ServeHTTP(w, r)
		})

		http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "https://localhost:8443"+r.URL.RequestURI(), http.StatusMovedPermanently)
		})

		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Fatalf("HTTP server error: %v", err)
		}
	}()

	router := setupRoutes()
	router.Handle("/metrics", promhttp.Handler()).Methods("GET")
	handler := prometheusMiddleware(router)

	log.Printf("\n    Gateway Server Starting    ")
	log.Printf("HTTPS Port: %s", port)
	log.Printf("HTTP Port: 8080")
	log.Printf("Feed Service: %s", feedServiceURL)
	log.Printf("\nPrometheus Metrics:")
	log.Printf("  HTTP:  http://localhost:8080/metrics")
	log.Printf("  HTTPS: https://localhost:%s/metrics", port)
	log.Printf("\nPublic Endpoints:")
	log.Printf("  POST https://localhost:%s/api/auth/register", port)
	log.Printf("  POST https://localhost:%s/api/auth/login", port)
	log.Printf("  GET  https://localhost:%s/healthz", port)
	log.Printf("\nProtected Endpoints (require JWT):")
	log.Printf("  GET/POST https://localhost:%s/api/profile/me", port)
	log.Printf("  GET      https://localhost:%s/api/profile/{userId}", port)
	log.Printf("  GET/POST/DELETE https://localhost:%s/api/friends", port)
	log.Printf("  GET/POST https://localhost:%s/api/posts/me", port)
	log.Printf("  GET      https://localhost:%s/api/posts/{userId}", port)
	log.Printf("  GET      https://localhost:%s/api/feed", port)
	log.Printf("\n")
	log.Println("Prometheus middleware enabled")

	if err := http.ListenAndServeTLS(":"+port, certFile, keyFile, handler); err != nil {
		log.Fatalf("Error starting TLS server: %v", err)
	}
}
