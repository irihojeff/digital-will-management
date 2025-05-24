# config.py - Enhanced Configuration
import os
from datetime import timedelta

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    SESSION_PERMANENT = False
    SESSION_TYPE = 'filesystem'
    PERMANENT_SESSION_LIFETIME = timedelta(hours=24)
    
    # Oracle Database Configuration
    ORACLE_USER = os.environ.get('ORACLE_USER') or 'your_oracle_user'
    ORACLE_PASSWORD = os.environ.get('ORACLE_PASSWORD') or 'your_oracle_password'
    ORACLE_DSN = os.environ.get('ORACLE_DSN') or 'localhost:1521/xe'
    ORACLE_THICK_MODE = True
    ORACLE_CLIENT_PATH = os.environ.get('ORACLE_CLIENT_PATH') or r'C:\instantclient_21_3'
    
    # File Upload Configuration
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file size
    UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
    ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'doc', 'docx'}

class DevelopmentConfig(Config):
    DEBUG = True
    TESTING = False

class ProductionConfig(Config):
    DEBUG = False
    TESTING = False
    # Add production-specific configurations

class TestingConfig(Config):
    DEBUG = True
    TESTING = True

config = {
    'default': DevelopmentConfig,
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig
}

# database/connection.py - Enhanced Database Connection
import oracledb
import os
from flask import current_app, g

def get_db_connection():
    """Get database connection with proper error handling"""
    if 'db_connection' not in g:
        try:
            # Connection string
            dsn = current_app.config['ORACLE_DSN']
            user = current_app.config['ORACLE_USER']
            password = current_app.config['ORACLE_PASSWORD']
            
            # Create connection
            g.db_connection = oracledb.connect(
                user=user,
                password=password,
                dsn=dsn
            )
            
            # Set session parameters for better Oracle integration
            cursor = g.db_connection.cursor()
            cursor.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'")
            cursor.execute("ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF'")
            cursor.close()
            
        except oracledb.Error as e:
            current_app.logger.error(f"Database connection error: {e}")
            raise
    
    return g.db_connection

def close_db_connection(exception=None):
    """Close database connection"""
    db = g.pop('db_connection', None)
    if db is not None:
        try:
            db.close()
        except oracledb.Error as e:
            current_app.logger.error(f"Error closing database: {e}")

def init_db_app(app):
    """Initialize database with Flask app"""
    app.teardown_appcontext(close_db_connection)

# requirements.txt
"""
Flask==2.3.3
Flask-Session==0.5.0
oracledb==1.4.2
Werkzeug==2.3.7
python-dotenv==1.0.0
"""

# .env.example - Environment Variables Template
"""
# Database Configuration
ORACLE_USER=your_oracle_username
ORACLE_PASSWORD=your_oracle_password
ORACLE_DSN=localhost:1521/xe
ORACLE_CLIENT_PATH=C:\instantclient_21_3

# Flask Configuration
FLASK_ENV=development
SECRET_KEY=your-super-secret-key-here

# Upload Configuration
UPLOAD_FOLDER=uploads
MAX_CONTENT_LENGTH=16777216
"""

# Enhanced Login Template (login.html update)
login_html_enhancement = """
<!-- Add this script to login.html for demo user quick login -->
<script>
// Quick login function for demo
function quickLogin(userType) {
    const credentials = {
        'testator': {
            email: 'jean.claude@example.rw',
            password: 'demo123',
            role: 'testator'
        },
        'executor': {
            email: 'solange.mukamana@lawfirm.rw', 
            password: 'demo123',
            role: 'executor'
        },
        'beneficiary': {
            email: 'eric.munyaneza@example.rw',
            password: 'demo123', 
            role: 'beneficiary'
        }
    };
    
    const creds = credentials[userType];
    if (creds) {
        document.getElementById('email').value = creds.email;
        document.getElementById('password').value = creds.password;
        document.getElementById('role').value = creds.role;
    }
}

// Add quick login buttons to demo credentials card
document.addEventListener('DOMContentLoaded', function() {
    const demoCard = document.querySelector('.border-info .card-body');
    if (demoCard) {
        const quickLoginSection = document.createElement('div');
        quickLoginSection.className = 'mt-3';
        quickLoginSection.innerHTML = `
            <p class="mb-2"><strong>Quick Login:</strong></p>
            <div class="btn-group-vertical w-100" role="group">
                <button type="button" class="btn btn-outline-primary btn-sm" onclick="quickLogin('testator')">
                    Login as Testator
                </button>
                <button type="button" class="btn btn-outline-success btn-sm" onclick="quickLogin('executor')">
                    Login as Executor  
                </button>
                <button type="button" class="btn btn-outline-info btn-sm" onclick="quickLogin('beneficiary')">
                    Login as Beneficiary
                </button>
            </div>
        `;
        demoCard.appendChild(quickLoginSection);
    }
});
</script>
"""



