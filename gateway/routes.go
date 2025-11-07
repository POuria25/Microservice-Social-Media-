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
	//router.MethodNotAllowedHandler = http.HandlerFunc(methodNotAllowedHandler)

	// Public routes
	router.HandleFunc("/api/auth/register", registerHandler).Methods("POST")
	router.HandleFunc("/api/auth/login", loginHandler).Methods("POST")
	router.HandleFunc("/healthz", healthCheckHandler).Methods("GET")

	// Protected routes can be added here with authMiddleware

	protected := router.PathPrefix("/api").Subrouter()
	protected.Use(authMiddleware)

	protected.HandleFunc("/profile/me", proxyToUserService).Methods("GET", "POST")
	protected.HandleFunc("/profile/{userId}", proxyToUserService).Methods("GET")
	protected.HandleFunc("/friends", proxyToUserService).Methods("GET", "POST", "DELETE")

	// Post-service routes
	protected.HandleFunc("/posts/me", proxyToPostService).Methods("GET", "POST")
	protected.HandleFunc("/posts/{userId}", proxyToPostService).Methods("GET")

	// Feed-service routes
	protected.HandleFunc("/feed", proxyToFeedService).Methods("GET")

	return router
}
