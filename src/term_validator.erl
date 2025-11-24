%%
%% Copyright (c) 2024, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.txt file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>, March 2023
%%
-module(term_validator).
-moduledoc """
Term validator API.

It provides the single validate/2 function this library features (along with
a variant to specify a custom set of validators) and a function to retrieve
the built-in validators.
""".

-export_type([validator_name/0]).

-export_type([option_name/0]).
-export_type([option_value/0]).
-export_type([option/0]).

-export_type([options/0]).
-export_type([format/0]).
-export_type([validators/0]).

-export([validate/2, validate/3]).
-export([validators/0]).

-type validator_name() :: atom().

-type option_name() :: atom().
-type option_value() :: term().
-type option() :: {atom(), term()}.

-type options() :: [option()].
-type format() :: validator_name() | {validator_name(), options()}.
-type validators() :: #{
    validator_name() := module()
}.

-callback options(mandatory | optional) -> dynamic | [option_name()].

-callback pre_validate(term(), options(), validators()) ->
    {valid, term(), options()} |
    {invalid, Reason :: term()} |
    {missing_options, [option_name()]} |
    {invalid_options, [option_name()]}
.
-callback validate(term(), option(), validators()) ->
    {valid, term()} |
    {invalid, Reason :: term()} |
    {invalid_option_value, Reason :: term()}
.
-callback post_validate(term(), validators()) ->
    valid |
    {invalid, Reason :: term()}
.

-type validate_ret() ::
    valid |
    {invalid, Reason :: term()} |
    {no_validator, validator_name()} |
    {missing_options, [option_name()]} |
    {invalid_options, [option_name()]} |
    {invalid_option_value, option_name(), Reason :: term()}
.

-doc """
Validate an Erlang term using the built-in validators.

It is equivalent to calling the `validate/3` function with the list of
built-in validators.
""".
-spec validate(term(), format()) -> validate_ret().
validate(Term, Format) ->
    validate(Term, Format, validators()).

-doc """
Validate an Erlang term using the specified validators.

It validates an Erlang term using a specified set of validators.
""".
-spec validate(term(), format(), validators()) -> validate_ret().
validate(Term, Format, Validators) ->
    {Name, Options} = case Format of
        {Name_, Options_} ->
            {Name_, Options_};
        Name_ ->
            {Name_, []}
    end,

    case maps:get(Name, Validators, undefined) of
        undefined ->
            {no_validator, Name};
        Validator ->
            MandatoryOptions = Validator:options(mandatory),
            OptionalOptions = Validator:options(optional),
            case has_dynamic_options(MandatoryOptions, OptionalOptions) of
                yes ->
                    % If the validator has dynamic options, it becomes
                    % responsible for validating the options itself.
                    validate_term(Validator, Term, Options, Validators);
                no ->
                    AllOptions = MandatoryOptions ++ OptionalOptions,
                    case has_missing_options(Options, MandatoryOptions) of
                        {yes, MissingOptions} ->
                            {missing_options, MissingOptions};
                        no ->
                            case has_invalid_options(Options, AllOptions) of
                                {yes, InvalidOptions} ->
                                    {invalid_options, InvalidOptions};
                                no ->
                                    validate_term(Validator, Term, Options, Validators)
                            end
                    end
            end
    end.

-doc """
Return the built-in validators.

It returns a map containing the built-in validators. The keys are the
validator names and the values are the validator modules.
""".
-spec validators() -> validators().
validators() ->
    #{
        any => any_validator,
        atom => atom_validator,
        bool => bool_validator,
        number => number_validator,
        string => string_validator,
        list => list_validator,
        tuple => tuple_validator,
        tuple_dynamic => tuple_dynamic_validator,
        map => map_validator,
        map_dynamic => map_dynamic_validator,
        any_of => any_of_validator,
        all_of => all_of_validator
    }.

-spec has_dynamic_options(options(), options()) -> yes | no.
has_dynamic_options(_MandatoryOptions, dynamic) ->
    yes;
has_dynamic_options(dynamic, _OptionalOptions) ->
    yes;
has_dynamic_options(_MandatoryOptions, _OptionalOptions) ->
    no.

-spec has_missing_options(options(), [option_name()]) ->
    no | {yes, [option_name()]}.
has_missing_options(Options, MandatoryOptions) ->
    Missing = lists:filter(fun(Name) ->
        not proplists:is_defined(Name, Options)
    end, MandatoryOptions),
    case Missing of
        [] -> no;
        _  -> {yes, Missing}
    end.

-spec has_invalid_options(options(), [option_name()]) ->
    no | {yes, [option_name()]}.
has_invalid_options(Options, ValidatorOptions) ->
    % We check validity of options one by one and add them to a list.
    InvalidOptions = lists:foldr(fun(Option, InvalidOptions) ->
        Name = case Option of
            {Name_, _Value} -> Name_;
            Name_ -> Name_
        end,
        case lists:member(Name, ValidatorOptions) of
            true -> InvalidOptions;
            false -> [Name | InvalidOptions]
        end
    end, [], Options),
    case InvalidOptions of
        [] -> no;
        _ -> {yes, InvalidOptions}
    end.

-spec validate_term(any(), term(), options(), validators()) ->
    valid | {invalid | Reason :: term()}.
validate_term(Validator, Term, Options, Validators) ->
    case Validator:pre_validate(Term, Options, Validators) of
        {valid, NextTerm, NextOptions} ->
            case validate_term_with_options(Validator, NextTerm, NextOptions, Validators) of
                {valid, NextNextTerm} ->
                    Validator:post_validate(NextNextTerm, Validators);
                {invalid, Reason} ->
                    {invalid, Reason};
                {invalid_option_value, Option, Reason} ->
                    {invalid_option_value, Option, Reason}
            end;
        {invalid, Reason} ->
            {invalid, Reason};
        {missing_options, MissingOptions} ->
            {missing_options, MissingOptions};
        {invalid_options, InvalidOptions} ->
            {invalid_options, InvalidOptions}
    end.

validate_term_with_options(_Validator, Term, [], _Validators) ->
    {valid, Term};
validate_term_with_options(Validator, Term, [Option|Options], Validators) ->
    case Validator:validate(Term, Option, Validators) of
        {valid, NextTerm} ->
            validate_term_with_options(Validator, NextTerm, Options, Validators);
        {invalid, Reason} ->
            {invalid, Reason};
        {invalid_option_value, Reason} ->
            {invalid_option_value, Option, Reason}
    end.
