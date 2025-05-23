# app.py

import os
from functools import wraps
from datetime import timedelta

from flask import (
    Flask, render_template, redirect, url_for,
    session, flash, request
)
from flask_session import Session
from werkzeug.security import generate_password_hash, check_password_hash
import oracledb

from config import config
from database.connection import get_db_connection

def create_app():
    # Pick config based on FLASK_ENV
    env = os.getenv('FLASK_ENV', 'default')
    app = Flask(
        __name__,
        template_folder="templates",
        static_folder="static"
    )
    app.config.from_object(config[env])

    # Flask-Session
    Session(app)

    # Optional: if you ever need thick mode
    if app.config['ORACLE_THICK_MODE']:
        oracledb.init_oracle_client(lib_dir=app.config['ORACLE_CLIENT_PATH'])

    # ─── Auth Decorators ──────────────────────────────
    def login_required(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            if 'user_id' not in session:
                flash('Please log in first.', 'warning')
                return redirect(url_for('login'))
            return f(*args, **kwargs)
        return wrapped

    def role_required(roles):
        def deco(f):
            @wraps(f)
            def wrapped(*args, **kwargs):
                if session.get('user_role') not in roles:
                    flash('You do not have permission.', 'danger')
                    return redirect(url_for('dashboard'))
                return f(*args, **kwargs)
            return wrapped
        return deco

    # ─── Routes ───────────────────────────────────────

    @app.route('/')
    def index():
        return render_template('index.html')

    @app.route('/login', methods=['GET','POST'])
    def login():
        if request.method == 'POST':
            email    = request.form['email']
            password = request.form['password']
            # role selection can be validated/stored if you want
            conn = get_db_connection()
            cur  = conn.cursor()
            try:
                cur.execute("""
                    SELECT user_id, full_name, email, password_hash, role 
                    FROM users WHERE email = :email
                """, {'email': email})
                row = cur.fetchone()
                if row and check_password_hash(row[3], password):
                    session['user_id']    = row[0]
                    session['user_name']  = row[1]
                    session['user_email'] = row[2]
                    session['user_role']  = row[4]
                    session.permanent      = True
                    flash(f'Welcome, {row[1]}!', 'success')
                    return redirect(url_for('dashboard'))
                else:
                    flash('Invalid credentials.', 'danger')
            except oracledb.Error as err:
                flash(f'Login error: {err}', 'danger')
            finally:
                cur.close()
                conn.close()
        return render_template('login.html')

    @app.route('/register', methods=['GET','POST'])
    def register():
        if request.method == 'POST':
            full_name = request.form['full_name']
            email     = request.form['email']
            password  = request.form['password']
            phone     = request.form['phone']
            dob       = request.form['dob']
            address   = request.form['address']
            role      = request.form['role']
            conn = get_db_connection()
            cur  = conn.cursor()
            try:
                # check exists
                cur.execute("SELECT COUNT(*) FROM users WHERE email = :email", {'email': email})
                if cur.fetchone()[0] > 0:
                    flash('Email already registered.', 'warning')
                    return render_template('register.html')
                # insert
                cur.execute("""
                    INSERT INTO users (
                      full_name, email, phone_number, date_of_birth,
                      address, role, password_hash
                    ) VALUES (
                      :name, :email, :phone,
                      TO_DATE(:dob,'YYYY-MM-DD'), :addr,
                      :role, :phash
                    )
                """, {
                    'name': full_name,
                    'email': email,
                    'phone': phone,
                    'dob': dob,
                    'addr': address,
                    'role': role,
                    'phash': generate_password_hash(password)
                })
                conn.commit()
                flash('Registration successful—please log in.', 'success')
                return redirect(url_for('login'))
            except oracledb.Error as err:
                flash(f'Registration error: {err}', 'danger')
                conn.rollback()
            finally:
                cur.close()
                conn.close()
        return render_template('register.html')

    @app.route('/dashboard')
    @login_required
    def dashboard():
        role = session.get('user_role')
        stats = {}
        conn = get_db_connection()
        cur  = conn.cursor()
        try:
            # demo: count of wills for testator
            if role == 'testator':
                cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :uid", {'uid': session['user_id']})
                stats['total_wills'] = cur.fetchone()[0]
        except oracledb.Error:
            pass
        finally:
            cur.close()
            conn.close()
        return render_template('dashboard.html', role=role, stats=stats)

    # ── Paste your other routes here (wills, assets, transfers, etc.) ──
    # Ensure each uses get_db_connection()

    return app

if __name__ == '__main__':
    # default picks DevelopmentConfig
    create_app().run(
        debug=True,
        host='0.0.0.0',
        port=5000
    )
