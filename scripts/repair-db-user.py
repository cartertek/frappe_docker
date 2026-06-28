#!/usr/bin/env python3
import json
import os
from pathlib import Path

import MySQLdb

site = os.environ["SITE_NAME"]
root_password = os.environ["DB_ROOT_PASSWORD"]

common_config = json.loads(Path("sites/common_site_config.json").read_text())
site_config = json.loads((Path("sites") / site / "site_config.json").read_text())

db_host = common_config.get("db_host") or site_config.get("db_host") or "db"
db_port = int(common_config.get("db_port") or site_config.get("db_port") or 3306)
db_name = site_config["db_name"]
db_password = site_config["db_password"]

conn = MySQLdb.connect(host=db_host, port=db_port, user="root", passwd=root_password)
try:
    cur = conn.cursor()
    for host in ("%", "localhost"):
        cur.execute(
            f"CREATE USER IF NOT EXISTS `{db_name}`@%s IDENTIFIED BY %s",
            (host, db_password),
        )
        cur.execute(f"ALTER USER `{db_name}`@%s IDENTIFIED BY %s", (host, db_password))
        cur.execute(f"GRANT ALL PRIVILEGES ON `{db_name}`.* TO `{db_name}`@%s", (host,))
    cur.execute("FLUSH PRIVILEGES")
finally:
    conn.close()
