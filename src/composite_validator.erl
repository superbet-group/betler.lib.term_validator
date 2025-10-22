-module(composite_validator).
-moduledoc false.

-export([options/1]).
-export([pre_validate/3]).
-export([validate/4]).
-export([post_validate/2]).

options(_) ->
    dynamic.

pre_validate(Term, [{formats, Formats}] = Options, Validators) ->
    % We want to check if there is a validator for each format. Note that
    % instead of being reported as an invalid option value, it's reported as
    % invalid options.
    MissingValidators = lists:foldr(
        fun
            F({Name, _Value}, Accumulator) ->
                F(Name, Accumulator);
            F(Name, Accumulator) ->
                case maps:is_key(Name, Validators) of
                    true ->
                        Accumulator;
                    false ->
                        [Name|Accumulator]
                end
        end,
        [],
        Formats
    ),
    case MissingValidators of
        [] ->
            {valid, Term, Options};
        _ ->
            {invalid_options, MissingValidators}
    end;
pre_validate(Term, Options, Validators) ->
    % To allow a nicer syntax, the options are actually the list of formats
    % instead. We transform the list of formats into the 'formats' option and
    % do the actual validation when processing the 'formats' option.
    pre_validate(Term, [{formats, Options}], Validators).

validate(all, Term, Formats, Validators) ->
    first_invalid(Term, Formats, Validators);
validate(any, Term, Formats, Validators) ->
    Result = lists:any(fun(Format) ->
        term_validator:validate(Term, Format, Validators) == valid
    end, Formats),
    case Result of
        true ->
            {valid, Term};
        false ->
            {invalid, {not_any_of, Formats}}
    end.

post_validate(_Term, _Validators) ->
    valid.


% Used in all_of validator: we want to have the first invalid reason
% so we don't have to guess which of the validators failed.
first_invalid(Term, [Format | RestFormats], Validators) ->
    case term_validator:validate(Term, Format, Validators) of
        valid ->
            first_invalid(Term, RestFormats, Validators);
        {invalid, Reason} ->
            {invalid, Reason}
    end;
first_invalid(Term, [], _Validators) ->
    {valid, Term}.