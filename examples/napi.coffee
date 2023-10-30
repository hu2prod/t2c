project "template", ()->
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  # ###################################################################################################
  #    napi_lib
  # ###################################################################################################
  # napi_lib "randomx", {
    # url   : "https://github.com/ArweaveTeam/RandomX.git"
    # commit: "d64fce8329f85bbafe43ffbfd03284242b13fb1c"
  # }
  
  napi_package "randomx", ()->
    # napi_config_include "../../../src_c_lib/randomx/repo/src"
    # napi_config_lib "'<!(pwd)'/../../../src_c_lib/randomx/build_node16-linux-x64/librandomx.a", "node16-linux-x64"
    
    # napi_config_cflags_cc "-O3"
    # napi_config_cflags_cc "-fexceptions"
    
    # napi_include """
    #   #include "randomx.h"
    #   """#"
    # napi_config_lib "-lgmp"
    
    # napi_init_raw """
      # printf("module is loaded\\n");
      # """
    # napi_file_raw_pre "util.h", """
      # const int ARWEAVE_INPUT_DATA_SIZE = 48;
      # """
    
    # ###################################################################################################
    #    class
    # ###################################################################################################
    # TODO will be replaced with struct, field
    napi_class "Randomx_context", ()->
      napi_class_kt "a", "u32"
      napi_fn "init", ()->
        napi_fn_arg "data_src",     "buf"
        napi_fn_raw_fixed_code """
          _this->a = 2;
          """
    
    # ###################################################################################################
    #    pipeline
    # ###################################################################################################
    napi_pipeline "ml_pipeline", ()->
      policy_set "task_saturation_threshold", 10
      
      napi_class "ml_pipeline_task", ()->
        napi_class_kt "some",     "buf"
        napi_class_field_raw """
          FILE*  fd;
          """
      # napi_class "ml_pipeline_thread", ()->
      # napi_class "ml_pipeline_node", ()->
      
      napi_pipeline_fn "io", ()->
        # thread
        # node
        napi_fn_raw_fixed_code """
          bool res = false;
          while (i_ring->can_pull()) {
            if (!o_ring->get_free_nonbackpressure_push_size()) {
              return res;
            }
            Ml_pipeline_task* task = i_ring->pull();
            
            // TODO
            
            o_ring->push(task);
            res = true;
          }
          """#"