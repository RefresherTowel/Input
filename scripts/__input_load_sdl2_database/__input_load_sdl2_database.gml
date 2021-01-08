function __input_load_sdl2_database(_filename)
{
    var _t = get_timer();
    
    __input_trace("Loading SDL2 database from \"", _filename, "\"");
    
    #region Break down the input database into a 2D array
    
    var _cell_delimiter   = ",";
    var _string_delimiter = "\"";
    
    var _buffer = buffer_load(_filename);
    if (_buffer < 0)
    {
        show_message("Could not load external SDL2 database \"" + string(_filename) + "\"\n\nCheck the path and that sandboxing is turned OFF for this project");
        return false;
    }
    
    var _size = buffer_get_size(_buffer) + 1;
    buffer_resize(_buffer, _size);
    
    var _cell_delimiter_ord      = ord(_cell_delimiter);
    var _string_delimiter_double = _string_delimiter + _string_delimiter;
    var _string_delimiter_ord    = ord(_string_delimiter);
    
    var _root_array = [];
    var _row_array  = undefined;
    
    var _newline     = false;
    var _read        = false;
    var _word_start  = 0;
    var _in_string   = false;
    var _string_cell = false;
    
    repeat(_size)
    {
        var _value = buffer_read(_buffer, buffer_u8);
        
        if (_value == _string_delimiter_ord)
        {
            _in_string = !_in_string;
            if (_in_string) _string_cell = true;
        }
        else
        {
            if (_value == 0)
            {
                if (_in_string) _string_cell = true;
                _in_string = false;
                
                var _prev_value = buffer_peek(_buffer, buffer_tell(_buffer)-2, buffer_u8);
                if ((_prev_value != _cell_delimiter_ord) && (_prev_value != 10) && (_prev_value != 13))
                {
                    _read = true;
                }
            }
            
            if (!_in_string)
            {
                if ((_value == 10) || (_value == 13))
                {
                    var _prev_value = buffer_peek(_buffer, buffer_tell(_buffer)-2, buffer_u8);
                    if ((_prev_value != 10) && (_prev_value != 13))
                    {
                        _newline = true;
                        if (_prev_value != _cell_delimiter_ord)
                        {
                            _read = true;
                        }
                        else
                        {
                            ++_word_start;
                        }
                    }
                    else
                    {
                        ++_word_start;
                    }
                }
            
                if (_read || (_value == _cell_delimiter_ord))
                {
                    _read = false;
                
                    var _tell = buffer_tell(_buffer);
                    var _old_value = buffer_peek(_buffer, _tell-1, buffer_u8);
                    buffer_poke(_buffer, _tell-1, buffer_u8, 0x00);
                    buffer_seek(_buffer, buffer_seek_start, _word_start);
                    var _string = buffer_read(_buffer, buffer_string);
                    buffer_poke(_buffer, _tell-1, buffer_u8, _old_value);
                    
                    if (_string_cell)
                    {
                        if ((string_byte_at(_string, 1) == _string_delimiter_ord)
                        &&  (string_byte_at(_string, string_byte_length(_string)) == _string_delimiter_ord))
                        {
                            _string = string_copy(_string, 2, string_length(_string)-2); //Trim off leading/trailing quote marks
                        }
                    }
                    
                    _string = string_replace_all(_string, _string_delimiter_double, _string_delimiter); //Replace double quotes with single quotes
                    
                    if (_row_array == undefined)
                    {
                        _row_array = [];
                        _root_array[@ array_length(_root_array)] = _row_array;
                    }
                    
                    _row_array[@ array_length(_row_array)] = _string;
                
                    _string_cell = false;
                    _word_start = _tell;
                }
            
                if (_newline)
                {
                    _newline = false;
                    _row_array = undefined;
                }
            }
        }
    }
    
    buffer_delete(_buffer);
    
    #endregion
    
    var _db_array             = global.__input_sdl2_database.array;
    var _db_by_vendor_product = global.__input_sdl2_database.by_vendor_product;
    var _db_by_platform       = global.__input_sdl2_database.by_platform
    
    var _y = 0;
    repeat(array_length(_root_array))
    {
        var _row_array = _root_array[_y];
        if (is_array(_row_array))
        {
            //Ignore comments
            if (string_pos("#", _row_array[0]) <= 0)
            {
                //Add this definition to the main database array
                _db_array[@ array_length(_db_array)] = _row_array;
                
                //Figure out this definition's vendor+product name is
                var _result = __input_gamepad_guid_parse(_row_array[0], false);
                var _vendor_product = _result.vendor + _result.product;
                
                //Add this definition to the "by vendor+product" struct
                var _vp_array = variable_struct_get(_db_by_vendor_product, _vendor_product);
                if (!is_array(_vp_array))
                {
                    _vp_array = [];
                    variable_struct_set(_db_by_vendor_product, _vendor_product, _vp_array);
                }
                _vp_array[@ array_length(_vp_array)] = _row_array;
                
                //Find what platform this definition is for
                //We do this backwards for the sake of efficiency
                var _platform = undefined;
                var _x = array_length(_row_array)-1;
                repeat(array_length(_row_array))
                {
                    var _lower = string_lower(_row_array[_x]);
                    if (_lower == "platform:windows" ) { _platform = os_windows; break; }
                    if (_lower == "platform:mac os x") { _platform = os_macosx;  break; }
                    if (_lower == "platform:mac"     ) { _platform = os_macosx;  break; }
                    if (_lower == "platform:macos"   ) { _platform = os_macosx;  break; }
                    if (_lower == "platform:linux"   ) { _platform = os_linux;   break; }
                    if (_lower == "platform:ubuntu"  ) { _platform = os_linux;   break; }
                    if (_lower == "platform:android" ) { _platform = os_android; break; }
                    if (_lower == "platform:ios"     ) { _platform = os_ios;     break; }
                    if (_lower == "platform:tvos"    ) { _platform = os_tvos;    break; }
                    --_x;
                }
                
                //If we found a platform...
                if (_platform != undefined)
                {
                    //Add the OS type to the end of the definition's array
                    _row_array[@ array_length(_row_array)] = _platform;
                    
                    //Add this definition to the "by platform" struct
                    var _os_array = variable_struct_get(_db_by_platform, _platform);
                    if (!is_array(_os_array))
                    {
                        _os_array = [];
                        variable_struct_set(_db_by_platform, _platform, _os_array);
                    }
                    _os_array[@ array_length(_os_array)] = _row_array;
                }
            }
        }
        
        ++_y;
    }
    
    __input_trace(array_length(_db_array), " gamepad definitions found");
    __input_trace("Loaded in ", (get_timer() - _t)/1000, "ms");
    
    return true;
}