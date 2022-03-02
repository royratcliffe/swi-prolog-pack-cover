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

:- autoload(library(aggregate), [aggregate_all/3]).
:- autoload(library(apply), [convlist/3]).
:- autoload(library(filesex), [relative_file_name/3]).
:- autoload(library(lists), [member/2]).
:- autoload(library(ordsets),
            [ord_intersect/2, ord_intersection/3, ord_subtract/3]).
:- autoload(library(prolog_pack), [pack_property/2]).
:- autoload(library(test_cover), [show_coverage/1]).
:- use_module(library(plunit), [load_test_files/1]).

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
    (   SumInFile > 0
    ->  NotCoveredPercent is 100 * SumNotCovered / SumInFile,
        FailedInFilePercent is 100 * SumFailedInFile / SumInFile,
        CoveredPercent is 100 - NotCoveredPercent,
        format('Not covered:~t~f~40|%~n', [NotCoveredPercent]),
        format('Failed in file:~t~f~40|%~n', [FailedInFilePercent]),
        format('Covered:~t~f~40|%~n', [CoveredPercent])
    ;   true
    ).

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

cover(Goal, Covers) :- show_coverage(covered(Goal, Covers)).

covered(Goal, Covers) :-
    call(Goal),
    prolog_cover:covered(Succeeded, Failed),
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
    findall(Clause, prolog_cover:clause_source(Clause, File, _), InFile0),
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

clean(Clauses, Length) :-
    prolog_cover:clean_set(Clauses, CleanClauses),
    length(CleanClauses, Length).

%!  subdir(+Dir, +File, -Rel) is semidet.
%
%   Only succeeds if File lives beneath Dir in the file system.

subdir(Dir, File, Rel) :-
    relative_file_name(File, Dir, Rel),
    \+ sub_atom(Rel, 0, _, _, (..)).
