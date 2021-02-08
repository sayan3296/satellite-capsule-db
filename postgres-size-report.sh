#!/bin/bash

 
TABLEQUERY=$(cat <<-END
 SELECT table_name, pg_size_pretty(total_bytes) AS total
      , pg_size_pretty(index_bytes) AS INDEX
      , pg_size_pretty(toast_bytes) AS toast
      , pg_size_pretty(table_bytes) AS TABLE
    FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes FROM (
        SELECT c.oid,nspname AS table_schema, relname AS TABLE_NAME
                , c.reltuples AS row_estimate
                , pg_total_relation_size(c.oid) AS total_bytes
                , pg_indexes_size(c.oid) AS index_bytes
                , pg_total_relation_size(reltoastrelid) AS toast_bytes
            FROM pg_class c
            LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE relkind = 'r'
    ) a
  ) a order by total_bytes DESC LIMIT 30;
END
)

# echo $TABLEQUERY
cd ~postgres

echo ""
echo "*************** Database sizes *****************"
echo ""
su - postgres -c "psql -c '\l+'"

echo ""
echo "************* Candlepin Tablesizes *************"
echo ""
echo $TABLEQUERY | su - postgres -c "psql -d candlepin"


echo ""
echo "************** Foreman Tablesizes **************"
echo ""
echo $TABLEQUERY | su - postgres -c "psql -d foreman"


echo ""
echo "*************** FileSystem Usage ***************"
echo ""

if [ -d /var/lib/pgsql ]
then
echo "du -hs /var/lib/pgsql/*"
du -hs /var/lib/pgsql/*
echo
fi

if [ -d /var/lib/pgsql/data ]
then
echo "du -hs /var/lib/pgsql/data/*"
du -hs /var/lib/pgsql/data/*
fi

if [ -d /var/opt/rh/rh-postgresql12/lib/pgsql ]
then
echo "du -hs /var/opt/rh/rh-postgresql12/lib/pgsql/*"
du -hs /var/opt/rh/rh-postgresql12/lib/pgsql/*
echo
fi

if [ -d /var/opt/rh/rh-postgresql12/lib/pgsql/data ]
then
echo "du -hs /var/opt/rh/rh-postgresql12/lib/pgsql/data/*"
du -hs /var/opt/rh/rh-postgresql12/lib/pgsql/data/*
fi

echo -e "\n\n************** Row count from some concerned foreman tables **************\n\n"

satver=$(rpm -q satellite --qf "%{VERSION}" | awk -F'.' '{ print $1$2 }')

echo -e "Table_Name\tTotal_Count\tCount_older_than_30_days" | column -t -o "      "
echo -e "----------\t-----------\t------------------------" | column -t -o "      "
for i in trends trend_counters sessions reports audits logs foreman_tasks_tasks fact_names fact_values;
do
  if [ $i == 'foreman_tasks_tasks' ]
  then
    _COUNT=$(su - postgres -c "psql -d foreman -c 'select count(*) as count from $i ;'" | egrep -v "count|--|row|^$")
    _COUNT30=$(su - postgres -c "psql -d foreman -c 'select count(*) as count from $i where started_at < CURRENT_DATE - INTERVAL '\''30 days'\'';'" | egrep -v "count|--|row|^$") 
    echo -e "$i\t $_COUNT\t $_COUNT30"
  elif [ $i == 'logs' ] && [ $satver -le 65 ]
  then
    _COUNT=$(su - postgres -c "psql -d foreman -c 'select count(*) as count from $i;'"| egrep -v "count|--|row|^$")
    _COUNT30='NA'
    echo -e "$i\t $_COUNT\t $_COUNT30"
  elif [ $i != 'logs' ] || [ $i == 'foreman_tasks_tasks' ]
  then
    _COUNT=$(su - postgres -c "psql -d foreman -c 'select count(*) as count from $i;'"| egrep -v "count|--|row|^$")
    _COUNT30=$(su - postgres -c "psql -d foreman -c 'select count(*) as count from $i where created_at < CURRENT_DATE - INTERVAL '\''30 days'\'';'"| egrep -v "count|--|row|^$")
    echo -e "$i\t $_COUNT\t $_COUNT30"
  fi
done | column -t -o "      "
