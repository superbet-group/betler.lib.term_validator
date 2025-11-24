%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(map_validator).
-moduledoc false.

-behaviour(term_validator).

-export([options/1]).
-export([pre_validate/3]).
-export([validate/3]).
-export([post_validate/2]).

options(mandatory) ->
    [fields];
options(optional) ->
    [].

pre_validate(Term, Options, _Validators) when is_map(Term) ->
    {valid, Term, Options};
pre_validate(_Term, _Options, _Validators) ->
    {invalid, not_map}.

validate(Term, {fields, Fields}, Validators) when is_list(Fields) ->
    % We first compute the missing fields by iterating over the declared
    % mandatory fields and check if they are all present in the Erlang map.
    % Then we compute the invalid and extra fields by iterating over the fields
    % of the Erlang map.
    MissingFields = lists:foldr(
        fun
            ({Key, _Format, mandatory}, Accumulator) ->
                case maps:is_key(Key, Term) of
                    true ->
                        Accumulator;
                    false ->
                        [Key|Accumulator]
                end;
            ({_Key, _Format, optional}, Accumulator) ->
                Accumulator
        end,
        [],
        Fields
    ),
    case MissingFields of
        [] ->
            {UnexpectedFields, InvalidFields} = maps:fold(
                fun(Key, Value, {UnexpectedFields, InvalidFields} = Accumulator) ->
                    case proplists:lookup(Key, Fields) of
                        none ->
                            {[Key|UnexpectedFields], InvalidFields};
                        {Key, Format, _} ->
                            case term_validator:validate(Value, Format, Validators) of
                                valid ->
                                    Accumulator;
                                {invalid, Reason} ->
                                    {UnexpectedFields, [{Key, Reason}|InvalidFields]};
                                OtherError ->
                                    {UnexpectedFields, [{Key, OtherError}|InvalidFields]}
                            end
                    end
                end,
                {[], []},
                Term
            ),
            case UnexpectedFields of
                [] ->
                    case InvalidFields of
                        [] ->
                            {valid, Term};
                        _ ->
                            {invalid, {fields, InvalidFields}}
                    end;
                _ ->
                    {invalid, {unexpected_fields, UnexpectedFields}}
            end;
        _ ->
            {invalid, {missing_fields, MissingFields}}
    end;
validate(_Term, {fields, _Fields}, _Validators) ->
    {invalid_option_value, not_list}.

post_validate(_Term, _Validators) ->
    valid.
