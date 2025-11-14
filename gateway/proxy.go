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

	proxy := httputil.NewSingleHostReverseProxy(target)

	proxy.Director = func(req *http.Request) {

		req.URL.Path = strings.TrimPrefix(req.URL.Path, "/api")

		req.URL.Scheme = target.Scheme
		req.URL.Host = target.Host

		if v := req.Header.Get("X-User-ID"); v != "" {
			req.Header.Set("X-User-ID", v)

			req.Header.Set("User-ID", v)
		}
		if v := req.Header.Get("Authorization"); v != "" {
			req.Header.Set("Authorization", v)
		}

		//req.Header.Set("X-Forwarded-Host", req.Host)
		//req.Header.Set("X-Forwarded-Proto", "https")

		req.Header.Set("X-Original-Host", req.Host)
		req.Header.Set("X-Forwarded-Host", req.Host)
		req.Header.Set("X-Forwarded-Proto", "https")
		req.Header.Set("X-Forwarded-For", req.RemoteAddr)
	}

	proxy.ModifyResponse = func(resp *http.Response) error {
		log.Printf("BACKEND %s RESPONSE: %d %s", resp.Request.URL.Host, resp.StatusCode, resp.Request.URL.Path)
		return nil
	}

	return proxy, nil
}
