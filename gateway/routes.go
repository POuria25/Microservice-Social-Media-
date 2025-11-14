package main

import (
	"github.com/gorilla/mux"
)

func setupRoutes() *mux.Router {

	/*
	* setupRoutes initializes the HTTP routes for the gateway server.
	* It defines the registration endpoint and health check endpoint.
	*
	* @return *mux.Router - The configured router with defined routes.
	 */

	router := mux.NewRouter()
	router.HandleFunc("/healthz", healthCheckHandler).Methods("GET")

	// Public routes
	router.HandleFunc("/api/auth/register", registerHandler).Methods("POST")
	router.HandleFunc("/api/auth/login", loginHandler).Methods("POST")

	// Protected routes
	api := router.PathPrefix("/api").Subrouter()
	api.Use(authMiddleware)

	// User-service routes
	api.HandleFunc("/profile/me", proxyToUserService).Methods("GET", "POST")
	api.HandleFunc("/profile/{userId}", proxyToUserService).Methods("GET")
	api.HandleFunc("/friends", proxyToUserService).Methods("GET", "POST", "DELETE")

	// Post-service routes
	api.HandleFunc("/posts", proxyToPostService).Methods("GET", "POST")
	api.HandleFunc("/posts/{userId}", proxyToPostService).Methods("GET")

	// Feed-service
	api.HandleFunc("/feed", proxyToFeedService).Methods("GET")

	return router
}
