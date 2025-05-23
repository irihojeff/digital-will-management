import os
from functools import wraps
from datetime import datetime, timedelta

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
    env = os.getenv('FLASK_ENV', 'default')
    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.config.from_object(config[env])
    Session(app)

    if app.config.get('ORACLE_THICK_MODE'):
        oracledb.init_oracle_client(lib_dir=app.config['ORACLE_CLIENT_PATH'])

    # ─── Decorators ──────────────────────────────
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
            email    = request.form.get('email')
            password = request.form.get('password')
            conn = get_db_connection(); cur = conn.cursor()
            try:
                cur.execute("""
                    SELECT user_id, full_name, email, password_hash, role
                      FROM users
                     WHERE email = :email
                """, {'email': email})
                row = cur.fetchone()
                if row and check_password_hash(row[3], password):
                    session.update({
                        'user_id':    row[0],
                        'user_name':  row[1],
                        'user_email': row[2],
                        'user_role':  row[4],
                    })
                    session.permanent = True
                    flash(f'Welcome, {row[1]}!', 'success')
                    return redirect(url_for('dashboard'))
                flash('Invalid credentials.', 'danger')
            except oracledb.Error as err:
                flash(f'Login error: {err}', 'danger')
            finally:
                cur.close(); conn.close()
        return render_template('login.html')

    @app.route('/register', methods=['GET','POST'])
    def register():
        if request.method == 'POST':
            full_name = request.form.get('full_name')
            email     = request.form.get('email')
            password  = request.form.get('password')
            phone     = request.form.get('phone')
            dob       = request.form.get('dob')
            address   = request.form.get('address')
            role      = request.form.get('role')
            conn = get_db_connection(); cur = conn.cursor()
            try:
                cur.execute("SELECT COUNT(*) FROM users WHERE email = :email", {'email': email})
                if cur.fetchone()[0] > 0:
                    flash('Email already registered.', 'warning')
                    return render_template('register.html')
                cur.execute("""
                    INSERT INTO users (
                      full_name, email, phone_number,
                      date_of_birth, address, role, password_hash
                    ) VALUES (
                      :name, :email, :phone,
                      TO_DATE(:dob,'YYYY-MM-DD'), :addr, :role, :phash
                    )
                """, {
                    'name':  full_name,
                    'email': email,
                    'phone': phone,
                    'dob':   dob,
                    'addr':  address,
                    'role':  role,
                    'phash': generate_password_hash(password)
                })
                conn.commit()
                flash('Registration successful—please log in.', 'success')
                return redirect(url_for('login'))
            except oracledb.Error as err:
                flash(f'Registration error: {err}', 'danger')
                conn.rollback()
            finally:
                cur.close(); conn.close()
        return render_template('register.html')

    @app.route('/dashboard')
    @login_required
    def dashboard():
        role = session.get('user_role')
        stats = {}
        conn = get_db_connection(); cur = conn.cursor()
        try:
            if role == 'testator':
                cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :uid", {'uid': session['user_id']})
                stats['total_wills'] = cur.fetchone()[0]
                cur.execute("""
                    SELECT COUNT(*) FROM assets a
                     JOIN wills w ON a.will_id = w.will_id
                    WHERE w.user_id = :uid
                """, {'uid': session['user_id']})
                stats['total_assets'] = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :uid AND status='Draft'", {'uid': session['user_id']})
                stats['pending_wills'] = cur.fetchone()[0]
                cur.execute("""
                    SELECT COUNT(*) FROM will_asset_beneficiaries wab
                     JOIN assets a ON wab.asset_id = a.asset_id
                     JOIN wills w ON a.will_id = w.will_id
                    WHERE w.user_id = :uid
                """, {'uid': session['user_id']})
                stats['total_beneficiaries'] = cur.fetchone()[0]

            elif role == 'executor':
                cur.execute("SELECT COUNT(*) FROM executors WHERE email = :email", {'email': session['user_email']})
                stats['assigned_wills'] = cur.fetchone()[0]
                cur.execute("""
                    SELECT COUNT(*) FROM transfer_logs t
                     JOIN assets a ON t.asset_id = a.asset_id
                     JOIN wills w ON a.will_id = w.will_id
                     JOIN executors e ON w.will_id = e.will_id
                    WHERE e.email = :email AND t.transfer_status='Initiated'
                """, {'email': session['user_email']})
                stats['pending_transfers'] = cur.fetchone()[0]
                cur.execute("""
                    SELECT COUNT(*) FROM transfer_logs t
                     JOIN assets a ON t.asset_id = a.asset_id
                     JOIN wills w ON a.will_id = w.will_id
                     JOIN executors e ON w.will_id = e.will_id
                    WHERE e.email = :email AND t.transfer_status='Completed'
                """, {'email': session['user_email']})
                stats['completed_transfers'] = cur.fetchone()[0]

            elif role == 'beneficiary':
                cur.execute("""
                    SELECT COUNT(*) FROM will_asset_beneficiaries wab
                     JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    WHERE b.email = :email
                """, {'email': session['user_email']})
                stats['assigned_assets'] = cur.fetchone()[0]
                cur.execute("""
                    SELECT NVL(SUM(a.value * wab.share_percent/100),0) FROM will_asset_beneficiaries wab
                     JOIN assets a ON wab.asset_id = a.asset_id
                     JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    WHERE b.email = :email
                """, {'email': session['user_email']})
                stats['total_value'] = cur.fetchone()[0]

        except oracledb.Error as err:
            flash(f"Dashboard load error: {err}", 'danger')
        finally:
            cur.close(); conn.close()

        today = datetime.now()
        return render_template('dashboard.html',
                               role=role,
                               stats=stats,
                               today=today)

    @app.route('/wills')
    @login_required
    def list_wills():
        conn = get_db_connection(); cur = conn.cursor()
        try:
            if session['user_role']=='testator':
                cur.execute("""
                    SELECT will_id,title,description,status,created_at
                      FROM wills
                     WHERE user_id=:uid
                  ORDER BY created_at DESC
                """, {'uid': session['user_id']})
            else:
                cur.execute("""
                    SELECT DISTINCT w.will_id,w.title,w.description,w.status,w.created_at
                      FROM wills w
                      JOIN executors e ON w.will_id=e.will_id
                     WHERE e.email=:email
                  ORDER BY w.created_at DESC
                """, {'email': session['user_email']})
            wills = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Error fetching wills: {err}', 'danger'); wills=[]
        finally:
            cur.close(); conn.close()
        return render_template('wills/list.html', wills=wills)

    @app.route('/wills/create', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def create_will():
        if request.method=='POST':
            title = request.form.get('title')
            desc  = request.form.get('description')
            conn=get_db_connection(); cur=conn.cursor()
            try:
                cur.execute("""
                    INSERT INTO wills(user_id,title,description,status)
                    VALUES(:uid,:t,:d,'Draft')
                """, {'uid': session['user_id'], 't': title, 'd': desc})
                conn.commit()
                flash('Will created.', 'success')
                return redirect(url_for('list_wills'))
            except oracledb.Error as err:
                flash(f'Create error: {err}', 'danger'); conn.rollback()
            finally:
                cur.close(); conn.close()
        return render_template('wills/create.html')

    @app.route('/wills/<int:will_id>')
    @login_required
    def view_will(will_id):
        conn=get_db_connection(); cur=conn.cursor()
        try:
            cur.execute("""
                SELECT w.*,u.full_name FROM wills w
                 JOIN users u ON w.user_id=u.user_id
                WHERE w.will_id=:wid
            """, {'wid': will_id})
            will = cur.fetchone()
            cur.execute("""
                SELECT asset_id,name,description,asset_type,value,location
                  FROM assets WHERE will_id=:wid
            """, {'wid': will_id})
            assets=cur.fetchall()
            cur.execute("""
                SELECT executor_id,full_name,email,phone_number,is_primary
                  FROM executors WHERE will_id=:wid
            """, {'wid': will_id})
            executors=cur.fetchall()
        except oracledb.Error as err:
            flash(f'Fetch error: {err}','danger'); will,assets,executors = None,[],[]
        finally:
            cur.close(); conn.close()
        return render_template('wills/view.html',
                               will=will, assets=assets, executors=executors)

    @app.route('/wills/<int:will_id>/approve', methods=['POST'])
    @login_required
    @role_required(['testator','admin'])
    def approve_will(will_id):
        conn=get_db_connection(); cur=conn.cursor()
        try:
            cur.callproc('approve_will',[will_id])
            conn.commit(); flash('Will approved!','success')
        except oracledb.Error as err:
            flash(f'Approve error: {err}','danger'); conn.rollback()
        finally:
            cur.close(); conn.close()
        return redirect(url_for('view_will', will_id=will_id))

    @app.route('/wills/<int:will_id>/assets/add', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def add_asset(will_id):
        if request.method=='POST':
            f = request.form
            conn=get_db_connection(); cur=conn.cursor()
            try:
                cur.execute("""
                    INSERT INTO assets(
                      will_id,name,description,asset_type,
                      value,location,acquisition_date
                    ) VALUES (
                      :w,:n,:d,:t,:v,:l,TO_DATE(:ad,'YYYY-MM-DD')
                    )
                """, {
                    'w': will_id,
                    'n': f.get('name'),
                    'd': f.get('description'),
                    't': f.get('asset_type'),
                    'v': float(f.get('value') or 0),
                    'l': f.get('location'),
                    'ad': f.get('acquisition_date')
                })
                conn.commit(); flash('Asset added','success')
                return redirect(url_for('view_will', will_id=will_id))
            except oracledb.Error as err:
                flash(f'Add asset error: {err}','danger'); conn.rollback()
            finally:
                cur.close(); conn.close()
        return render_template('assets/add.html', will_id=will_id)

    @app.route('/assets/<int:asset_id>/assign', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def assign_asset(asset_id):
        if request.method=='POST':
            f=request.form; conn=get_db_connection(); cur=conn.cursor()
            try:
                cur.callproc('assign_asset_to_beneficiary',[
                    asset_id,
                    int(f.get('beneficiary_id')),
                    float(f.get('share_percent')),
                    f.get('conditions')
                ])
                conn.commit(); flash('Assigned!','success')
            except oracledb.Error as err:
                flash(f'Assign error: {err}','danger'); conn.rollback()
            finally:
                cur.close(); conn.close()
            return redirect(request.referrer or url_for('dashboard'))
        # GET: load form data
        conn=get_db_connection(); cur=conn.cursor()
        try:
            cur.execute("SELECT name,description,value FROM assets WHERE asset_id=:a",{'a':asset_id})
            asset=cur.fetchone()
            cur.execute("SELECT beneficiary_id,full_name,relation FROM beneficiaries ORDER BY full_name",{})
            bens=cur.fetchall()
            cur.execute("""
                SELECT b.full_name,wab.share_percent,wab.conditions
                  FROM will_asset_beneficiaries wab
                  JOIN beneficiaries b ON wab.beneficiary_id=b.beneficiary_id
                 WHERE wab.asset_id=:a
            """, {'a':asset_id})
            alloc=cur.fetchall()
        finally:
            cur.close(); conn.close()
        return render_template('assets/assign.html',
                               asset=asset, beneficiaries=bens,
                               current_allocations=alloc, asset_id=asset_id)

    @app.route('/beneficiaries', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def manage_beneficiaries():
        if request.method=='POST':
            f=request.form; conn=get_db_connection(); cur=conn.cursor()
            try:
                cur.execute("""
                    INSERT INTO beneficiaries(
                      full_name,relation,email,phone_number,
                      address,date_of_birth,notes
                    ) VALUES (
                      :n,:r,:e,:p,:a,TO_DATE(:d,'YYYY-MM-DD'),:o
                    )
                """, {
                    'n': f.get('full_name'),
                    'r': f.get('relation'),
                    'e': f.get('email'),
                    'p': f.get('phone'),
                    'a': f.get('address'),
                    'd': f.get('dob'),
                    'o': f.get('notes')
                })
                conn.commit(); flash('Beneficiary added','success')
            except oracledb.Error as err:
                flash(f'Beneficiaries error: {err}','danger'); conn.rollback()
            finally:
                cur.close(); conn.close()
            return redirect(url_for('manage_beneficiaries'))

        conn=get_db_connection(); cur=conn.cursor()
        try:
            cur.execute("""
                SELECT beneficiary_id,full_name,relation,email,phone_number
                  FROM beneficiaries
              ORDER BY full_name
            """)
            bens=cur.fetchall()
        except oracledb.Error as err:
            flash(f'Fetch error: {err}','danger'); bens=[]
        finally:
            cur.close(); conn.close()
        return render_template('beneficiaries/list.html', beneficiaries=bens)

    @app.route('/transfers')
    @login_required
    @role_required(['executor','admin'])
    def list_transfers():
        conn=get_db_connection(); cur=conn.cursor()
        try:
            if session['user_role']=='admin':
                cur.execute("""
                    SELECT t.transfer_id,a.name,b.full_name,
                           t.transfer_date,t.transfer_status,t.approved_by
                      FROM transfer_logs t
                      JOIN assets a ON t.asset_id=a.asset_id
                      JOIN beneficiaries b ON t.beneficiary_id=b.beneficiary_id
                  ORDER BY t.transfer_date DESC
                """)
            else:
                cur.execute("""
                    SELECT DISTINCT t.transfer_id,a.name,b.full_name,
                           t.transfer_date,t.transfer_status,t.approved_by
                      FROM transfer_logs t
                      JOIN assets a ON t.asset_id=a.asset_id
                      JOIN beneficiaries b ON t.beneficiary_id=b.beneficiary_id
                      JOIN wills w ON a.will_id=w.will_id
                      JOIN executors e ON w.will_id=e.will_id
                     WHERE e.email=:email
                  ORDER BY t.transfer_date DESC
                """, {'email': session['user_email']})
            transfers=cur.fetchall()
        except oracledb.Error as err:
            flash(f'Transfers error: {err}','danger'); transfers=[]
        finally:
            cur.close(); conn.close()
        return render_template('admin/transfers.html', transfers=transfers)

    @app.route('/transfers/initiate', methods=['POST'])
    @login_required
    @role_required(['executor','admin'])
    def initiate_transfer():
        asset_id      = int(request.form.get('asset_id'))
        beneficiary_id= int(request.form.get('beneficiary_id'))
        conn=get_db_connection(); cur=conn.cursor()
        try:
            cur.callproc('transfer_asset',[asset_id, beneficiary_id])
            conn.commit(); flash('Transfer initiated','success')
        except oracledb.Error as err:
            msg=str(err)
            if 'ORA-20001' in msg or 'ORA-20002' in msg:
                flash('Blocked (weekend/holiday)','warning')
            else:
                flash(f'Transfer error: {err}','danger')
            conn.rollback()
        finally:
            cur.close(); conn.close()
        return redirect(url_for('list_transfers'))

    @app.route('/logout')
    def logout():
        session.clear()
        flash('Logged out.','info')
        return redirect(url_for('index'))

    # Stub routes for the template placeholders
    @app.route('/documents/upload')
    @login_required
    def upload_document():
        flash('Upload coming soon','info')
        return redirect(url_for('dashboard'))

    @app.route('/assets/my')
    @login_required
    @role_required(['beneficiary'])
    def view_my_assets():
        flash('My assets view coming soon','info')
        return redirect(url_for('dashboard'))

    @app.route('/documents/download')
    @login_required
    @role_required(['beneficiary'])
    def download_documents():
        flash('Download coming soon','info')
        return redirect(url_for('dashboard'))

    return app

if __name__ == '__main__':
    create_app().run(debug=True, host='0.0.0.0', port=5000)
