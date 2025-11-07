package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

func registerHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* registerHandler handles user registration requests.
	* It validates the input, checks for existing users, hashes the password,
	* and stores the new user in the database.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param r *http.Request - The incoming HTTP request containing registration data.
	*
	* @return void
	 */

	if r.Header.Get("Content-Type") != "application/json" {
		respondWithError(w, http.StatusBadRequest, "Content-Type must be application/json")
		return
	}

	var req RegisterUser
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	req.Email = strings.ToLower(req.Email)

	if req.Email == "" || req.Password == "" {
		respondWithError(w, http.StatusBadRequest, "Email and password are required")
		return
	}

	if !isValidEmail(req.Email) {
		respondWithError(w, http.StatusBadRequest, "Invalid email format")
		return
	}

	if len(req.Password) < 6 {
		respondWithError(w, http.StatusBadRequest, "Password must be at least 6 characters long")
		return
	}

	if len(req.Password) > 72 {
		respondWithError(w, http.StatusBadRequest, "Password must be at most 72 characters long")
		return
	}

	var exists bool
	err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE email=$1)", req.Email).Scan(&exists)
	if err != nil {
		log.Printf("Error checking existing user: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	if exists {
		respondWithError(w, http.StatusConflict, "Email already registered")
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost) // Fixed: added :
	if err != nil {
		log.Printf("Error hashing password: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	userID := uuid.New()

	_, err = db.Exec(
		"INSERT INTO users (id, email, password_hash, created_at) VALUES ($1, $2, $3, $4)",
		userID,
		req.Email,
		string(hashedPassword),
		time.Now(),
	)
	if err != nil {
		log.Printf("Error inserting new user: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	log.Printf("User registered successfully: %s (ID: %s)", req.Email, userID)
	respondWithJSON(w, http.StatusCreated, RegisterResponse{
		Message: "User registered successfully",
		UserID:  userID.String(),
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* loginHandler handles user login requests.
	* It validates the input, checks the credentials, and returns a JWT token upon successful authentication.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param r *http.Request - The incoming HTTP request containing login data.
	*
	* @return void
	 */

	if r.Header.Get("Content-Type") != "application/json" {
		respondWithError(w, http.StatusBadRequest, "Content-Type must be application/json")
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	req.Email = strings.ToLower(req.Email)

	if req.Email == "" || req.Password == "" {
		respondWithError(w, http.StatusBadRequest, "Email and password are required")
		return
	}

	if !checkRateLimit(req.Email) {
		respondWithError(w, http.StatusTooManyRequests, "Too many login attempts. Please try again later.")
		return
	}

	var userID string
	var passwordHash string
	err := db.QueryRow("SELECT id, password_hash FROM users WHERE email=$1", req.Email).Scan(&userID, &passwordHash)
	if err == sql.ErrNoRows {
		respondWithError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}
	if err != nil {
		log.Printf("Error querying user: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	token, err := generateJWT(userID)
	if err != nil {
		log.Printf("Error generating JWT: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	log.Printf("User logged in successfully: %s (ID: %s)", req.Email, userID)
	respondWithJSON(w, http.StatusOK, LoginResponse{
		AccessToken: token,
	})
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* healthCheckHandler responds to health check requests.
	* It verifies the database connection and returns the health status.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param r *http.Request - The incoming HTTP request for health check
	*
	* @return void
	 */

	if err := db.Ping(); err != nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database connection error") // Fixed: removed duplicate
		return
	}

	respondWithJSON(w, http.StatusOK, map[string]string{
		"status":   "healthy",
		"database": "connected",
	})
}
