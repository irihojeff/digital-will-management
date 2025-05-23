# config.py

import os
from datetime import timedelta

class Config:
    """Base configuration for Digital Will Management System"""

    # Flask session & security
    SECRET_KEY               = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    SESSION_TYPE             = 'filesystem'
    SESSION_FILE_DIR         = os.path.join(os.path.dirname(__file__), 'flask_session')
    SESSION_PERMANENT         = True
    PERMANENT_SESSION_LIFETIME = timedelta(hours=2)
    SESSION_COOKIE_HTTPONLY  = True
    SESSION_COOKIE_SAMESITE  = 'Lax'

    # Oracle DB credentials
    ORACLE_USER       = os.getenv('ORACLE_USER', 'japhet_db')
    ORACLE_PASSWORD   = os.getenv('ORACLE_PASSWORD', 'StrongPassword123')
    ORACLE_DSN        = os.getenv('ORACLE_DSN', 'localhost:1521/XEPDB1')
    ORACLE_THICK_MODE = False
    ORACLE_CLIENT_PATH = os.getenv(
        'ORACLE_CLIENT_PATH',
        r'C:\oracle\instantclient_21_3'
    )

    # File upload settings (if you need)
    UPLOAD_FOLDER     = os.path.join(os.path.dirname(__file__), 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB
    ALLOWED_EXTENSIONS = {'pdf','doc','docx','jpg','jpeg','png'}

class DevelopmentConfig(Config):
    DEBUG   = True
    TESTING = False

class ProductionConfig(Config):
    DEBUG   = False
    TESTING = False
    SESSION_COOKIE_SECURE = True

class TestingConfig(Config):
    DEBUG            = True
    TESTING          = True
    WTF_CSRF_ENABLED = False

config = {
    'development': DevelopmentConfig,
    'production':  ProductionConfig,
    'testing':     TestingConfig,
    'default':     DevelopmentConfig
}
