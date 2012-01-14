r"""
Format Sage documentation for viewing with IPython and the notebook

AUTHORS:

- William Stein (2005): initial version.
- Nick Alexander (2007): nodetex functions
- Nick Alexander (2008): search_src, search_def improvements
- Martin Albrecht (2008-03-21): parse LaTeX description environments in sagedoc
- John Palmieri (2009-04-11): fix for #5754 plus doctests
- Dan Drake (2009-05-21): refactor search_* functions, use system 'find' instead of sage -grep
- John Palmieri (2009-06-28): don't use 'find' -- use Python (os.walk, re.search) instead.
- Simon King (2011-09): Use os.linesep, avoid destruction of embedding information,
  enable nodetex in a docstring. Consequently use sage_getdoc.

TESTS:

Check that argspecs of extension function/methods appear correctly,
see :trac:`12849`::

    sage: docfilename = os.path.join(SAGE_ROOT, 'devel', 'sage', 'doc', 'output', 'html', 'en', 'reference', 'sage', 'symbolic', 'expression.html')
    sage: for line in open(docfilename):
    ...       if "#sage.symbolic.expression.Expression.N" in line:
    ...           print line
    <tt class="descname">N</tt><big>(</big><em>prec=None</em>, <em>digits=None</em><big>)</big>...
"""
#*****************************************************************************
#       Copyright (C) 2005 William Stein <wstein@gmail.com>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

import os, re, sys
import pydoc
from sage.misc.viewer import browser
from sage.misc.misc import SAGE_DOC, tmp_dir
from sagenb.misc.sphinxify import sphinxify
import sage.version

# two kinds of substitutions: math, which should only be done on the
# command line -- in the notebook, these should instead by taken care
# of by MathJax -- and nonmath, which should be done always.
math_substitutes = [ # don't forget leading backslash '\\'
    ('\\to', '-->'),
    ('\\leq', '<='),
    ('\\geq', '>='),
    ('\\le', '<='),
    ('\\ge', '>='),
    ('\\cdots', '...'),
    ('\\ldots', '...'),
    ('\\dots', '...'),
    ('\\cdot', ' *'),
    (' \\times', ' x'),
    ('\\times', ' x'),
    ('\\backslash','\\'),
    ('\\mapsto', ' |--> '),
]
nonmath_substitutes = [
    ('\\_','_'),
    ('\\item', '* '),
    ('<BLANKLINE>',''),
    ('\\bf', ''),
    ('\\sage', 'Sage'),
    ('\\SAGE', 'Sage'),
    ('\\Sage', 'Sage'),
    ('\\rm', ''),
    ('backslash','\\'),
    ('begin{enumerate}',''),
    ('end{enumerate}',''),
    ('begin{description}',''),
    ('end{description}',''),
    ('begin{itemize}',''),
    ('end{itemize}',''),
    ('begin{verbatim}',''),
    ('end{verbatim}',''),
    ('note{','NOTE: '),
]

def _rmcmd(s, cmd, left='', right=''):
    """
    Remove the LaTeX command ``cmd`` from the string ``s``.  This
    function is used by ``detex``.

    INPUT:

    - ``s`` - (string) string from which to remove the command

    - ``cmd`` - (string) command to be removed.  This should be a
      command which takes a single argument, like 'emph' or 'url'; the
      command is removed, but its argument is not.

    - ``left``, ``right`` - (string, optional, default '') add these
      strings at the left and right ends of the command. See the
      examples.

    EXAMPLES::

        sage: from sage.misc.sagedoc import _rmcmd
        sage: _rmcmd('Check out \\url{http://www.sagemath.org}.', 'url')
        'Check out http://www.sagemath.org.'
        sage: _rmcmd('Text in \\emph{italics} looks like this.', 'emph', '*', '*')
        'Text in *italics* looks like this.'
        sage: _rmcmd('This is a \\very{silly} example.', 'very', right='!?')
        'This is a silly!? example.'
    """
    c = '\\%s{'%cmd
    while True:
        i = s.find(c)
        if i == -1:
            return s
        nesting = 1
        j = i+len(c)+1
        while j < len(s) and nesting > 0:
            if s[j] == '{':
                nesting += 1
            elif s[j] == '}':
                nesting -= 1
            j += 1
        j -= 1  # j is position of closing '}'
        if j < len(s):
            s = s[:i] + left + s[i+len(c):j] + right + s[j+1:]
        else:
            return s

# I wanted to be cool and use regexp's, but they aren't really
# useful, since really this is a parsing problem, because of
# nesting of commands, etc.   Since it doesn't have to be
# super super fast (it's a page of text scrolled to the user),
# the above works fine.

#
## import re
## def _rmcmd(s, cmd, left='', right=''):
##     c = '\\%s{.*}'%cmd
##     r = re.compile(c, re.DOTALL)
##     while True:
##         m = r.search(s)
##         if m is None: break
##         s = s[:m.start()] + left + s[m.start()+len(cmd)+1:m.end()-1] \
##             + right + s[m.end():]
##     return s

import re
itempattern = re.compile(r"\\item\[?([^]]*)\]? *(.*)")
itemreplace = r"* \1 \2"

def detex(s, embedded=False):
    r"""nodetex
    This strips LaTeX commands from a string; it is used by the
    ``format`` function to process docstrings for display from the
    command line interface.

    INPUT:

    - ``s`` - string
    - ``embedded`` - boolean (optional, default False)

    If ``embedded`` is False, then do the replacements in both
    ``math_substitutes`` and ``nonmath_substitutes``.  If True, then
    only do ``nonmath_substitutes``.

    OUTPUT:

    string

    EXAMPLES::

        sage: from sage.misc.sagedoc import detex
        sage: detex(r'Some math: `n \geq k`.  A website: \url{sagemath.org}.')
        'Some math: n >= k.  A website: sagemath.org.\n'
        sage: detex(r'More math: `x \mapsto y`.  {\bf Bold face}.')
        'More math: x  |-->  y.  { Bold face}.\n'
        sage: detex(r'`a, b, c, \ldots, z`')
        'a, b, c, ..., z\n'
        sage: detex(r'`a, b, c, \ldots, z`', embedded=True)
        '`a, b, c, \\ldots, z`'
    """
    s = _rmcmd(s, 'url')
    s = _rmcmd(s, 'code')
    s = _rmcmd(s, 'class')
    s = _rmcmd(s, 'mbox')
    s = _rmcmd(s, 'text')
    s = _rmcmd(s, 'section')
    s = _rmcmd(s, 'subsection')
    s = _rmcmd(s, 'subsubsection')
    s = _rmcmd(s, 'note', 'NOTE: ', '')
    s = _rmcmd(s, 'emph', '*', '*')
    s = _rmcmd(s, 'textbf', '*', '*')

    s = re.sub(itempattern, itemreplace, s)

    for a,b in nonmath_substitutes:
        s = s.replace(a,b)
    if not embedded: # not in the notebook
        s = _rmcmd(s, 'mathop')
        s = _rmcmd(s, 'mathrm')
        s = sphinxify(s, format='text')
        for a,b in math_substitutes:  # do math substitutions
            s = s.replace(a,b)
        s = s.replace('\\','')        # nuke backslashes
    return s

