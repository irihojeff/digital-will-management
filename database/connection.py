# database/connection.py

import oracledb
from contextlib import contextmanager
from flask import g
from config import Config

# (Optional) thick mode initialization
if Config.ORACLE_THICK_MODE:
    try:
        oracledb.init_oracle_client(lib_dir=Config.ORACLE_CLIENT_PATH)
    except Exception as e:
        print(f"Failed to init Oracle thick client: {e}")

class DatabaseConnection:
    """Helper for Oracle connections using oracledb."""

    def __init__(self):
        self.params = {
            'user':     Config.ORACLE_USER,
            'password': Config.ORACLE_PASSWORD,
            'dsn':      Config.ORACLE_DSN
        }

    def get_connection(self):
        return oracledb.connect(**self.params)

    @contextmanager
    def get_cursor(self, commit=True):
        conn = self.get_connection()
        cur  = conn.cursor()
        try:
            yield cur
            if commit:
                conn.commit()
        except:
            conn.rollback()
            raise
        finally:
            cur.close()
            conn.close()

# global instance
db = DatabaseConnection()

def get_db_connection():
    """Acquire a raw connection (for complex needs)."""
    return db.get_connection()
