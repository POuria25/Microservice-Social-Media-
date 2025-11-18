package main

import "time"

type Post struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Content   string    `json:"content"`
	Titlle    string    `json:"title,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	//UpdatedAt time.Time `json:"updatedAt, omitempty"`
}

type UserProfile struct {
	ID       string   `json:"id"`
	Username string   `json:"username"`
	Email    string   `json:"email"`
	Friends  []string `json:"friends"`
}

var payload struct {
	Friends []string `json:"friends"`
}

type FeedItem struct {
	Post   Post        `json:"post"`
	Author UserProfile `json:"author"`
}

var profile struct {
	Friends []string `json:"friends"`
}
