package main

import "time"

type Post struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type UserProfile struct {
	ID      string   `json:"id"`
	Email   string   `json:"email"`
	Friends []string `json:"friends"`
}
