package main

import (
	"log"
	"net/http"
	"strings"
)

func proxyToUserService(w http.ResponseWriter, r *http.Request) {
	/*
	* proxyToUserService proxies requests to the user service.
	* @param w http.ResponseWriter - The response writer to send data back to the client.
	* @param r *http.Request - The incoming HTTP request.
	 */

	log.Printf("Proxying to user service: %s %s", r.Method, r.URL.Path)
	r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api")
	userServiceProxy.ServeHTTP(w, r)
}

func proxyToPostService(w http.ResponseWriter, r *http.Request) {

	/*
	* proxyToPostService proxies requests to the post service.
	* @param w http.ResponseWriter - The response writer to send data back to the client.
	* @param r *http.Request - The incoming HTTP request.
	 */

	log.Printf("Proxying to post service: %s %s", r.Method, r.URL.Path)

	path := strings.TrimPrefix(r.URL.Path, "/api")

	if path == "/posts" {
		path = "/posts/me"
	}

	r.URL.Path = path
	postServiceProxy.ServeHTTP(w, r)
}

func proxyToFeedService(w http.ResponseWriter, r *http.Request) {
	/*
	* proxyToFeedService proxies requests to the feed service.
	* @param w http.ResponseWriter - The response writer to send data back to the client.
	* @param r *http.Request - The incoming HTTP request.
	 */

	log.Printf("Proxying to feed service: %s %s", r.Method, r.URL.Path)
	r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api")
	feedServiceProxy.ServeHTTP(w, r)
}