def process_dollars(s):
    r"""nodetex
    Replace dollar signs with backticks.

    More precisely, do a regular expression search.  Replace a plain
    dollar sign ($) by a backtick (`).  Replace an escaped dollar sign
    (\\$) by a dollar sign ($).  Don't change a dollar sign preceded or
    followed by a backtick (\`$ or \$`), because of strings like
    "``$HOME``".  Don't make any changes on lines starting with more
    spaces than the first nonempty line in ``s``, because those are
    indented and hence part of a block of code or examples.

    This also doesn't replaces dollar signs enclosed in curly braces,
    to avoid nested math environments.

    EXAMPLES::

        sage: from sage.misc.sagedoc import process_dollars
        sage: process_dollars('hello')
        'hello'
        sage: process_dollars('some math: $x=y$')
        'some math: `x=y`'

    Replace \\$ with $, and don't do anything when backticks are involved::

        sage: process_dollars(r'a ``$REAL`` dollar sign: \$')
        'a ``$REAL`` dollar sign: $'

    Don't make any changes on lines indented more than the first
    nonempty line::

        sage: s = '\n first line\n     indented $x=y$'
        sage: s == process_dollars(s)
        True

    Don't replace dollar signs enclosed in curly braces::

        sage: process_dollars(r'f(n) = 0 \text{ if $n$ is prime}')
        'f(n) = 0 \\text{ if $n$ is prime}'

    This is not perfect::

        sage: process_dollars(r'$f(n) = 0 \text{ if $n$ is prime}$')
        '`f(n) = 0 \\text{ if $n$ is prime}$'

    The regular expression search doesn't find the last $.
    Fortunately, there don't seem to be any instances of this kind of
    expression in the Sage library, as of this writing.
    """
    if s.find("$") == -1:
        return s
    # find how much leading whitespace s has, for later comparison:
    # ignore all $ on lines which start with more whitespace.
    whitespace = re.match(r'\s*\S', s.lstrip('\n'))
    whitespace = ' ' * (whitespace.end() - 1) # leading whitespace
    # Indices will be a list of pairs of positions in s, to search between.
    # If the following search has no matches, then indices will be (0, len(s)).
    indices = [0]
    # This searches for "$blah$" inside a pair of curly braces --
    # don't change these, since they're probably coming from a nested
    # math environment.  So for each match, search to the left of its
    # start and to the right of its end, but not in between.
    for m in re.finditer(r"{[^{}$]*\$([^{}$]*)\$[^{}$]*}", s):
        indices[-1] = (indices[-1], m.start())
        indices.append(m.end())
    indices[-1] = (indices[-1], len(s))
    # regular expression for $ (not \$, `$, $`, and only on a line
    # with no extra leading whitespace).
    #
    # in detail:
    #   re.compile("^" # beginning of line
    #               + "(%s%)?" % whitespace
    #               + r"""(\S # non whitespace
    #                     .*?)? # non-greedy match any non-newline characters
    #                     (?<!`|\\)\$(?!`) # $ with negative lookbehind and lookahead
    #                  """, re.M | re.X)
    #
    # except that this doesn't work, so use the equivalent regular
    # expression without the 're.X' option.  Maybe 'whitespace' gets
    # eaten up by re.X?
    regexp = "^" + "(%s)?"%whitespace + r"(\S.*?)?(?<!`|\\)\$(?!`)"
    dollar = re.compile(regexp, re.M)
    # regular expression for \$
    slashdollar = re.compile(r"\\\$")
    for start, end in indices:
        while dollar.search(s, start, end):
            m = dollar.search(s, start, end)
            s = s[:m.end()-1] + "`" + s[m.end():]
        while slashdollar.search(s, start, end):
            m = slashdollar.search(s, start, end)
            s = s[:m.start()] + "$" + s[m.end():]
    return s

def process_extlinks(s, embedded=False):
    r"""nodetex

    In docstrings at the command line, process markup related to the
    Sphinx extlinks extension. For example, replace ``:trac:`NUM```
    with ``http://trac.sagemath.org/NUM``, and similarly with
    ``:python:TEXT`` and ``:wikipedia:TEXT``, looking up the url from
    the dictionary ``extlinks`` in SAGE_ROOT/devel/doc/common/conf.py.
    If ``TEXT`` is of the form ``blah <LINK>``, then it uses ``LINK``
    rather than ``TEXT`` to construct the url.

    In the notebook, don't do anything: let sphinxify take care of it.

    INPUT:

    - ``s`` -- string, in practice a docstring
    - ``embedded`` -- boolean (optional, default False)

    This function is called by :func:`format`, and if in the notebook,
    it sets ``embedded`` to be ``True``, otherwise ``False``.

    EXAMPLES::

        sage: from sage.misc.sagedoc import process_extlinks
        sage: process_extlinks('See :trac:`1234`, :wikipedia:`Wikipedia <Sage_(mathematics_software)>`, and :trac:`4321` ...')
        'See http://trac.sagemath.org/1234, http://en.wikipedia.org/wiki/Sage_(mathematics_software), and http://trac.sagemath.org/4321 ...'
        sage: process_extlinks('See :trac:`1234` for more information.', embedded=True)
        'See :trac:`1234` for more information.'
        sage: process_extlinks('see :python:`Implementing Descriptors <reference/datamodel.html#implementing-descriptors>` ...')
        'see http://docs.python.org/release/.../reference/datamodel.html#implementing-descriptors ...'
    """
    if embedded:
        return s
    oldpath = sys.path
    sys.path = oldpath + [os.path.join(SAGE_DOC, 'common')]
    from conf import pythonversion, extlinks
    sys.path = oldpath
    for key in extlinks:
        while True:
            m = re.search(':%s:`([^`]*)`' % key, s)
            if not m:
                break
            link = m.group(1)
            m = re.search('.*<([^>]*)>', link)
            if m:
                link = m.group(1)
            s = re.sub(':%s:`([^`]*)`' % key,
                       extlinks[key][0].replace('%s', link),
                       s, count=1)
    return s

