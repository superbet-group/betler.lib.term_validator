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
    [allow_extra_fields].


% Map structure (missing/unexpected keys) is checked in pre_validate/3.
% Field values are validated in validate/3.
pre_validate(Term, Options, _Validators) when is_map(Term) ->
    % 'fields' is a mandatory option, it's presence has been checked before this function is called
    FieldsList = proplists:get_value(fields, Options),
    % 'allow_extra_fields' is optional, and default is false
    AllowExtra = proplists:get_value(allow_extra_fields, Options, false),

    MandatoryKeysSet = gb_sets:from_list([ Key || {Key, _, mandatory} <- FieldsList ]),
    AllKeysSet = gb_sets:from_list([ Key || {Key, _, _} <- FieldsList ]),
    TermKeysSet = gb_sets:from_list(maps:keys(Term)),

    MissingKeys = gb_sets:to_list(gb_sets:subtract(MandatoryKeysSet, TermKeysSet)),
    UnexpectedKeys = gb_sets:to_list(gb_sets:subtract(TermKeysSet, AllKeysSet)),

    MissingErrorList = get_missing_keys_error(MissingKeys),
    UnexpectedErrorList = get_unexpected_keys_error(AllowExtra, UnexpectedKeys),
    case MissingErrorList ++ UnexpectedErrorList of
        [] ->
            {valid, Term, proplists:delete(allow_extra_fields, Options)};
        [SingleError | _] ->
            {invalid, SingleError}
    end;
pre_validate(_Term, _Options, _Validators) ->
    {invalid, not_map}.


validate(Term, {fields, Fields}, Validators) ->
    % for a more efficient lookup convert list to map
    FieldsMap = maps:from_list([ {Key, Format} || {Key, Format, _MandatoryOpt} <- Fields ]),
    InvalidFields = lists:filtermap(
        fun({Key, Value}) ->
            case maps:find(Key, FieldsMap) of
                error ->  % extra field with allow_extra_fields == true, ignore it here
                    false;
                {ok, Format} ->
                    case term_validator:validate(Value, Format, Validators) of
                        valid ->
                            false;
                        {invalid, Reason} ->
                            {true, {Key, Reason}};
                        InvalidOptions ->
                            {true, {Key, InvalidOptions}}
                    end
            end
        end,
        maps:to_list(Term)
    ),
    case InvalidFields of
        [] ->
            {valid, Term};
        _ ->
            {invalid, {fields, InvalidFields}}
    end.

post_validate(_Term, _Validators) ->
    valid.


%%%-------------------------------------------------------------------
%%% internal functions

get_missing_keys_error([]) ->
    [];
get_missing_keys_error(MissingKeys) ->
    [{missing_fields, MissingKeys}].

get_unexpected_keys_error(false, [_|_] = UnexpectedKeys) ->
    [{unexpected_fields, UnexpectedKeys}];
get_unexpected_keys_error(_, _) ->
    [].
