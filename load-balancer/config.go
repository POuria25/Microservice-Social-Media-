package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// BackendPool represents a pool backend servers
type BackendPool struct {
	Name       string   `yaml:"name"`
	ListenPort int      `yaml:"listen_port"`
	Backends   []string `yaml:"backends"`
}

// Config represents the load balancer configuration
type Config struct {
	Pools               []BackendPool `yaml:"pools"`
	HealthCheckInterval string        `yaml:"health_check_interval"`
	ConnectionTimeout   string        `yaml:"connection_timeout"`
}

func LoadConfig(path string) (*Config, error) {

	data, err := os.ReadFile(path) // Read File
	if err != nil {
		return nil, fmt.Errorf("failed to read config file : %w", err)
	}

	var config Config

	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	if len(config.Pools) == 0 {
		return nil, fmt.Errorf("Config validation failed, no pools defined in configuration")
	}

	for _, pool := range config.Pools {
		if pool.Name == "" {
			return nil, fmt.Errorf("pool name can not be empty")
		}
		if pool.ListenPort == 0 {
			return nil, fmt.Errorf("pool %s: listen_port can not be 0", pool.Name)
		}
		if len(pool.Backends) == 0 {
			return nil, fmt.Errorf("pool %s : no backends defined", pool.Name)
		}
	}
	return &config, nil
}

func (c *Config) GetHealthCheckInterval() time.Duration {
	if c.HealthCheckInterval == "" {
		return 10 * time.Second
	}
	duration, err := time.ParseDuration(c.HealthCheckInterval)
	if err != nil {
		log.Printf("Invalid health_check_interval %s", c.HealthCheckInterval)
		return 10 * time.Second
	}

	return duration
}

func (c *Config) GetConnectionTimeout() time.Duration {
	if c.ConnectionTimeout == "" {
		return 5 * time.Second
	}

	duration, err := time.ParseDuration(c.ConnectionTimeout)
	if err != nil {
		return 5 * time.Second
	}

	return duration
}
