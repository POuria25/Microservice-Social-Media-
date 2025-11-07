package main

import (
	"net/http"
	"strings"
)

func proxyToUserService(w http.ResponseWriter, r *http.Request) {

	//log.Print("Proxying to user service: %s %s", r.Method, r.URL.Path)
	r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api")
	userServiceProxy.ServeHTTP(w, r)
}

func proxyToPostService(w http.ResponseWriter, r *http.Request) {

	r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api")
	postServiceProxy.ServeHTTP(w, r)
}

func proxyToFeedService(w http.ResponseWriter, r *http.Request) {
	r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api")
	feedServiceProxy.ServeHTTP(w, r)
}
