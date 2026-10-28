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
    print("ok")


if __name__ == "__main__":
    main()
