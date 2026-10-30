import os
import sqlite3
import time

import auth


def memory():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE users (id INTEGER PRIMARY KEY, paid_until INTEGER NOT NULL DEFAULT 0, plan TEXT NOT NULL DEFAULT '')"
    )
    conn.execute("INSERT INTO users(id, paid_until, plan) VALUES (7, 0, '')")
    conn.execute(
        """
        CREATE TABLE payments (
          mp_id TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL,
          plan TEXT NOT NULL,
          days INTEGER NOT NULL,
          amount_cents INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE subscription_requests (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          plan TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pendente'
        )
        """
    )
    conn.execute(
        "INSERT INTO subscription_requests(user_id, plan, created_at) VALUES (7, 'mensal', ?)",
        (int(time.time()),),
    )
    return conn


def payment(**extra):
    data = {
        "id": 1001,
        "status": "approved",
        "currency_id": "BRL",
        "transaction_amount": 49.99,
        "external_reference": "7:mensal:mes",
    }
    data.update(extra)
    return data


def main():
    body = auth.build_preference(7, "mensal", "ano")
    assert "payer" not in body
    body = auth.build_preference(7, "mensal", "ano", "maria@example.com")
    assert body["payer"]["email"] == "maria@example.com"
    assert body["external_reference"] == "7:mensal:ano"
    assert round(body["items"][0]["unit_price"] * 100) == 48000
    assert body["notification_url"].endswith("/api/mercadopago/webhook")

    os.environ["MERCADOPAGO_ACCESS_TOKEN"] = "APP_USR-exemplo"
    assert auth.checkout_url({"sandbox_init_point": "https://sandbox", "init_point": "https://www"}) == "https://www"
    del os.environ["MERCADOPAGO_ACCESS_TOKEN"]

    conn = memory()
    assert auth.apply_approved_payment(conn, payment(status="pending")) == "ignored"
    assert conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"] == 0

    assert auth.apply_approved_payment(conn, payment(transaction_amount=1)) == "ignored"
    assert conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"] == 0

    before = int(time.time())
    assert auth.apply_approved_payment(conn, payment()) == "applied"
    paid_until = conn.execute("SELECT paid_until, plan FROM users WHERE id = 7").fetchone()
    assert paid_until["plan"] == "mensal"
    assert paid_until["paid_until"] >= before + 31 * auth.DAY - 2
    assert conn.execute("SELECT status FROM subscription_requests").fetchone()["status"] == "concluido"

    assert auth.apply_approved_payment(conn, payment()) == "duplicate"
    again = conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"]
    assert again == paid_until["paid_until"]

    assert auth.apply_approved_payment(conn, payment(external_reference="consulta:1", transaction_amount=10.9)) == "ignored"
    assert conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"] == paid_until["paid_until"]

    prepared, error = auth.prepare_consulta("essencial", "111.444.777-35", "cpf")
    assert error == "" and prepared["cents"] == 1090 and prepared["document"] == "11144477735"
    assert auth.prepare_consulta("essencial", "111.111.111-11", "cpf")[0] is None
    assert auth.prepare_consulta("localizador", "maria@example.com", "email")[0]["document"] == "maria@example.com"
    assert auth.prepare_consulta("localizador", "11987654321", "telefone")[0]["search_type"] == "telefone"
    assert auth.prepare_consulta("protestos", "11.222.333/0001-81", "cnpj")[0] is not None

    body = auth.build_consulta_preference(9, "Localizador", 990, "maria@example.com")
    assert body["external_reference"] == "consulta:9"
    assert round(body["items"][0]["unit_price"] * 100) == 990
    assert "consulta=ok" in body["back_urls"]["success"]
    assert body["payer"]["email"] == "maria@example.com"

    conn.execute(
        """
        CREATE TABLE consultations (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          type_slug TEXT NOT NULL,
          search_type TEXT NOT NULL,
          document TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'aguardando',
          mp_id TEXT UNIQUE,
          result_json TEXT NOT NULL DEFAULT '',
          error TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          paid_at INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    conn.execute(
        """
        INSERT INTO consultations(id, user_id, type_slug, search_type, document, amount_cents, created_at)
        VALUES (9, 7, 'localizador', 'email', 'maria@example.com', 990, ?)
        """,
        (int(time.time()),),
    )
    paid_before = conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"]
    os.environ["CONSULTA_API_TOKEN"] = ""
    assert auth.apply_consulta_payment(conn, payment(id=2002, transaction_amount=1, external_reference="consulta:9")) == "ignored"
    assert auth.apply_consulta_payment(conn, payment(id=2002, transaction_amount=9.9, external_reference="consulta:9")) == "applied"
    row = conn.execute("SELECT status, mp_id, paid_at FROM consultations WHERE id = 9").fetchone()
    assert row["mp_id"] == "2002"
    assert row["status"] in ("paga", "falha", "consultando")
    assert conn.execute("SELECT paid_until FROM users WHERE id = 7").fetchone()["paid_until"] == paid_before
    assert auth.apply_consulta_payment(conn, payment(id=2002, transaction_amount=9.9, external_reference="consulta:9")) == "duplicate"

    for item in auth.CONSULTAS.values():
        cents = item["cents"]
        assert round((cents / 100) * 100) == cents
    assert auth.consulta_payload({"data": {"score": 1}})["score"] == 1
    assert auth.consulta_payload({"response": {"data": {"score": 2}}})["score"] == 2
    assert auth.consulta_payload({"error": False}) is None

    conn.execute(
        """
        INSERT INTO consultations(id, user_id, type_slug, search_type, document, amount_cents, created_at)
        VALUES (11, 7, 'essencial', 'cpf', '11144477735', 1090, ?)
        """,
        (int(time.time()),),
    )
    waiting = conn.execute("SELECT * FROM consultations WHERE id = 11").fetchone()
    missed = auth.sync_consulta_payment(
        conn,
        waiting,
        lookup=lambda consult_id: payment(id=3003, transaction_amount=1, external_reference=f"consulta:{consult_id}"),
    )
    assert missed["status"] == "aguardando" and not missed["mp_id"]
    synced = auth.sync_consulta_payment(
        conn,
        missed,
        lookup=lambda consult_id: payment(id=3003, transaction_amount=10.9, external_reference=f"consulta:{consult_id}"),
    )
    assert synced["mp_id"] == "3003"
    assert synced["status"] in ("paga", "falha", "consultando")
    again = auth.sync_consulta_payment(conn, synced, lookup=lambda _consult_id: (_ for _ in ()).throw(AssertionError("repetiu")))
    assert again["mp_id"] == "3003"
    kept = auth.resume_consulta(conn, synced)
    assert kept["error"] == synced["error"]

    now = int(time.time())
    people = sqlite3.connect(":memory:")
    people.row_factory = sqlite3.Row
    people.execute(
        """
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL,
          name TEXT NOT NULL,
          email TEXT NOT NULL DEFAULT '',
          role TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          trial_ends_at INTEGER NOT NULL DEFAULT 0,
          paid_until INTEGER NOT NULL DEFAULT 0,
          plan TEXT NOT NULL DEFAULT ''
        )
        """
    )
    people.execute(
        "INSERT INTO users(id, username, name, role, created_at, trial_ends_at, paid_until, plan) VALUES (2, 'op', 'Op', 'comum', ?, 1, ?, 'mensal')",
        (now - 10 * auth.DAY, now + 20 * auth.DAY),
    )
    people.execute(
        "INSERT INTO users(id, username, name, role, created_at, trial_ends_at, paid_until, plan) VALUES (1, 'admin', 'Admin', 'admin', ?, ?, ?, 'cortesia')",
        (now, now + 3650 * auth.DAY, now + 3650 * auth.DAY),
    )
    fresh, message = auth.cancel_subscription(people, 1)
    assert fresh is None and "administrador" in message
    assert people.execute("SELECT paid_until FROM users WHERE id = 1").fetchone()["paid_until"] > now
    fresh, message = auth.cancel_subscription(people, 2)
    assert message == "" and fresh["plan"] == "" and fresh["paid_until"] == 0
    assert auth.access_of(fresh)["status"] == "vencido"
    again, message = auth.cancel_subscription(people, 2)
    assert again is None and "ativa" in message

    codes = sqlite3.connect(":memory:")
    codes.row_factory = sqlite3.Row
    codes.execute(
        """
        CREATE TABLE password_codes (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          code_hash TEXT NOT NULL,
          salt TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          password_salt TEXT NOT NULL,
          expires_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
        """
    )
    salt, digest = auth.hash_password("senha123")
    owner = {"id": 4, "email": "maria@example.com", "salt": salt, "password_hash": digest}
    sent = []

    def send(email, code):
        sent.append((email, code))

    moment = 1_700_000_000
    masked, message, status = auth.start_password_change(codes, owner, "errada", "nova1234", send, now=moment)
    assert masked is None and status == 400 and sent == []
    masked, message, status = auth.start_password_change(codes, owner, "senha123", "nova1234", send, now=moment)
    assert status == 200 and masked == "m***@example.com" and message == ""
    code = sent[0][1]
    assert code not in message and len(code) == 6
    ok, message = auth.take_password_code(codes, 4, "000000", "nova1234", now=moment)
    assert not ok and "incorreto" in message
    ok, message = auth.take_password_code(codes, 4, code, "outra123", now=moment)
    assert not ok and "mudou" in message
    ok, message = auth.take_password_code(codes, 4, code, "nova1234", now=moment)
    assert ok and message == ""
    ok, message = auth.take_password_code(codes, 4, code, "nova1234", now=moment + auth.PASSWORD_CODE_TTL + 5)
    assert not ok and "expirou" in message

    def boom(email, code):
        raise auth.MailError("envio")

    masked, message, status = auth.start_password_change(codes, owner, "senha123", "nova1234", boom, now=moment + 10)
    assert status == 502 and "e-mail" in message
    assert codes.execute("SELECT COUNT(*) AS n FROM password_codes WHERE expires_at > ?", (moment + 10,)).fetchone()["n"] == 0
    empty = dict(owner)
    empty["email"] = ""
    masked, message, status = auth.start_password_change(codes, empty, "senha123", "nova1234", send, now=moment + 20)
    assert status == 400 and "e-mail" in message

    codes.execute(
        """
        CREATE TABLE sessions (
          token TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        )
        """
    )
    codes.executemany(
        "INSERT INTO sessions(token, user_id, expires_at) VALUES (?, ?, ?)",
        [("atual", 4, moment + 1000), ("outro", 4, moment + 1000), ("alheio", 8, moment + 1000)],
    )
    auth.end_other_sessions(codes, 4, "atual")
    left = [row["token"] for row in codes.execute("SELECT token FROM sessions ORDER BY token")]
    assert left == ["alheio", "atual"]
    auth.end_other_sessions(codes, 8, "")
    left = [row["token"] for row in codes.execute("SELECT token FROM sessions ORDER BY token")]
    assert left == ["atual"]

    box = sqlite3.connect(":memory:")
    box.row_factory = sqlite3.Row
    box.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email_confirmed INTEGER NOT NULL DEFAULT 0)")
    box.execute(
        """
        CREATE TABLE email_confirmations (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          token_hash TEXT NOT NULL,
          expires_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
        """
    )
    box.execute("INSERT INTO users(id, name) VALUES (3, ?)", ("<script>Maria",))
    moment = 1_700_000_000
    token = auth.issue_email_confirmation(box, 3, moment)
    assert token and auth.email_token_hash(token) != token
    plain, html_body = auth.confirmation_mail("<script>Maria", "https://acertaifinancas.com.br/api/confirm-email?token=abc")
    assert "&lt;script&gt;Maria" in html_body
    assert "<script>" not in html_body
    assert "logo.png" in html_body
    assert "Liberar minha conta" in html_body
    assert "<script>Maria" in plain
    assert "não vale mais" in auth.confirmation_page(False)
    assert auth.take_email_confirmation(box, "errado", moment) is None
    opened = auth.take_email_confirmation(box, token, moment)
    assert opened["name"] == "<script>Maria"
    assert box.execute("SELECT email_confirmed FROM users WHERE id = 3").fetchone()["email_confirmed"] == 1
    assert auth.take_email_confirmation(box, token, moment) is None
    assert "&lt;script&gt;Maria" in auth.confirmation_page(True, opened["name"])
    for _ in range(5):
        assert auth.issue_email_confirmation(box, 3, moment + 10)
    assert auth.issue_email_confirmation(box, 3, moment + 10) is None

    store = sqlite3.connect(":memory:")
    store.row_factory = sqlite3.Row
    store.execute(
        """
        CREATE TABLE account_data (
          user_id INTEGER PRIMARY KEY,
          revision INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          payload TEXT NOT NULL
        )
        """
    )
    payload = {"clients": [{"id": 1, "name": "Ana"}], "settings": {"creditor_name": "Casa"}}
    status, revision, _, _ = auth.store_account(store, 1, 0, payload, 10)
    assert status == "ok" and revision == 1
    status, revision, _, current = auth.store_account(store, 1, 0, payload, 11)
    assert status == "conflict" and revision == 1
    assert current["clients"][0]["name"] == "Ana"
    status, _, _, _ = auth.store_account(store, 1, 1, {"settings": {"session_token": "x"}}, 12)
    assert status == "invalid"
    status, revision, _, _ = auth.store_account(
        store, 1, 1, {"clients": [], "settings": {"pix_key": "abc"}}, 12
    )
    assert status == "ok" and revision == 2
    assert auth.account_payload_ok({"nope": []}) is False
    print("ok")


if __name__ == "__main__":
    main()
