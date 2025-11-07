package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

var (
	userServiceURL = getEnvOrDefault("USER_SERVICE_URL", "http://user-load-balancer:9001")
	postServiceURL = getEnvOrDefault("POST_SERVICE_URL", "http://post-load-balancer:9002")
	feedServiceURL = getEnvOrDefault("FEED_SERVICE_URL", "http://feed-service:5000")
)

var (
	userServiceProxy *httputil.ReverseProxy
	postServiceProxy *httputil.ReverseProxy
	feedServiceProxy *httputil.ReverseProxy
)

func initializeProxies() error {
	var err error

	userServiceProxy, err = createReverseProxy(userServiceURL)
	if err != nil {
		return fmt.Errorf("failed to create user service proxy: %w", err)
	}

	postServiceProxy, err = createReverseProxy(postServiceURL)
	if err != nil {
		return fmt.Errorf("failed to create post service proxy: %w", err)
	}

	feedServiceProxy, err = createReverseProxy(feedServiceURL)
	if err != nil {
		return fmt.Errorf("failed to create feed service proxy: %w", err)
	}

	log.Println("Reverse proxies initialized")
	log.Printf("User Service : %s", userServiceURL)
	log.Printf("Post Service : %s", postServiceURL)
	log.Printf("Feed Service : %s", feedServiceURL)

	return nil
}

func createReverseProxy(targetURL string) (*httputil.ReverseProxy, error) {

	target, err := url.Parse(targetURL)
	if err != nil {
		return nil, fmt.Errorf("invalid target URL: %w", err)
	}

	//Create the reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(target)

	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {

		originalDirector(req)

		log.Printf("Forwarding: %s %s to %s %s", req.Method, req.URL.Path, target.Host, req.URL.Path)
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("x Proxy error for %s %s: %v", r.Method, r.URL.Path, err)
		if strings.Contains(err.Error(), "404") || strings.Contains(err.Error(), "connection refused") || strings.Contains(err.Error(), "not found") {
			respondWithError(w, http.StatusBadGateway, "Not found")
		} else {
			respondWithError(w, http.StatusBadGateway, "Backend service temporarily unavaible")
		}
	}

	return proxy, nil
}