def process_mathtt(s):
    r"""nodetex
    Replace \\mathtt{BLAH} with BLAH in the command line.

    INPUT:

    - ``s`` - string, in practice a docstring

    This function is called by :func:`format`.

    EXAMPLES::

        sage: from sage.misc.sagedoc import process_mathtt
        sage: process_mathtt(r'e^\mathtt{self}')
        'e^self'
    """
    while True:
        start = s.find("\\mathtt{")
        end = s.find("}", start)
        if start == -1 or end == -1:
            break
        s = s[:start] + s[start+8:end] + s[end+1:]
    return s

def format(s, embedded=False):
    r"""noreplace
    Format Sage documentation ``s`` for viewing with IPython.

    This calls ``detex`` on ``s`` to convert LaTeX commands to plain
    text, unless the directive ``nodetex`` is given in the first line
    of the string.

    Also, if ``s`` contains a string of the form ``<<<obj>>>``, then
    it replaces it with the docstring for ``obj``, unless the
    directive ``noreplace`` is given in the first line. If an error
    occurs under the attempt to find the docstring for ``obj``, then
    the substring ``<<<obj>>>`` is preserved.

    Directives must be separated by a comma.

    NOTE:

    If the first line of the string provides embedding information,
    which is the case for doc strings from extension modules, then
    the first line will not be changed.

    INPUT:

    - ``s`` - string
    - ``embedded`` - boolean (optional, default False)

    OUTPUT: string

    Set ``embedded`` equal to True if formatting for use in the
    notebook; this just gets passed as an argument to ``detex``.

    EXAMPLES::

        sage: from sage.misc.sagedoc import format
        sage: identity_matrix(2).rook_vector.__doc__[115:184]
        'Let `A` be a general `m` by `n`\n        (0,1)-matrix with `m \\le n`. '
        sage: format(identity_matrix(2).rook_vector.__doc__[115:184])
        'Let A be a general m by n\n   (0,1)-matrix with m <= n.\n'

    If the first line of the string is 'nodetex', remove 'nodetex' but
    don't modify any TeX commands::

        sage: format("nodetex\n`x \\geq y`")
        '`x \\geq y`'

    Testing a string enclosed in triple angle brackets::

        sage: format('<<<identity_matrix')
        '<<<identity_matrix\n'
        sage: format('identity_matrix>>>')
        'identity_matrix>>>\n'
        sage: format('<<<identity_matrix>>>')[:28]
        'Definition: identity_matrix('

    TESTS:

    We check that the todo Sphinx extension is correctly activated::

        sage: sage.misc.sagedoc.format(sage.combinat.ranker.on_fly.__doc__)
        "   Returns ...  Todo: add tests as in combinat::rankers\n"

    We check that the embedding information of a doc string from an extension
    module is preserved, even if it is longer than a usual line. Moreover,
    a ``nodetex`` directive in the first "essential" line of the doc string
    is recognised. That has been implemented in trac ticket #11815::

        sage: r = 'File: _local_user_with_a_very_long_name_that_would_normally_be_wrapped_sage_temp_machine_name_1234_tmp_1_spyx_0.pyx (starting at line 6)\nnodetex\nsome doc for a cython method\n`x \geq y`'
        sage: print format(r)
        File: _local_user_with_a_very_long_name_that_would_normally_be_wrapped_sage_temp_machine_name_1234_tmp_1_spyx_0.pyx (starting at line 6)
        <BLANKLINE>
        some doc for a cython method
        `x \geq y`

    In the following use case, the ``nodetex`` directive would have been ignored prior
    to #11815::

        sage: cython_code = ["def testfunc(x):",
        ... "    '''",
        ... "    nodetex",
        ... "    This is a doc string with raw latex",
        ... "",
        ... "    `x \\geq y`",
        ... "    '''",
        ... "    return -x"]
        sage: cython('\n'.join(cython_code))
        sage: from sage.misc.sageinspect import sage_getdoc
        sage: print sage_getdoc(testfunc)
        <BLANKLINE>
            This is a doc string with raw latex
        <BLANKLINE>
            `x \geq y`
        <BLANKLINE>

    We check that the ``noreplace`` directive works, even combined with ``nodetex`` and
    an embedding information (see trac ticket #11817)::

        sage: print format('File: bla.py (starting at line 1)\nnodetex, noreplace\n<<<identity_matrix>>>`\\not= 0`')
        File: bla.py (starting at line 1)
        <<<identity_matrix>>>`\not= 0`

    If replacement is impossible, then no error is raised::

        sage: print format('<<<bla\n<<<bla>>>\n<<<identity_matrix>>>')
        <<<bla <<<bla>>>
        <BLANKLINE>
        Definition: identity_matrix(ring, n=0, sparse=False)
        <BLANKLINE>
           Return the n x n identity matrix over the given ring.
        ...

    """
    if not isinstance(s, str):
        raise TypeError, "s must be a string"

    # Doc strings may contain embedding information, which should not
    # be subject to formatting (line breaks must not be inserted).
    # Hence, we first try to find out whether there is an embedding
    # information.
    first_newline = s.find(os.linesep)
    embedding_info = ''
    if first_newline > -1:
        first_line = s[:first_newline]
        from sage.misc.sageinspect import _extract_embedded_position
        if _extract_embedded_position(first_line) is not None:
            embedding_info = first_line + os.linesep
            s = s[first_newline+len(os.linesep):]
            # Hence, by now, s starts with the second line.
    else:
        from sage.misc.sageinspect import _extract_embedded_position
        if _extract_embedded_position(s) is not None:
            return s

    # Leading empty lines must be removed, since we search for directives
    # in the first line.
    s = s.lstrip(os.linesep)

    # parse directives at beginning of docstring
    # currently, only 'nodetex' and 'noreplace' are supported.
    # 'no' + 'doctest' may be supported eventually (don't type that as
    # one word, or the whole file will not be doctested).
    first_newline = s.find(os.linesep)
    if first_newline > -1:
        first_line = s[:first_newline]
    else:
        first_line = s
    # Moreover, we must strip blank space in order to get the directives
    directives = [ d.strip().lower() for d in first_line.split(',') ]

    if 'noreplace' in directives or 'nodetex' in directives:
        s = s[first_newline+len(os.linesep):]

    import sage.all
    import sage.server.support
    docs = set([])
    if 'noreplace' not in directives:
        i_0 = 0
        while True:
            i = s[i_0:].find("<<<")
            if i == -1: break
            j = s[i_0+i+3:].find('>>>')
            if j == -1: break
            obj = s[i_0+i+3 : i_0+i+3+j]
            if obj in docs:
                t = ''
            else:
                try:
                    x = eval('sage.all.%s'%obj, locals())
                except AttributeError:
                    # A pair <<<...>>> has been found, but the object not.
                    i_0 += i+6+j
                    continue
                except SyntaxError:
                    # This is a simple heuristics to cover the case of
                    # a non-matching set of <<< and >>>
                    i_0 += i+3
                    continue
                t0 = sage.misc.sageinspect.sage_getdef(x, obj)
                t1 = sage.misc.sageinspect.sage_getdoc(x)
                t = 'Definition: ' + t0 + '\n\n' + t1
                docs.add(obj)
            s = s[:i_0+i] + '\n' + t + s[i_0+i+6+j:]
            i_0 += i

    if 'nodetex' not in directives:
        s = process_dollars(s)
        if not embedded:
            s = process_mathtt(s)
        s = process_extlinks(s, embedded=embedded)
        s = detex(s, embedded=embedded)
    return embedding_info+s

