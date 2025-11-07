package main

import "net/http"

func getProfileHandler(w http.ResponseWriter, r *http.Request) {

	/*
	* getProfileHandler handles requests to retrieve the authenticated user's profile.
	* It extracts the user ID from the request header and responds with a success message.
	* @param w http.ResponseWriter - The response writer to send responses to the client.
	* @param r *http.Request - The incoming HTTP request.
	* @return void
	 */

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		respondWithError(w, http.StatusUnauthorized, "User ID not found in request")
		return
	}

	respondWithJSON(w, http.StatusOK, map[string]string{
		"message": "User profile accessed successfully",
		"user_id": userID,
	})
}

/*func methodNotAllowedHandler(w http.ResponseWriter, r *http.Request) {
	respondWithError(w, http.StatusMethodNotAllowed, "Method not allowed")
}*/
