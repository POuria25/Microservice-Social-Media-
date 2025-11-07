package main

import (
	"sync"
	"time"
)

var loginAttempts = make(map[string][]time.Time)
var loginAttemptsMutex sync.Mutex

const (
	maxLoginAttempts = 10
	loginWindowHours = 1
)

func checkRateLimit(email string) bool {

	/*
	* checkRateLimit checks if the login attempts for a given email exceed the allowed limit.
	* @param email string - The email address to check login attempts for.
	*
	* @return bool - True if the login attempt is allowed, false if rate limit is exceeded.
	 */

	loginAttemptsMutex.Lock()
	defer loginAttemptsMutex.Unlock()

	now := time.Now()
	cutoff := now.Add(-loginWindowHours * time.Hour)

	attempts, exists := loginAttempts[email]
	if !exists {
		loginAttempts[email] = []time.Time{now}
		return true
	}

	validAttempts := []time.Time{}
	for _, attemptTime := range attempts {
		if attemptTime.After(cutoff) {
			validAttempts = append(validAttempts, attemptTime)
		}
	}

	if len(validAttempts) >= maxLoginAttempts {
		return false
	}

	validAttempts = append(validAttempts, now)
	loginAttempts[email] = validAttempts
	return true
}
