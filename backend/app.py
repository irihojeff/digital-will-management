from flask import Flask, request, jsonify
import oracledb
import os

# ------------------------------
# Oracle DB Configuration
# ------------------------------
DB_USER = os.getenv("DB_USER", "JAPHET_DB")
DB_PASSWORD = os.getenv("DB_PASSWORD", "StrongPassword123")
DB_DSN = os.getenv("DB_DSN", "localhost/XEPDB1")

app = Flask(__name__)

# ------------------------------
# Utility: Get Oracle Connection
# ------------------------------
def get_connection():
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)

# ------------------------------
# Health Check Route
# ------------------------------
@app.route("/ping")
def ping():
    return {"status": "running"}, 200

# ------------------------------
# Route: Assign Asset to Beneficiary
# ------------------------------
@app.route("/api/assign-beneficiary", methods=["POST"])
def assign_asset():
    data = request.json
    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.callproc("assign_asset_to_beneficiary", [
            data["asset_id"],
            data["beneficiary_id"],
            data["share_percent"],
            data.get("conditions", None)
        ])

        conn.commit()
        return {"message": "Asset assigned successfully."}, 200

    except oracledb.Error as e:
        return {"error": str(e)}, 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

@app.route("/api/approve-will", methods=["POST"])
def approve_will():
    data = request.json
    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.callproc("approve_will", [data["will_id"]])

        conn.commit()
        return {"message": f"Will ID {data['will_id']} approved successfully."}, 200

    except oracledb.Error as e:
        return {"error": str(e)}, 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ------------------------------
# Main Entrypoint
# ------------------------------
if __name__ == "__main__":
    app.run(debug=True, port=5000)
