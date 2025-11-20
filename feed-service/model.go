package main

import "time"

// Post represents a social media post.
type Post struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Content   string    `json:"content"`
	Title     string    `json:"title,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// UserProfile represents a user's profile information.
type UserProfile struct {
	ID       string   `json:"id"`
	Username string   `json:"username"`
	Email    string   `json:"email"`
	Friends  []string `json:"friends"`
}

// FeedItem represents an item in the user's feed, combining post and author information.
type FeedItem struct {
	Post   Post        `json:"post"`
	Author UserProfile `json:"author"`
}

// Internal struct to parse user profile response
var profile struct {
	Friends []string `json:"friends"`
}
