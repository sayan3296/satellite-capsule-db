# Scripts to check and maintain the performance of postgres and mongo databases.

- Explanations for individual scripts can be found below.

    - **postgres-size-report.sh**       ->     Can be used to check the deatiled size report for different tables in foreman\candlepin databases for satellite
    
    - **mongo-size-report.sh**          ->     Can be used to check the details size report for all collections in pulp database for satellite\capsule 
    
    - **postgres-vaccum-reindex.sh**    ->     Can be used to perform a full vaccuming and re-indexing of foreman\candlepin databases on satellite.
    
    - **mongo-repair.sh**               ->     Can be used to compress\repair the mongodb in satellite\capsule to improve DB performance.

    - **mongo-compact-collections.sh**  ->     Can be used to compact\defragment mongo database collections and release unnecessary disk space in satellite\capsule
