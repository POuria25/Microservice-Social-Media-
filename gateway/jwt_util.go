package main

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var jwtKey = []byte(getEnvOrDefault("JWT_SECRET", "my_secret_key"))

const jwtExpiryTime = 1 * time.Hour

func generateJWT(userID string) (string, error) {

	/*
	* generateJWT creates a JWT token for the authenticated user.
	* @param userID string - The ID of the user for whom the token is being generated.
	* @return string - The generated JWT token.
	* @return error - An error if the token could not be generated, nil otherwise.
	 */

	expirationTime := time.Now().Add(jwtExpiryTime)
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(jwtKey)
	if err != nil {
		return "", err
	}
	return tokenString, nil
}