def format_src(s):
    """
    Format Sage source code ``s`` for viewing with IPython.

    If ``s`` contains a string of the form "<<<obj>>>", then it
    replaces it with the source code for "obj".

    INPUT: ``s`` - string

    OUTPUT: string

    EXAMPLES::

        sage: from sage.misc.sagedoc import format_src
        sage: format_src('unladen swallow')
        'unladen swallow'
        sage: format_src('<<<Sq>>>')[5:15]
        'Sq(*nums):'
    """
    if not isinstance(s, str):
        raise TypeError, "s must be a string"
    docs = set([])
    import sage.all
    while True:
        i = s.find("<<<")
        if i == -1: break
        j = s[i+3:].find('>>>')
        if j == -1: break
        obj = s[i+3:i+3+j]
        if obj in docs:
            t = ''
        else:
            x = eval('sage.all.%s'%obj, locals())
            t = my_getsource(x, False)
            docs.add(obj)
        if t is None:
            print x
            t = ''
        s = s[:i] + '\n' + t + s[i+6+j:]

    return s

###############################

def _search_src_or_doc(what, string, extra1='', extra2='', extra3='',
                       extra4='', extra5='', **kwds):
    r"""
    Search the Sage library or documentation for lines containing
    ``string`` and possibly some other terms. This function is used by
    :func:`search_src`, :func:`search_doc`, and :func:`search_def`.

    INPUT:

    - ``what``: either ``'src'`` or ``'doc'``, according to whether you
      are searching the documentation or source code.
    - the rest of the input is the same as :func:`search_src`,
      :func:`search_doc`, and :func:`search_def`.

    OUTPUT:

    If ``interact`` is ``False``, a string containing the results;
    otherwise, there is no output and the results are presented
    according to whether you are using the notebook or command-line
    interface. In the command-line interface, each line of the results
    has the form ``filename:num:line of code``, where ``num`` is the
    line number in ``filename`` and ``line of code`` is the line that
    matched your search terms.

    EXAMPLES::

        sage: from sage.misc.sagedoc import _search_src_or_doc
        sage: print _search_src_or_doc('src', 'matrix\(', 'incidence_structures', 'self', '^combinat', interact=False) # random # long time
        misc/sagedoc.py:        sage: _search_src_or_doc('src', 'matrix(', 'incidence_structures', 'self', '^combinat', interact=False)
        combinat/designs/incidence_structures.py:        M1 = self.incidence_matrix()
        combinat/designs/incidence_structures.py:        A = self.incidence_matrix()
        combinat/designs/incidence_structures.py:        M = transpose(self.incidence_matrix())
        combinat/designs/incidence_structures.py:    def incidence_matrix(self):
        combinat/designs/incidence_structures.py:        A = self.incidence_matrix()
        combinat/designs/incidence_structures.py:        A = self.incidence_matrix()
        combinat/designs/incidence_structures.py:        #A = self.incidence_matrix()

    TESTS:

    The examples are nice, but marking them "random" means we're not
    really testing if the function works, just that it completes. These
    tests aren't perfect, but are reasonable.

    ::

        sage: len(_search_src_or_doc('src', 'matrix\(', 'incidence_structures', 'self', 'combinat', interact=False).splitlines()) > 1
        True
        sage: 'abvar/homology' in _search_src_or_doc('doc', 'homology', 'variety', interact=False)  # long time (4s on sage.math, 2012)
        True
        sage: 'divisors' in _search_src_or_doc('src', '^ *def prime', interact=False)
        True
    """
    # process keywords
    if 'interact' in kwds:
        interact = kwds['interact']
    else:
        interact = True
    if 'path_re' in kwds:
        path_re = kwds['path_re']
    else:
        path_re = ''
    if 'module' in kwds:
        module = kwds['module']
    else:
        module = 'sage'
    if 'whole_word' in kwds:
        whole_word = kwds['whole_word']
    else:
        whole_word = False
    if 'ignore_case' in kwds:
        ignore_case = kwds['ignore_case']
    else:
        ignore_case = False
    if 'multiline' in kwds:
        multiline = kwds['multiline']
    else:
        multiline = False
    # done processing keywords
    # define module, exts (file extension), title (title of search),
    # base_path (top directory in which to search)
    ROOT = os.environ['SAGE_ROOT']
    if what == 'src':
        if module.find('sage') == 0:
            module = module[4:].lstrip(".")  # remove 'sage' or 'sage.' from module
            base_path = os.path.join('devel', 'sage', 'sage')
        else:
            base_path = os.path.join('devel', 'sage')
        module = module.replace(".", os.sep)
        exts = ['py', 'pyx', 'pxd']
        title = 'Source Code'
    else:
        module = ''
        exts = ['html']
        title = 'Documentation'
        base_path = os.path.join('devel', 'sage', 'doc', 'output')
        doc_path = os.path.join(ROOT, 'devel', 'sage', 'doc')

        # We need to import stuff from SAGE_ROOT/devel/sage/doc/common
        # To do this, we temporarily change sys.path
        oldpath = sys.path
        sys.path = oldpath + [os.path.join(ROOT, 'devel', 'sage', 'doc', 'common')]
        import build_options as builder
        # List of languages
        lang = builder.LANGUAGES
        # Documents in SAGE_ROOT/devel/sage/doc/LANG/ to omit
        omit = builder.OMIT
        sys.path = oldpath

        # List of documents, minus the omitted ones
        documents = []
        for L in lang:
            documents += [os.path.join(L, dir) for dir
                          in os.listdir(os.path.join(doc_path, L))
                          if dir not in omit]

        # Check to see if any documents are missing.  This just
        # checks to see if the appropriate output directory exists,
        # not that it contains a complete build of the docs.
        missing = [os.path.join(doc_path, 'output', 'html', doc)
                   for doc in documents if not
                   os.path.exists(os.path.join(doc_path, 'output', 'html', doc))]
        num_missing = len(missing)
        if num_missing > 0:
            print """Warning, the following Sage documentation hasn't been built,
so documentation search results may be incomplete:
"""
            for s in missing:
                print s
            if num_missing > 1:
                print """
You can build these with 'sage -docbuild DOCUMENT html',
where DOCUMENT is one of""",
                for s in missing:
                    if s.find('en') != -1:
                        print "'%s'," % os.path.split(s)[-1],
                    else:
                        print "'%s'," % os.path.join(
                            os.path.split(os.path.split(s)[0])[-1],
                            os.path.split(s)[-1]),
                print """
or you can use 'sage -docbuild all html' to build all of the missing documentation."""
            else:
                s = missing[0]
                if s.find('en') != -1:
                    s = os.path.split(s)[-1]
                else:
                    s = os.path.join(
                        os.path.split(os.path.split(s)[0])[-1],
                        os.path.split(s)[-1])
                print """
You can build this with 'sage -docbuild %s html'.""" % s

    base_path = os.path.join(ROOT, base_path)
    strip = len(base_path)
    results = ''
    # in regular expressions, '\bWORD\b' matches 'WORD' but not
    # 'SWORD' or 'WORDS'.  so if the user requests a whole_word
    # search, append and prepend '\b' to each string.
    if whole_word:
        string = r'\b' + string + r'\b'
        if extra1:
            extra1 = r'\b' + extra1 + r'\b'
        if extra2:
            extra2 = r'\b' + extra2 + r'\b'
        if extra3:
            extra3 = r'\b' + extra3 + r'\b'
        if extra4:
            extra4 = r'\b' + extra4 + r'\b'
        if extra5:
            extra5 = r'\b' + extra5 + r'\b'
    if ignore_case:
        # 'flags' is a flag passed to re.search. use bit-wise or "|" to combine flags.
        flags = re.IGNORECASE
    else:
        flags = 0
    # done with preparation; ready to start search
    for dirpath, dirs, files in os.walk(os.path.join(base_path, module)):
        for f in files:
            if not f.startswith('.') and re.search("\.(" + "|".join(exts) + ")$", f):
                filename = os.path.join(dirpath, f)
                if re.search(path_re, filename):
                    if multiline:
                        line = open(filename).read()
                        if re.search(string, line, flags):
                            match_list = line
                        else:
                            match_list = None
                        for extra in [extra1, extra2, extra3, extra4, extra5]:
                            if extra and match_list:
                                if not re.search(extra, match_list):
                                    match_list = None
                        if match_list:
                            results += filename[strip:].lstrip("/") + "\n"
                    else:
                        match_list = [(lineno, line) for lineno, line in
                                      enumerate(open(filename).read().splitlines(True))
                                      if re.search(string, line, flags)]
                        for extra in [extra1, extra2, extra3, extra4, extra5]:
                            if extra:
                                match_list = filter(lambda s:
                                                        re.search(extra, s[1],
                                                                  re.MULTILINE | flags),
                                                    match_list)
                        for num, line in match_list:
                            results += ':'.join([filename[strip:].lstrip("/"),
                                                 str(num+1),
                                                 line])

    if not interact:
        return results

    from sage.server.support import EMBEDDED_MODE
    if EMBEDDED_MODE:   # I.e., running from the notebook
        if multiline: # insert the colons that format_search_as_html expects
            results = ":\n".join(results.splitlines()) + ":"
        # format the search terms nicely
        terms = ', '.join(['"%s"' % s for s in [string] + [extra1,
                          extra2, extra3, extra4, extra5] if s])
        print format_search_as_html(title, results, terms)
    else:
        # hard-code a 25-line screen into the pager; this works around a
        # problem with doctests: see
        # http://trac.sagemath.org/sage_trac/ticket/5806#comment:11
        from IPython.genutils import page
        page(results, screen_lines = 25)

