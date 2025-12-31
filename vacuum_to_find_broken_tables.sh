#!/bin/bash

### ERROR in question ###
# Error message from server: ERROR:  missing chunk number 0 for toast value 730428 in pg_toast_26337
# uncommitted xmin 176271890 from before xid cutoff 362574848 needs to be frozen
####

# Check if a database name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <database_name>"
    exit 1
fi

DB_NAME="$1"
USER="postgres"

# Verify database exists
DB_EXISTS=$(psql -U $USER -lqt | cut -d \| -f 1 | grep -w "$DB_NAME" | wc -l)
if [ "$DB_EXISTS" -eq 0 ]; then
    echo "Error: Database '$DB_NAME' not found."
    exit 1
fi

echo "Starting one-by-one vacuum freeze on: $DB_NAME"

# Get a list of all tables (including system catalogs)
# We process catalogs first to prioritize clearing the 'stuck' system age
TABLES=$(psql -U $USER -d "$DB_NAME" -t -c "
SELECT n.nspname || '.' || c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' 
AND n.nspname NOT IN ('information_schema')
ORDER BY (n.nspname = 'pg_catalog') DESC, n.nspname, c.relname;")

FAILED_TABLES=()

for TABLE in $TABLES; do
    echo "----------------------------------------------------"
    echo "Processing: $TABLE"
    
    # Run VACUUM FREEZE. 2>&1 redirects errors to stdout so they appear in logs.
    psql -U $USER -d "$DB_NAME" -c "VACUUM (FREEZE, VERBOSE) $TABLE;" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: $TABLE"
    else
        echo "FAILED: $TABLE"
        FAILED_TABLES+=("$TABLE")
    fi
done

echo "----------------------------------------------------"
echo "SUMMARY"
echo "----------------------------------------------------"
if [ ${#FAILED_TABLES[@]} -ne 0 ]; then
    echo "The following tables failed and require manual repair:"
    for FT in "${FAILED_TABLES[@]}"; do
        echo " - $FT"
    done
else
    echo "All tables vacuumed successfully!"
fi

echo ""
echo "Current Database XID Age:"
psql -U $USER -d "$DB_NAME" -c "SELECT datname, age(datfrozenxid) FROM pg_database WHERE datname = '$DB_NAME';"