# run.py - Application entry point
run_py_content = """
#!/usr/bin/env python3
\"\"\"
Digital Will Management System
Main application entry point
\"\"\"

import os
from app import create_app
from database.connection import init_db_app

# Create Flask application
app = create_app()

# Initialize database
init_db_app(app)

if __name__ == '__main__':
    # Get configuration from environment
    debug = os.environ.get('FLASK_ENV') == 'development'
    host = os.environ.get('FLASK_HOST', '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 5000))
    
    print(f\"\"\"
    ╔══════════════════════════════════════════════════════════════╗
    ║                Digital Will Management System                ║
    ║                                                              ║
    ║  🏥 AUCA Capstone Project - Database Development with PL/SQL ║
    ║  🚀 Starting application on http://{host}:{port}               ║
    ║  🔧 Debug mode: {debug}                                        ║
    ╚══════════════════════════════════════════════════════════════╝
    \"\"\")
    
    # Run the application
    app.run(
        debug=debug,
        host=host,
        port=port,
        threaded=True
    )
"""

# File structure documentation
file_structure = """
# Recommended Project Structure:

digital-will-management/
├── app.py                          # Main Flask application
├── run.py                          # Application entry point  
├── config.py                       # Configuration settings
├── requirements.txt                # Python dependencies
├── .env                           # Environment variables (create from .env.example)
├── .env.example                   # Environment template
├── utils.py                       # Utility functions
├── README.md                      # Project documentation
│
├── database/
│   ├── __init__.py
│   ├── connection.py              # Database connection handling
│   ├── schema.sql                 # Database schema
│   ├── procedures.sql             # Stored procedures  
│   ├── triggers.sql               # Database triggers
│   └── sample_data.sql            # Sample data
│
├── templates/
│   ├── base.html                  # Base template
│   ├── index.html                 # Home page
│   ├── login.html                 # Login page
│   ├── register.html              # Registration page
│   ├── dashboard.html             # Dashboard
│   │
│   ├── wills/
│   │   ├── list.html              # Wills list
│   │   ├── create.html            # Create will
│   │   └── view.html              # View will details
│   │
│   ├── assets/
│   │   ├── add.html               # Add asset
│   │   └── assign.html            # Assign asset
│   │
│   ├── beneficiaries/
│   │   ├── list.html              # Beneficiaries list
│   │   └── my_assets.html         # Beneficiary assets view
│   │
│   ├── executors/
│   │   └── add.html               # Add executor
│   │
│   ├── transfers/
│   │   └── list.html              # Transfers list
│   │
│   ├── documents/
│   │   └── upload.html            # Document upload
│   │
│   ├── reports/
│   │   └── will_summary.html      # Will summary report
│   │
│   ├── admin/
│   │   ├── system_stats.html      # System statistics
│   │   └── audit_logs.html        # Audit logs
│   │
│   └── errors/
│       ├── 404.html               # Not found page
│       └── 500.html               # Server error page
│
├── static/
│   ├── css/
│   │   └── style.css              # Custom styles
│   ├── js/
│   │   └── app.js                 # Custom JavaScript
│   └── uploads/                   # File uploads directory
│
└── flask_session/                 # Session files (auto-created)
"""