def search_src(string, extra1='', extra2='', extra3='', extra4='',
               extra5='', **kwds):
    r"""
    Search Sage library source code for lines containing ``string``.
    The search is case-sensitive.

    INPUT:

    - ``string`` - a string to find in the Sage source code.

    - ``extra1``, ..., ``extra5`` - additional strings to require when
      searching.  Lines must match all of these, as well as ``string``.

    - ``whole_word`` (optional, default False) - if True, search for
      ``string`` and ``extra1`` (etc.) as whole words only.  This
      assumes that each of these arguments is a single word, not a
      regular expression, and it might have unexpected results if used
      with regular expressions.

    - ``ignore_case`` (optional, default False) - if True, perform a
      case-insensitive search

    - ``multiline`` (optional, default False) - if True, search more
      than one line at a time.  In this case, print any matching file
      names, but don't print line numbers.

    - ``interact`` (optional, default ``True``) - if ``False``, return
      a string with all the matches. Otherwise, this function returns
      ``None``, and the results are displayed appropriately, according
      to whether you are using the notebook or the command-line
      interface. You should not ordinarily need to use this.

    - ``path_re`` (optional, default '') - regular expression which
      the filename (including the path) must match.

    - ``module`` (optional, default 'sage') - the module in which to
      search.  The default is 'sage', the entire Sage library.  If
      ``module`` doesn't start with "sage", then the links in the
      notebook output may not function.

    OUTPUT: If ``interact`` is False, then return a string with all of
    the matches, separated by newlines.  On the other hand, if
    ``interact`` is True (the default), there is no output.  Instead:
    at the command line, the search results are printed on the screen
    in the form ``filename:line_number:line of text``, showing the
    filename in which each match occurs, the line number where it
    occurs, and the actual matching line.  (If ``multiline`` is True,
    then only the filename is printed for each match.)  The file paths
    in the output are relative to ``$SAGE_ROOT/devel/sage/``.  In the
    notebook, each match produces a link to the actual file in which
    it occurs.

    The ``string`` and ``extraN`` arguments are treated as regular
    expressions, as is ``path_re``, and errors will be raised if they
    are invalid. The matches will be case-sensitive unless
    ``ignore_case`` is True.

    .. note::

        The ``extraN`` parameters are present only because
        ``search_src(string, *extras, interact=False)``
        is not parsed correctly by Python 2.6; see http://bugs.python.org/issue1909.

    EXAMPLES:

    First note that without using ``interact=False``, this function
    produces no output, while with ``interact=False``, the output is a
    string.  These examples almost all use this option, so that they
    have something to which to compare their output.

    You can search for "matrix" by typing ``search_src("matrix")``.
    This particular search will produce many results::

        sage: len(search_src("matrix", interact=False).splitlines()) # random # long time
        9522

    You can restrict to the Sage calculus code with
    ``search_src("matrix", module="sage.calculus")``, and this
    produces many fewer results::

        sage: len(search_src("matrix", module="sage.calculus", interact=False).splitlines()) # random
        26

    Note that you can do tab completion on the ``module`` string.
    Another way to accomplish a similar search::

        sage: len(search_src("matrix", path_re="calc", interact=False).splitlines()) > 15
        True

    The following produces an error because the string 'fetch(' is a
    malformed regular expression::

        sage: print search_src(" fetch(", "def", interact=False)
        Traceback (most recent call last):
        ...
        error: unbalanced parenthesis

    To fix this, *escape* the parenthesis with a backslash::

        sage: print search_src(" fetch\(", "def", interact=False) # random # long time
        matrix/matrix0.pyx:    cdef fetch(self, key):
        matrix/matrix0.pxd:    cdef fetch(self, key)

        sage: print search_src(" fetch\(", "def", "pyx", interact=False) # random # long time
        matrix/matrix0.pyx:    cdef fetch(self, key):

    As noted above, the search is case-sensitive, but you can make it
    case-insensitive with the 'ignore_case' key word::

        sage: s = search_src('Matrix', path_re='matrix', interact=False); s.find('x') > 0
        True

        sage: s = search_src('MatRiX', path_re='matrix', interact=False); s.find('x') > 0
        False

        sage: s = search_src('MatRiX', path_re='matrix', interact=False, ignore_case=True); s.find('x') > 0
        True

    Searches are by default restricted to single lines, but this can
    be changed by setting ``multiline`` to be True.  In the following,
    since ``search_src(string, interact=False)`` returns a string with
    one line for each match, counting the length of
    ``search_src(string, interact=False).splitlines()`` gives the
    number of matches. ::

        sage: len(search_src('log', 'derivative', interact=False).splitlines()) < 10
        True
        sage: len(search_src('log', 'derivative', interact=False, multiline=True).splitlines()) > 30
        True

    A little recursive narcissism: let's do a doctest that searches for
    this function's doctests. Note that you can't put "sage:" in the
    doctest string because it will get replaced by the Python ">>>"
    prompt.

    ::

        sage: print search_src('^ *sage[:] .*search_src\(', interact=False) # long time
        misc/sagedoc.py:... len(search_src("matrix", interact=False).splitlines()) # random # long time
        misc/sagedoc.py:... len(search_src("matrix", module="sage.calculus", interact=False).splitlines()) # random
        misc/sagedoc.py:... len(search_src("matrix", path_re="calc", interact=False).splitlines()) > 15
        misc/sagedoc.py:... print search_src(" fetch(", "def", interact=False)
        misc/sagedoc.py:... print search_src(" fetch\(", "def", interact=False) # random # long time
        misc/sagedoc.py:... print search_src(" fetch\(", "def", "pyx", interact=False) # random # long time
        misc/sagedoc.py:... s = search_src('Matrix', path_re='matrix', interact=False); s.find('x') > 0
        misc/sagedoc.py:... s = search_src('MatRiX', path_re='matrix', interact=False); s.find('x') > 0
        misc/sagedoc.py:... s = search_src('MatRiX', path_re='matrix', interact=False, ignore_case=True); s.find('x') > 0
        misc/sagedoc.py:... len(search_src('log', 'derivative', interact=False).splitlines()) < 10
        misc/sagedoc.py:... len(search_src('log', 'derivative', interact=False, multiline=True).splitlines()) > 30
        misc/sagedoc.py:... print search_src('^ *sage[:] .*search_src\(', interact=False) # long time
        misc/sagedoc.py:... len(search_src("matrix", interact=False).splitlines()) > 9000 # long time
        misc/sagedoc.py:... print search_src('matrix', 'column', 'row', 'sub', 'start', 'index', interact=False) # random # long time

    TESTS:

    As of this writing, there are about 9500 lines in the Sage library that
    contain "matrix"; it seems safe to assume we'll continue to have
    over 9000 such lines::

        sage: len(search_src("matrix", interact=False).splitlines()) > 9000 # long time
        True

    Check that you can pass 5 parameters::

        sage: print search_src('matrix', 'column', 'row', 'sub', 'start', 'index', interact=False) # random # long time
        matrix/matrix0.pyx:598:        Get The 2 x 2 submatrix of M, starting at row index and column
        matrix/matrix0.pyx:607:        Get the 2 x 3 submatrix of M starting at row index and column index
        matrix/matrix0.pyx:924:        Set the 2 x 2 submatrix of M, starting at row index and column
        matrix/matrix0.pyx:933:        Set the 2 x 3 submatrix of M starting at row index and column

    """
    return _search_src_or_doc('src', string, extra1=extra1, extra2=extra2,
                              extra3=extra3, extra4=extra4, extra5=extra5,
                              **kwds)

