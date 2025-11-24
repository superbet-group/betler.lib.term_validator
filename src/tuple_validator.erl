%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, July 2023
%%
-module(tuple_validator).
-moduledoc false.

-behaviour(term_validator).

-export([options/1]).
-export([pre_validate/3]).
-export([validate/3]).
-export([post_validate/2]).

options(mandatory) ->
    [elements];
options(optional) ->
    [].

pre_validate(Term, Options, _Validators) when is_tuple(Term) ->
    {valid, Term, Options};
pre_validate(_Term, _Options, _Validators) ->
    {invalid, not_tuple}.

validate(Term, {elements, Elements}, _Validators) when tuple_size(Term) > length(Elements) ->
    {invalid, too_many_elements};
validate(Term, {elements, Elements}, _Validators) when tuple_size(Term) < length(Elements) ->
    {invalid, too_few_elements};
validate(Term, {elements, Elements}, Validators) ->
    Result = lists:foldr(
        fun({Format, Index}, Accumulator) ->
            Element = element(Index, Term),
            case term_validator:validate(Element, Format, Validators) of
                valid ->
                    Accumulator;
                {invalid, Reason} ->
                    [{Index, Reason}|Accumulator];
                OtherError ->
                    [{Index, OtherError}|Accumulator]
            end
        end,
        [],
        lists:zip(Elements, lists:seq(1, length(Elements)))
    ),
    case Result of
        [] ->
            {valid, Term};
        _ ->
            {invalid, {elements, Result}}
    end.

post_validate(_Term, _Validators) ->
    valid.
