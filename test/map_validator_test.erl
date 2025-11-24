%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(map_validator_test).
-include_lib("eunit/include/eunit.hrl").

map_validator_test() ->
    valid = term_validator:validate(#{}, {map, [{fields, []}]}),
    {missing_options, [fields]} = term_validator:validate(#{}, {map, []}),

    Format = {map, [{fields, []}]},
    {invalid, not_map} = term_validator:validate(yolo, Format),
    {invalid, not_map} = term_validator:validate(42, Format),
    {invalid, not_map} = term_validator:validate("Hello world!", Format),
    {invalid, not_map} = term_validator:validate([], Format),
    {invalid, not_map} = term_validator:validate([{}], Format),
    valid = term_validator:validate(#{}, Format),

    ok.

map_validator_fields_test() ->
    Format = {map, [{fields, [
        {foo, bool, mandatory},
        {"bar", number, optional}
    ]}]},
    valid = term_validator:validate(#{
        foo => false,
        "bar" => 42
    }, Format),

    % Test mandatory fields.
    {invalid, {missing_fields, [foo]}} = term_validator:validate(#{
        "bar" => 42
    }, Format),
    {invalid, {missing_fields, [foo]}} = term_validator:validate(#{
        "foo" => true
    }, Format),
    {invalid, {fields, [{foo, not_bool}]}} = term_validator:validate(#{
        foo => 42,
        "bar" => 42
    }, Format),

    % Test optional fields.
    valid = term_validator:validate(#{
        foo => false
    }, Format),
    {invalid, {fields, [{"bar", not_number}]}} = term_validator:validate(#{
        foo => false,
        "bar" => true
    }, Format),

    % Test non-declared fields.
    {invalid, {unexpected_fields, [quz]}} = term_validator:validate(#{
        foo => false,
        "bar" => 42,
        quz => "Hello world!"
    }, Format),

    % Test lazy validation.
    {invalid, {fields, Fields}} = term_validator:validate(#{
        foo => 42,
        "bar" => false
    }, Format),
    true = lists:member({foo, not_bool}, Fields),
    true = lists:member({"bar", not_number}, Fields),

    ok.

map_validator_options_test() ->
    UnknownValidatorFormat = {map, [{fields, [
        {foo, unknown_validator, mandatory}
    ]}]},
    {invalid, {fields, [{foo,{no_validator,unknown_validator}}]}} = term_validator:validate(#{
        foo => true
    }, UnknownValidatorFormat),

    MissingOptionFormat = {map, []},
    {missing_options, [fields]} = term_validator:validate(#{}, MissingOptionFormat),

    InvalidOptionsFormat = {map, [{fields, []}, {unknown_option, true}]},
    {invalid_options, [unknown_option]} = term_validator:validate(#{}, InvalidOptionsFormat),

    InvalidOptionValue = {map, [{fields, atom}]},
    {invalid_option_value,{fields,atom},not_list} = term_validator:validate(#{}, InvalidOptionValue),

    ok.
