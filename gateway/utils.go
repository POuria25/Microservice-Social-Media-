package main

import (
	"encoding/json"
	"net/http"
	"os"
)

func getEnvOrDefault(key, defaultValue string) string {

	/*
	* getEnvOrDefault retrieves the value of an environment variable or returns a default value if not set.
	* @param key string - The name of the environment variable.
	* @param defaultValue string - The default value to return if the environment variable is not set.
	*
	* @return string - The value of the environment variable or the default value.
	 */

	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func isValidEmail(email string) bool {

	/*
	* isValidEmail performs a basic validation of the email format.
	* @param email string - The email address to validate.
	*
	* @return bool - True if the email format is valid, false otherwise.
	*
	 */

	hasAt := false
	hasDot := false
	for _, char := range email {
		if char == '@' {
			hasAt = true
		}
		if char == '.' {
			hasDot = true
		}
	}
	return hasAt && hasDot && len(email) > 3
}

func respondWithJSON(w http.ResponseWriter, statusCode int, payload interface{}) {

	/*
	* respondWithJSON sends a JSON response to the client.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param statusCode int - The HTTP status code for the response.
	* @param payload interface{} - The data to be encoded as JSON and sent in the response
	*
	* @return void
	 */

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(payload)
}

func respondWithError(w http.ResponseWriter, statusCode int, message string) {

	/*
	* respondWithError sends an error response in JSON format to the client.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param statusCode int - The HTTP status code for the error response.
	* @param message string - The error message to be included in the response.
	*
	* @return void
	 */

	respondWithJSON(w, statusCode, ErrorResponse{Error: message})
}
