package main

import "github.com/golang-jwt/jwt/v5"

/*
* RegisterUser represents the expected payload for user registration.
* It includes the user's email and password.
 */
type RegisterUser struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

/*
* LoginRequest represents the expected payload for user login.
* It includes the user's email and password.
 */
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

/*
* RegisterResponse represents the response sent back to the client upon successful registration.
* It includes a success message and the newly created user's ID.
 */
type RegisterResponse struct {
	Message string `json:"message"`
	UserID  string `json:"user_id"`
}

/*
* ErrorResponse represents the structure of an error response sent back to the client.
* It includes an error message.
 */
type ErrorResponse struct {
	Error string `json:"error"`
}

/*
* LoginResponse represents the response sent back to the client upon successful login.
* It includes the JWT access token.
 */
type LoginResponse struct {
	AccessToken string `json:"access_token"`
}

/*
* Claims represents the JWT claims structure.
* It includes the user ID and standard registered claims.
 */
type Claims struct {
	UserID string `json:"sub"`
	jwt.RegisteredClaims
}