def search_doc(string, extra1='', extra2='', extra3='', extra4='',
               extra5='', **kwds):
    """
    Search Sage HTML documentation for lines containing ``string``. The
    search is case-sensitive.

    The file paths in the output are relative to
    ``$SAGE_ROOT/devel/sage/doc/output``.

    INPUT: same as for :func:`search_src`.

    OUTPUT: same as for :func:`search_src`.

    EXAMPLES:

    See the documentation for :func:`search_src` for more examples. ::

        sage: search_doc('creates a polynomial', path_re='tutorial', interact=False) # random
        html/en/tutorial/tour_polynomial.html:<p>This creates a polynomial ring and tells Sage to use (the string)

    If you search the documentation for 'tree', then you will get too
    many results, because many lines in the documentation contain the
    word 'toctree'.  If you use the ``whole_word`` option, though, you
    can search for 'tree' without returning all of the instances of
    'toctree'.  In the following, since ``search_doc('tree',
    interact=False)`` returns a string with one line for each match,
    counting the length of ``search_doc('tree',
    interact=False).splitlines()`` gives the number of matches. ::

        sage: len(search_doc('tree', interact=False).splitlines()) > 2500  # long time
        True
        sage: len(search_doc('tree', whole_word=True, interact=False).splitlines()) < 500  # long time
        True
    """
    return _search_src_or_doc('doc', string, extra1=extra1, extra2=extra2,
                              extra3=extra3, extra4=extra4, extra5=extra5,
                              **kwds)

