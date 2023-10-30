module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    db
# ###################################################################################################
def "db", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "db", name, "def"
  root.policy_set_here_weak "type",   "postgres"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  platform = project_node.policy_get_val_use "platform"
  switch platform
    when "nodejs"
      root.policy_set_here_weak "driver", "sequelize"
  
  root.data_hash.migration_autoincrement ?= 0
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "db db_migration", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    name = "migration_#{mod_runner.current_runner.curr_root.data_hash.migration_autoincrement++}"
  
  root = mod_runner.current_runner.curr_root.tr_get "db_migration", name, "def"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# for define db_model use: struct, field

def "db struct db_index", (field_list_str, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "db_index", field_list_str, "def"
  root.data_hash.field_list_str = field_list_str
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "db db_dyn_enum", (type)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "db_dyn_enum", type, "def"
  
  root

# TODO move to hydrator (postgres only)
# ###################################################################################################
#    db_backup
# ###################################################################################################
bdh_module_name_root module, "db_backup",
  nodegen       : (root, ctx)->
    npm_script "db:backup", "./db_backup.sh"
    false
  
  emit_codegen  : (root, ctx)->
    # TODO db lookup
    # TODO А еще неплохо бы сюда сохраняемые процедуры записать. Но я их пока не использую, потому подождет
    db_name = root.parent.data_hash.database_name
    ctx.file_render_exec "db_backup.sh", """
      #!/bin/bash
      set -e
      
      if [ -z "$PGPASSWORD" ]; then
        PGPASSWORD=`cat .env | grep "SEQUELIZE_PASSWORD" | awk '{split($0,a,"="); print a[2]}'`
      fi
      
      if [ -z "$PGPASSWORD" ]; then
        echo "missing PGPASSWORD"
        exit 1
      fi
      
      YEAR=`date +%Y`
      DATE=`date +"%d.%m"`
      DATE_FULL=`date +"%d.%m.%Y"`
      DB_NAME=#{db_name}
      PORT=5432
      CONNECTION_ARG="--host=127.0.0.1 --port=$PORT --username=postgres --dbname=$DB_NAME"
      
      BACKUP_PATH="/data/backup/$YEAR/$DATE/$DB_NAME"
      RESTORE_SCHEMA_ENUM_SQL="${BACKUP_PATH}/restore_schema_enum.sql"
      RESTORE_SCHEMA_SQL="${BACKUP_PATH}/restore_schema.sql"
      RESTORE_SCHEMA_SH="${BACKUP_PATH}/restore_schema.sh"
      RESTORE_SH="${BACKUP_PATH}/restore.sh"
      
      mkdir -p "$BACKUP_PATH"
      
      echo "#/bin/bash" >  $RESTORE_SH
      echo "set -e"     >> $RESTORE_SH
      
      echo "" >  $RESTORE_SCHEMA_SQL
      echo "#/bin/bash" >  $RESTORE_SCHEMA_SH
      echo "set -e"     >> $RESTORE_SCHEMA_SH
      echo "sudo -u postgres psql -c 'create database $DB_NAME;' || echo ''"  >> $RESTORE_SCHEMA_SH
      echo "sudo -u postgres psql --dbname=$DB_NAME -f restore_schema_enum.sql"  >> $RESTORE_SCHEMA_SH
      echo "sudo -u postgres psql --dbname=$DB_NAME -f restore_schema.sql"  >> $RESTORE_SCHEMA_SH
      
      
      ENUM_DUMP_SQL="
      SELECT format(
        'CREATE TYPE %s AS ENUM (%s);',
        enumtypid::regtype,
        string_agg(quote_literal(enumlabel), ', ')
      )
      FROM pg_enum
      GROUP BY enumtypid;
      "
      PGPASSWORD=$PGPASSWORD psql $CONNECTION_ARG --tuples-only -c "$ENUM_DUMP_SQL" >> $RESTORE_SCHEMA_ENUM_SQL
      
      for MODEL in src/db/models/*; do
        TABLE=`echo $MODEL | awk '{split($0,a,"."); print a[1]}' | awk '{split($0,a,"/"); print a[4]}'`
        if [ "$TABLE" = "index" ]; then
          continue
        fi
        echo $TABLE
        BACKUP_FILE_FULL="${BACKUP_PATH}/${TABLE}_${DATE_FULL}"
        BACKUP_FILE="${TABLE}_${DATE_FULL}"
        PGPASSWORD=$PGPASSWORD pg_dump $CONNECTION_ARG --table=$TABLE --data-only -Fc -Z5  --file=$BACKUP_FILE_FULL
        PGPASSWORD=$PGPASSWORD pg_dump $CONNECTION_ARG --table=$TABLE --schema-only >> $RESTORE_SCHEMA_SQL
        
        echo "sudo -u postgres pg_restore -Fc --dbname=$DB_NAME --table=$TABLE $BACKUP_FILE" >> $RESTORE_SH
      done
      
      # sequelize internal stuff
      TABLE=SequelizeMeta
      echo $TABLE
      BACKUP_FILE_FULL="${BACKUP_PATH}/${TABLE}_${DATE_FULL}"
      BACKUP_FILE="${BACKUP_PATH}/${TABLE}_${DATE_FULL}"
      # NOTE fix pg_dump
      PGPASSWORD=$PGPASSWORD pg_dump $CONNECTION_ARG --table=\\"SequelizeMeta\\" --data-only -Fc -Z5  --file=$BACKUP_FILE_FULL
      PGPASSWORD=$PGPASSWORD pg_dump $CONNECTION_ARG --table=\\"SequelizeMeta\\" --schema-only >> $RESTORE_SCHEMA_SQL
      echo "sudo -u postgres pg_restore -Fc --dbname=$DB_NAME --table=\\"SequelizeMeta\\" $BACKUP_FILE" >> $RESTORE_SH
      
      
      echo 'echo "ok"' >> $RESTORE_SH
      echo 'echo "ok"' >> $RESTORE_SCHEMA_SH
      
      chmod +x $RESTORE_SH
      chmod +x $RESTORE_SCHEMA_SH
      
      echo "ok"
      
      """#"
    false
  

def "db db_backup", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "db_backup", "db_backup", "def"
  bdh_node_module_name_assign_on_call root, module, "db_backup"
  
  root

