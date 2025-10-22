%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(all_of_validator_test).
-include_lib("eunit/include/eunit.hrl").

all_of_validator_test() ->
    AllFormats = [
        {number, [{min, 42}]},
        {number, [{max, 42}]}
    ],
    Format = {all_of, AllFormats},

    {invalid, not_number} = term_validator:validate(yolo, Format),

    {invalid, not_number} = term_validator:validate(true, Format),
    {invalid, not_number} = term_validator:validate(false, Format),
    {invalid, {must_be_greater_or_equal_to,42}} = term_validator:validate(41, Format),
    valid = term_validator:validate(42, Format),
    {invalid, {must_be_lower_or_equal_to,42}} = term_validator:validate(42.5, Format),
    {invalid, {must_be_lower_or_equal_to,42}} = term_validator:validate(43, Format),
    {invalid, not_number} = term_validator:validate("Hello world!", Format),
    {invalid, not_number} = term_validator:validate("Hi world!", Format),
    {invalid, not_number} = term_validator:validate([], Format),
    {invalid, not_number} = term_validator:validate({}, Format),
    {invalid, not_number} = term_validator:validate(#{}, Format),

    InvalidFormat = {all_of, [xyz, {abc, []}]},
    {invalid_options, [xyz, abc]} = term_validator:validate(yolo, InvalidFormat),

    ok.
