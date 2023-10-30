module = @
fs = require "fs"
{execSync} = require "child_process"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# TODO file_render_exec_ne?

# ###################################################################################################
#    deploy_hetzner
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner",
  emit_codegen  : (root, ctx)->
    ctx.file_render_ne "deploy/PROD_HOST", "change_me"
    ctx.file_render_exec "deploy/ssh.sh", """
      #!/bin/bash
      ssh `cat deploy/PROD_HOST`
      """#"
    ctx.file_render_exec_ne "deploy/scp/basic_software.sh", ctx.tpl_read "deploy_hetzner/basic_software.sh"
    
    ctx.file_render_exec "deploy/1_basic_software.sh", """
      #!/bin/bash
      PROD_HOST=`cat deploy/PROD_HOST`
      rsync -aPx -z --compress-level=9 ./deploy/scp/basic_software.sh $PROD_HOST:/data/
      ssh $PROD_HOST "cd /data && ./basic_software.sh"
      
      """#"
    
    false

def "deploy_hetzner", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner", "deploy_hetzner", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    deploy_hetzner_nodejs
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner_nodejs",
  emit_codegen  : (root, ctx)->
    p "TODO deploy_hetzner_nodejs pnpm detect"
    ctx.file_render_exec "deploy/1_nodejs.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      ssh $PROD_HOST "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash"
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && nvm i 16 && npm i -g iced-coffee-script pnpm"
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && npm completion >> ~/.bashrc" 
      
      """#"
    
    false

def "deploy_hetzner deploy_hetzner_nodejs", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner_nodejs", "deploy_hetzner_nodejs", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner_nodejs"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root


# ###################################################################################################
#    deploy_hetzner_db_postgres
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner_db_postgres",
  emit_codegen  : (root, ctx)->
    if !fs.existsSync "deploy/DB_PASS" # protection execSync
      ctx.file_render "deploy/DB_PASS", execSync("openssl rand -base64 20 | sed 's/[=+\/]//g'").toString().trim()
    
    ctx.file_render_exec "deploy/1_postgres.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      DB_PASS=`cat deploy/DB_PASS`
      ssh $PROD_HOST apt-get install -y postgresql postgresql-contrib
      ssh $PROD_HOST "sudo -u postgres psql -c \\"ALTER USER postgres WITH PASSWORD '$DB_PASS';\\""
      
      """#"
    
    ctx.file_render_exec "deploy/12_db_create.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && cd /data && npm run db:create"
      
      """#"
    
    ctx.file_render_exec "deploy/13_db_migrate.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && cd /data && npm run db:migrate"
      
      """#"
    
    false

def "deploy_hetzner deploy_hetzner_db_postgres", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner_db_postgres", "deploy_hetzner_db_postgres", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner_db_postgres"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    deploy_hetzner_proxy
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner_proxy",
  nodegen  : (root, ctx)->
    starter_tmux_set "deploy_hetzner_proxy", "prod", """
      cd /data/proxy
      npm start
      """
    false
  
  emit_codegen  : (root, ctx)->
    # TODO policy
    p "TODO deploy_hetzner_proxy policy"
    ctx.file_render_ne "deploy/scp/proxy/EMAIL",  "virdvip@gmail.com"
    ctx.file_render_ne "deploy/scp/proxy/DOMAIN", "vird.name"
    
    p "TODO deploy_hetzner_proxy .env DOMAIN policy"
    service_port_offset = root.policy_get_val_use "service_port_offset"
    ctx.file_render_ne "deploy/scp/proxy/.env",   """
      HTTP_BYPASS=http://localhost:#{10000+service_port_offset}
      WS_BYPASS=http://localhost:#{21000+service_port_offset}
      DOMAIN=vird.name
      # if no https (-header content-security-policy)
      # DEV=1
      """
    
    file_list = """
cert.sh
loop.sh
static/__keep
src/prod_proxy.coffee
src/config.coffee
package.json
package-lock.json
""".split "\n"
    
    for file in file_list
      ctx.file_render_exec "deploy/scp/proxy/#{file}", ctx.tpl_read "deploy_hetzner/proxy/#{file}"
    
    ctx.file_render_exec "deploy/2_rsync_proxy.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      rsync -aPx -z --compress-level=9 ./deploy/scp/proxy/*.* $PROD_HOST:/data/proxy/
      
      """#"
    
    ctx.file_render_exec "deploy/4_npm_proxy.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && cd /data/proxy && npm ci"
      
      """#"
    
    false

def "deploy_hetzner deploy_hetzner_proxy", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner_proxy", "deploy_hetzner_proxy", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner_proxy"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    deploy_hetzner_frontend
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner_frontend",
  emit_codegen  : (root, ctx)->
    ctx.file_render_exec_ne "deploy/10_rsync_frontend.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      rsync -aPx -z --compress-level=9 ./htdocs/* $PROD_HOST:/data/htdocs/
      
      """
    
    false

def "deploy_hetzner deploy_hetzner_frontend", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner_frontend", "deploy_hetzner_frontend", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner_frontend"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    deploy_hetzner_backend
# ###################################################################################################
bdh_module_name_root module, "deploy_hetzner_backend",
  emit_codegen  : (root, ctx)->
    p "TODO deploy_hetzner_backend pnpm detect"
    p "TODO deploy_hetzner_backend missing .env.prod (manual)"
    
    ctx.file_render_exec_ne "deploy/10_rsync_backend.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      rsync -aPx -z --compress-level=9 ./src/*     $PROD_HOST:/data/src/
      rsync -aPx -z --compress-level=9 ./*.sh      $PROD_HOST:/data/
      rsync -aPx -z --compress-level=9 ./*.json    $PROD_HOST:/data/
      rsync -aPx -z --compress-level=9 ./.sequelizerc $PROD_HOST:/data/
      rsync -aPx -z --compress-level=9 ./.env.prod $PROD_HOST:/data/.env
      rsync -aPx -z --compress-level=9 ./starter/* $PROD_HOST:/data/starter/
      
      """
    
    ctx.file_render_exec "deploy/11_npm.sh", """
      #!/bin/bash
      set -e
      PROD_HOST=`cat deploy/PROD_HOST`
      ssh $PROD_HOST "source ~/.nvm/nvm.sh && cd /data && pnpm i"
      
      """#"
    
    false

def "deploy_hetzner deploy_hetzner_backend", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "deploy_hetzner_backend", "deploy_hetzner_backend", "def"
  bdh_node_module_name_assign_on_call root, module, "deploy_hetzner_backend"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
