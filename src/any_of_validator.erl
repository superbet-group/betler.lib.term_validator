%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(any_of_validator).
-moduledoc false.

-behaviour(term_validator).

-export([options/1]).
-export([pre_validate/3]).
-export([validate/3]).
-export([post_validate/2]).

options(Opts) ->
    composite_validator:options(Opts).

pre_validate(Term, Options, Validators) ->
    composite_validator:pre_validate(Term, Options, Validators).

validate(Term, {formats, Formats}, Validators) ->
    composite_validator:validate(any, Term, Formats, Validators).

post_validate(Term, Validators) ->
    composite_validator:post_validate(Term, Validators).