print(f"""
# Enhanced Digital Will Management System

## Complete Template Set Created! 

Your enhanced system now includes:

### ✅ Frontend Templates (Enhanced):
- **Base Template**: Enhanced navigation with role-based menus
- **Authentication**: Login/Register with demo credentials
- **Dashboard**: Role-specific statistics and quick actions
- **Will Management**: Create, view, approve wills with full workflow
- **Asset Management**: Add assets, assign to beneficiaries with validation
- **Beneficiary Management**: Add/manage beneficiaries with inheritance tracking
- **Transfer Management**: Initiate and track asset transfers
- **Executor Management**: Add executors, set primary executor
- **Document Upload**: File upload with type validation
- **Reports**: Comprehensive will summary reports
- **Admin Panel**: System statistics and audit logs
- **Error Pages**: Professional 404/500 error handling

### ✅ Backend Integration (Enhanced app.py):
- **PL/SQL Integration**: All stored procedures properly integrated
- **Error Handling**: Oracle error codes mapped to user-friendly messages
- **Form Validation**: Server-side validation with proper feedback
- **Role-Based Access**: Comprehensive permission system
- **AJAX Support**: API endpoints for dynamic content
- **File Upload**: Document management system
- **Audit Integration**: Complete audit trail functionality

### ✅ Key Features Demonstrated:

1. **Database Triggers**: 
   - Weekend/holiday transfer blocking
   - Asset allocation validation
   - Audit logging
   - Status change tracking

2. **Stored Procedures**:
   - `approve_will`: Will approval workflow
   - `assign_asset_to_beneficiary`: Asset assignment with validation
   - `transfer_asset`: Asset transfer with business rules
   - `add_document`: Document management
   - `set_primary_executor`: Executor management
   - `delete_draft_will`: Safe will deletion

3. **Complex Queries**:
   - Multi-table joins for reporting
   - Aggregations for statistics
   - Role-based data filtering
   - Asset allocation calculations

4. **Business Logic**:
   - Asset allocation cannot exceed 100%
   - Will approval workflow
   - Transfer restrictions (weekends/holidays)
   - Role-based permissions

### 🚀 Getting Started:

1. **Setup Database**: Run your schema, triggers, procedures, and sample data
2. **Install Dependencies**: `pip install -r requirements.txt`
3. **Configure Environment**: Copy `.env.example` to `.env` and update settings
4. **Run Application**: `python run.py`

### 📋 Demo Flow:

1. **Login as Testator** (jean.claude@example.rw / demo123):
   - View dashboard with will statistics
   - Create new will or view existing ones
   - Add assets to wills
   - Add beneficiaries
   - Assign assets to beneficiaries
   - Add executors
   - Approve will (triggers PL/SQL procedure)

2. **Login as Executor** (solange.mukamana@lawfirm.rw / demo123):
   - View assigned wills
   - Initiate asset transfers
   - Track transfer progress
   - View transfer restrictions

3. **Login as Beneficiary** (eric.munyaneza@example.rw / demo123):
   - View assigned assets
   - Check inheritance value
   - Track transfer status

4. **Admin Features**:
   - System-wide statistics
   - Audit log viewing
   - Overall system monitoring

### 💡 Key Enhancements Made:

1. **UI/UX Improvements**:
   - Professional dashboard with statistics cards
   - Interactive forms with validation
   - Modal dialogs for better user experience
   - Responsive design for mobile devices
   - Toast notifications and alerts

2. **Functionality Additions**:
   - Asset allocation progress tracking
   - Real-time value calculations
   - Transfer initiation workflow
   - Document upload system
   - Comprehensive reporting

3. **Error Handling**:
   - Oracle error code mapping
   - User-friendly error messages
   - Graceful failure handling
   - Form validation feedback

4. **Security & Validation**:
   - Input sanitization
   - SQL injection prevention
   - Role-based access control
   - Session management

### 🔧 Technical Highlights:

- **Oracle Integration**: Seamless PL/SQL procedure calls
- **Transaction Management**: Proper commit/rollback handling
- **Error Mapping**: Oracle errors mapped to user messages
- **Responsive Design**: Works on desktop and mobile
- **AJAX Support**: Dynamic content loading
- **Print Support**: Print-friendly report layouts

### 📊 Database Features Showcased:

- **Complex Triggers**: Multi-table validation and business rules
- **Stored Procedures**: Business logic encapsulation
- **Audit Logging**: Comprehensive activity tracking
- **Data Integrity**: Referential integrity and constraints
- **Performance**: Optimized queries with proper indexing

This enhanced system provides a complete demonstration of:
- Modern web application development with Flask
- Professional UI/UX design
- Comprehensive Oracle PL/SQL integration
- Real-world business logic implementation
- Production-ready error handling and validation

Your Digital Will Management System is now ready for a professional capstone demonstration! 🎉
""")

