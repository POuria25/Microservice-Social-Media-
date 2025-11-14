package main

import (
	"log"
	"net/http"
	"strings"
)

func proxyToUserService(w http.ResponseWriter, r *http.Request) {
	log.Printf("Proxying to user service: %s %s", r.Method, r.URL.Path)
	userServiceProxy.ServeHTTP(w, r)
}

func proxyToPostService(w http.ResponseWriter, r *http.Request) {
	log.Printf("Proxying to post service: %s %s", r.Method, r.URL.Path)

	path := strings.TrimPrefix(r.URL.Path, "/api")

	if path == "/posts" {
		path = "/posts/me"
	}

	r.URL.Path = path
	postServiceProxy.ServeHTTP(w, r)
}

func proxyToFeedService(w http.ResponseWriter, r *http.Request) {
	log.Printf("Proxying to feed service: %s %s", r.Method, r.URL.Path)
	feedServiceProxy.ServeHTTP(w, r)
}
