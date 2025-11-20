package main

import (
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

func main() {
	// Configure logging
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Create router
	router := mux.NewRouter()

	// Register routes
	router.HandleFunc("/health", healthCheckHandler).Methods("GET")
	router.HandleFunc("/feed", getFeedHandler).Methods("GET")

	// Start server
	addr := ":" + port
	log.Printf("	Feed Service Starting...	")
	log.Printf("Listening on %s", addr)
	log.Printf("Endpoints:")
	log.Printf("  GET /health - Health check")
	log.Printf("  GET /feed   - Get user's feed (requires X-User-ID header)")

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