# Additional JavaScript for enhanced interactivity
additional_js = """
// Additional JavaScript enhancements for the system

// Auto-save functionality for forms
function enableAutoSave(formId, saveUrl) {
    const form = document.getElementById(formId);
    if (!form) return;
    
    const inputs = form.querySelectorAll('input, textarea, select');
    inputs.forEach(input => {
        input.addEventListener('change', function() {
            const formData = new FormData(form);
            fetch(saveUrl, {
                method: 'POST',
                body: formData
            }).then(response => {
                if (response.ok) {
                    showToast('Changes saved automatically', 'success');
                }
            }).catch(error => {
                console.error('Auto-save failed:', error);
            });
        });
    });
}

// Real-time asset allocation calculator
function updateAllocationProgress(assetId) {
    const shareInputs = document.querySelectorAll(`[data-asset-id="${assetId}"] input[name="share_percent"]`);
    let totalPercent = 0;
    
    shareInputs.forEach(input => {
        totalPercent += parseFloat(input.value) || 0;
    });
    
    const progressBar = document.querySelector(`[data-asset-id="${assetId}"] .progress-bar`);
    if (progressBar) {
        progressBar.style.width = Math.min(totalPercent, 100) + '%';
        progressBar.textContent = totalPercent.toFixed(1) + '%';
        
        // Update color based on completion
        progressBar.className = 'progress-bar';
        if (totalPercent >= 100) {
            progressBar.classList.add('bg-success');
        } else if (totalPercent >= 80) {
            progressBar.classList.add('bg-warning');
        } else {
            progressBar.classList.add('bg-danger');
        }
    }
    
    // Update remaining percentage
    const remainingSpan = document.querySelector(`[data-asset-id="${assetId}"] .remaining-percent`);
    if (remainingSpan) {
        remainingSpan.textContent = Math.max(0, 100 - totalPercent).toFixed(2) + '%';
    }
}

// Enhanced file upload with progress
function enhanceFileUpload(inputId) {
    const input = document.getElementById(inputId);
    if (!input) return;
    
    input.addEventListener('change', function(e) {
        const file = e.target.files[0];
        if (!file) return;
        
        // Validate file size (10MB limit)
        if (file.size > 10 * 1024 * 1024) {
            alert('File size must be less than 10MB');
            input.value = '';
            return;
        }
        
        // Show file preview if it's an image
        if (file.type.startsWith('image/')) {
            const reader = new FileReader();
            reader.onload = function(e) {
                showImagePreview(e.target.result);
            };
            reader.readAsDataURL(file);
        }
        
        // Show file info
        const fileInfo = document.getElementById('fileInfo');
        if (fileInfo) {
            fileInfo.innerHTML = `
                <div class="alert alert-info">
                    <i class="fas fa-file"></i>
                    <strong>${file.name}</strong> (${formatFileSize(file.size)})
                </div>
            `;
        }
    });
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function showImagePreview(src) {
    const preview = document.getElementById('imagePreview') || createImagePreview();
    preview.innerHTML = `<img src="${src}" class="img-thumbnail" style="max-width: 200px; max-height: 200px;">`;
}

function createImagePreview() {
    const preview = document.createElement('div');
    preview.id = 'imagePreview';
    preview.className = 'mt-2';
    document.querySelector('#fileInfo').appendChild(preview);
    return preview;
}

// Enhanced table sorting
function makeSortable(tableId) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const headers = table.querySelectorAll('th[data-sort]');
    headers.forEach(header => {
        header.style.cursor = 'pointer';
        header.innerHTML += ' <i class="fas fa-sort text-muted"></i>';
        
        header.addEventListener('click', function() {
            const column = this.dataset.sort;
            const isAscending = !this.classList.contains('sort-asc');
            
            // Reset all sort indicators
            headers.forEach(h => {
                h.classList.remove('sort-asc', 'sort-desc');
                const icon = h.querySelector('i');
                icon.className = 'fas fa-sort text-muted';
            });
            
            // Set current sort indicator
            this.classList.add(isAscending ? 'sort-asc' : 'sort-desc');
            const icon = this.querySelector('i');
            icon.className = isAscending ? 'fas fa-sort-up text-primary' : 'fas fa-sort-down text-primary';
            
            // Sort table rows
            sortTable(table, column, isAscending);
        });
    });
}

function sortTable(table, column, ascending) {
    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));
    
    rows.sort((a, b) => {
        const aVal = a.querySelector(`[data-sort-value="${column}"]`)?.textContent.trim() || 
                     a.cells[parseInt(column)]?.textContent.trim() || '';
        const bVal = b.querySelector(`[data-sort-value="${column}"]`)?.textContent.trim() || 
                     b.cells[parseInt(column)]?.textContent.trim() || '';
        
        // Try to parse as numbers
        const aNum = parseFloat(aVal.replace(/[^0-9.-]/g, ''));
        const bNum = parseFloat(bVal.replace(/[^0-9.-]/g, ''));
        
        if (!isNaN(aNum) && !isNaN(bNum)) {
            return ascending ? aNum - bNum : bNum - aNum;
        }
        
        // String comparison
        return ascending ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    });
    
    // Re-append sorted rows
    rows.forEach(row => tbody.appendChild(row));
}

// Initialize enhanced features when page loads
document.addEventListener('DOMContentLoaded', function() {
    // Enable tooltips
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
    
    // Make tables sortable
    const sortableTables = document.querySelectorAll('table[data-sortable]');
    sortableTables.forEach(table => makeSortable(table.id));
    
    // Enhance file uploads
    const fileInputs = document.querySelectorAll('input[type="file"]');
    fileInputs.forEach(input => enhanceFileUpload(input.id));
    
    // Auto-focus first input in modals
    const modals = document.querySelectorAll('.modal');
    modals.forEach(modal => {
        modal.addEventListener('shown.bs.modal', function() {
            const firstInput = this.querySelector('input, textarea, select');
            if (firstInput) firstInput.focus();
        });
    });
});
"""

