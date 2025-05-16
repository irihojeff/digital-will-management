
# ✅ Digital Will & Asset Transfer System - Project Roadmap

## 🟩 PHASE 1: Database Design & Setup ✅
- [x] Define enhanced ERD with Rwandan context
- [x] Create schema SQL (`schema_tue_27066_japhet_digitalwill_db.sql`)
- [x] Execute and create all tables in Oracle
- [x] Insert sample data from Rwanda (`sample_data_tue_27066_japhet_digitalwill_db.sql`)

---

## 🟩 PHASE 2: Core Logic with PL/SQL 🔄 *(Current Phase)*

### 🔁 Triggers
- [ ] Trigger: block INSERT/UPDATE/DELETE during weekdays
- [ ] Trigger: block transfers on upcoming holidays (`holidays` table)
- [ ] Trigger: auto-insert into `will_status_history` when `wills.status` changes
- [ ] Trigger: update `wills.last_updated_at` on will/asset/beneficiary change

### 🧠 Procedures & Functions
- [ ] Procedure: assign asset to beneficiary with validations
- [ ] Function: calculate total value of assets for a will
- [ ] Procedure: get will summary (assets, beneficiaries, executors)
- [ ] Package: reusable audit logging procedure

---

## 🟩 PHASE 3: Flask + Oracle Integration 🔧
- [ ] Create Flask app (`app.py`)
- [ ] Connect to Oracle using `oracledb`
- [ ] Build routes: add will, assign assets, assign beneficiary
- [ ] Build route: request transfer → trigger-protected logic
- [ ] Return messages from PL/SQL to user (e.g., transfer blocked)
- [ ] Admin route: view audit logs or transfer logs

---

## 🟩 PHASE 4: Frontend Forms (HTML/CSS) 💻
- [ ] HTML form: register user, create will, add asset
- [ ] HTML form: assign beneficiary (dropdown)
- [ ] HTML form: trigger transfer process
- [ ] Admin HTML page: view audit log & transfer logs

---

## 🟩 PHASE 5: Reporting & Documentation 📝
- [ ] GitHub `README.md` with full summary and code references
- [ ] PowerPoint slides: ERD, BPMN/UML, screenshots, triggers, procedures
- [ ] Submit GitHub + Google Drive + email to instructor

---

### 🔄 Let's keep this updated as we progress together.
