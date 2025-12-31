# Scripts to check and maintain the performance of postgres and mongo databases.

- Explanations for individual scripts can be found below.

    - **postgres-size-report.sh**       ->     Can be used to check the deatiled size report for different tables in foreman\candlepin databases for satellite
    
    - **mongo-size-report.sh**          ->     Can be used to check the details size report for all collections in pulp database for satellite\capsule
    
    - **postgres-vaccum-reindex.sh**    ->     Can be used to perform a full vaccuming and re-indexing of foreman\candlepin databases on satellite.
    
    - **mongo-repair.sh**               ->     Can be used to compress\repair the mongodb in satellite\capsule to improve DB performance.

    - **mongo-compact-collections.sh**  ->     Can be used to compact\defragment mongo database collections and release unnecessary disk space in satellite\capsule

    - **vacuum_to_find_broken_tables.sh**  ->     Can be used to find tables that are somehow corrupted i.e. missing chunk or uncommited xmin

    - **fix_broken_rows_v2.sh**  ->    Can be used to fix the corrupted data. All the rows from the original table would be moved to a temporary table, then all rows in the original table be deleted.
                                       After that, the rows from the temporary table  migrated back to the original table. Finally, vacuum the table.
