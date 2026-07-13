"""
WRDS – Audit Analytics: min / max cyber-breach disclosure date per firm.

Audit Analytics' Cyber Security breach data lives in the WRDS `audit` schema.
The exact table name and disclosure-date column differ slightly across
subscriptions, so this script first *discovers* the right table/column and
then computes the earliest and latest disclosure date for each firm.

Requirements:
    pip install wrds
    (You'll be prompted for your WRDS username/password on first connect,
     and can save a ~/.pgpass file so you aren't asked again.)
"""

import wrds

# ---------------------------------------------------------------------------
# 1. Connect
# ---------------------------------------------------------------------------
db = wrds.Connection()          # prompts for WRDS credentials

# ---------------------------------------------------------------------------
# 2. Discover the cyber-breach table inside the Audit Analytics schema
# ---------------------------------------------------------------------------
LIBRARY = "audit"               # Audit Analytics schema on WRDS

tables = db.list_tables(library=LIBRARY)
cyber_tables = [t for t in tables if "cyber" in t.lower() or "breach" in t.lower()]
print("Candidate cyber-breach tables:", cyber_tables)

# Pick the first match (usually 'cybersecurity' / 'auditcyber' etc.).
# If several are listed, set TABLE explicitly to the one you want.
TABLE = cyber_tables[0] if cyber_tables else "cybersecurity"

# Inspect columns so we can find the disclosure-date and firm-id fields.
cols = db.describe_table(library=LIBRARY, table=TABLE)
print(cols)

# ---------------------------------------------------------------------------
# 3. Pick the disclosure-date column and the firm identifier
# ---------------------------------------------------------------------------
# Common Audit Analytics field names — adjust after looking at the print above.
#   disclosure date : 'disclosuredate', 'date_of_disclosure', 'disclosure_dt',
#                      'date_became_aware', 'date_of_breach'
#   firm identifier : 'company_fkey' (Audit Analytics key), 'ticker', 'cik',
#                      'company_name'
DATE_COL = "disclosuredate"     # <-- set to the real column from step 2
FIRM_COL = "company_fkey"       # <-- set to your preferred firm identifier

# ---------------------------------------------------------------------------
# 4. Min / max disclosure date per firm
# ---------------------------------------------------------------------------
query = f"""
    SELECT {FIRM_COL}                AS firm,
           MIN({DATE_COL})          AS first_disclosure,
           MAX({DATE_COL})          AS last_disclosure,
           COUNT(*)                 AS n_breaches
    FROM {LIBRARY}.{TABLE}
    WHERE {DATE_COL} IS NOT NULL
    GROUP BY {FIRM_COL}
    ORDER BY firm
"""

result = db.raw_sql(query)
print(result.head(20))

# Overall (whole-database) date range, for reference:
overall = db.raw_sql(
    f"SELECT MIN({DATE_COL}) AS min_date, MAX({DATE_COL}) AS max_date "
    f"FROM {LIBRARY}.{TABLE} WHERE {DATE_COL} IS NOT NULL"
)
print("Overall disclosure-date range:")
print(overall)

# Save per-firm results if you want them on disk:
# result.to_csv("cyberbreach_date_range_by_firm.csv", index=False)

db.close()
