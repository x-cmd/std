
function exec_help(){
    print "___x_cmd_param_int _x_cmd_help ;"
    if (exit_code == "")    exit_code = 0
    print "return " exit_code
    exit_now(1) # TODO: should I return 0?
}

BEGIN {
    HAS_SPE_ARG = false
    _X_CMD_PARAM_ARG_ = "_X_CMD_PARAM_ARG_"
}

NR==4 {
    if( arg_arr[1] == "_dryrun" ){
        DRYRUN_FLAG = true
        IS_INTERACTIVE = false
        arr_shift( arg_arr, 1 )
        handle_arguments()
        print "return 0"
        exit_now(0)
    }

    if ( arg_arr[1] == "help" )             if (! subcmd_exist_by_id( subcmd_id_by_name("help") ))      exec_help()
    if ( arg_arr[1] ~ /^(--help|-h)$/ )     if (! option_exist_by_alias( arg_arr[ 1 ] ))                exec_help()
}

# Section: Defaults As Map
NR>=5 {
    # Setting default values
    if (keyline == "") {
        line_arr_len = split($0, line_arr, ARG_SEP)
        objectname = line_arr[1]
        keyline = line_arr[2]
    } else {
        if (objectname == OBJECT_NAME)  option_default_map[keyline] = $0
        keyline = ""
    }
}
# EndSection

# Section: handle_arguments
function arg_typecheck_then_generate_code( option_id, optarg_id, arg_var_name, _arg_val,          _ret ){
    _ret = assert( optarg_id, arg_var_name, _arg_val )
    if ( _ret == true )                     code_append_assignment( arg_var_name, _arg_val )
    else if ( ! is_interactive() )          panic_error( _ret )
    else                                    code_query_append_by_optionid_optargid( arg_var_name, option_id, optarg_id )
}

function handle_arguments_restargv_typecheck( use_ui_form, i, argval, is_dsl_default,           _tmp, _option_id, _optarg_id){
    _option_id = option_get_id_by_alias( "#" i )
    _optarg_id = _option_id S 1

    if (argval != "") {
        _ret = assert(_optarg_id, "$" i, argval)
        if (_ret == true)                       return true
        else if (false == use_ui_form) {
            if (is_dsl_default == true)         panic_param_define_error(_ret)
            else                                panic_error( _ret )
        } else {
            code_query_append_by_optionid_optargid( _X_CMD_PARAM_ARG_ i, _option_id, _optarg_id )
            return false
        }
    }

    if (option_arr[ "#n" ] == "")     return true               # nth_rule

    _ret = assert(_optarg_id, "$" i, argval)
    if (_ret == true)                           return true
    else if (false == use_ui_form) {
        if (is_dsl_default == true)             panic_param_define_error(_ret)
        else                                    panic_error( _ret )
    } else {
        code_query_append_by_optionid_optargid( _X_CMD_PARAM_ARG_ i, _option_id, _optarg_id )
        return false
    }
}

function handle_arguments_restargv___( i, _set_arg_namelist,             _arg_val, _option_id, _named_value, _tmp ) {

    _set_arg_namelist[ i ] = i  # TODO: For future optimization.
    if ( i <= arg_arr[ L ]) {
        _arg_val = arg_arr[ i ]
        # To set the input value and continue
        if ( true != handle_arguments_restargv_typecheck( is_interactive(), i, _arg_val, false ) ) {    # Fail the type check
            _set_arg_namelist[ i ] = _X_CMD_PARAM_ARG_ i
        }

        _option_id = option_get_id_by_alias( "#" i )

        _tmp = option_name_get_without_hyphen( _option_id ); if (_tmp == "") _tmp = _X_CMD_PARAM_ARG_ i
        code_append_assignment( _tmp, _arg_val )
        _set_arg_namelist[ i ] = _tmp;
    } else {
        _option_id = option_get_id_by_alias( "#" i )
        _named_value = rest_arg_named_value[ _option_id ]

        # TODO: Using something better, like OPTARG_DEFAULT_REQUIRED_VALUE
        if (_named_value != "") {
            _tmp = option_name_get_without_hyphen( _option_id )
            _set_arg_namelist[ i ] = _tmp;
            return                # Already check
        }

        _arg_val = optarg_default_get( _option_id )
        if ( optarg_default_value_eq_require(_arg_val) ) {
            # Don't define a default value
            # TODO: Why can't exit here???
            if (! is_interactive())   return panic_required_value_error( _option_id )

            _tmp = option_name_get_without_hyphen( _option_id ); if (_tmp == "") _tmp = _X_CMD_PARAM_ARG_ i
            code_query_append_by_optionid_optargid( _tmp, _option_id, optarg_id )
            _set_arg_namelist[ i ] = _tmp
        } else {
            # Already defined a default value
            # TODO: Tell the user, it is wrong because of default definition in DSL, not the input.
            handle_arguments_restargv_typecheck( false, i, _arg_val, true )
            _tmp = option_name_get_without_hyphen( _option_id ); if (_tmp == "") _tmp = _X_CMD_PARAM_ARG_ i
            code_append_assignment( _tmp, _arg_val )
            _set_arg_namelist[ i ] = _tmp
        }
    }
}

