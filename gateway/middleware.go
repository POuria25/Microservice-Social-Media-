package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

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
