/*  File:    action.pl
    Author:  Roy Ratcliffe
    Created: Feb 26 2022
    Purpose: SWI-Prolog pack installation with test coverage

Copyright (c) 2022, Roy Ratcliffe, United Kingdom

Permission is hereby granted, free of charge,  to any person obtaining a
copy  of  this  software  and    associated   documentation  files  (the
"Software"), to deal in  the   Software  without  restriction, including
without limitation the rights to  use,   copy,  modify,  merge, publish,
distribute, sublicense, and/or sell  copies  of   the  Software,  and to
permit persons to whom the Software is   furnished  to do so, subject to
the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT  WARRANTY OF ANY KIND, EXPRESS
OR  IMPLIED,  INCLUDING  BUT  NOT   LIMITED    TO   THE   WARRANTIES  OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR   PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS  OR   COPYRIGHT  HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY,  WHETHER   IN  AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM,  OUT  OF   OR  IN  CONNECTION  WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

:- use_module(library(aggregate), [aggregate_all/3]).
:- use_module(library(apply), [maplist/3, convlist/3, exclude/3]).
:- use_module(library(filesex), [relative_file_name/3]).
:- use_module(library(lists), [member/2]).
:- use_module(library(option), [option/2]).
:- use_module(library(ordsets),
              [ord_intersect/2, ord_intersection/3, ord_subtract/3]).
:- use_module(library(prolog_pack), [pack_property/2]).
:- use_module(library(prolog_coverage), [show_coverage/1]).
:- use_module(library(url), [parse_url/2]).
:- use_module(library(http/http_client), [http_get/3]).
:- use_module(library(http/json), [atom_json_term/3, json_write_dict/3]).
:- use_module(library(plunit), [load_test_files/1]).
:- use_module(library(settings), [setting/4, setting/2]).

:- ensure_loaded(library(http/http_json)).

:- setting(runner_os, atom, env('RUNNER_OS', ''),
           'GitHub runner operating system').

:- setting(shield_os, atom, env('SHIELD_OS', 'Linux'),
           'Runner OS to use for updating shield Gist').

:- setting(gist_id, atom, env('COVFAIL_GISTID', ''),
           'Covered and failed-in-file Gist identifier').

:- setting(access_token, atom, env('GHAPI_PAT', ''),
           'GitHub API personal access token').

:- initialization(main, main).

main :-
    load_pack(_),
    cover(Covers),
    aggregate_all(
        all(sum(InFile), sum(NotCovered), sum(FailedInFile), count),
        member(_-cover{
                     in_file:InFile,
                     not_covered:NotCovered,
                     failed_in_file:FailedInFile
                 }, Covers),
        all(SumInFile, SumNotCovered, SumFailedInFile, Count)
    ),
    format('Clauses in files:~t~d~40|~n', [SumInFile]),
    format('Clauses not covered:~t~d~40|~n', [SumNotCovered]),
    format('Failed clauses in files:~t~d~40|~n', [SumFailedInFile]),
    format('Number of files:~t~d~40|~n', [Count]),
    forall(member(Rel-Cover, Covers),
           (   json_write_dict(
                   current_output,
                   _{  rel:Rel,
                       cover:Cover
                    }, [width(0)]
               ),
               nl
           )),
    (   SumInFile > 0
    ->  NotCoveredPercent is 100 * SumNotCovered / SumInFile,
        FailedInFilePercent is 100 * SumFailedInFile / SumInFile,
        CoveredPercent is 100 - NotCoveredPercent,
        format('Not covered:~t~f~40|%~n', [NotCoveredPercent]),
        format('Failed in file:~t~f~40|%~n', [FailedInFilePercent]),
        format('Covered:~t~f~40|%~n', [CoveredPercent]),
        shield(CoveredPercent, FailedInFilePercent)
    ;   true
    ),
    !.

shield(Cov, Fail) :-
    setting(runner_os, RunnerOS),
    setting(shield_os, ShieldOS),
    (   RunnerOS == ShieldOS
    ->  shield(Cov, Fail, _)
    ;   true
    ).

shield(Cov, Fail, Reply) :-
    setting(gist_id, GistID),
    GistID \== '',
    !,
    shield_files([cov-Cov, fail-Fail], Files),
    ghapi_update_gist(GistID, json(json([files=Files])), Reply, []).

shield_files(Pairs, json(Files)) :- maplist(shield_file, Pairs, Files).

shield_file(Label-Percent, File=json([content=Content])) :-
    atom_concat(Label, '.json', File),
    format(atom(Message), '~1f%', [Percent]),
    shield_color(Label, Percent, Color),
    atom_json_term(Content, json([ schemaVersion=1,
                                   label=Label,
                                   message=Message,
                                   color=Color
                                 ]), []),
    format('raw/~s~n', [File]).

shield_color(fail, Percent0, Color) =>
    Percent is 100 - Percent0,
    shield_color(Percent, Color).
shield_color(_, Percent, Color) => shield_color(Percent, Color).

shield_color(Percent, red) :- Percent < 20, !.
shield_color(Percent, orange) :- Percent < 40, !.
shield_color(Percent, yellow) :- Percent < 60, !.
shield_color(Percent, yellowgreen) :- Percent < 80, !.
shield_color(_, green).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Catches the succeeded and failed clauses by calling a predicate that
calls the Goal, typically run_tests/0 and friends.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  load_pack(?Pack) is det.
%
%   Loads library source files and their related test sources. Utilises
%   the undocumented library/1 pack property.

load_pack(Pack) :-
    findall(library(File), pack_property(Pack, library(File)), Files),
    load_files(Files, []),
    load_test_files([]).

%!  cover(Covers) is det.
%!  cover(Goal, Dir, Covers) is det.
%!  cover(Goal, Covers) is det.

cover(Covers) :-
    absolute_file_name(pack(.), Dir),
    cover(run_tests, Dir, Covers).

cover(Goal, Dir, Covers) :-
    cover(Goal, Covers0),
    convlist(cover_subdir(Dir), Covers0, Covers).

cover_subdir(Dir, File-Cover, Rel-Cover) :- subdir(Dir, File, Rel).

cover(Goal, Covers) :- coverage(covered(Goal, Covers), []).

covered(Goal, Covers) :-
    call(Goal),
    prolog_coverage:covered(Succeeded, Failed),
    findall(Cover, file_cover(Succeeded, Failed, Cover), Covers).

%!  file_cover(Succeeded, Failed, FileCover:pair(atom, dict)) is nondet.
%!  file_cover(?File, +Succeeded, +Failed, -Cover:dict) is semidet.
%
%   Derived from the prolog_cover:file_coverage/4 private predicate.
%
%   Counts clauses within a File in total but also computes the number
%   of clauses not covered and the number that fail.

file_cover(Succeeded, Failed, File-Cover) :-
    source_file(File),
    file_cover(File, Succeeded, Failed, Cover).

file_cover(File, Succeeded, Failed,
           cover{
               in_file:InFileLength,
               not_covered:NotCoveredLength,
               failed_in_file:FailedInFileLength
           }) :-
    findall(Clause, prolog_coverage:clause_source(Clause, File, _), InFile0),
    sort(InFile0, InFile),
    (   ord_intersect(InFile, Succeeded)
    ->  true
    ;   ord_intersect(InFile, Failed)
    ),
    !,
    ord_intersection(InFile, Succeeded, SucceededInFile),
    ord_intersection(InFile, Failed, FailedInFile),
    ord_subtract(InFile, SucceededInFile, NotCovered0),
    ord_subtract(NotCovered0, FailedInFile, NotCovered),
    clean(InFile, InFileLength),
    clean(NotCovered, NotCoveredLength),
    clean(FailedInFile, FailedInFileLength).

%!  clean(Clauses, Length) is det.
%
%   Cleans the Clauses and counts the number of non-dirty clauses as
%   Length where dirty includes:
%
%       - `user`, `plunit` or `prolog_cover` clauses;
%       - 'unit test' head clauses.
%
%   The latter excludes the test heads that otherwise skew the total
%   number of clauses upwards and therefore incorrectly reduces the
%   coverage percentage.

clean(Clauses, Length) :-
    prolog_coverage:clean_set(Clauses, CleanClauses0),
    exclude(is_dirty, CleanClauses0, CleanClauses),
    length(CleanClauses, Length).

is_dirty(Clause) :-
    clause_property(Clause, predicate(Predicate)),
    dirty_predicate(Predicate).

dirty_predicate(user:_/_) :- !.
dirty_predicate(plunit:_/_) :- !.
dirty_predicate(prolog_coverage:_/_) :- !.
dirty_predicate(_:'unit test'/_).

%!  subdir(+Dir, +File, -Rel) is semidet.
%
%   Only succeeds if File lives beneath Dir in the file system.

subdir(Dir, File, Rel) :-
    relative_file_name(File, Dir, Rel),
    \+ sub_atom(Rel, 0, _, _, (..)).

%!  ghapi_update_gist(+GistID, +Data, -Reply, +Options) is det.
%
%   Updates a Gist by its unique identifier. Data is the patch payload
%   as a JSON object, or dictionary if you include json_object(dict) in
%   Options. Reply is the updated Gist in JSON on success.
%
%   The example below illustrates a Gist update using a JSON term.
%   Notice the doubly-nested `json/1` terms. The first sets up the HTTP
%   request for JSON while the inner term specifies a JSON _object_
%   payload. In this example, the update adds or replaces the `cov.json`
%   file with content of "{}" as serialised JSON. Update requests for
%   Gists have a `files` object with a nested filename-object comprising
%   a content string for the new contents of the file.
%
%       ghapi_update_gist(
%           ec92ac84832950815861d35c2f661953,
%           json(json([ files=json([ 'cov.json'=json([ content='{}'
%                                                    ])
%                                  ])
%                     ])), _, []).
%
%   @see https://docs.github.com/en/rest/reference/gists#update-a-gist

ghapi_update_gist(GistID, Data, Reply, Options) :-
    ghapi_get([gists, GistID], Reply, [method(patch), post(Data)|Options]).

%!  ghapi_get(+PathComponents, +Data, +Options) is det.
%
%   Accesses the GitHub API. Supports JSON terms and dictionaries. For
%   example, the following goal accesses the GitHub Gist API looking for
%   a particular Gist by its identifier and unifies `A` with a JSON term
%   representing the Gist's current contents and state.
%
%       ghapi_get([gists, ec92ac84832950815861d35c2f661953], A, []).
%
%   Supports all HTTP methods despite the predicate name. The "get"
%   mirrors the underlying http_get/3 method which also supports all
%   methods. POST and PATCH send data using the `post/1` option and
%   override the default HTTP verb using the `method/1` option.
%   Similarly here.
%
%   Handles authentication via settings, and from the system environment
%   indirectly. Option `ghapi_access_token/1` overrides both. Order of
%   overriding proceeds as: option, setting, environment, none. Empty
%   atom counts as none.
%
%   Abstracts away the path using path components. Argument
%   PathComponents is an atomic list specifying the URL path.

ghapi_get(PathComponents, Data, Options) :-
    ghapi_get_options(Options_, Options),
    atomic_list_concat([''|PathComponents], /, Path),
    parse_url(URL, [protocol(https), host('api.github.com'), path(Path)]),
    http_get(URL, Data,
             [ request_header('Accept'='application/vnd.github.v3+json')
             | Options_
             ]).

ghapi_get_options([ request_header('Authorization'=Authorization)
                  | Options
                  ], Options) :-
    ghapi_access_token(AccessToken, Options),
    AccessToken \== '',
    !,
    format(atom(Authorization), 'token ~s', [AccessToken]).
ghapi_get_options(Options, Options).

ghapi_access_token(AccessToken, Options) :-
    option(ghapi_access_token(AccessToken), Options),
    !.
ghapi_access_token(AccessToken, _Options) :-
    setting(access_token, AccessToken).
