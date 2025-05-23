# Digital Will Management System
## AUCA Capstone Project 2024-2025
### Database Development with PL/SQL (INSY 8311)

**Student:** Japhet Nsengiyumva  
**Project Type:** Individual Capstone Project  
**Lecturer:** Eric Maniraguha  

---

## 🎯 Project Overview

The Digital Will Management System is a comprehensive PL/SQL-based Oracle database solution that automates the creation, management, and execution of digital wills. This system demonstrates advanced database programming techniques including procedures, functions, triggers, packages, and comprehensive auditing mechanisms.

### 🏆 Key Innovation
This project goes beyond the basic requirements by implementing a complete **Flask web application** with a professional user interface, showcasing the database functionality through an interactive, user-friendly platform.

---

## 🏗️ System Architecture

### Database Layer (Oracle PL/SQL)
- **11 Tables** with proper normalization (3NF)
- **6 Stored Procedures** with comprehensive validation
- **15+ Triggers** for business logic and security
- **Comprehensive Audit System** for all operations
- **Weekend/Holiday Restrictions** as per assignment requirements

### Application Layer (Flask Python)
- **Professional Web Interface** for testing and demonstration
- **Real-time Procedure Testing** with immediate feedback
- **Audit Log Visualization** and monitoring
- **Interactive Reports** and analytics
- **Responsive Design** with Bootstrap 5

---

## 🗄️ Database Schema

### Core Tables
1. **users** - Testators and user information
2. **wills** - Will documents and metadata
3. **executors** - Will executors with primary designation
4. **assets** - Property and asset information
5. **beneficiaries** - Inheritance beneficiaries
6. **will_asset_beneficiaries** - Asset allocation mapping
7. **transfer_logs** - Asset transfer tracking
8. **will_status_history** - Status change auditing
9. **documents** - Document attachments
10. **holidays** - Holiday reference for restrictions
11. **audit_log** - Comprehensive system auditing

---

## 🔧 Key Procedures Implemented

### 1. `approve_will(p_will_id)`
**Purpose:** Validates and approves draft wills
- ✅ Checks for executors and primary executor
- ✅ Validates asset allocation (90%+ requirement)
- ✅ Updates status from Draft to Approved
- ✅ Records status history and audit logs

### 2. `assign_asset_to_beneficiary(p_asset_id, p_beneficiary_id, p_share_percent, p_conditions)`
**Purpose:** Assigns assets to beneficiaries with validation
- ✅ Validates asset and beneficiary existence
- ✅ Prevents over-allocation (total shares ≤ 100%)
- ✅ Checks will execution status
- ✅ Comprehensive error handling

### 3. `transfer_asset(p_asset_id, p_beneficiary_id)`
**Purpose:** Initiates asset transfers to beneficiaries
- ✅ Validates asset-beneficiary relationships
- ✅ Checks will approval status
- ✅ Prevents duplicate transfers
- ✅ Subject to weekend/holiday restrictions

### 4. `add_document(p_related_entity, p_entity_id, p_title, p_description, p_file_path, p_file_type)`
**Purpose:** Attaches documents to wills or assets
- ✅ Validates entity references (WILL/ASSET)
- ✅ File type validation
- ✅ Automatic timestamping
- ✅ Audit trail creation

### 5. `set_primary_executor(p_executor_id)`
**Purpose:** Manages primary executor designation
- ✅ Ensures only one primary per will
- ✅ Data consistency validation
- ✅ Transaction safety with savepoints
- ✅ Comprehensive logging

### 6. `delete_draft_will(p_will_id, p_force_delete, p_confirm_text)`
**Purpose:** Safely deletes draft wills and related data
- ✅ Cascading deletion of related records
- ✅ Status validation (Draft only)
- ✅ Force delete with confirmation for non-drafts
- ✅ Complete audit trail

---

## 🎯 Advanced Triggers Implementation

### Business Logic Triggers
1. **`trg_block_weekend_holiday_transfer`** - Prevents transfers on weekends/holidays
2. **`trg_status_change_log`** - Tracks all will status changes
3. **`trg_check_asset_share_percent`** - Validates asset allocation percentages
4. **`trg_validate_complete_allocation`** - Ensures 100% allocation before execution

