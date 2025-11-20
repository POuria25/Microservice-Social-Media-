package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"sync"
)

var (
	userServiceURL string
	postServiceURL string
	port           string
)

func init() {
	userServiceURL = os.Getenv("USER_SERVICE_URL")
	if userServiceURL == "" {
		userServiceURL = "http://user-load-balancer:9001"
	}

	postServiceURL = os.Getenv("POST_SERVICE_URL")
	if postServiceURL == "" {
		postServiceURL = "http://post-load-balancer:9002"
	}

	port = os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}

	log.Printf("Feed service Configuration:")
	log.Printf("User Service: %s", userServiceURL)
	log.Printf("Post Service: %s", postServiceURL)
	log.Printf("Port: %s", port)
}

func getUserFriends(userID string) ([]string, error) {

	/*
	* getUserFriends fetches the list of friend IDs for a given user from the user-service.
	*
	* @param userID string - The ID of the user whose friends are to be fetched.
	* @return []string - A slice of friend user IDs.
	* @return error - An error if the operation fails.
	 */

	if userID == "" {
		return []string{}, fmt.Errorf("missing user ID")
	}

	url := fmt.Sprintf("%s/pro", userServiceURL)
	log.Printf("[Feed] Fetching friends for user %s from %s", userID, url)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request to user-service: %w", err)
	}
	req.Header.Set("X-User-ID", userID)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calling user-service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("[Feed] user-service returned 404 for user %s - treating as no friends", userID)
		return []string{}, nil
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("[Feed] user-service returned status %d for user %s: %s", resp.StatusCode, userID, string(body))
		return nil, fmt.Errorf("user-service returned status %d", resp.StatusCode)
	}

	if err := json.NewDecoder(resp.Body).Decode(&profile); err != nil {
		log.Printf("[Feed] error decoding user-service response for user %s: %v", userID, err)
		return nil, fmt.Errorf("decoding user profile: %w", err)
	}

	if profile.Friends == nil {
		log.Printf("[Feed] user-service did not include 'friends' for user %s", userID)
		return []string{}, nil
	}

	log.Printf("[Feed] User %s has %d friend(s): %v", userID, len(profile.Friends), profile.Friends)
	return profile.Friends, nil
}

func getPostForUser(userID string) ([]Post, error) {

	/*
	* getPostForUser fetches posts for a specific user from the post-service.
	*
	* @param userID string - The ID of the user whose posts are to be fetched.
	* @return []Post - A slice of Post objects.
	* @return error - An error if the operation fails.
	 */

	url := fmt.Sprintf("%s/posts/%s", postServiceURL, userID)
	log.Printf("[Feed] Fetching posts for user %s from %s", userID, url)

	resp, err := http.Get(url)
	if err != nil {
		log.Printf("[Feed] Error calling post-service for user %s: %v", userID, err)
		return nil, fmt.Errorf("failed to call post-service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("[Feed] No posts for user %s", userID)
		return []Post{}, nil
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("[Feed] Post-service returned status %d for user %s", resp.StatusCode, userID)
		return nil, fmt.Errorf("post-service returned status %d", resp.StatusCode)
	}

	var posts []Post
	if err := json.NewDecoder(resp.Body).Decode(&posts); err != nil {
		log.Printf("[Feed] Error decoding posts for user %s: %v", userID, err)
		return nil, fmt.Errorf("failed to decode posts %w", err)
	}

	log.Printf("[Feed] Found %d post(s) for user %s", len(posts), userID)
	return posts, nil
}

func getPostFromfriends(friendIDs []string) []Post {

	/*
	* getPostFromfriends fetches posts from all friends concurrently.
	*
	* @param friendIDs []string - A slice of friend user IDs.
	* @return []Post - A slice of Post objects collected from all friends.
	 */

	var (
		wg       sync.WaitGroup
		mu       sync.Mutex
		allPosts []Post
	)

	postsChan := make(chan []Post, len(friendIDs))

	for _, friendID := range friendIDs {
		wg.Add(1)
		go func(fid string) {
			defer wg.Done()

			posts, err := getPostForUser(fid)
			if err != nil {
				log.Printf("[Feed] Failed to get posts for friend %s: %v", fid, err)
				return
			}

			if len(posts) > 0 {
				postsChan <- posts
			}
		}(friendID)
	}

	go func() {
		wg.Wait()
		close(postsChan)
	}()

	for posts := range postsChan {
		mu.Lock()
		allPosts = append(allPosts, posts...)
		mu.Unlock()
	}

	log.Printf("[Feed] Collected total of %d post(s) from all friends", len(allPosts))
	return allPosts
}

func sortAndLimitPosts(posts []Post, limit int) []Post {

	/*
	* sortAndLimitPosts sorts posts by creation time in descending order and
	* limits the result to a specified number.
	*
	* @param posts []Post - A slice of Post objects to be sorted and limited.
	* @param limit int - The maximum number of posts to return.
	* @return []Post - A slice of sorted and limited Post objects.
	 */

	sort.Slice(posts, func(i, j int) bool {
		return posts[i].CreatedAt.After(posts[j].CreatedAt)
	})

	if len(posts) > limit {
		posts = posts[:limit]
	}

	log.Printf("[Feed] Returning %d post(s) after sorting and limiting", len(posts))
	return posts
}

func getFeedHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* getFeedHandler handles the /feed endpoint to provide a user's feed.
	*
	* @param w http.ResponseWriter - The response writer to send data back to the client.
	* @param r *http.Request - The incoming HTTP request.
	 */

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		log.Printf("[Feed] Missing X-User-ID header")
		http.Error(w, "unauthorized: Missing user ID", http.StatusUnauthorized)
		return
	}

	log.Printf("[Feed] Processing feed request for user %s", userID)

	friends, err := getUserFriends(userID)
	if err != nil {
		log.Printf("[Feed] Error getting friends: %v", err)
		http.Error(w, "Failed to fetch friends", http.StatusInternalServerError)
		return
	}

	if len(friends) == 0 {
		log.Printf("[Feed] User %s has no friends, returning empty feed", userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode([]Post{})
		return
	}

	allPosts := getPostFromfriends(friends)

	if len(allPosts) == 0 {
		log.Printf("[Feed] No posts found for user %s 's friends", userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode([]Post{})
		return
	}

	limited := sortAndLimitPosts(allPosts, 10)

	log.Printf("[Feed] Successfully generated feed for user %s with %d post(s)", userID, len(limited))
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(limited)
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* healthCheckHandler handles the /health endpoint to provide a health status of the service.
	*
	* @param w http.ResponseWriter - The response writer to send data back to the client.
	* @param r *http.Request - The incoming HTTP request.
	 */

	w.WriteHeader(http.StatusOK)
	io.WriteString(w, "Feed service is healthy\n")
}
