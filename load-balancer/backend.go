package main

import (
	"log"
	"net"
	"sync"
	"time"
)

// Backend represents a backend server
type Backend struct {
	Address string
	Alive   bool
	mutex   sync.RWMutex
}

func (b *Backend) SetAlive(alive bool) {

	/*
	* Set the backend's alive status in a thread-safe manner
	* Parameters:
	*   alive (bool): The new alive status
	* Returns:
	*   None
	 */

	b.mutex.Lock()         // Lock the mutex for writing
	defer b.mutex.Unlock() // Ensure the mutex is unlocked after setting the status
	b.Alive = alive        // Update the alive status
}

func (b *Backend) IsAlive() bool {

	/*
	* Check if the backend is alive in a thread-safe manner
	* Parameters:
	*   None
	* Returns:
	*   bool: The current alive status of the backend
	 */

	b.mutex.RLock()         // Lock the mutex for reading
	defer b.mutex.RUnlock() // Ensure the mutex is unlocked after reading the status
	return b.Alive          // Return the alive status

}

func (b *Backend) HealthCheck() {

	/*
	* Perform a health check on the backend server
	* Parameters:
	*   None
	* Returns:
	*   None
	 */

	// Attempt to establish a TCP connection to the backend server
	timeout := 2 * time.Second                              // Set a timeout for the connection attempt
	conn, err := net.DialTimeout("tcp", b.Address, timeout) // Try to connect to the backend
	if err != nil {
		b.SetAlive(false)
		log.Printf("Health check failed for %s: %v\n", b.Address, err)
		return
	}
	conn.Close()     // Close the connection if successful
	b.SetAlive(true) // Mark the backend as alive
	log.Printf("Health check succeeded for %s\n", b.Address)
}