def search_def(name, extra1='', extra2='', extra3='', extra4='',
               extra5='', **kwds):
    r"""
    Search Sage library source code for function definitions containing
    ``name``. The search is case sensitive.

    INPUT: same as for :func:`search_src`.

    OUTPUT: same as for :func:`search_src`.

    .. note::

        The regular expression used by this function only finds function
        definitions that are preceded by spaces, so if you use tabs on a
        "def" line, this function will not find it. As tabs are not
        allowed in Sage library code, this should not be a problem.

    EXAMPLES:

    See the documentation for :func:`search_src` for more examples. ::

        sage: print search_def("fetch", interact=False) # random # long time
        matrix/matrix0.pyx:    cdef fetch(self, key):
        matrix/matrix0.pxd:    cdef fetch(self, key)

        sage: print search_def("fetch", path_re="pyx", interact=False) # random # long time
        matrix/matrix0.pyx:    cdef fetch(self, key):
    """
    # since we convert name to a regular expression, we need to do the
    # 'whole_word' conversion here, rather than pass it on to
    # _search_src_or_doc.
    if 'whole_word' in kwds and kwds['whole_word']:
        name = r'\b' + name + r'\b'
        if extra1:
            extra1 = r'\b' + extra1 + r'\b'
        if extra2:
            extra2 = r'\b' + extra2 + r'\b'
        if extra3:
            extra3 = r'\b' + extra3 + r'\b'
        if extra4:
            extra4 = r'\b' + extra4 + r'\b'
        if extra5:
            extra5 = r'\b' + extra5 + r'\b'
        kwds['whole_word'] = False

    return _search_src_or_doc('src', '^ *[c]?def.*%s' % name, extra1=extra1,
                              extra2=extra2, extra3=extra3, extra4=extra4,
                              extra5=extra5, **kwds)

def format_search_as_html(what, r, search):
    r"""
    Format the output from ``search_src``, ``search_def``, or
    ``search_doc`` as html, for use in the notebook.

    INPUT:

    - ``what`` - (string) what was searched (source code or
      documentation)
    - ``r`` - (string) the results of the search
    - ``search`` - (string) what was being searched for

    This function parses ``r``: it should have the form ``FILENAME:
    string`` where FILENAME is the file in which the string that matched
    the search was found. Everything following the first colon is
    ignored; we just use the filename. If FILENAME ends in '.html', then
    this is part of the documentation; otherwise, it is in the source
    code.  In either case, an appropriate link is created.

    EXAMPLES::

        sage: from sage.misc.sagedoc import format_search_as_html
        sage: format_search_as_html('Source', 'algebras/steenrod_algebra_element.py:        an antihomomorphism: if we call the antipode `c`, then', 'antipode antihomomorphism')
        '<html><font color="black"><h2>Search Source: antipode antihomomorphism</h2></font><font color="darkpurple"><ol><li><a href="/src/algebras/steenrod_algebra_element.py" target="_blank"><tt>algebras/steenrod_algebra_element.py</tt></a>\n</ol></font></html>'
        sage: format_search_as_html('Other', 'html/en/reference/sage/algebras/steenrod_algebra_element.html:an antihomomorphism: if we call the antipode <span class="math">c</span>, then', 'antipode antihomomorphism')
        '<html><font color="black"><h2>Search Other: antipode antihomomorphism</h2></font><font color="darkpurple"><ol><li><a href="/doc/live/reference/sage/algebras/steenrod_algebra_element.html" target="_blank"><tt>reference/sage/algebras/steenrod_algebra_element.html</tt></a>\n</ol></font></html>'
    """
    s = '<html>'
    s += '<font color="black">'
    s += '<h2>Search %s: %s</h2>'%(what, search)
    s += '</font>'
    s += '<font color="darkpurple">'
    s += '<ol>'

    files = set([])
    for L in r.splitlines():
        i = L.find(':')
        if i != -1:
            files.add(L[:i])
    files = list(files)
    files.sort()
    for F in files:
        if F.endswith('.html'):
            F = F.split('/', 2)[2]
            url = '/doc/live/' + F
        else:
            # source code
            url = '/src/' + F
        s += '<li><a href="%s" target="_blank"><tt>%s</tt></a>\n'%(url, F)
    s += '</ol>'
    s += '</font>'
    s += '</html>'
    return s

#######################################
## Add detex'ing of documentation
#######################################
import sageinspect

def my_getsource(obj, is_binary):
    """
    Retrieve the source code for ``obj``.

    INPUT:

    - ``obj`` - a Sage object, function, etc.
    - ``is_binary`` - (boolean) ignored argument.

    OUTPUT: its documentation (string)

    EXAMPLES::

        sage: from sage.misc.sagedoc import my_getsource
        sage: s = my_getsource(identity_matrix, True)
        sage: s[:19]
        'def identity_matrix'
    """
    try:
        s = sageinspect.sage_getsource(obj, is_binary)
        return format_src(s)
    except Exception, msg:
        print 'Error getting source:', msg
        return None

