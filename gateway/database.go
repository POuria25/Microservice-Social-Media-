package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"
)

var db *sql.DB

func initializeDatabase(postgresURL string) error {

	/*
	* initializeDatabase sets up the connection to the PostgreSQL database.
	* It attempts to connect with retries and creates the necessary tables if they do not exist.
	* @param postgresURL string - The connection string for the PostgreSQL database.
	*
	* @return error - An error if the initialization fails, nil otherwise.
	 */

	var err error
	db, err = sql.Open("postgres", postgresURL)
	if err != nil {
		return fmt.Errorf("error opening database: %w", err)
	}

	if err := connectWithRetries(db, 5); err != nil {
		return fmt.Errorf("could not connect to database: %w", err)
	}

	log.Println("Successfully connected to database")

	if err := createUsersTable(db); err != nil {
		return fmt.Errorf("error creating table: %w", err)
	}

	log.Println("Users table created or already exists")
	log.Println("Gateway database setup complete!")
	return nil
}

func connectWithRetries(db *sql.DB, maxRetries int) error {

	/*
	* connectWithRetries attempts to connect to the database with retries.
	* @param db *sql.DB - The database connection object.
	* @param maxRetries int - The maximum number of connection attempts.
	*
	* @return error - An error if the connection could not be established after retries, nil otherwise.
	 */

	var err error
	for i := 0; i < maxRetries; i++ {
		err = db.Ping()
		if err == nil {
			return nil
		}
		log.Printf("Connection attempt %d failed, retrying...", i+1)
		time.Sleep(2 * time.Second)
	}
	return err
}

func createUsersTable(db *sql.DB) error {

	/*
	* createUsersTable creates the users table in the database if it does not already exist.
	* @param db *sql.DB - The database connection object.
	*
	* @return error - An error if the table could not be created, nil otherwise.
	 */

	createTableSQL := `
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY,
		email TEXT NOT NULL UNIQUE,
		password_hash TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	`

	_, err := db.Exec(createTableSQL)
	if err != nil {
		return fmt.Errorf("error executing CREATE TABLE: %w", err)
	}

	return nil
}
