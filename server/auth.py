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
DAY = 24 * 60 * 60
USERNAME = re.compile(r"^[a-z0-9._]{3,32}$")

# Planos oferecidos. Preencha "link" com o endereço de pagamento para abrir direto;
# vazio, o app registra o pedido e mostra como falar com o suporte.
PLANS = {
    "mensal": {"label": "Plano Mensal", "price": "R$ 49,99/mês", "months": 1, "link": ""},
    "app_relatorio": {"label": "Aplicativo + Relatório", "price": "R$ 69,90/mês", "months": 1, "link": ""},
}
CHECKOUT_MESSAGE = (
    "Pedido registrado. Fale com o suporte para concluir o pagamento e liberar o acesso."
)
TRIAL_DAYS = 3
# Configurações de cada pessoa que acompanham o login em qualquer aparelho.
SETTING_KEY = re.compile(
    r"^(creditor_name|company_name|pix_key|pix_keys|font_scale|sig_[a-z_]{1,40}|msg_[a-z0-9_]{1,60})$"
)
SETTING_VALUE_MAX = 20_000
SETTINGS_MAX = 200


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
          created_at INTEGER NOT NULL,
          trial_ends_at INTEGER NOT NULL DEFAULT 0,
          paid_until INTEGER NOT NULL DEFAULT 0,
          plan TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS sessions (
          token TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          expires_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS user_settings (
          user_id INTEGER NOT NULL REFERENCES users(id),
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (user_id, key)
        );
        CREATE TABLE IF NOT EXISTS subscription_requests (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          plan TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pendente'
        );
        """
    )
    upgraded = False
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()}
    for name, definition in (
        ("trial_ends_at", "INTEGER NOT NULL DEFAULT 0"),
        ("paid_until", "INTEGER NOT NULL DEFAULT 0"),
        ("plan", "TEXT NOT NULL DEFAULT ''"),
    ):
        if name not in columns:
            conn.execute(f"ALTER TABLE users ADD COLUMN {name} {definition}")
            upgraded = True
    if upgraded:
        # Quem administra o sistema não é afetado pelo teste; os demais começam os 3 dias agora.
        now = int(time.time())
        conn.execute(
            "UPDATE users SET paid_until = ?, plan = 'cortesia' WHERE role = 'admin'",
            (now + 3650 * DAY,),
        )
        conn.execute(
            "UPDATE users SET trial_ends_at = ?, paid_until = 0, plan = '' WHERE role != 'admin'",
            (now + TRIAL_DAYS * DAY,),
        )
        conn.commit()
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
            INSERT INTO users(username, name, role, salt, password_hash, active, created_at, trial_ends_at)
            VALUES (?, ?, ?, ?, ?, 1, ?, ?)
            """,
            (username, name, role, salt, digest, now, now + TRIAL_DAYS * DAY),
        )
        created.append(f"{username} ({role}): {password}")
    conn.commit()
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(PASSWORD_FILE, flags, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write("\n".join(created) + "\n")


def access_of(row, now=None):
    """Situação do acesso: teste, assinatura ativa ou vencido, com os dias restantes."""
    now = int(now or time.time())
    paid_until = int(row["paid_until"] or 0)
    created = int(row["created_at"] or now)
    trial_end = int(row["trial_ends_at"] or 0) or (created + TRIAL_DAYS * DAY)
    # Administrador nunca fica trancado fora do sistema.
    admin = row["role"] == "admin"
    if paid_until > now:
        return {
            "status": "assinante",
            "days_left": (paid_until - now + DAY - 1) // DAY,
            "trial_ends_at": trial_end,
            "paid_until": paid_until,
            "plan": row["plan"] or "",
            "blocked": False,
        }
    if trial_end > now:
        return {
            "status": "teste",
            "days_left": (trial_end - now + DAY - 1) // DAY,
            "trial_ends_at": trial_end,
            "paid_until": paid_until,
            "plan": row["plan"] or "",
            "blocked": False,
        }
    return {
        "status": "vencido",
        "days_left": 0,
        "trial_ends_at": trial_end,
        "paid_until": paid_until,
        "plan": row["plan"] or "",
        "blocked": not admin,
    }


def public_user(row, now=None):
    return {
        "id": row["id"],
        "username": row["username"],
        "name": row["name"],
        "role": row["role"],
        "active": bool(row["active"]),
        "access": access_of(row, now),
    }


def current_user(conn, header):
    if not header or not header.startswith("Bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    row = conn.execute(
        """
        SELECT u.id, u.username, u.name, u.role, u.active, u.created_at,
               u.trial_ends_at, u.paid_until, u.plan
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
            if method == "POST" and path == "/api/signup":
                self._signup(conn, data)
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
            if path == "/api/subscribe" and method == "POST":
                self._subscribe(conn, actor, data)
                return
            if path == "/api/requests" and method == "GET":
                self._list_requests(conn, actor)
                return
            if path == "/api/settings" and method == "GET":
                self._get_settings(conn, actor)
                return
            if path == "/api/settings" and method == "POST":
                self._save_settings(conn, actor, data)
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
                elif action == "access":
                    self._set_access(conn, actor, user_id, data)
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

    def _signup(self, conn, data):
        """Conta nova, sempre comum, com 3 dias grátis e já entra no sistema."""
        recent = conn.execute(
            "SELECT COUNT(*) AS n FROM users WHERE created_at > ?",
            (int(time.time()) - 3600,),
        ).fetchone()["n"]
        if recent >= 40:
            self._send(429, {"error": "Muitas contas criadas agora. Tente de novo em alguns minutos."})
            return
        username = str(data.get("username", "")).strip().lower()
        name = str(data.get("name", "")).strip()
        password = str(data.get("password", ""))
        if not USERNAME.fullmatch(username):
            self._send(400, {"error": "Usuário: 3 a 32 letras, números, ponto ou _."})
            return
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        if len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        now = int(time.time())
        salt, digest = hash_password(password)
        try:
            cur = conn.execute(
                """
                INSERT INTO users(username, name, role, salt, password_hash, active, created_at, trial_ends_at)
                VALUES (?, ?, 'comum', ?, ?, 1, ?, ?)
                """,
                (username, name, salt, digest, now, now + TRIAL_DAYS * DAY),
            )
        except sqlite3.IntegrityError:
            self._send(409, {"error": "Já existe um usuário com esse login."})
            return
        token = secrets.token_urlsafe(32)
        conn.execute(
            "INSERT INTO sessions(token, user_id, expires_at) VALUES (?, ?, ?)",
            (token, cur.lastrowid, now + SESSION_SECONDS),
        )
        conn.commit()
        row = conn.execute(
            "SELECT id, username, name, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
            (cur.lastrowid,),
        ).fetchone()
        self._send(200, {"token": token, "user": public_user(row)})

    def _require_admin(self, actor):
        if actor["role"] != "admin":
            self._send(403, {"error": "Só um administrador pode fazer isso."})
            return False
        return True

    def _list_users(self, conn, actor):
        if not self._require_admin(actor):
            return
        rows = conn.execute("SELECT id, username, name, role, active, created_at, trial_ends_at, paid_until, plan FROM users ORDER BY name").fetchall()
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
                INSERT INTO users(username, name, role, salt, password_hash, active, created_at, trial_ends_at)
                VALUES (?, ?, ?, ?, ?, 1, ?, ?)
                """,
                (username, name, role, salt, digest, int(time.time()), int(time.time()) + TRIAL_DAYS * DAY),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            self._send(409, {"error": "Já existe um usuário com esse login."})
            return
        row = conn.execute(
            "SELECT id, username, name, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
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

    def _get_settings(self, conn, actor):
        rows = conn.execute("SELECT key, value FROM user_settings WHERE user_id = ?", (actor["id"],)).fetchall()
        self._send(200, {"settings": {row["key"]: row["value"] for row in rows}})

    def _subscribe(self, conn, actor, data):
        """Registra o pedido de assinatura e devolve o link de pagamento, quando configurado."""
        plan = str(data.get("plan", "")).strip()
        if plan not in PLANS:
            self._send(400, {"error": "Plano inválido."})
            return
        conn.execute(
            "INSERT INTO subscription_requests(user_id, plan, created_at) VALUES (?, ?, ?)",
            (actor["id"], plan, int(time.time())),
        )
        conn.commit()
        link = PLANS[plan]["link"]
        self._send(
            200,
            {
                "requested": True,
                "checkout_url": link,
                "message": CHECKOUT_MESSAGE if not link else "",
            },
        )

    def _list_requests(self, conn, actor):
        if not self._require_admin(actor):
            return
        rows = conn.execute(
            """
            SELECT r.id, r.plan, r.created_at, r.status, u.name, u.username
            FROM subscription_requests r
            JOIN users u ON u.id = r.user_id
            ORDER BY r.created_at DESC
            LIMIT 200
            """
        ).fetchall()
        self._send(
            200,
            {
                "requests": [
                    {
                        "id": row["id"],
                        "plan": row["plan"],
                        "plan_label": PLANS.get(row["plan"], {}).get("label", row["plan"]),
                        "created_at": row["created_at"],
                        "status": row["status"],
                        "name": row["name"],
                        "username": row["username"],
                    }
                    for row in rows
                ]
            },
        )

    def _set_access(self, conn, actor, user_id, data):
        """Libera ou encerra o acesso de alguém (usado depois de confirmar o pagamento)."""
        if not self._require_admin(actor):
            return
        row = conn.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        days = data.get("days", 0)
        try:
            days = int(days)
        except (TypeError, ValueError):
            self._send(400, {"error": "Informe os dias."})
            return
        if days < 0 or days > 3650:
            self._send(400, {"error": "Dias inválidos."})
            return
        plan = str(data.get("plan", "")).strip()
        current = conn.execute("SELECT paid_until FROM users WHERE id = ?", (user_id,)).fetchone()["paid_until"]
        base = max(int(current or 0), int(time.time()))
        paid_until = base + days * DAY if days else 0
        conn.execute(
            "UPDATE users SET paid_until = ?, plan = ? WHERE id = ?",
            (paid_until, plan if days else "", user_id),
        )
        conn.execute(
            "UPDATE subscription_requests SET status = 'concluido' WHERE user_id = ? AND status = 'pendente'",
            (user_id,),
        )
        conn.commit()
        fresh = conn.execute(
            "SELECT id, username, name, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
        self._send(200, {"user": public_user(fresh)})
    def _save_settings(self, conn, actor, data):
        changes = data.get("settings")
        if not isinstance(changes, dict):
            self._send(400, {"error": "Pedido inválido."})
            return
        for key, value in changes.items():
            if not isinstance(key, str) or not SETTING_KEY.match(key):
                self._send(400, {"error": "Configuração desconhecida."})
                return
            if value is not None and (not isinstance(value, str) or len(value) > SETTING_VALUE_MAX):
                self._send(400, {"error": "Valor inválido."})
                return
        existing = {
            row["key"]
            for row in conn.execute("SELECT key FROM user_settings WHERE user_id = ?", (actor["id"],)).fetchall()
        }
        final = (existing | {k for k, v in changes.items() if v is not None}) - {
            k for k, v in changes.items() if v is None
        }
        if len(final) > SETTINGS_MAX:
            self._send(400, {"error": "Configurações demais."})
            return
        for key, value in changes.items():
            if value is None:
                conn.execute("DELETE FROM user_settings WHERE user_id = ? AND key = ?", (actor["id"], key))
            else:
                conn.execute(
                    """
                    INSERT INTO user_settings(user_id, key, value) VALUES (?, ?, ?)
                    ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
                    """,
                    (actor["id"], key, value),
                )
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
            "SELECT id, username, name, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
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