class _sage_doc:
    """
    Open Sage documentation in a web browser, from either the
    command-line or the notebook.

    - Type "browse_sage_doc.DOCUMENT()" to open the named document --
      for example, "browse_sage_doc.tutorial()" opens the tutorial.
      Available documents are

      - tutorial: the Sage tutorial
      - reference: the Sage reference manual
      - constructions: "how do I construct ... in Sage?"
      - developer: the Sage developer's guide.

    - Type "browse_sage_doc(OBJECT, output=FORMAT, view=BOOL)" to view
      the documentation for OBJECT, as in
      "browse_sage_doc(identity_matrix, 'html').  ``output`` can be
      either 'html' or 'rst': the form of the output.  ``view`` is
      only relevant if ``output`` is ``html``; in this case, if
      ``view`` is True (its default value), then open up the
      documentation in a web browser.  Otherwise, just output the
      documentation as a string.

    EXAMPLES::

        sage: browse_sage_doc._open("reference", testing=True)[0]  # indirect doctest
        'http://localhost:8000/doc/live/reference/index.html'
        sage: browse_sage_doc(identity_matrix, 'rst')[-107:-47]
        'Full MatrixSpace of 3 by 3 sparse matrices over Integer Ring'
    """
    def __init__(self):
        """
        EXAMPLES::

            sage: browse_sage_doc._base_url
            'http://localhost:8000/doc/live/'
        """
        self._base_url = "http://localhost:8000/doc/live/"
        self._base_path = os.path.join(SAGE_DOC, "output/html/en/")

    def __call__(self, obj, output='html', view=True):
        r"""
        Return the documentation for ``obj``.

        INPUT:

        - ``obj`` - a Sage object
        - ``output`` - 'html', 'rst', or 'text': return documentation in this form
        - ``view`` - only has an effect if output is 'html': in this
          case, if ``view`` is ``True``, display the documentation in
          a web browser.  Otherwise, return the documentation as a
          string.

        EXAMPLES::

            sage: browse_sage_doc(identity_matrix, 'rst')
            "...**File:**...**Type:**...**Definition:** identity_matrix..."
            sage: identity_matrix.__doc__ in browse_sage_doc(identity_matrix, 'rst')
            True
            sage: browse_sage_doc(identity_matrix, 'html', False)
            '...div...File:...Type:...Definition:...identity_matrix...'

        In the 'text' version, double colons have been replaced with
        single ones (among other things)::

            sage: '::' in browse_sage_doc(identity_matrix, 'rst')
            True
            sage: '::' in browse_sage_doc(identity_matrix, 'text')
            False
        """
        if output != 'html' and view:
            view = False
        # much of the following is taken from 'docstring' in server/support.py
        s  = ''
        newline = "\n\n"  # blank line to start new paragraph

        try:
            filename = sageinspect.sage_getfile(obj)
            s += '**File:** %s' % filename
            s += newline
        except TypeError:
            pass

        obj_name = ''
        locs = sys._getframe(1).f_locals
        for var in locs:
            if id(locs[var]) == id(obj):
                obj_name = var

        s += '**Type:** %s' % type(obj)
        s += newline
        s += '**Definition:** %s' % sageinspect.sage_getdef(obj, obj_name)
        s += newline
        s += '**Docstring:**'
        s += newline
        s += sageinspect.sage_getdoc(obj, obj_name, embedded_override=True)

        # now s should be the reST version of the docstring
        if output == 'html':
            html = sphinxify(s)
            if view:
                path = os.path.join(tmp_dir(), "temp.html")
                filed = open(path, 'w')

                static_path = os.path.join(SAGE_DOC, 'output/html/en/_static')
                if os.path.exists(static_path):
                    title = obj_name + ' - Sage ' + sage.version.version + ' Documentation'
                    template = """<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>%(title)s</title>
    <link rel="stylesheet" href="%(static_path)s/default.css" type="text/css" />
    <link rel="stylesheet" href="%(static_path)s/pygments.css" type="text/css" />
    <style type="text/css">
      <!--
        div.body {
          margin: 1.0em;
          padding: 1.0em;
        }
        div.bodywrapper {
          margin: 0;
        }
      -->
    </style>
    <script type="text/javascript">
      var DOCUMENTATION_OPTIONS = {
        URL_ROOT:    '',
        VERSION:     '%(version)s',
        COLLAPSE_MODINDEX: false,
        FILE_SUFFIX: '.html',
        HAS_SOURCE:  false
      };
    </script>
    <script type="text/javascript" src="%(static_path)s/jquery.js"></script>
    <script type="text/javascript" src="%(static_path)s/doctools.js"></script>
    <script type="text/javascript" src="%(static_path)s/mathjax_sage.js"></script>
    <link rel="shortcut icon" href="%(static_path)s/favicon.ico" />
    <link rel="icon" href="%(static_path)s/sageicon.png" type="image/x-icon" />
  </head>
  <body>
    <div class="document">
      <div class="documentwrapper">
        <div class="bodywrapper">
          <div class="body">
            %(html)s
          </div>
        </div>
      </div>
    </div>
  </body>
</html>"""
                    html = template % { 'html': html,
                                        'static_path': static_path,
                                        'title': title,
                                        'version': sage.version.version }

                filed.write(html)
                filed.close()
                os.system(browser() + " " + path)
            else:
                return html
        elif output == 'rst':
            return s
        elif output == 'text':
            return sphinxify(s, format='text')
        else:
            raise ValueError, "output type %s not recognized" % output

    def _open(self, name, testing=False):
        """
        Open the document ``name`` in a web browser.  This constructs
        the appropriate URL and/or path name and passes it to the web
        browser.

        INPUT:

        - ``name`` - string, name of the documentation

        - ``testing`` - boolean (optional, default False): if True,
          then just return the URL and path-name for this document;
          don't open the web browser.

        EXAMPLES::

            sage: browse_sage_doc._open("reference", testing=True)[0]
            'http://localhost:8000/doc/live/reference/index.html'
            sage: browse_sage_doc._open("tutorial", testing=True)[1]
            '...doc/output/html/en/tutorial/index.html'
        """
        url = self._base_url + os.path.join(name, "index.html")
        path = os.path.join(self._base_path, name, "index.html")
        if not os.path.exists(path):
            raise OSError, """The document '%s' does not exist.  Please build it
with 'sage -docbuild %s html --mathjax' and try again.""" %(name, name)

        if testing:
            return (url, path)

        from sage.server.support import EMBEDDED_MODE
        if EMBEDDED_MODE:
            os.system(browser() + " " + url)
        else:
            os.system(browser() + " " + path)

    def tutorial(self):
        """
        The Sage tutorial.  To get started with Sage, start here.

        EXAMPLES::

            sage: tutorial()  # indirect doctest, not tested
        """
        self._open("tutorial")

    def reference(self):
        """
        The Sage reference manual.

        EXAMPLES::

            sage: reference() # indirect doctest, not tested
            sage: manual() # indirect doctest, not tested
        """
        self._open("reference")

    manual = reference

    def developer(self):
        """
        The Sage developer's guide.  Learn to develop programs for Sage.

        EXAMPLES::

            sage: developer()  # indirect doctest, not tested
        """
        self._open("developer")

    def constructions(self):
        """
        Sage constructions.  Attempts to answer the question "How do I
        construct ... in Sage?"

        EXAMPLES::

            sage: constructions()  # indirect doctest, not tested
        """
        self._open("constructions")

browse_sage_doc = _sage_doc()
tutorial = browse_sage_doc.tutorial
reference = browse_sage_doc.reference
manual = browse_sage_doc.reference
developer = browse_sage_doc.developer
constructions = browse_sage_doc.constructions

python_help = pydoc.help

def help(module=None):
    """
    If there is an argument ``module``, print the Python help message
    for ``module``.  With no argument, print a help message about
    getting help in Sage.

    EXAMPLES::

        sage: help()
        Welcome to Sage ...
    """
    if not module is None:
        python_help(module)
    else:
        print """Welcome to Sage %s!

To view the Sage tutorial in your web browser, type "tutorial()", and
to view the (very detailed) Sage reference manual, type "manual()".
For help on any Sage function, for example "matrix_plot", type
"matrix_plot?" to see a help message, type "help(matrix_plot)" to see
a very similar message, type "browse_sage_doc(matrix_plot)" to view a
help message in a web browser, and type "matrix_plot??" to look at the
function's source code.

(When you type something like "matrix_plot?", "help(matrix_plot)", or
"matrix_plot??", Sage may start a paging program to display the
requested message. Type a space to scroll to the next page, type "h"
to get help on the paging program, and type "q" to quit it and return
to the "sage:" prompt.)

For license information for Sage and its components, read the file
"COPYING.txt" in the top-level directory of the Sage installation,
or type "license()".

To enter Python's interactive online help utility, type "python_help()".
To get help on a Python function, module or package, type "help(MODULE)" or
"python_help(MODULE)".""" % sage.version.version