### Data Integrity Triggers
5. **`trg_validate_executor_exists`** - Ensures executors before approval
6. **`trg_single_primary_executor`** - Enforces one primary executor per will
7. **`trg_validate_document_entity`** - Validates document references
8. **`trg_validate_email_format`** - Email format validation
9. **`trg_prevent_will_deletion`** - Prevents deletion of approved/executed wills

### Audit & Timestamp Triggers
10. **`trg_update_last_modified_on_wills`** - Automatic timestamp updates
11. **`trg_update_last_modified_on_assets`** - Asset change timestamps
12. **`trg_update_last_modified_on_executors`** - Executor change timestamps
13. **`trg_audit_wills`** - Comprehensive will auditing
14. **Multiple cascading update triggers** for data consistency

---

## 🚀 Installation & Setup

### Prerequisites
- Oracle Database 19c or later
- Python 3.8+
- pip (Python package manager)

### 1. Database Setup
```sql
-- 1. Create the database schema
@schema_tue_27066_japhet_digitalwill_db.sql

-- 2. Load sample data
@sample_data_tue_27066_japhet_digitalwill_db.sql

-- 3. Create procedures
@procedures_tue_27066_japhet_digitalwill_db.sql

-- 4. Create triggers
@triggers_tue_27066_japhet_digitalwill_db.sql
```

### 2. Python Environment Setup
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install required packages
pip install flask oracledb python-oracledb
```

### 3. Application Configuration
```bash
# Set environment variables
export DB_USER="JAPHET_DB"
export DB_PASSWORD="StrongPassword123"
export DB_DSN="localhost/XEPDB1"
```

### 4. Run the Application
```bash
python app.py
```

Access the application at: `http://localhost:5000`

---

## 🖥️ Web Interface Features

### Dashboard
- **System Overview** with key statistics
- **Real-time Activity** monitoring
- **Quick Actions** for procedure testing
- **Visual Charts** for data representation

### Procedure Testing Interface
- **Interactive Forms** for each procedure
- **Real-time Validation** and error handling
- **Detailed Results** with success/failure feedback
- **Test Case Scenarios** with pre-defined data

### Audit & Monitoring
- **Comprehensive Audit Logs** with filtering
- **Security Monitoring** dashboard
- **Activity Statistics** and trends
- **Export Capabilities** for reporting

### Reports & Analytics
- **Will Status Distribution** charts
- **Asset Allocation** summaries
- **User Activity** patterns
- **System Performance** metrics

---

## 🧪 Testing Scenarios

### 1. Will Approval Testing
```
Test Cases:
✅ Valid draft will with executors and assets
❌ Will without executors (should fail)
❌ Will without primary executor (should fail)
❌ Will with under-allocated assets (should fail)
❌ Already approved will (should fail)
```

### 2. Asset Assignment Testing
```
Test Cases:
✅ Valid asset-beneficiary assignment
❌ Over-allocation (>100% shares)
❌ Non-existent asset/beneficiary
❌ Executed will modification (should fail)
```

### 3. Weekend/Holiday Restriction Testing
```
Test Cases:
❌ Transfer on Saturday (should fail)
❌ Transfer on Sunday (should fail)
❌ Transfer on Independence Day (should fail)
✅ Transfer on valid weekday
```

### 4. Trigger Validation Testing
```
Test Cases:
❌ Multiple primary executors (should fail)
❌ Invalid email format (should fail)
❌ Document reference to non-existent entity (should fail)
✅ Valid operations with proper audit logging
```

---

## 📊 Assignment Requirements Fulfillment

### ✅ Phase VI: Database Interaction and Transactions
- **Parameterized Procedures:** All 6 procedures use parameters
- **Cursor Usage:** Implemented in validation queries
- **Exception Handling:** Comprehensive error handling in all procedures
- **Packages:** Could be extended to group related procedures
- **DML/DDL Operations:** Full CRUD operations implemented

