
# Except getting option argument count
function aobj_cal_rest_argc_maxmin( obj, obj_prefix,       i, j, k, l, _min, _max, _arr, _arrl ){
    _min = 0
    _max = 0
    l = obj[ obj_prefix L ]
    for (i=1; i<=l; ++i) {
        k = juq(obj[ obj_prefix, i ])

        if (k ~ "^#n") {
            _max = 10000 # Big Number
            continue
        }

        if (k ~ "^#[a-z]") continue

        _arrl = split(k, _arr, "|")
        for (j=1; j<=_arrl; ++j) NAME_ID[ obj_prefix, _arr[j] ] = jqu(k)

        if (k ~ "^#[0-9]+") {
            k = int( substr(k, 2) )
            if (aobj_required( obj, obj_prefix SUBSEP obj[ obj_prefix, i ] ) ) {
                if (_min < k) _min = k
            }
            if (_max < k) _max = k
        }
    }
    obj[ obj_prefix, L "restargc__min" ] = _min
    obj[ obj_prefix, L "restargc__max" ] = _max
}

function aobj_option_all_set( lenv_table, obj, obj_prefix,  i, l, k ){
    l = obj[ obj_prefix L ]
    for (i=1; i<=l; ++i) {
        k = obj[ obj_prefix, i ]
        if (k ~ "^\"[^-]") continue
        if ( aobj_istrue(obj, obj_prefix SUBSEP k SUBSEP "\"#subcmd\"" ) ) continue

        if ( aobj_required(obj, obj_prefix SUBSEP k) ) {
            if ( lenv_table[ k ] == "" )  return false
        }
    }
    return true
}

function aobj_get_subcmdid_by_name( obj, obj_prefix, name, _res ){
    _res = aobj_get_id_by_name( obj, obj_prefix, name )
    if ( juq(_res) ~ /^[^-]/) return _res
    if ( aobj_istrue(obj, obj_prefix SUBSEP _res SUBSEP "#subcmd" ) ) return _res
    return
}

function aobj_get_id_by_name( obj, obj_prefix, name, _res ){
    if ("" != (_res = NAME_ID[ obj_prefix, name ]) )  return _res
    aobj_cal_rest_argc_maxmin( obj, obj_prefix )
    return NAME_ID[ obj_prefix, name ]
}

function aobj_required( obj, kp ){
    return (obj[ kp, "\"#r\"" ] == "true" )
}

function aobj_istrue( obj, kp ){
    return (obj[ kp ] == "true" )
}

function aobj_get_optargc( obj, obj_prefix, option_id,  _res, i ){
    obj_prefix = obj_prefix SUBSEP option_id
    if ( "" != (_res = obj[ obj_prefix L "argc" ]) ) return _res
    for (i=1; i<100; ++i) {     # 100 means MAXINT
        if (obj[ obj_prefix, jqu("#" i) ] == "") break
    }
    if (i != 1 ) return obj[ obj_prefix, option_id L "argc" ] = --i
    else {
        if ( obj[ obj_prefix ] == "[") return obj[ obj_prefix L "argc" ] = ( obj[ obj_prefix, option_id L ] != 0 )
        l = obj[ obj_prefix L]
        for (i=1; i<=l; ++i) {
            v = obj[ obj_prefix, i ]
            if ((v ~ "^\"#exec") || (v ~ "^\"#cand") || v ~ "^\"#regex") return obj[ obj_prefix L "argc" ] = 1
            if (v ~ "^\"#") continue
            return obj[ obj_prefix L "argc" ] = 1
        }
    }
    return 0
}

function aobj_get_minimum_rest_argc( obj, obj_prefix, rest_arg_id,  _res ){
    if ( ( _res = obj[ obj_prefix, L "restargc__min" ] ) != "" ) return _res

    aobj_cal_rest_argc_maxmin( obj, obj_prefix, rest_arg_id )
    return obj[ obj_prefix, L "restargc__min" ]
}

function aobj_get_maximum_rest_argc( obj, obj_prefix, rest_arg_id, _res ){
    if ( ( _res = obj[ obj_prefix, L "restargc__max" ] ) != "" ) return _res

    aobj_cal_rest_argc_maxmin( obj, obj_prefix, rest_arg_id )
    return obj[ obj_prefix, L "restargc__max" ]
}


