package main

import (
	"io"
	"log"
	"net"
	"sync"
	"time"
)

// LoadBalancer represents a load balancer
type LoadBalancer struct {
	name     string
	backends []*Backend
	current  int64
	mutex    sync.Mutex
}

func (lb *LoadBalancer) NextBackend() *Backend {

	/*
	* Select the next available backend using round-robin
	* Parameters:
	*   None
	* Returns:
	*   Backend: The selected backend server
	 */

	lb.mutex.Lock()         // Lock the mutex for thread-safe access
	defer lb.mutex.Unlock() // Ensure the mutex is unlocked after selection

	for i := 0; i < len(lb.backends); i++ { // Loop through backends to find an alive one
		index := (int(lb.current)) % len(lb.backends) // Calculate the index using round-robin
		lb.current++

		Backend := lb.backends[index] // Get the backend at the calculated index
		if Backend.IsAlive() {
			log.Printf("[%s] - Selected backend: %s\n", lb.name, Backend.Address)
			return Backend // Return the alive backend
		}
	}
	log.Printf("[%s] - No alive backends available\n", lb.name)
	return nil
}

func (lb *LoadBalancer) TcpConnection(clientConn net.Conn) {

	/*
	* Handle a TCP connection and proxy it to the selected backend
	* Parameters:
	*   clientConn (net.Conn): The client connection to be proxied
	* Returns:
	*   None
	 */

	defer clientConn.Close() // Ensure the client connection is closed after handling

	backend := lb.NextBackend() // Select the next available backend
	if backend == nil {
		log.Printf("[%s] - No alive backends available\n", lb.name)
		return
	}

	// Establish a connection to the selected backend
	backendConn, err := net.DialTimeout("tcp", backend.Address, 5*time.Second)
	if err != nil {
		log.Printf("[%s] - Failed to connect to backend %s: %v\n", lb.name, backend.Address, err)
		backend.SetAlive(false)
		return
	}
	defer backendConn.Close() // Ensure the backend connection is closed after handling
	log.Printf("[%s] - Proxying connection to backend %s\n", lb.name, backend.Address)

	errCh := make(chan error, 2) // Channel to capture errors from goroutines

	// Start goroutines to copy data between client and backend
	go func() {
		_, err := io.Copy(backendConn, clientConn)
		errCh <- err
	}()

	go func() {
		_, err := io.Copy(clientConn, backendConn)
		errCh <- err
	}()

	<-errCh
}

func (lb *LoadBalancer) StartHealthCheck(interval time.Duration) {

	/*
	* Start periodic health checks for all backends
	* Parameters:
	*   interval (time.Duration): The interval between health checks
	* Returns:
	*   None
	 */

	// Start a ticker to perform health checks at regular intervals
	ticker := time.NewTicker(interval)
	go func() {
		for range ticker.C {
			for _, backend := range lb.backends {
				go backend.HealthCheck()
			}
		}
	}()

	log.Printf("[%s] - Started health checks (interval: %v)\n", lb.name, interval)
	// Initial health check on startup
	for _, backend := range lb.backends {
		backend.HealthCheck()
	}
}

func NewLoadBalancer(name string, backends []string) *LoadBalancer {

	/*
	* Create a new LoadBalancer instance
	* Parameters:
	*   name (string): Name of the load balancer pool
	*   backends ([]string): A list of backend server addresses
	* Returns:
	*   LoadBalancer: The created LoadBalancer instance
	 */

	// Initialize the LoadBalancer with the provided backends
	lb := &LoadBalancer{
		name:     name,
		backends: make([]*Backend, 0, len(backends)),
		current:  0,
	}
	// Add each backend to the load balancer
	for _, addr := range backends {
		backend := &Backend{
			Address: addr,
			Alive:   true,
		}
		lb.backends = append(lb.backends, backend)
		log.Printf("[%s] - Added backend: %s\n", name, addr)
	}
	return lb // Return the initialized LoadBalancer
}

func (lb *LoadBalancer) Start(port string) {

	/*
	* Start the load balancer to listen for incoming connections
	* Parameters
	*   port (string): The port on which the load balancer listens
	* Returns:
	*   None
	 */

	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("[%s] - Failed to start load balancer on port %s: %v\n", lb.name, port, err)
	}
	defer listener.Close()
	log.Printf("[%s] - Load balancer started on port %s\n", lb.name, port)

	for {
		clientConn, err := listener.Accept()
		if err != nil {
			log.Printf("[%s] - Failed to accept client connection: %v\n", lb.name, err)
			continue
		}

		go lb.TcpConnection(clientConn)
	}
}
