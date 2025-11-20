package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// responseWriter is a custom http.ResponseWriter that captures the status code for metrics.
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func newResponseWriter(w http.ResponseWriter) *responseWriter {
	/*
	* newResponseWriter creates a new responseWriter that wraps the given http.ResponseWriter
	* and initializes the status code to http.StatusOK.
	*
	* @param w http.ResponseWriter - The original response writer to wrap.
	* @return *responseWriter - The wrapped response writer with status code tracking.
	 */

	return &responseWriter{w, http.StatusOK}
}

func (rw *responseWriter) WriteHeader(code int) {

	/*
	* WriteHeader captures the status code and calls the underlying ResponseWriter's WriteHeader method.
	*
	* @param code int - The HTTP status code to write.
	* @return void
	 */

	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func prometheusMiddleware(next http.Handler) http.Handler {
	/*
	* prometheusMiddleware is a middleware function that records Prometheus metrics for each HTTP request.
	* It tracks the request count and latency for each endpoint.
	* @param next http.Handler - The next handler to call in the chain.
	*
	* @return http.Handler - A new handler that includes the Prometheus metrics tracking.
	 */
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		start := time.Now() // Start time for latency measurement

		wrapped := newResponseWriter(w) // Wrap the original ResponseWriter

		next.ServeHTTP(wrapped, r) // Call the next handler

		duration := time.Since(start).Seconds() // Calculate request duration

		endpoint := r.URL.Path // Extract the endpoint path

		status := strconv.Itoa(wrapped.statusCode) // Get the response status code

		// Update Prometheus metrics

		requestCounter.WithLabelValues(endpoint, r.Method, status).Inc()
		requestLatency.WithLabelValues(endpoint).Observe(duration)
	})
}

func authMiddleware(next http.Handler) http.Handler {

	/*
	* authMiddleware is a middleware function that checks for a valid JWT token in the Authorization header.
	* If the token is valid, it allows the request to proceed to the next handler; otherwise, it responds with an unauthorized error.
	* @param next http.Handler - The next handler to call if authentication is successful.
	*
	* @return http.Handler - A new handler that includes the authentication check.
	 */

	/*
	* Extraction of the Autorization header from the incoming HTTP request.
	 */
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			respondWithError(w, http.StatusUnauthorized, "Missing Authorization header")
			return
		}

		/*
		* Splitting the Authorization header to extract the Bearer token.
		 */

		//parts := strings.Split(authHeader, " ")
		parts := strings.SplitN(authHeader, " ", 2) // is safer in case the token contains spaces
		if len(parts) != 2 || parts[0] != "Bearer" {
			respondWithError(w, http.StatusUnauthorized, "Invalid Authorization header format")
			return
		}

		tokenStr := parts[1]
		if tokenStr == "" {
			respondWithError(w, http.StatusUnauthorized, "Missing token")
			return
		}

		/*
		* Parsing and validating the JWT token.
		 */
		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return jwtKey, nil
		})

		if err != nil || !token.Valid {
			respondWithError(w, http.StatusUnauthorized, "Invalid token")
			return
		}

		/*
		* Extracting the user ID from the token claims and setting it in the request header for downstream handlers.
		 */
		userID := claims.UserID
		if userID == "" {
			respondWithError(w, http.StatusUnauthorized, "Invalid token claims")
			return
		}
		/*
		* Setting the user ID in the request header for downstream handlers.
		 */
		r.Header.Set("X-User-ID", userID)
		log.Printf("Authenticated request for user ID: %s", userID)
		next.ServeHTTP(w, r)
	})
}
