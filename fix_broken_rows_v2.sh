#!/bin/bash

### ERROR in question ###
# Error message from server: ERROR:  missing chunk number 0 for toast value 730428 in pg_toast_26337
# uncommitted xmin 176271890 from before xid cutoff 362574848 needs to be frozen
####

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <database_name> <table_name>"
    exit 1
fi

DB_NAME=$1
TABLE_NAME=$2
USER="postgres"
STAGING_TABLE="${TABLE_NAME}_staging"

echo "----------------------------------------------------"
echo "Starting TABLE BOUNCE: $DB_NAME.$TABLE_NAME"
echo "----------------------------------------------------"

# 1. Verify Database and Table exist
DB_EXISTS=$(psql -U $USER -lqt | cut -d \| -f 1 | grep -w "$DB_NAME" | wc -l)
if [ "$DB_EXISTS" -eq 0 ]; then
    echo "Error: Database '$DB_NAME' not found."
    exit 1
fi

# 2. Execute the Bounce Logic
# We use a single PL/pgSQL block for maximum speed and error handling
psql -U $USER -d "$DB_NAME" <<EOF
DO \$$
DECLARE
    r record;
    saved_count int := 0;
    lost_count int := 0;
BEGIN
    -- Disable triggers/FKs for this session to allow data movement
    SET session_replication_role = 'replica';

    -- Create empty staging clone
    RAISE NOTICE 'Creating staging table...';
    EXECUTE 'CREATE TABLE $STAGING_TABLE (LIKE "$TABLE_NAME" INCLUDING ALL)';

    -- Row-by-row move (The "Rescue" phase)
    RAISE NOTICE 'Scanning for healthy rows...';
    FOR r IN (SELECT ctid FROM "$TABLE_NAME") LOOP
        BEGIN
            EXECUTE 'INSERT INTO $STAGING_TABLE SELECT * FROM "$TABLE_NAME" WHERE ctid = ' || quote_literal(r.ctid);
            saved_count := saved_count + 1;
        EXCEPTION WHEN OTHERS THEN
            lost_count := lost_count + 1;
            -- Skip corrupt row and continue
        END;
    END LOOP;

    RAISE NOTICE 'Migration finished. Rescued: %, Corrupt rows skipped: %', saved_count, lost_count;

    -- Delete all records
    RAISE NOTICE 'Deleting all rows in the original table';
    EXECUTE 'DELETE FROM "$TABLE_NAME"';

    -- The Reset phase
    -- RAISE NOTICE 'Truncating original table to clear corruption...';
    -- EXECUTE 'TRUNCATE "$TABLE_NAME"';

    -- Restore phase
    RAISE NOTICE 'Restoring data to original table...';
    EXECUTE 'INSERT INTO "$TABLE_NAME" SELECT * FROM $STAGING_TABLE';

    -- Cleanup
    EXECUTE 'DROP TABLE $STAGING_TABLE';
    
    RAISE NOTICE 'Bounce complete.';
END \$$;
EOF

# 3. Finalization
echo "----------------------------------------------------"
echo "Resetting Transaction Age (Vacuum Freeze)..."
psql -U $USER -d "$DB_NAME" -c "VACUUM (FREEZE, VERBOSE) \"$TABLE_NAME\";"

echo "----------------------------------------------------"
echo "FINAL CHECK: Database Age"
psql -U $USER -d "$DB_NAME" -c "SELECT datname, age(datfrozenxid) FROM pg_database WHERE datname = '$DB_NAME';"
