#!/usr/bin/env python3
"""Login e níveis de acesso do Juros. Escuta só em localhost."""

import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB_PATH = os.environ.get("JUROS_AUTH_DB", "/var/lib/juros/auth.db")
PASSWORD_FILE = os.environ.get("JUROS_AUTH_PASSWORDS", "/var/lib/juros/senhas-iniciais.txt")
HOST = "127.0.0.1"
PORT = 8765
ITERATIONS = 120_000
SESSION_SECONDS = 14 * 24 * 60 * 60
USERNAME = re.compile(r"^[a-z0-9._]{3,32}$")


def connect():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def hash_password(password, salt=None):
    if salt is None:
        salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), ITERATIONS).hex()
    return salt, digest


def password_ok(password, salt, digest):
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), ITERATIONS).hex()
    return hmac.compare_digest(check, digest)


def ensure_schema(conn):
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          salt TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS sessions (
          token TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          expires_at INTEGER NOT NULL
        );
        """
    )
    count = conn.execute("SELECT COUNT(*) AS n FROM users").fetchone()["n"]
    if count:
        conn.commit()
        return
    created = []
    now = int(time.time())
    for username, name, role in (
        ("admin", "Roberto Lins", "admin"),
        ("operador", "Operador", "comum"),
        ("caixa", "Caixa", "comum"),
    ):
        password = secrets.token_urlsafe(9)
        salt, digest = hash_password(password)
        conn.execute(
            """
            INSERT INTO users(username, name, role, salt, password_hash, active, created_at)
            VALUES (?, ?, ?, ?, ?, 1, ?)
            """,
            (username, name, role, salt, digest, now),
        )
        created.append(f"{username} ({role}): {password}")
    conn.commit()
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(PASSWORD_FILE, flags, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write("\n".join(created) + "\n")


def public_user(row):
    return {
        "id": row["id"],
        "username": row["username"],
        "name": row["name"],
        "role": row["role"],
        "active": bool(row["active"]),
    }


def current_user(conn, header):
    if not header or not header.startswith("Bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    row = conn.execute(
        """
        SELECT u.id, u.username, u.name, u.role, u.active
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token = ? AND s.expires_at > ?
        """,
        (token, int(time.time())),
    ).fetchone()
    if row is None or not row["active"]:
        return None
    return row


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._route("GET")

    def do_POST(self):
        self._route("POST")

    def log_message(self, fmt, *args):
        return

    def _route(self, method):
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b""
        try:
            data = json.loads(raw.decode() or "{}") if raw else {}
        except json.JSONDecodeError:
            self._send(400, {"error": "Pedido inválido."})
            return
        if not isinstance(data, dict):
            self._send(400, {"error": "Pedido inválido."})
            return
        conn = connect()
        try:
            if method == "GET" and path == "/api/health":
                self._send(200, {"ok": True})
                return
            if method == "POST" and path == "/api/login":
                self._login(conn, data)
                return
            actor = current_user(conn, self.headers.get("Authorization"))
            if actor is None:
                self._send(401, {"error": "Entre novamente."})
                return
            if method == "POST" and path == "/api/logout":
                token = self.headers.get("Authorization", "")[7:].strip()
                conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
                conn.commit()
                self._send(200, {"ok": True})
                return
            if path == "/api/me" and method == "GET":
                self._send(200, {"user": public_user(actor)})
                return
            if path == "/api/me" and method == "POST":
                self._update_profile(conn, actor, data)
                return
            if path == "/api/users" and method == "GET":
                self._list_users(conn, actor)
                return
            if path == "/api/users" and method == "POST":
                self._create_user(conn, actor, data)
                return
            parts = path.split("/")
            if len(parts) == 5 and parts[1] == "api" and parts[2] == "users" and method == "POST":
                try:
                    user_id = int(parts[3])
                except ValueError:
                    self._send(404, {"error": "Usuário não encontrado."})
                    return
                action = parts[4]
                if action == "role":
                    self._set_role(conn, actor, user_id, data)
                elif action == "active":
                    self._set_active(conn, actor, user_id, data)
                elif action == "password":
                    self._set_password(conn, actor, user_id, data)
                else:
                    self._send(404, {"error": "Não encontrado."})
                return
            self._send(404, {"error": "Não encontrado."})
        finally:
            conn.close()

    def _login(self, conn, data):
        username = str(data.get("username", "")).strip().lower()
        password = str(data.get("password", ""))
        row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
        if row is None or not password_ok(password, row["salt"], row["password_hash"]):
            self._send(401, {"error": "Usuário ou senha incorretos."})
            return
        if not row["active"]:
            self._send(403, {"error": "Este usuário está desativado."})
            return
        token = secrets.token_urlsafe(32)
        conn.execute(
            "INSERT INTO sessions(token, user_id, expires_at) VALUES (?, ?, ?)",
            (token, row["id"], int(time.time()) + SESSION_SECONDS),
        )
        conn.commit()
        self._send(200, {"token": token, "user": public_user(row)})

    def _require_admin(self, actor):
        if actor["role"] != "admin":
            self._send(403, {"error": "Só um administrador pode fazer isso."})
            return False
        return True

    def _list_users(self, conn, actor):
        if not self._require_admin(actor):
            return
        rows = conn.execute("SELECT id, username, name, role, active FROM users ORDER BY name").fetchall()
        self._send(200, {"users": [public_user(row) for row in rows]})

    def _create_user(self, conn, actor, data):
        if not self._require_admin(actor):
            return
        username = str(data.get("username", "")).strip().lower()
        name = str(data.get("name", "")).strip()
        password = str(data.get("password", ""))
        role = str(data.get("role", "comum"))
        if not USERNAME.fullmatch(username):
            self._send(400, {"error": "Usuário: 3 a 32 letras, números, ponto ou _."})
            return
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        if len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        if role not in ("admin", "comum"):
            self._send(400, {"error": "Nível de acesso inválido."})
            return
        salt, digest = hash_password(password)
        try:
            cur = conn.execute(
                """
                INSERT INTO users(username, name, role, salt, password_hash, active, created_at)
                VALUES (?, ?, ?, ?, ?, 1, ?)
                """,
                (username, name, role, salt, digest, int(time.time())),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            self._send(409, {"error": "Já existe um usuário com esse login."})
            return
        row = conn.execute(
            "SELECT id, username, name, role, active FROM users WHERE id = ?",
            (cur.lastrowid,),
        ).fetchone()
        self._send(200, {"user": public_user(row)})

    def _set_role(self, conn, actor, user_id, data):
        if not self._require_admin(actor):
            return
        role = str(data.get("role", ""))
        if role not in ("admin", "comum"):
            self._send(400, {"error": "Nível de acesso inválido."})
            return
        row = conn.execute("SELECT id, role FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if row["role"] == "admin" and role != "admin":
            admins = conn.execute("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND active = 1").fetchone()["n"]
            if admins <= 1:
                self._send(400, {"error": "Precisa continuar existindo um administrador."})
                return
        conn.execute("UPDATE users SET role = ? WHERE id = ?", (role, user_id))
        conn.commit()
        self._send(200, {"ok": True})

    def _set_active(self, conn, actor, user_id, data):
        if not self._require_admin(actor):
            return
        if actor["id"] == user_id:
            self._send(400, {"error": "Você não pode desativar a própria conta."})
            return
        active = 1 if data.get("active") else 0
        row = conn.execute("SELECT id, role, active FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if row["role"] == "admin" and row["active"] and not active:
            admins = conn.execute("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND active = 1").fetchone()["n"]
            if admins <= 1:
                self._send(400, {"error": "Precisa continuar existindo um administrador."})
                return
        conn.execute("UPDATE users SET active = ? WHERE id = ?", (active, user_id))
        if not active:
            conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
        conn.commit()
        self._send(200, {"ok": True})

    def _update_profile(self, conn, actor, data):
        name = str(data.get("name", "")).strip()
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        conn.execute("UPDATE users SET name = ? WHERE id = ?", (name, actor["id"]))
        conn.commit()
        row = conn.execute(
            "SELECT id, username, name, role, active FROM users WHERE id = ?",
            (actor["id"],),
        ).fetchone()
        self._send(200, {"user": public_user(row)})

    def _set_password(self, conn, actor, user_id, data):
        if actor["id"] != user_id and actor["role"] != "admin":
            self._send(403, {"error": "Só um administrador pode alterar a senha de outra pessoa."})
            return
        password = str(data.get("password", ""))
        if len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        row = conn.execute("SELECT id, salt, password_hash FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if actor["id"] == user_id and not password_ok(str(data.get("current", "")), row["salt"], row["password_hash"]):
            self._send(400, {"error": "Senha atual incorreta."})
            return
        salt, digest = hash_password(password)
        conn.execute("UPDATE users SET salt = ?, password_hash = ? WHERE id = ?", (salt, digest, user_id))
        if actor["id"] != user_id:
            conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
        conn.commit()
        self._send(200, {"ok": True})

    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    conn = connect()
    try:
        ensure_schema(conn)
    finally:
        conn.close()
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
