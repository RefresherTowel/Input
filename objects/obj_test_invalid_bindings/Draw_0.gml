var _string = "";
_string += "gamepad = " + input_player_gamepad_get_type() + "\n\n";

var _array = input_player_gamepad_get_invalid_bindings();
var _i = 0;
repeat(array_length(_array))
{
    _string += string(_array[_i]) + "\n";
    ++_i;
}

draw_text(10, 10, _string);