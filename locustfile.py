from locust import HttpUser, task, between
import random
import string
import urllib3
import json
import base64

# Ignore SSL warnings for self-signed certificate on https://localhost:8443
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class AuthenticatedUser(HttpUser):
    """
    Authenticated user:
    - on_start: register + login via gateway
    - then hits all authenticated endpoints:
        /api/feed
        /api/friends
        /api/posts (POST)
        /api/posts/{userId}
        /api/profile/me
        /api/profile/{userId}
    """
    wait_time = between(1, 3)
    host = "https://localhost:8443"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.client.verify = False

        self.token = None
        self.user_id = None
        self.username = None
        self.email = None
        self.password = None

    def on_start(self):
        # Generate unique credentials per virtual user
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
        self.username = f"user_{suffix}"
        self.email = f"{self.username}@test.com"
        self.password = f"Pass123!{suffix}"

        self._register()
        self._login()

    def _register(self):
        """
        POST /api/auth/register
        """
        self.environment.events.request.fire(
            request_type="INFO",
            name="[SETUP] register",
            response_time=0,
            response_length=0,
            exception=None,
        )

        resp = self.client.post(
            "/api/auth/register",
            json={
                "username": self.username,
                "email": self.email,
                "password": self.password,
            },
            name="/api/auth/register",
        )

        if resp.status_code in (200, 201, 409):
            try:
                data = resp.json()
                uid = data.get("user_id")
                if uid:
                    self.user_id = uid
            except Exception:
                pass
        else:
            print(f"[REGISTER] Failed ({resp.status_code}): {resp.text}")

    def _login(self):
        """
        POST /api/auth/login
        """
        self.environment.events.request.fire(
            request_type="INFO",
            name="[SETUP] login",
            response_time=0,
            response_length=0,
            exception=None,
        )

        resp = self.client.post(
            "/api/auth/login",
            json={
                "email": self.email,
                "password": self.password,
            },
            name="/api/auth/login",
        )

        if resp.status_code == 200:
            try:
                data = resp.json()
                self.token = data.get("access_token") or data.get("token")
                # If register didn't give us user_id, get it from JWT sub
                if self.token and not self.user_id:
                    self._extract_user_id_from_jwt()
            except Exception as e:
                print(f"[LOGIN] JSON parse error: {e} | resp={resp.text}")
        else:
            print(f"[LOGIN] Failed ({resp.status_code}): {resp.text}")

    def _extract_user_id_from_jwt(self):
        """
        Decode JWT payload and use "sub" as user_id (if present).
        """
        try:
            parts = self.token.split(".")
            if len(parts) != 3:
                return
            payload = parts[1]
            payload += "=" * (-len(payload) % 4)  # fix padding
            decoded = json.loads(base64.urlsafe_b64decode(payload))
            self.user_id = decoded.get("sub")
        except Exception as e:
            print(f"[JWT] Failed to decode token: {e}")

    def auth_headers(self):
        if self.token:
            return {"Authorization": f"Bearer {self.token}"}
        return {}

    @task(5)
    def get_feed(self):
        """
        GET /api/feed
        Forwarded directly to feed-service.
        """
        if not self.token:
            return

        self.client.get(
            "/api/feed",
            headers=self.auth_headers(),
            name="/api/feed",
        )

    @task(3)
    def create_post(self):
        """
        POST /api/posts
        Forwarded to post-service via post-service load-balancer.
        """
        if not self.token:
            return

        n = random.randint(1, 1000000)
        self.client.post(
            "/api/posts",
            headers=self.auth_headers(),
            name="/api/posts [POST]",
            json={
                "content": f"Test post from Locust #{n} by {self.username}",
                "title": f"Locust post #{n}",
            },
        )

    @task(2)
    def get_user_posts(self):
        """
        GET /api/posts/{userId}
        Forwarded to post-service via post-service load-balancer.
        """
        if not self.token or not self.user_id:
            return

        self.client.get(
            f"/api/posts/{self.user_id}",
            headers=self.auth_headers(),
            name="/api/posts/{userId}",
        )

    @task(2)
    def get_friends(self):
        """
        GET /api/friends
        Forwarded to user-service via user-service load-balancer.
        returns `null` for empty friends list.
        """
        if not self.token:
            return

        with self.client.get(
            "/api/friends",
            headers=self.auth_headers(),
            name="/api/friends",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(
                    f"Unexpected status {resp.status_code} for /api/friends: {resp.text}"
                )

    @task(1)
    def get_my_profile(self):
        """
        GET /api/profile/me
        Forwarded to user-service via user-service load-balancer.
        Acceptance criteria:
          - 200 OK as success
          - 404 with "User not found" as success at LB/gateway level
        """
        if not self.token:
            return

        with self.client.get(
            "/api/profile/me",
            headers=self.auth_headers(),
            name="/api/profile/me",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            elif resp.status_code == 404 and "User not found" in resp.text:
                resp.success()
            else:
                resp.failure(
                    f"Unexpected status {resp.status_code} for /api/profile/me: {resp.text}"
                )

    @task(1)
    def get_profile_by_id(self):
        """
        GET /api/profile/{userId}
        Forwarded to user-service via user-service load-balancer.

        Same acceptance criteria as /api/profile/me.
        """
        if not self.token or not self.user_id:
            return

        url = f"/api/profile/{self.user_id}"
        with self.client.get(
            url,
            headers=self.auth_headers(),
            name="/api/profile/{userId}",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            elif resp.status_code == 404 and "User not found" in resp.text:
                resp.success()
            else:
                resp.failure(
                    f"Unexpected status {resp.status_code} for {url}: {resp.text}"
                )


class UnauthenticatedUser(HttpUser):
    """
    Unauthenticated user:
    - only hits /api/auth/register and /api/auth/login
    to load test the public authentication surface.
    """
    wait_time = between(2, 4)
    host = "https://localhost:8443"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.client.verify = False

    @task
    def register_and_login(self):
        # Generate random user each time
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
        username = f"guest_{suffix}"
        email = f"{username}@test.com"
        password = f"Guest123!{suffix}"

        # Register
        self.client.post(
            "/api/auth/register",
            json={
                "username": username,
                "email": email,
                "password": password,
            },
            name="/api/auth/register",
        )

        # Login
        self.client.post(
            "/api/auth/login",
            json={
                "email": email,
                "password": password,
            },
            name="/api/auth/login",
        )
