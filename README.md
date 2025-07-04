# 📜 Digital Will Management System

## Overview

The **Digital Will Management System** is a comprehensive **PL/SQL Oracle Database + Flask web application** developed to automate will creation, approval, execution, and estate distribution in Rwanda. It demonstrates advanced **database design, PL/SQL programming, and Python web development** while addressing security, transparency, and efficiency challenges in estate management.

---

## 🎯 Features

✅ Automated will lifecycle workflows (creation, approval, execution)
✅ Role-based access control for testators, executors, beneficiaries, and admins
✅ Real-time asset allocation validation
✅ Transfer management with weekend/holiday blocking
✅ Full audit logging for legal compliance
✅ Responsive, user-friendly web interface

---

## 🗄️ Technologies

**Database:** Oracle 19c, PL/SQL (procedures, triggers, packages, exception handling)
**Backend:** Flask (Python), REST API integration
**Frontend:** HTML, CSS, JavaScript, Bootstrap
**Tools:** Git, VS Code, Postman

---

## 🚀 Installation & Setup

**Prerequisites:** Oracle Database, Python 3.8+, Flask, Git, Chrome/Firefox

1️⃣ Clone repository:

```bash
git clone https://github.com/irihojeff/digital-will-management.git
cd digital-will-management
```

2️⃣ Set up Oracle Database:

* Create user:

```sql
CREATE USER tues_27066_japhet_digitalwill_db IDENTIFIED BY japhet;
GRANT ALL PRIVILEGES TO tues_27066_japhet_digitalwill_db;
```

* Run provided schema and sample data scripts.

3️⃣ Install dependencies:

```bash
pip install flask flask-session oracledb werkzeug
```

4️⃣ Configure `config.py` with database credentials.

5️⃣ Run the application:

```bash
python app.py
```

---

## 🧪 Testing

✅ Weekend transfer blocking and asset allocation validation
✅ Full will lifecycle execution and audit tracking
✅ Secure authentication for all user roles

---

## 📈 Sample SQL Queries

**Will Summary:**

```sql
SELECT w.title, w.status, COUNT(a.asset_id) AS asset_count, SUM(a.value) AS total_value
FROM wills w
LEFT JOIN assets a ON w.will_id = a.will_id
GROUP BY w.will_id, w.title, w.status;
```

**Audit Trail:**

```sql
SELECT user_name, action, action_table, timestamp, status
FROM audit_log
WHERE timestamp >= SYSDATE - 7
ORDER BY timestamp DESC;
```

---

## 📞 Contact

👤 Japhet Idukundiriho
📧 [idukundiriho.japhet@auca.ac.rw](mailto:idukundiriho.japhet@auca.ac.rw)
🌐 [LinkedIn](https://www.linkedin.com/in/japhet-idukundiriho)
💻 [GitHub](https://github.com/irihojeff/digital-will-management)

---

## 🚀 Future Enhancements

✅ Mobile app with push notifications
✅ AI for asset valuation and document parsing
✅ Blockchain for immutable will versioning and smart contract execution

---

## 💡 Purpose

This project demonstrates advanced database programming, backend integration, and real-world application of **MIS principles in estate management**, strengthening readiness for **internships and full-stack developer roles**.
