import os
from functools import wraps
from datetime import datetime, timedelta

from flask import (
    Flask, render_template, redirect, url_for,
    session, flash, request, jsonify
)
from flask_session import Session
from werkzeug.security import generate_password_hash, check_password_hash
import oracledb

from config import config
from database.connection import get_db_connection, db

def create_app():
    env = os.getenv('FLASK_ENV', 'default')
    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.config.from_object(config[env])
    
    # Ensure upload folder exists
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['SESSION_FILE_DIR'], exist_ok=True)
    
    Session(app)

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
                user_role = session.get('user_role')
                all_roles = session.get('all_roles', [])
                
                # Check if user has any of the required roles
                has_permission = any(role in all_roles for role in roles)
                
                if not has_permission:
                    flash('You do not have permission.', 'danger')
                    return redirect(url_for('dashboard'))
                return f(*args, **kwargs)
            return wrapped
        return deco

    # ─── Helper Functions ────────────────────────
    def determine_user_role(user_id, email):
        """Determine user role based on their presence in different tables"""
        try:
            with db.get_cursor() as cur:
                # First check if user has an initial_role set during registration
                cur.execute("SELECT initial_role FROM users WHERE user_id = :user_id", {'user_id': user_id})
                initial_role_result = cur.fetchone()
                initial_role = initial_role_result[0] if initial_role_result else None
                
                # If they registered as admin, they remain admin
                if initial_role == 'admin':
                    return 'admin'
                
                # Check if user owns any wills (testator)
                cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :user_id", {'user_id': user_id})
                will_count = cur.fetchone()[0]
                
                # Check if user is an executor
                cur.execute("SELECT COUNT(*) FROM executors WHERE email = :email", {'email': email})
                executor_count = cur.fetchone()[0]
                
                # Check if user is a beneficiary
                cur.execute("SELECT COUNT(*) FROM beneficiaries WHERE email = :email", {'email': email})
                beneficiary_count = cur.fetchone()[0]
                
                # Determine primary role (prioritize testator > executor > beneficiary > initial_role)
                if will_count > 0:
                    return 'testator'
                elif executor_count > 0:
                    return 'executor'
                elif beneficiary_count > 0:
                    return 'beneficiary'
                elif initial_role:
                    return initial_role  # Use their registered role
                else:
                    return 'user'  # Default role for users without specific assignments
        except Exception as e:
            print(f"Error determining user role: {e}")
            return 'user'  # Default fallback role

    def get_user_roles(user_id, email):
        """Get all roles a user has (they might have multiple roles)"""
        roles = []
        try:
            with db.get_cursor() as cur:
                # Check initial role from registration
                cur.execute("SELECT initial_role FROM users WHERE user_id = :user_id", {'user_id': user_id})
                initial_role_result = cur.fetchone()
                initial_role = initial_role_result[0] if initial_role_result else None
                
                if initial_role == 'admin':
                    roles.append('admin')
                
                # Check testator role
                cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :user_id", {'user_id': user_id})
                if cur.fetchone()[0] > 0:
                    roles.append('testator')
                
                # Check executor role
                cur.execute("SELECT COUNT(*) FROM executors WHERE email = :email", {'email': email})
                if cur.fetchone()[0] > 0:
                    roles.append('executor')
                
                # Check beneficiary role
                cur.execute("SELECT COUNT(*) FROM beneficiaries WHERE email = :email", {'email': email})
                if cur.fetchone()[0] > 0:
                    roles.append('beneficiary')
                
                # If no specific roles found, use initial role
                if not roles and initial_role:
                    roles.append(initial_role)
                    
        except Exception as e:
            print(f"Error getting user roles: {e}")
        
        return roles if roles else ['user']

    def safe_execute_procedure(cursor, proc_name, params):
        """Safely execute stored procedures with enhanced error handling"""
        try:
            cursor.callproc(proc_name, params)
            return True, None
        except oracledb.Error as err:
            error_obj, = err.args
            error_code = error_obj.code
            error_message = error_obj.message
            
            # Map Oracle error codes to user-friendly messages
            if error_code == 20001:
                # Weekend blocking - extract clean message
                if "Weekend Transfer Blocked:" in error_message:
                    clean_message = error_message.split("Weekend Transfer Blocked:", 1)[1].strip()
                    return False, f"⚠️ Weekend Restriction: {clean_message}"
                else:
                    return False, "⚠️ Weekend Restriction: Asset transfers are not allowed on weekends (Saturday/Sunday). Please try again on a weekday."
            elif error_code == 20002:
                # Holiday blocking - extract clean message
                if "Holiday Transfer Blocked:" in error_message:
                    clean_message = error_message.split("Holiday Transfer Blocked:", 1)[1].strip()
                    return False, f"🎄 Holiday Restriction: {clean_message}"
                else:
                    return False, "🎄 Holiday Restriction: Asset transfers are not allowed on public holidays. Please try again on a regular business day."
            elif error_code == 20099:
                # Transfer validation error
                return False, "❌ Transfer Validation Error: Unable to process transfer at this time. Please contact system administrator."
            elif error_code in (21001, 21002, 23001, 23002):
                return False, "❌ Invalid Data: The specified record does not exist in the system."
            elif error_code == 21003:
                return False, "🔒 Cannot Modify: This will has already been executed and cannot be changed."
            elif error_code == 21004:
                return False, "📊 Allocation Error: Asset allocation cannot exceed 100%. Please adjust the percentages."
            elif error_code in (20091, 20092, 20093, 20094, 20095):
                return False, f"📋 Will Approval Error: {error_message.split(':', 1)[-1].strip()}"
            elif error_code == 12702:
                # NLS parameter error - provide helpful message
                return False, "🌐 System Configuration Issue: There's a language setting problem. Please contact system administrator."
            else:
                # For any other database errors, provide a clean generic message
                return False, f"⚠️ Database Operation Failed: Please try again or contact support if the problem persists."
    
    # ─── Routes ───────────────────────────────────────

    @app.route('/')
    def index():
        return render_template('index.html')

    @app.route('/login', methods=['GET','POST'])
    def login():
        if request.method == 'POST':
            email = request.form.get('email')
            password = request.form.get('password')
            
            if not email or not password:
                flash('Email and password are required.', 'danger')
                return render_template('login.html')
            
            try:
                with db.get_cursor() as cur:
                    cur.execute("""
                        SELECT user_id, full_name, email, password_hash
                        FROM users
                        WHERE email = :user_email
                    """, {'user_email': email})
                    row = cur.fetchone()
                    
                    if row:
                        user_id, full_name, user_email, stored_password = row
                        
                        # For demo purposes, if password_hash is NULL, allow any password
                        # In production, you should require proper password hashing
                        password_valid = False
                        
                        if stored_password is None:
                            # Demo mode - accept any password but recommend setting up proper passwords
                            password_valid = True
                            flash('Demo mode: Please set up proper passwords in production.', 'warning')
                        else:
                            # Check hashed password
                            password_valid = check_password_hash(stored_password, password)
                        
                        if password_valid:
                            # Determine user role based on their assignments
                            primary_role = determine_user_role(user_id, user_email)
                            all_roles = get_user_roles(user_id, user_email)
                            
                            session.update({
                                'user_id': user_id,
                                'user_name': full_name,
                                'user_email': user_email,
                                'user_role': primary_role,
                                'all_roles': all_roles  # Store all roles for advanced permissions
                            })
                            session.permanent = True
                            
                            flash(f'Welcome, {full_name}! Logged in as {primary_role}.', 'success')
                            return redirect(url_for('dashboard'))
                        else:
                            flash('Invalid password.', 'danger')
                    else:
                        flash('Invalid email address.', 'danger')
                        
            except oracledb.Error as err:
                flash(f'Login error: {err}', 'danger')
        
        return render_template('login.html')

    @app.route('/register', methods=['GET','POST'])
    def register():
        if request.method == 'POST':
            full_name = request.form.get('full_name')
            email = request.form.get('email')
            password = request.form.get('password')
            confirm_password = request.form.get('confirm_password')
            phone = request.form.get('phone')
            dob = request.form.get('dob')
            address = request.form.get('address')
            initial_role = request.form.get('initial_role')
            admin_code = request.form.get('admin_code')
            
            # Validate required fields
            if not all([full_name, email, password, initial_role]):
                flash('Full name, email, password, and account type are required.', 'danger')
                return render_template('register.html')
            
            # Validate password confirmation
            if password != confirm_password:
                flash('Password confirmation does not match.', 'danger')
                return render_template('register.html')
            
            # Validate password strength
            if len(password) < 6:
                flash('Password must be at least 6 characters long.', 'danger')
                return render_template('register.html')
            
            # Validate admin code if registering as admin
            if initial_role == 'admin':
                if not admin_code or admin_code != 'ADMIN2025':
                    flash('Invalid admin access code.', 'danger')
                    return render_template('register.html')
            
            try:
                with db.get_cursor() as cur:
                    # Check if email already exists
                    cur.execute("SELECT COUNT(*) FROM users WHERE email = :user_email", {'user_email': email})
                    if cur.fetchone()[0] > 0:
                        flash('Email already registered.', 'warning')
                        return render_template('register.html')
                    
                    # Hash the password
                    password_hash = generate_password_hash(password)
                    
                    # Insert new user with hashed password and initial role
                    cur.execute("""
                        INSERT INTO users (
                            full_name, email, password_hash, phone_number,
                            date_of_birth, address, initial_role
                        ) VALUES (
                            :user_name, :user_email, :password_hash, :user_phone,
                            CASE WHEN :user_dob IS NOT NULL THEN TO_DATE(:user_dob,'YYYY-MM-DD') ELSE NULL END, 
                            :user_addr, :initial_role
                        )
                    """, {
                        'user_name': full_name,
                        'user_email': email,
                        'password_hash': password_hash,
                        'user_phone': phone if phone else None,
                        'user_dob': dob if dob else None,
                        'user_addr': address if address else None,
                        'initial_role': initial_role
                    })
                    
                flash('Registration successful! Please log in.', 'success')
                return redirect(url_for('login'))
                
            except oracledb.Error as err:
                flash(f'Registration error: {err}', 'danger')
        
        return render_template('register.html')

    @app.route('/dashboard')
    @login_required
    def dashboard():
        role = session.get('user_role', 'user')
        all_roles = session.get('all_roles', [role])
        stats = {}
        
        try:
            with db.get_cursor() as cur:
                if 'testator' in all_roles:
                    # Get user's wills count
                    cur.execute("SELECT COUNT(*) FROM wills WHERE user_id = :user_id_param", {'user_id_param': session['user_id']})
                    stats['total_wills'] = cur.fetchone()[0]
                    
                    # Get total assets value
                    cur.execute("""
                        SELECT COUNT(*), NVL(SUM(value), 0) 
                        FROM assets a
                        JOIN wills w ON a.will_id = w.will_id
                        WHERE w.user_id = :user_id_param
                    """, {'user_id_param': session['user_id']})
                    result = cur.fetchone()
                    stats['total_assets'] = result[0]
                    stats['total_assets_value'] = result[1]
                    
                    # Get pending wills
                    cur.execute("""
                        SELECT COUNT(*) FROM wills 
                        WHERE user_id = :user_id_param AND status = :will_status
                    """, {'user_id_param': session['user_id'], 'will_status': 'Draft'})
                    stats['pending_wills'] = cur.fetchone()[0]
                    
                    # Get total beneficiaries assigned
                    cur.execute("""
                        SELECT COUNT(DISTINCT wab.beneficiary_id) 
                        FROM will_asset_beneficiaries wab
                        JOIN assets a ON wab.asset_id = a.asset_id
                        JOIN wills w ON a.will_id = w.will_id
                        WHERE w.user_id = :user_id_param
                    """, {'user_id_param': session['user_id']})
                    stats['total_beneficiaries'] = cur.fetchone()[0]

                if 'executor' in all_roles:
                    # Executor-specific stats
                    cur.execute("SELECT COUNT(*) FROM executors WHERE email = :exec_email", 
                               {'exec_email': session['user_email']})
                    stats['assigned_wills'] = cur.fetchone()[0]
                    
                    # Get pending transfers for executor
                    cur.execute("""
                        SELECT COUNT(*) FROM transfer_logs t
                        JOIN assets a ON t.asset_id = a.asset_id
                        JOIN wills w ON a.will_id = w.will_id
                        JOIN executors e ON w.will_id = e.will_id
                        WHERE e.email = :exec_email AND t.transfer_status = :transfer_status
                    """, {'exec_email': session['user_email'], 'transfer_status': 'Initiated'})
                    stats['pending_transfers'] = cur.fetchone()[0]

                if 'beneficiary' in all_roles:
                    # Beneficiary-specific stats
                    cur.execute("""
                        SELECT COUNT(*), NVL(SUM(a.value * wab.share_percent/100), 0) 
                        FROM will_asset_beneficiaries wab
                        JOIN assets a ON wab.asset_id = a.asset_id
                        JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                        WHERE b.email = :ben_email
                    """, {'ben_email': session['user_email']})
                    result = cur.fetchone()
                    stats['assigned_assets'] = result[0] if result else 0
                    stats['total_value'] = result[1] if result else 0

                if 'admin' in all_roles:
                    # Admin-specific stats
                    cur.execute("""
                        SELECT 
                            (SELECT COUNT(*) FROM users) as total_users,
                            (SELECT COUNT(*) FROM wills) as total_wills,
                            (SELECT COUNT(*) FROM assets) as total_assets,
                            (SELECT COUNT(*) FROM transfer_logs) as total_transfers
                        FROM dual
                    """)
                    admin_stats = cur.fetchone()
                    stats.update({
                        'system_users': admin_stats[0],
                        'system_wills': admin_stats[1],
                        'system_assets': admin_stats[2],
                        'system_transfers': admin_stats[3]
                    })

        except oracledb.Error as err:
            flash(f"Dashboard load error: {err}", 'danger')
            print(f"Database error: {err}")  # For debugging

        today = datetime.now()
        return render_template('dashboard.html', role=role, all_roles=all_roles, stats=stats, today=today)

    @app.route('/switch-role/<role>')
    @login_required
    def switch_role(role):
        """Allow users with multiple roles to switch between them"""
        all_roles = session.get('all_roles', [])
        
        if role in all_roles:
            session['user_role'] = role
            flash(f'Switched to {role} role.', 'info')
        else:
            flash('You do not have permission for that role.', 'danger')
        
        return redirect(url_for('dashboard'))

    @app.route('/wills')
    @login_required
    def list_wills():
        user_role = session.get('user_role')
        all_roles = session.get('all_roles', [])
        
        try:
            with db.get_cursor() as cur:
                if user_role == 'testator' or 'testator' in all_roles:
                    cur.execute("""
                        SELECT will_id, title, description, status, created_at,
                               (SELECT COUNT(*) FROM assets WHERE will_id = w.will_id) as asset_count,
                               (SELECT COUNT(*) FROM executors WHERE will_id = w.will_id) as executor_count
                        FROM wills w
                        WHERE user_id = :user_id_param
                        ORDER BY created_at DESC
                    """, {'user_id_param': session['user_id']})
                elif user_role == 'executor' or 'executor' in all_roles:
                    cur.execute("""
                        SELECT DISTINCT w.will_id, w.title, w.description, w.status, w.created_at,
                               (SELECT COUNT(*) FROM assets WHERE will_id = w.will_id) as asset_count,
                               (SELECT COUNT(*) FROM executors WHERE will_id = w.will_id) as executor_count
                        FROM wills w
                        JOIN executors e ON w.will_id = e.will_id
                        WHERE e.email = :exec_email
                        ORDER BY w.created_at DESC
                    """, {'exec_email': session['user_email']})
                elif user_role == 'admin' or 'admin' in all_roles:
                    cur.execute("""
                        SELECT will_id, title, description, status, created_at,
                               (SELECT COUNT(*) FROM assets WHERE will_id = w.will_id) as asset_count,
                               (SELECT COUNT(*) FROM executors WHERE will_id = w.will_id) as executor_count
                        FROM wills w
                        ORDER BY created_at DESC
                    """)
                else:
                    flash('You do not have permission to view wills.', 'danger')
                    return redirect(url_for('dashboard'))
                    
                wills = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Error fetching wills: {err}', 'danger')
            wills = []
        
        return render_template('wills/list.html', wills=wills)

    @app.route('/wills/create', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def create_will():
        if request.method == 'POST':
            title = request.form.get('title')
            description = request.form.get('description')
            
            if not title:
                flash('Will title is required.', 'danger')
                return render_template('wills/create.html')
            
            try:
                with db.get_cursor() as cur:
                    cur.execute("""
                        INSERT INTO wills(user_id, title, description, status)
                        VALUES(:user_id_param, :will_title, :will_desc, 'Draft')
                    """, {
                        'user_id_param': session['user_id'], 
                        'will_title': title, 
                        'will_desc': description
                    })
                    
                flash('Will created successfully.', 'success')
                return redirect(url_for('list_wills'))
            except oracledb.Error as err:
                flash(f'Create error: {err}', 'danger')
        
        return render_template('wills/create.html')

    @app.route('/wills/<int:will_id>')
    @login_required
    def view_will(will_id):
        try:
            with db.get_cursor(commit=False) as cur:
                # Get will details
                cur.execute("""
                    SELECT w.*, u.full_name as owner_name
                    FROM wills w
                    JOIN users u ON w.user_id = u.user_id
                    WHERE w.will_id = :will_id_param
                """, {'will_id_param': will_id})
                will = cur.fetchone()
                
                if not will:
                    flash('Will not found.', 'danger')
                    return redirect(url_for('list_wills'))
                
                # Check permission
                user_role = session.get('user_role')
                all_roles = session.get('all_roles', [])
                user_email = session.get('user_email')
                user_id = session.get('user_id')
                
                has_permission = False
                if 'admin' in all_roles:
                    has_permission = True
                elif 'testator' in all_roles and will[1] == user_id:  # will[1] is user_id
                    has_permission = True
                elif 'executor' in all_roles:
                    # Check if user is executor for this will
                    cur.execute("SELECT COUNT(*) FROM executors WHERE will_id = :will_id AND email = :email", 
                               {'will_id': will_id, 'email': user_email})
                    if cur.fetchone()[0] > 0:
                        has_permission = True
                
                if not has_permission:
                    flash('You do not have permission to view this will.', 'danger')
                    return redirect(url_for('list_wills'))
                
                # Get assets with allocation percentages
                cur.execute("""
                    SELECT a.asset_id, a.name, a.description, a.asset_type, a.value, a.location,
                           NVL((SELECT SUM(share_percent) 
                                FROM will_asset_beneficiaries 
                                WHERE asset_id = a.asset_id), 0) as allocated_percent
                    FROM assets a
                    WHERE a.will_id = :will_id_param
                    ORDER BY a.name
                """, {'will_id_param': will_id})
                assets = cur.fetchall()
                
                # Get executors
                cur.execute("""
                    SELECT executor_id, full_name, email, phone_number, relation, is_primary
                    FROM executors 
                    WHERE will_id = :will_id_param
                    ORDER BY is_primary DESC, full_name
                """, {'will_id_param': will_id})
                executors = cur.fetchall()
                
                # Get asset-beneficiary mappings
                cur.execute("""
                    SELECT a.name as asset_name, b.full_name as beneficiary_name, 
                           wab.share_percent, wab.conditions,
                           a.value * wab.share_percent / 100 as estimated_value
                    FROM will_asset_beneficiaries wab
                    JOIN assets a ON wab.asset_id = a.asset_id
                    JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    WHERE a.will_id = :will_id_param
                    ORDER BY a.name, b.full_name
                """, {'will_id_param': will_id})
                allocations = cur.fetchall()
                
        except oracledb.Error as err:
            flash(f'Fetch error: {err}', 'danger')
            will, assets, executors, allocations = None, [], [], []
            
        return render_template('wills/view.html',
                               will=will, assets=assets, 
                               executors=executors, allocations=allocations)

    @app.route('/wills/<int:will_id>/approve', methods=['POST'])
    @login_required
    @role_required(['testator'])
    def approve_will(will_id):
        try:
            with db.get_cursor() as cur:
                success, error_msg = safe_execute_procedure(cur, 'approve_will', [will_id])
                if success:
                    flash('Will approved successfully!', 'success')
                else:
                    flash(error_msg, 'danger')
        except Exception as err:
            flash(f'Unexpected error: {err}', 'danger')
        
        return redirect(url_for('view_will', will_id=will_id))

    @app.route('/wills/<int:will_id>/assets/add', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def add_asset(will_id):
        if request.method == 'POST':
            form_data = request.form
            required_fields = ['name', 'asset_type', 'value']
            
            # Validate required fields
            for field in required_fields:
                if not form_data.get(field):
                    flash(f'{field.replace("_", " ").title()} is required.', 'danger')
                    return render_template('assets/add.html', will_id=will_id)
            
            try:
                with db.get_cursor() as cur:
                    cur.execute("""
                        INSERT INTO assets(
                            will_id, name, description, asset_type,
                            value, location, acquisition_date
                        ) VALUES (
                            :will_id_param, :asset_name, :asset_desc, :asset_type_param, 
                            :asset_value, :asset_location, 
                            CASE WHEN :acq_date IS NOT NULL 
                                 THEN TO_DATE(:acq_date,'YYYY-MM-DD') 
                                 ELSE NULL END
                        )
                    """, {
                        'will_id_param': will_id,
                        'asset_name': form_data.get('name'),
                        'asset_desc': form_data.get('description'),
                        'asset_type_param': form_data.get('asset_type'),
                        'asset_value': float(form_data.get('value', 0)),
                        'asset_location': form_data.get('location'),
                        'acq_date': form_data.get('acquisition_date') or None
                    })
                    
                flash('Asset added successfully.', 'success')
                return redirect(url_for('view_will', will_id=will_id))
            except ValueError:
                flash('Invalid value format for asset value.', 'danger')
            except oracledb.Error as err:
                flash(f'Add asset error: {err}', 'danger')
        
        return render_template('assets/add.html', will_id=will_id)

    @app.route('/assets/<int:asset_id>/assign', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def assign_asset(asset_id):
        if request.method == 'POST':
            beneficiary_id = request.form.get('beneficiary_id')
            share_percent = request.form.get('share_percent')
            conditions = request.form.get('conditions')
            
            if not beneficiary_id or not share_percent:
                flash('Beneficiary and share percentage are required.', 'danger')
                return redirect(request.referrer or url_for('dashboard'))
            
            try:
                share_percent = float(share_percent)
                if share_percent <= 0 or share_percent > 100:
                    flash('Share percentage must be between 0 and 100.', 'danger')
                    return redirect(request.referrer or url_for('dashboard'))
            except ValueError:
                flash('Invalid share percentage format.', 'danger')
                return redirect(request.referrer or url_for('dashboard'))
            
            try:
                with db.get_cursor() as cur:
                    success, error_msg = safe_execute_procedure(cur, 'assign_asset_to_beneficiary', [
                        asset_id,
                        int(beneficiary_id),
                        share_percent,
                        conditions
                    ])
                    if success:
                        flash('Asset assigned successfully!', 'success')
                    else:
                        flash(error_msg, 'danger')
            except Exception as err:
                flash(f'Assignment error: {err}', 'danger')
            
            return redirect(request.referrer or url_for('dashboard'))
            
        # GET: load form data
        try:
            with db.get_cursor(commit=False) as cur:
                # Get asset details
                cur.execute("""
                    SELECT name, description, value, asset_type 
                    FROM assets 
                    WHERE asset_id = :asset_id_param
                """, {'asset_id_param': asset_id})
                asset = cur.fetchone()
                
                if not asset:
                    flash('Asset not found.', 'danger')
                    return redirect(url_for('dashboard'))
                
                # Get available beneficiaries
                cur.execute("""
                    SELECT beneficiary_id, full_name, relation, email
                    FROM beneficiaries 
                    ORDER BY full_name
                """)
                beneficiaries = cur.fetchall()
                
                # Get current allocations
                cur.execute("""
                    SELECT b.full_name, wab.share_percent, wab.conditions,
                           (SELECT value FROM assets WHERE asset_id = :asset_id_param) * wab.share_percent / 100 as estimated_value
                    FROM will_asset_beneficiaries wab
                    JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    WHERE wab.asset_id = :asset_id_param
                    ORDER BY wab.share_percent DESC
                """, {'asset_id_param': asset_id})
                current_allocations = cur.fetchall()
                
                # Calculate remaining allocation
                cur.execute("""
                    SELECT NVL(SUM(share_percent), 0) 
                    FROM will_asset_beneficiaries 
                    WHERE asset_id = :asset_id_param
                """, {'asset_id_param': asset_id})
                allocated_percent = cur.fetchone()[0]
                remaining_percent = 100 - allocated_percent
                
        except oracledb.Error as err:
            flash(f'Error loading asset details: {err}', 'danger')
            return redirect(url_for('dashboard'))
            
        return render_template('assets/assign.html',
                               asset=asset, 
                               beneficiaries=beneficiaries,
                               current_allocations=current_allocations, 
                               asset_id=asset_id,
                               remaining_percent=remaining_percent)

    @app.route('/beneficiaries', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def manage_beneficiaries():
        if request.method == 'POST':
            form_data = request.form
            
            # Validate required fields
            required_fields = ['full_name', 'relation']
            for field in required_fields:
                if not form_data.get(field):
                    flash(f'{field.replace("_", " ").title()} is required.', 'danger')
                    return redirect(url_for('manage_beneficiaries'))
            
            try:
                with db.get_cursor() as cur:
                    cur.execute("""
                        INSERT INTO beneficiaries(
                            full_name, relation, email, phone_number,
                            address, date_of_birth, notes
                        ) VALUES (
                            :ben_name, :ben_relation, :ben_email, :ben_phone, :ben_address, 
                            CASE WHEN :ben_dob IS NOT NULL 
                                 THEN TO_DATE(:ben_dob,'YYYY-MM-DD') 
                                 ELSE NULL END, 
                            :ben_notes
                        )
                    """, {
                        'ben_name': form_data.get('full_name'),
                        'ben_relation': form_data.get('relation'),
                        'ben_email': form_data.get('email'),
                        'ben_phone': form_data.get('phone'),
                        'ben_address': form_data.get('address'),
                        'ben_dob': form_data.get('dob') or None,
                        'ben_notes': form_data.get('notes')
                    })
                    
                flash('Beneficiary added successfully.', 'success')
            except oracledb.Error as err:
                flash(f'Error adding beneficiary: {err}', 'danger')
            
            return redirect(url_for('manage_beneficiaries'))

        # GET: show beneficiaries list
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("""
                    SELECT b.beneficiary_id, b.full_name, b.relation, b.email, b.phone_number,
                           COUNT(wab.asset_id) as assigned_assets,
                           NVL(SUM(a.value * wab.share_percent / 100), 0) as total_inheritance
                    FROM beneficiaries b
                    LEFT JOIN will_asset_beneficiaries wab ON b.beneficiary_id = wab.beneficiary_id
                    LEFT JOIN assets a ON wab.asset_id = a.asset_id
                    GROUP BY b.beneficiary_id, b.full_name, b.relation, b.email, b.phone_number
                    ORDER BY b.full_name
                """)
                beneficiaries = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Fetch error: {err}', 'danger')
            beneficiaries = []
        
        return render_template('beneficiaries/list.html', beneficiaries=beneficiaries)

    @app.route('/wills/<int:will_id>/executors/add', methods=['GET','POST'])
    @login_required
    @role_required(['testator'])
    def add_executor(will_id):
        if request.method == 'POST':
            form_data = request.form
            required_fields = ['full_name', 'email']
            
            for field in required_fields:
                if not form_data.get(field):
                    flash(f'{field.replace("_", " ").title()} is required.', 'danger')
                    return render_template('executors/add.html', will_id=will_id)
            
            try:
                with db.get_cursor() as cur:
                    # Check if this is the first executor (make them primary)
                    cur.execute("SELECT COUNT(*) FROM executors WHERE will_id = :will_id_param", {'will_id_param': will_id})
                    is_first_executor = cur.fetchone()[0] == 0
                    
                    cur.execute("""
                        INSERT INTO executors(
                            will_id, full_name, email, phone_number, relation, is_primary
                        ) VALUES (
                            :will_id_param, :exec_name, :exec_email, :exec_phone, :exec_relation, :exec_primary
                        )
                    """, {
                        'will_id_param': will_id,
                        'exec_name': form_data.get('full_name'),
                        'exec_email': form_data.get('email'),
                        'exec_phone': form_data.get('phone_number'),
                        'exec_relation': form_data.get('relation'),
                        'exec_primary': 'Y' if is_first_executor else 'N'
                    })
                    
                flash('Executor added successfully.', 'success')
                return redirect(url_for('view_will', will_id=will_id))
            except oracledb.Error as err:
                flash(f'Error adding executor: {err}', 'danger')
        
        return render_template('executors/add.html', will_id=will_id)

    @app.route('/transfers')
    @login_required
    @role_required(['executor', 'admin', 'testator'])
    def list_transfers():
        try:
            with db.get_cursor(commit=False) as cur:
                user_role = session.get('user_role')
                all_roles = session.get('all_roles', [])
                
                if 'admin' in all_roles:
                    cur.execute("""
                        SELECT t.transfer_id, a.name as asset_name, b.full_name as beneficiary_name,
                               t.transfer_date, t.transfer_status, t.approved_by, t.notes,
                               a.value, wab.share_percent,
                               (a.value * wab.share_percent / 100) as transfer_value
                        FROM transfer_logs t
                        JOIN assets a ON t.asset_id = a.asset_id
                        JOIN beneficiaries b ON t.beneficiary_id = b.beneficiary_id
                        LEFT JOIN will_asset_beneficiaries wab ON t.asset_id = wab.asset_id 
                                                               AND t.beneficiary_id = wab.beneficiary_id
                        ORDER BY t.transfer_date DESC
                    """)
                else:
                    # For executors and testators, show transfers they're involved with
                    cur.execute("""
                        SELECT DISTINCT t.transfer_id, a.name as asset_name, b.full_name as beneficiary_name,
                               t.transfer_date, t.transfer_status, t.approved_by, t.notes,
                               a.value, wab.share_percent,
                               (a.value * wab.share_percent / 100) as transfer_value
                        FROM transfer_logs t
                        JOIN assets a ON t.asset_id = a.asset_id
                        JOIN beneficiaries b ON t.beneficiary_id = b.beneficiary_id
                        JOIN wills w ON a.will_id = w.will_id
                        LEFT JOIN executors e ON w.will_id = e.will_id
                        LEFT JOIN will_asset_beneficiaries wab ON t.asset_id = wab.asset_id 
                                                               AND t.beneficiary_id = wab.beneficiary_id
                        WHERE e.email = :exec_email OR w.user_id = :user_id_param
                        ORDER BY t.transfer_date DESC
                    """, {'exec_email': session['user_email'], 'user_id_param': session['user_id']})
                transfers = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Transfers error: {err}', 'danger')
            transfers = []
        
        return render_template('transfers/list.html', transfers=transfers)

    @app.route('/transfers/initiate', methods=['POST'])
    @login_required
    @role_required(['executor', 'admin', 'testator'])
    def initiate_transfer():
        asset_id = request.form.get('asset_id')
        beneficiary_id = request.form.get('beneficiary_id')
        
        if not asset_id or not beneficiary_id:
            flash('Asset and beneficiary are required.', 'danger')
            return redirect(url_for('list_transfers'))
        
        try:
            asset_id = int(asset_id)
            beneficiary_id = int(beneficiary_id)
        except ValueError:
            flash('Invalid asset or beneficiary ID.', 'danger')
            return redirect(url_for('list_transfers'))
        
        try:
            with db.get_cursor() as cur:
                success, error_msg = safe_execute_procedure(cur, 'transfer_asset', [asset_id, beneficiary_id])
                if success:
                    flash('Transfer initiated successfully.', 'success')
                else:
                    flash(error_msg, 'warning' if 'weekend' in error_msg.lower() or 'holiday' in error_msg.lower() else 'danger')
        except Exception as err:
            flash(f'Transfer error: {err}', 'danger')
        
        return redirect(url_for('list_transfers'))

    @app.route('/api/transfer-form/<int:asset_id>')
    @login_required
    def get_transfer_form_data(asset_id):
        """API endpoint to get beneficiaries for an asset transfer form"""
        try:
            with db.get_cursor(commit=False) as cur:
                # Get asset details
                cur.execute("""
                    SELECT a.name, a.value, a.asset_type
                    FROM assets a
                    WHERE a.asset_id = :asset_id_param
                """, {'asset_id_param': asset_id})
                asset = cur.fetchone()
                
                if not asset:
                    return jsonify({'error': 'Asset not found'}), 404
                
                # Get eligible beneficiaries for this asset
                cur.execute("""
                    SELECT b.beneficiary_id, b.full_name, b.relation, wab.share_percent
                    FROM will_asset_beneficiaries wab
                    JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    WHERE wab.asset_id = :asset_id_param
                    ORDER BY b.full_name
                """, {'asset_id_param': asset_id})
                beneficiaries = cur.fetchall()
                
                return jsonify({
                    'asset': {
                        'name': asset[0],
                        'value': float(asset[1]) if asset[1] else 0,
                        'type': asset[2]
                    },
                    'beneficiaries': [
                        {
                            'id': b[0],
                            'name': b[1],
                            'relation': b[2],
                            'share_percent': float(b[3]) if b[3] else 0
                        } for b in beneficiaries
                    ]
                })
        except oracledb.Error as err:
            return jsonify({'error': str(err)}), 500

    @app.route('/documents/upload/<string:entity_type>/<int:entity_id>', methods=['GET', 'POST'])
    @login_required
    def upload_document(entity_type, entity_id):
        """Enhanced document upload with proper PL/SQL integration"""
        if entity_type not in ['will', 'asset']:
            flash('Invalid document type.', 'danger')
            return redirect(url_for('dashboard'))
        
        if request.method == 'POST':
            title = request.form.get('title')
            description = request.form.get('description')
            file_type = request.form.get('file_type', 'PDF')
            
            if not title:
                flash('Document title is required.', 'danger')
                return render_template('documents/upload.html', entity_type=entity_type, entity_id=entity_id)
            
            # For demo purposes, we'll simulate file upload
            file_path = f"/documents/{entity_type}_{entity_id}_{title.replace(' ', '_')}.{file_type.lower()}"
            
            try:
                with db.get_cursor() as cur:
                    success, error_msg = safe_execute_procedure(cur, 'add_document', [
                        entity_type.upper(),
                        entity_id,
                        title,
                        description,
                        file_path,
                        file_type
                    ])
                    if success:
                        flash('Document uploaded successfully.', 'success')
                        if entity_type == 'will':
                            return redirect(url_for('view_will', will_id=entity_id))
                        else:
                            return redirect(url_for('dashboard'))
                    else:
                        flash(error_msg, 'danger')
            except Exception as err:
                flash(f'Upload error: {err}', 'danger')
        
        return render_template('documents/upload.html', entity_type=entity_type, entity_id=entity_id)

    @app.route('/assets/my')
    @login_required
    @role_required(['beneficiary'])
    def view_my_assets():
        """View assets assigned to logged-in beneficiary"""
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("""
                    SELECT a.name, a.description, a.asset_type, a.value, a.location,
                           wab.share_percent, wab.conditions,
                           (a.value * wab.share_percent / 100) as my_share_value,
                           w.title as will_title, w.status as will_status,
                           CASE WHEN tl.transfer_id IS NOT NULL THEN tl.transfer_status ELSE 'Not Transferred' END as transfer_status
                    FROM will_asset_beneficiaries wab
                    JOIN assets a ON wab.asset_id = a.asset_id
                    JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                    JOIN wills w ON a.will_id = w.will_id
                    LEFT JOIN transfer_logs tl ON a.asset_id = tl.asset_id AND b.beneficiary_id = tl.beneficiary_id
                    WHERE b.email = :ben_email
                    ORDER BY w.title, a.name
                """, {'ben_email': session['user_email']})
                my_assets = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Error fetching assets: {err}', 'danger')
            my_assets = []
        
        return render_template('beneficiaries/my_assets.html', assets=my_assets)

    @app.route('/reports/will-summary/<int:will_id>')
    @login_required
    def will_summary_report(will_id):
        """Generate comprehensive will summary report"""
        try:
            with db.get_cursor(commit=False) as cur:
                # Get will details
                cur.execute("""
                    SELECT w.*, u.full_name as owner_name, u.email as owner_email
                    FROM wills w
                    JOIN users u ON w.user_id = u.user_id
                    WHERE w.will_id = :will_id_param
                """, {'will_id_param': will_id})
                will_details = cur.fetchone()
                
                if not will_details:
                    flash('Will not found.', 'danger')
                    return redirect(url_for('list_wills'))
                
                # Get summary statistics
                cur.execute("""
                    SELECT 
                        COUNT(a.asset_id) as total_assets,
                        NVL(SUM(a.value), 0) as total_value,
                        COUNT(DISTINCT wab.beneficiary_id) as total_beneficiaries,
                        COUNT(e.executor_id) as total_executors,
                        COUNT(CASE WHEN e.is_primary = 'Y' THEN 1 END) as primary_executors
                    FROM assets a
                    LEFT JOIN will_asset_beneficiaries wab ON a.asset_id = wab.asset_id
                    LEFT JOIN executors e ON a.will_id = e.will_id
                    WHERE a.will_id = :will_id_param
                """, {'will_id_param': will_id})
                summary_stats = cur.fetchone()
                
                # Get asset allocation details
                cur.execute("""
                    SELECT a.name, a.asset_type, a.value,
                           NVL(SUM(wab.share_percent), 0) as allocated_percent,
                           COUNT(wab.beneficiary_id) as beneficiary_count
                    FROM assets a
                    LEFT JOIN will_asset_beneficiaries wab ON a.asset_id = wab.asset_id
                    WHERE a.will_id = :will_id_param
                    GROUP BY a.asset_id, a.name, a.asset_type, a.value
                    ORDER BY a.name
                """, {'will_id_param': will_id})
                asset_allocations = cur.fetchall()
                
                # Get beneficiary summary
                cur.execute("""
                    SELECT b.full_name, b.relation,
                           COUNT(wab.asset_id) as assigned_assets,
                           NVL(SUM(a.value * wab.share_percent / 100), 0) as total_inheritance
                    FROM beneficiaries b
                    JOIN will_asset_beneficiaries wab ON b.beneficiary_id = wab.beneficiary_id
                    JOIN assets a ON wab.asset_id = a.asset_id
                    WHERE a.will_id = :will_id_param
                    GROUP BY b.beneficiary_id, b.full_name, b.relation
                    ORDER BY total_inheritance DESC
                """, {'will_id_param': will_id})
                beneficiary_summary = cur.fetchall()
                
        except oracledb.Error as err:
            flash(f'Report generation error: {err}', 'danger')
            return redirect(url_for('view_will', will_id=will_id))
            
        return render_template('reports/will_summary.html',
                               will=will_details,
                               stats=summary_stats,
                               assets=asset_allocations,
                               beneficiaries=beneficiary_summary)

    @app.route('/admin/system-stats')
    @login_required
    @role_required(['admin'])
    def system_statistics():
        """System-wide statistics dashboard"""
        try:
            with db.get_cursor(commit=False) as cur:
                # Overall system stats
                cur.execute("""
                    SELECT 
                        (SELECT COUNT(*) FROM users) as total_users,
                        (SELECT COUNT(*) FROM wills) as total_wills,
                        (SELECT COUNT(*) FROM assets) as total_assets,
                        (SELECT COUNT(*) FROM beneficiaries) as total_beneficiaries,
                        (SELECT COUNT(*) FROM executors) as total_executors,
                        (SELECT COUNT(*) FROM transfer_logs) as total_transfers,
                        (SELECT NVL(SUM(value), 0) FROM assets) as total_asset_value
                    FROM dual
                """)
                system_stats = cur.fetchone()
                
                # Will status distribution
                cur.execute("""
                    SELECT status, COUNT(*) as count
                    FROM wills
                    GROUP BY status
                    ORDER BY status
                """)
                will_status_dist = cur.fetchall()
                
                # Recent activity
                cur.execute("""
                    SELECT 'Will Created' as activity, w.title as description, w.created_at as activity_date
                    FROM wills w
                    WHERE w.created_at >= SYSDATE - 30
                    UNION ALL
                    SELECT 'Transfer Initiated' as activity, 
                           a.name || ' to ' || b.full_name as description, 
                           t.transfer_date as activity_date
                    FROM transfer_logs t
                    JOIN assets a ON t.asset_id = a.asset_id
                    JOIN beneficiaries b ON t.beneficiary_id = b.beneficiary_id
                    WHERE t.transfer_date >= SYSDATE - 30
                    ORDER BY activity_date DESC
                    FETCH FIRST 20 ROWS ONLY
                """)
                recent_activity = cur.fetchall()
                
        except oracledb.Error as err:
            flash(f'Error loading statistics: {err}', 'danger')
            system_stats = None
            will_status_dist = []
            recent_activity = []
            
        return render_template('admin/system_stats.html',
                               stats=system_stats,
                               status_distribution=will_status_dist,
                               recent_activity=recent_activity)

    @app.route('/executors/<int:executor_id>/set-primary', methods=['POST'])
    @login_required
    @role_required(['testator'])
    def set_primary_executor(executor_id):
        """Set an executor as primary using the stored procedure"""
        try:
            with db.get_cursor() as cur:
                success, error_msg = safe_execute_procedure(cur, 'set_primary_executor', [executor_id])
                if success:
                    flash('Primary executor updated successfully.', 'success')
                else:
                    flash(error_msg, 'danger')
        except Exception as err:
            flash(f'Error setting primary executor: {err}', 'danger')
        
        return redirect(request.referrer or url_for('dashboard'))

    @app.route('/wills/<int:will_id>/delete', methods=['POST'])
    @login_required
    @role_required(['testator'])
    def delete_will(will_id):
        """Delete a draft will using the stored procedure"""
        force_delete = request.form.get('force_delete') == 'true'
        confirm_text = request.form.get('confirm_text', '')
        
        try:
            with db.get_cursor() as cur:
                # For the procedure call, we need to handle the boolean parameter
                success, error_msg = safe_execute_procedure(cur, 'delete_draft_will', [
                    will_id, 
                    1 if force_delete else 0,  # Convert boolean to number for Oracle
                    confirm_text if confirm_text else None
                ])
                if success:
                    flash('Will deleted successfully.', 'success')
                    return redirect(url_for('list_wills'))
                else:
                    flash(error_msg, 'danger')
        except Exception as err:
            flash(f'Error deleting will: {err}', 'danger')
        
        return redirect(url_for('view_will', will_id=will_id))

    @app.route('/audit/logs')
    @login_required
    @role_required(['admin'])
    def view_audit_logs():
        """View system audit logs"""
        page = int(request.args.get('page', 1))
        per_page = 50
        offset = (page - 1) * per_page
        
        try:
            with db.get_cursor(commit=False) as cur:
                # Get total count
                cur.execute("SELECT COUNT(*) FROM audit_log")
                total_logs = cur.fetchone()[0]
                
                # Get paginated logs
                cur.execute("""
                    SELECT audit_id, user_name, action, action_table, record_id,
                           old_values, new_values, timestamp, status, ip_address
                    FROM (
                        SELECT a.*, ROW_NUMBER() OVER (ORDER BY timestamp DESC) as rn
                        FROM audit_log a
                    ) 
                    WHERE rn > :offset AND rn <= :limit
                """, {'offset': offset, 'limit': offset + per_page})
                logs = cur.fetchall()
                
                has_next = total_logs > (page * per_page)
                has_prev = page > 1
                
        except oracledb.Error as err:
            flash(f'Error loading audit logs: {err}', 'danger')
            logs = []
            has_next = False
            has_prev = False
            total_logs = 0
            
        return render_template('admin/audit_logs.html',
                               logs=logs,
                               page=page,
                               has_next=has_next,
                               has_prev=has_prev,
                               total_logs=total_logs)

    @app.route('/admin/users')
    @login_required
    @role_required(['admin'])
    def manage_users():
        """Admin interface to manage all users"""
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("""
                    SELECT u.user_id, u.full_name, u.email, u.initial_role, u.created_at,
                           (SELECT COUNT(*) FROM wills WHERE user_id = u.user_id) as wills_count,
                           (SELECT COUNT(*) FROM executors WHERE email = u.email) as executor_count,
                           (SELECT COUNT(*) FROM beneficiaries WHERE email = u.email) as beneficiary_count
                    FROM users u
                    ORDER BY u.created_at DESC
                """)
                users = cur.fetchall()
        except oracledb.Error as err:
            flash(f'Error fetching users: {err}', 'danger')
            users = []
        
        return render_template('admin/users.html', users=users)

    @app.route('/admin/test-weekend-transfer')
    @login_required
    @role_required(['admin'])
    def test_weekend_transfer():
        """Test weekend transfer blocking for demonstration"""
        try:
            with db.get_cursor() as cur:
                # First check if it's actually a weekend
                cur.execute("SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'D')) FROM dual")
                day_number = cur.fetchone()[0]
                is_weekend = day_number in [1, 7]  # 1=Sunday, 7=Saturday
                
                # Get day name for display
                cur.execute("SELECT TO_CHAR(SYSDATE, 'Day') FROM dual")
                day_name = cur.fetchone()[0].strip()
                
                if is_weekend:
                    flash(f'🚫 Weekend Blocking Active: Today is {day_name}. Transfer restrictions are in effect as designed.', 'warning')
                else:
                    # Get any asset and beneficiary for testing
                    cur.execute("""
                        SELECT wab.asset_id, wab.beneficiary_id, a.name, b.full_name
                        FROM will_asset_beneficiaries wab
                        JOIN assets a ON wab.asset_id = a.asset_id
                        JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
                        WHERE ROWNUM = 1
                    """)
                    test_data = cur.fetchone()
                    
                    if test_data:
                        asset_id, beneficiary_id, asset_name, beneficiary_name = test_data
                        success, error_msg = safe_execute_procedure(cur, 'transfer_asset', [asset_id, beneficiary_id])
                        
                        if success:
                            flash(f'✅ Test Transfer Successful: {asset_name} to {beneficiary_name} (Today is {day_name} - weekday transfers allowed)', 'success')
                        else:
                            flash(f'Test Result: {error_msg}', 'info')
                    else:
                        flash(f'ℹ️ Test Info: Today is {day_name} (weekday). No test data available for transfer demonstration.', 'info')
                        
        except Exception as err:
            flash(f'🔧 Test Error: Unable to perform weekend blocking test. Error: {str(err)}', 'danger')
        
        return redirect(url_for('system_statistics'))

    @app.route('/api/weekend-check')
    @login_required
    def check_weekend_status():
        """API endpoint to check if it's currently weekend"""
        try:
            with db.get_cursor() as cur:
                cur.execute("""
                    SELECT 
                        TO_NUMBER(TO_CHAR(SYSDATE, 'D')) as day_number,
                        TO_CHAR(SYSDATE, 'Day') as day_name,
                        TO_CHAR(SYSDATE, 'DD-MON-YYYY') as date_str,
                        CASE WHEN TO_NUMBER(TO_CHAR(SYSDATE, 'D')) IN (1, 7) 
                             THEN 'true' 
                             ELSE 'false' 
                        END as is_weekend
                    FROM dual
                """)
                result = cur.fetchone()
                
                return jsonify({
                    'day_number': result[0],
                    'day_name': result[1].strip(),
                    'date': result[2],
                    'is_weekend': result[3] == 'true',
                    'status': 'Weekend transfers blocked' if result[3] == 'true' else 'Weekday transfers allowed'
                })
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @app.context_processor
    def inject_template_vars():
        """Inject commonly used variables into all templates"""
        return {
            'current_year': datetime.now().year,
            'app_version': '1.0.0',
            'is_weekend': datetime.now().weekday() >= 5
        }

    @app.route('/logout')
    def logout():
        session.clear()
        flash('Logged out successfully.', 'info')
        return redirect(url_for('index'))

    # Error handlers
    @app.errorhandler(404)
    def not_found(error):
        return render_template('errors/404.html'), 404

    @app.errorhandler(500)
    def internal_error(error):
        return render_template('errors/500.html'), 500

    # Additional utility routes
    @app.route('/health')
    def health_check():
        """Simple health check endpoint"""
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("SELECT 1 FROM dual")
                result = cur.fetchone()
                if result:
                    return jsonify({'status': 'healthy', 'database': 'connected'}), 200
        except Exception as e:
            return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

    @app.route('/api/will/<int:will_id>/stats')
    @login_required
    def get_will_stats(will_id):
        """API endpoint to get will statistics"""
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("""
                    SELECT 
                        COUNT(a.asset_id) as total_assets,
                        NVL(SUM(a.value), 0) as total_value,
                        COUNT(DISTINCT wab.beneficiary_id) as total_beneficiaries,
                        AVG(CASE WHEN wab.share_percent IS NOT NULL THEN wab.share_percent ELSE 0 END) as avg_allocation
                    FROM assets a
                    LEFT JOIN will_asset_beneficiaries wab ON a.asset_id = wab.asset_id
                    WHERE a.will_id = :will_id_param
                """, {'will_id_param': will_id})
                stats = cur.fetchone()
                
                if stats:
                    return jsonify({
                        'total_assets': stats[0],
                        'total_value': float(stats[1]) if stats[1] else 0,
                        'total_beneficiaries': stats[2],
                        'avg_allocation': float(stats[3]) if stats[3] else 0
                    })
                else:
                    return jsonify({'error': 'Will not found'}), 404
                    
        except oracledb.Error as err:
            return jsonify({'error': str(err)}), 500

    @app.route('/api/beneficiary/<int:beneficiary_id>/assets')
    @login_required
    def get_beneficiary_assets(beneficiary_id):
        """API endpoint to get assets for a specific beneficiary"""
        try:
            with db.get_cursor(commit=False) as cur:
                cur.execute("""
                    SELECT a.asset_id, a.name, a.asset_type, a.value, wab.share_percent,
                           (a.value * wab.share_percent / 100) as inheritance_value
                    FROM will_asset_beneficiaries wab
                    JOIN assets a ON wab.asset_id = a.asset_id
                    WHERE wab.beneficiary_id = :ben_id_param
                    ORDER BY a.name
                """, {'ben_id_param': beneficiary_id})
                assets = cur.fetchall()
                
                return jsonify([{
                    'asset_id': asset[0],
                    'name': asset[1],
                    'type': asset[2],
                    'total_value': float(asset[3]) if asset[3] else 0,
                    'share_percent': float(asset[4]) if asset[4] else 0,
                    'inheritance_value': float(asset[5]) if asset[5] else 0
                } for asset in assets])
                
        except oracledb.Error as err:
            return jsonify({'error': str(err)}), 500

    return app

if __name__ == '__main__':
    app = create_app()
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║                Digital Will Management System                ║
    ║                                                              ║
    ║  🏥 AUCA Capstone Project - Database Development with PL/SQL ║
    ║  🚀 Application starting on http://localhost:5000           ║
    ║  🔧 Debug mode: True                                         ║
    ║                                                              ║
    ║  📋 Demo Credentials:                                        ║
    ║  👤 Testator: jean.claude@example.rw / any_password         ║
    ║  ⚖️  Executor: solange.mukamana@lawfirm.rw / any_password   ║
    ║  🎁 Beneficiary: eric.munyaneza@example.rw / any_password   ║
    ║  🔧 Admin: admin@digitalwill.rw / any_password              ║
    ║                                                              ║
    ║  🔐 Admin Registration Code: ADMIN2025                      ║
    ║  📊 New Features: Role switching, Admin panel, Audit logs   ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
    app.run(debug=True, host='0.0.0.0', port=5000)