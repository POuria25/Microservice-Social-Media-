package main

import (
	"fmt"
	"log"
	"os"
	"sync"
)

func main() {

	log.SetFlags(log.LstdFlags | log.Lshortfile)

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "/app/config.yaml"
	}

	log.Printf("Loading configuration from: %s", configPath)
	config, err := LoadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	if len(config.Pools) == 0 {
		log.Fatal("No backend pools configured in config.yaml")
	}

	log.Printf("Found %d pool(s) in configuration\n", len(config.Pools))

	var wg sync.WaitGroup

	for _, pool := range config.Pools {

		log.Printf("\n=== [%s] Initializing pool ===", pool.Name)
		log.Printf("  Port: %d", pool.ListenPort)
		log.Printf("  Backends: %v", pool.Backends)

		// Create load balancer for this pool - NOW PASSING THE NAME
		lb := NewLoadBalancer(pool.Name, pool.Backends)

		// Start health checks
		healthCheckInterval := config.GetHealthCheckInterval()
		lb.StartHealthCheck(healthCheckInterval)

		// Start the load balancer in a goroutine
		wg.Add(1)
		go func(LoadBalancer *LoadBalancer, port int) {
			defer wg.Done()
			LoadBalancer.Start(fmt.Sprintf("%d", port))
		}(lb, pool.ListenPort)
	}

	log.Println("\n=== All load balancers started successfully ===")
	log.Println("Press Ctrl+C to stop")

	// Wait forever (until killed)
	wg.Wait()

}