# Final setup instructions
setup_instructions = """
## 🎯 Final Setup Instructions:

### 1. Database Setup:
```sql
-- Run in this order:
1. schema_tue_27066_japhet_digitalwill_db.sql
2. triggers_tue_27066_japhet_digitalwill_db.sql  
3. procedures_tue_27066_japhet_digitalwill_db.sql
4. sample_data_tue_27066_japhet_digitalwill_db.sql
```

### 2. Python Environment:
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install Flask==2.3.3 Flask-Session==0.5.0 oracledb==1.4.2 Werkzeug==2.3.7

# Set environment variables
export ORACLE_USER=your_username
export ORACLE_PASSWORD=your_password
export ORACLE_DSN=localhost:1521/xe
export FLASK_ENV=development
```

### 3. File Structure:
```
Create the directories and place files as shown in the file structure above.
Make sure templates are in the templates/ folder and static files in static/.
```

### 4. Run Application:
```bash
python run.py
```

### 5. Demo Credentials:
- **Testator**: jean.claude@example.rw / demo123
- **Executor**: solange.mukamana@lawfirm.rw / demo123  
- **Beneficiary**: eric.munyaneza@example.rw / demo123

### 6. Key Demo Points:

1. **Show Database Integration**: 
   - Create will → stored procedure call
   - Approve will → business logic validation
   - Asset assignment → percentage validation
   - Transfer initiation → weekend/holiday blocking

2. **Show Error Handling**:
   - Try transfers on weekend
   - Try over-allocating assets
   - Try approving will without executor

3. **Show Reporting**:
   - Generate will summary reports
   - View system statistics
   - Check audit logs

4. **Show User Experience**:
   - Role-based navigation
   - Real-time calculations
   - Professional UI/UX

Your Digital Will Management System demonstrates enterprise-level database development with PL/SQL! 🚀
"""

print(setup_instructions)