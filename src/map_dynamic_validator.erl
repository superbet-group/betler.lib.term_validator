%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(map_dynamic_validator).
-moduledoc false.

-behaviour(term_validator).

-export([options/1]).
-export([pre_validate/3]).
-export([validate/3]).
-export([post_validate/2]).

options(mandatory) ->
    [];
options(optional) ->
    [key, value, length, min, max].

pre_validate(Term, Options, _Validators) when is_map(Term) ->
    % We want to invalidate the 'min' and 'max' options when the 'length'
    % option is used (as they are shortcuts for the 'length' option).
    InvalidOptions = length_option_validator:invalid_options(Options),
    case InvalidOptions of
        [] ->
            {valid, Term, Options};
        _ ->
            {invalid_options, InvalidOptions}
    end;
pre_validate(_Term, _Options, _Validators) ->
    {invalid, not_map}.

validate(Term, {key, Format}, Validators) ->
    Result = lists:foldr(fun(Key, Accumulator) ->
        case term_validator:validate(Key, Format, Validators) of
            valid ->
                Accumulator;
            {invalid, Reason} ->
                [{Key, Reason}|Accumulator];
            OtherError ->
                [{Key, OtherError}|Accumulator]
        end
    end, [], maps:keys(Term)),
    case Result of
        [] ->
            {valid, Term};
        _ ->
            {invalid, {keys, Result}}
    end;

validate(Term, {value, Format}, Validators) ->
    Result = maps:fold(fun(Key, Value, Accumulator) ->
        case term_validator:validate(Value, Format, Validators) of
            valid ->
                Accumulator;
            {invalid, Reason} ->
                [{Key, Reason}|Accumulator];
            OtherError ->
                [{Key, OtherError}|Accumulator]
        end
    end, [], Term),
    case Result of
        [] ->
            {valid, Term};
        _ ->
            {invalid, {values, Result}}
    end;
validate(Term, {length, {Minimum, Maximum}}, _Validators) ->
    case length_option_validator:validate_length(erlang:map_size(Term), Minimum, Maximum) of
        valid ->
            {valid, Term};
        {invalid, Reason} ->
            {invalid, {length, Reason}}
    end;
validate(Term, {min, Minimum}, Validators) ->
    % The 'min' option is a shortcut for "{length, {Minimum, no_max}}".
    validate(Term, {length, {Minimum, no_max}}, Validators);
validate(Term, {max, Maximum}, Validators) ->
    % The 'max' option is a shortcut for "{length, {no_min, Maximum}}".
    validate(Term, {length, {no_min, Maximum}}, Validators).

post_validate(_Term, _Validators) ->
    valid.