### ✅ Phase VII: Advanced Programming and Auditing
- **Problem Statement:** Clear justification for triggers and auditing
- **Weekend/Holiday Restrictions:** Fully implemented with trigger
- **Holiday Reference Table:** Dynamic holiday checking
- **Comprehensive Auditing:** All operations logged with user tracking
- **Security Enhancement:** Prevents unauthorized access and modifications

### ✅ Innovation Beyond Requirements
- **Complete Web Application:** Professional Flask interface
- **Real-time Testing:** Interactive procedure testing
- **Visual Analytics:** Charts and reports for better understanding
- **Production-Ready:** Error handling, logging, and user experience

---

## 📈 Performance Features

- **Transaction Management:** Proper COMMIT/ROLLBACK usage
- **Autonomous Transactions:** For audit logging without affecting main transactions
- **Savepoints:** For partial rollback in complex procedures
- **Efficient Queries:** Optimized SQL with proper indexing considerations
- **Error Recovery:** Graceful handling of all error scenarios

---

## 🔒 Security Features

- **Comprehensive Auditing:** Every action tracked with user, timestamp, and IP
- **Access Control:** Procedure-based security model
- **Data Validation:** Multiple layers of input validation
- **Injection Prevention:** Parameterized queries throughout
- **Weekend/Holiday Enforcement:** Business rule enforcement via triggers

---

## 📚 Documentation Structure

```
/project-root/
├── app.py                          # Main Flask application
├── templates/                      # HTML templates
│   ├── base.html                  # Base template with navigation
│   ├── dashboard.html             # Main dashboard
│   ├── procedures_menu.html       # Procedure testing menu
│   ├── test_approval.html         # Will approval testing
│   ├── audit_logs.html           # Audit log viewer
│   └── [other templates]
├── static/                        # CSS, JS, images
├── sql/
│   ├── schema_tue_27066_japhet_digitalwill_db.sql
│   ├── procedures_tue_27066_japhet_digitalwill_db.sql
│   ├── triggers_tue_27066_japhet_digitalwill_db.sql
│   └── sample_data_tue_27066_japhet_digitalwill_db.sql
├── screenshots/                   # Application screenshots for GitHub
├── README.md                      # This documentation
└── requirements.txt               # Python dependencies
```

---

## 🎯 Future Enhancements

1. **Advanced Reporting:** More sophisticated analytics and reporting
2. **Email Notifications:** Automated notifications for status changes
3. **Document Upload:** Real file upload and storage
4. **Multi-language Support:** Kinyarwanda and French language options
5. **Mobile App:** React Native mobile application
6. **Blockchain Integration:** Immutable will storage for legal compliance

---

## 🏆 Project Achievements

### Technical Accomplishments
- ✅ **Complete Database Design** with 11 normalized tables
- ✅ **6 Advanced Procedures** with comprehensive validation
- ✅ **15+ Triggers** covering all business requirements
- ✅ **Comprehensive Audit System** for security and compliance
- ✅ **Weekend/Holiday Restrictions** as per assignment requirements

### Innovation Highlights
- 🚀 **Professional Web Interface** beyond assignment scope
- 🚀 **Real-time Testing Platform** for immediate procedure validation
- 🚀 **Interactive Analytics** with visual charts and reports
- 🚀 **Production-Ready Application** with proper error handling
- 🚀 **Complete Documentation** for easy understanding and maintenance

### Assignment Compliance
- ✅ **All Phase VI requirements** fully implemented
- ✅ **All Phase VII requirements** comprehensively addressed
- ✅ **Weekend/Holiday restriction** properly enforced
- ✅ **Comprehensive auditing** with user tracking
- ✅ **Security enhancements** exceeding basic requirements

---

## 📞 Contact Information

**Student:** Japhet Nsengiyumva  
**Email:** [Your Email]  
**Student ID:** tue_27066  
**Course:** Database Development with PL/SQL (INSY 8311)  
**Institution:** African University of Central Africa (AUCA)  
**Academic Year:** 2024-2025  

---

## 📄 License

This project is developed for academic purposes as part of the AUCA Capstone Project requirements.

---

*"Whatever you do, work at it with all your heart, as working for the Lord, not for human masters." — Colossians 3:23 (NIV)*