function handle_arguments_restargv(         _final_rest_argv_len, _set_arg_namelist, i ){

    _final_rest_argv_len = final_rest_argv[ L ]

    for ( i=1; i<=_final_rest_argv_len; ++i ) {
        handle_arguments_restargv___( i, _set_arg_namelist )
    }

    # TODO: You should set the default value, if you have no .
    if (QUERY_CODE != ""){
        QUERY_CODE = "local ___X_CMD_UI_FORM_EXIT_STRATEGY=\"execute|exit\"; x ui form " substr(QUERY_CODE, 9)
        QUERY_CODE = QUERY_CODE ";\nif [ \"$___X_CMD_UI_FORM_EXIT\" = \"exit\" ]; then return 1; fi;"
        code_append(QUERY_CODE)
    }

    if (_final_rest_argv_len >= 1) {
        code_append( "set -- " str_joinwrap( " ", "\"$", "\"", _set_arg_namelist, "", 1, _final_rest_argv_len  ) )
    }
}

function handle_arguments___(   i, j, _arg_name, _arg_name_short, _arg_val, _option_id, _option_name, _option_argc, _arg_arr_len ){
    _arg_arr_len = arg_arr[ L ]
    arr_clone(arg_arr, tmp_arr)
    i = 1; while (i <= _arg_arr_len) {
        _arg_name = arg_arr[ i ]
        # ? Notice: EXIT: Consider unhandled arguments are rest_argv
        if ( _arg_name == "--" )  break
        if ( ( _arg_name == "--help") || ( _arg_name == "-h") )   exec_help()

        _option_id = option_get_id_by_alias( _arg_name )
        if ( _option_id == ""  ) {
            if (_arg_name ~ /^-[^-]/) {
                _arg_name = substr(_arg_name, 2)
                arg_len = split(_arg_name, arg_arr, //)
                for (j=1; j<=arg_len; ++j) {
                    _arg_name_short  = "-" arg_arr[ j ]
                    _option_id       = option_get_id_by_alias( _arg_name_short )
                    _option_name     = option_name_get_without_hyphen( _option_id )

                    # TODO: consider this start rest argument list.
                    if (_option_name == "") {
                        HAS_SPE_ARG = true
                        break
                    }
                    code_append_assignment( _option_name, "true" )
                }
                continue
            } else if( _arg_name ~ /^--?/ ) {
                break
            }
        }
        if( HAS_SPE_ARG == true )        arr_clone(tmp_arr, arg_arr)

        option_arr_assigned[ _option_id ] = true

        _option_argc     = option_argc_get( _option_id )
        _option_name     = option_name_get_without_hyphen( _option_id )

        # If _option_argc == 0, op
        if ( option_multarg_is_enable( _option_id ) )   _option_name = _option_name "_" option_assign_count_inc( _option_id )

        # EXIT: Consider unhandled arguments are rest_argv
        if ( !( _arg_name ~ /^--?/ ) )      break

        if (_option_argc == 0)              code_append_assignment( _option_name, "true" )      # print code XXX=true
        else if (_option_argc == 1) {
            _arg_val = arg_arr[ ++i ]

            if ( _option_id ~ "^#" )        rest_arg_named_value[ _option_id ] = _arg_val       # NAMED REST_ARGUMENT
            if (i > _arg_arr_len)           panic_required_value_error(_option_id)

            arg_typecheck_then_generate_code(       _option_id, _option_id S 1,     _option_name,            _arg_val )
        } else {
            for ( j=1; j<=_option_argc; ++j ) {
                _arg_val = arg_arr[ ++i ]
                if (i > _arg_arr_len)    panic_required_value_error(_option_id)

                arg_typecheck_then_generate_code(   _option_id, _option_id S j,     _option_name "_" j,      _arg_val )
            }
        }
        i += 1
    }
    return i
}

function handle_arguments(          i, _arg_arr_len, _subcmd_id, _tmp ) {
    i = handle_arguments___()

    check_required_option_ready()

    # if subcommand declaration exists
    if ( HAS_SUBCMD == true ) {
        _subcmd_id = subcmd_id_by_name( arg_arr[i] )
        if (! subcmd_exist_by_id( _subcmd_id ) ) {
            HAS_SUBCMD = false  # No subcommand found
        } else {
            split( _subcmd_id , _tmp, "|" )
            code_append_assignment( "PARAM_SUBCMD", _tmp[1] )
            code_append( "shift " i )
            return
            # i += 1
        }
    }

    code_append( "shift " (i-1) )

    _arg_arr_len = arg_arr[ L ]
    if (final_rest_argv[ L ] < _arg_arr_len - (i - 1)) {
        final_rest_argv[ L ] = _arg_arr_len - (i - 1)
    }

    #Remove the processed arg_arr and move the arg_arr back forward
    arr_shift( arg_arr, (i-1) )

    handle_arguments_restargv()
}

END{
    # if (EXIT_CODE == "000") code_print()    # TODO: Why?
    if (EXIT_CODE == 0) {
        handle_arguments()
        # debug( CODE )
        code_print()
    }
}
# EndSection
