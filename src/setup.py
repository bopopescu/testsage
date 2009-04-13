#!/usr/bin/env python

import os, sys, time
from distutils.core import setup
from distutils.extension import Extension

#########################################################
### List of Extensions
###
### Since Sage 3.2 the list of extensions resides in
### module_list.py in the same directory as this file
### (augmented by the list of interpreters
### generated by sage/ext/gen_interpreters.py)
#########################################################

from module_list import ext_modules
import sage.ext.gen_interpreters

#########################################################
### Configuration
#########################################################

if len(sys.argv) > 1 and sys.argv[1] == "sdist":
    sdist = True
else:
    sdist = False

if not os.environ.has_key('SAGE_ROOT'):
    print "    ERROR: The environment variable SAGE_ROOT must be defined."
    sys.exit(1)
else:
    SAGE_ROOT  = os.environ['SAGE_ROOT']
    SAGE_LOCAL = SAGE_ROOT + '/local/'
    SAGE_DEVEL = SAGE_ROOT + '/devel/'

if not os.environ.has_key('SAGE_VERSION'):
    SAGE_VERSION=0
else:
    SAGE_VERSION = os.environ['SAGE_VERSION']

SITE_PACKAGES = '%s/lib/python/site-packages/'%SAGE_LOCAL
if not os.path.exists(SITE_PACKAGES):
    SITE_PACKAGES = '%s/lib/python2.5/site-packages/'%SAGE_LOCAL
    if not os.path.exists(SITE_PACKAGES):
        SITE_PACKAGES = '%s/lib/python2.4/site-packages/'%SAGE_LOCAL
        if not os.path.exists(SITE_PACKAGES) and os.environ.has_key('SAGE_DEBIAN'):
            SITE_PACKAGES = '%s/lib/python2.5/site-packages/'%SAGE_LOCAL
            os.system('mkdir -p "%s"'%SITE_PACKAGES)
        if not os.path.exists(SITE_PACKAGES):
            raise RuntimeError, "Unable to find site-packages directory (see setup.py file in sage python code)."

if not os.path.exists('build/sage'):
    os.makedirs('build/sage')

sage_link = SITE_PACKAGES + '/sage'
if not os.path.islink(sage_link) or not os.path.exists(sage_link):
    os.system('rm -rf "%s"'%sage_link)
    os.system('cd %s; ln -sf ../../../../devel/sage/build/sage .'%SITE_PACKAGES)

include_dirs = ['%s/include'%SAGE_LOCAL, \
                '%s/include/csage'%SAGE_LOCAL, \
                ## this is included, but doesn't actually exist
                ## '%s/include/python'%SAGE_LOCAL, \
                '%s/sage/sage/ext'%SAGE_DEVEL]

extra_compile_args = [ ]

# comment these four lines out to turn on warnings from gcc
import distutils.sysconfig
NO_WARN = True
if NO_WARN and distutils.sysconfig.get_config_var('CC').startswith("gcc"):
    extra_compile_args.append('-w')

DEVEL = False
if DEVEL:
    extra_compile_args.append('-ggdb')

# Generate interpreters

sage.ext.gen_interpreters.rebuild(SAGE_DEVEL + 'sage/sage/ext/interpreters')
ext_modules = ext_modules + sage.ext.gen_interpreters.modules

######################################################################
# CODE for generating C/C++ code from Cython and doing dependency
# checking, etc.  In theory distutils would run Cython, but I don't
# trust it at all, and it won't have the more sophisticated dependency
# checking that we need.
######################################################################

for m in ext_modules:
    m.libraries = ['csage'] + m.libraries + ['stdc++', 'ntl']
    m.extra_compile_args += extra_compile_args
    if os.environ.has_key('SAGE_DEBIAN'):
        m.library_dirs += ['/usr/lib','/usr/lib/eclib','/usr/lib/singular','/usr/lib/R/lib','%s/lib' % SAGE_LOCAL]
    else:
        m.library_dirs += ['%s/lib' % SAGE_LOCAL]

#############################################
###### Parallel Cython execution
#############################################

def execute_list_of_commands_in_serial(command_list):
    """
    INPUT:
        command_list -- a list of commands, each given as a pair
           of the form [command, argument].

    OUTPUT:
        the given list of commands are all executed in serial
    """
    for f,v in command_list:
        r = f(v)
        if r != 0:
            print "Error running command, failed with status %s."%r
            sys.exit(1)

def run_command(cmd):
    """
    INPUT:
        cmd -- a string; a command to run

    OUTPUT:
        prints cmd to the console and then runs os.system
    """
    print cmd
    return os.system(cmd)

def apply_pair(p):
    """
    Given a pair p consisting of a function and a value, apply
    the function to the value.

    This exists solely because we can't pickle an anonymous function
    in execute_list_of_commands_in_parallel below.
    """
    return p[0](p[1])

def execute_list_of_commands_in_parallel(command_list, nthreads):
    """
    INPUT:
        command_list -- a list of pairs, consisting of a
             function to call and its argument
        nthreads -- integer; number of threads to use

    OUTPUT:
        Executes the given list of commands, possibly in parallel,
        using nthreads threads.  Terminates setup.py with an exit code of 1
        if an error occurs in any subcommand.

    WARNING: commands are run roughly in order, but of course successive
    commands may be run at the same time.
    """
    print "Execute %s commands (using %s threads)"%(len(command_list), min(len(command_list),nthreads))
    from processing import Pool
    p = Pool(nthreads)
    for r in p.imap(apply_pair, command_list):
        if r:
            print "Parallel build failed with status %s."%r
            sys.exit(1)

def number_of_threads():
    """
    Try to determine the number of threads one can run at once on this
    system (e.g., the number of cores).  If successful return that
    number.  Otherwise return 0 to indicate failure.

    OUTPUT:
        int
    """
    if hasattr(os, "sysconf") and os.sysconf_names.has_key("SC_NPROCESSORS_ONLN"): # Linux and Unix
        n = os.sysconf("SC_NPROCESSORS_ONLN")
        if isinstance(n, int) and n > 0:
            return n
    try:
        return int(os.popen2("sysctl -n hw.ncpu")[1].read().strip())
    except:
        return 0

def execute_list_of_commands(command_list):
    """
    INPUT:
        command_list -- a list of strings or pairs
    OUTPUT:
        For each entry in command_list, we attempt to run the command.
        If it is a string, we call os.system. If it is a pair [f, v],
        we call f(v). On machines with more than 1 cpu the commands
        are run in parallel.
    """
    t = time.time()
    if not os.environ.has_key('MAKE'):
        nthreads = 1
    else:
        MAKE = os.environ['MAKE']
        z = [w[2:] for w in MAKE.split() if w.startswith('-j')]
        if len(z) == 0:  # no command line option
            nthreads = 1
        else:
            # Determine number of threads from command line argument.
            # Also, use the OS to cap the number of threads, in case
            # user annoyingly makes a typo and asks to use 10000
            # threads at once.
            try:
                nthreads = int(z[0])
                n = 2*number_of_threads()
                if n:  # prevent dumb typos.
                    nthreads = min(nthreads, n)
            except ValueError:
                nthreads = 1

    # normalize the command_list to handle strings correctly
    command_list = [ [run_command, x] if isinstance(x, str) else x for x in command_list ]

    if nthreads > 1:
        # parallel version
        execute_list_of_commands_in_parallel(command_list, nthreads)
    else:
        # non-parallel version
        execute_list_of_commands_in_serial(command_list)
    print "Time to execute %s commands: %s seconds"%(len(command_list), time.time() - t)

#############################################
###### Dependency checking
#############################################

CYTHON_INCLUDE_DIRS=[ SAGE_LOCAL + '/lib/python2.5/site-packages/Cython/Includes/' ]

# matches any dependency
import re
dep_regex = re.compile(r'^ *(?:(?:cimport +([\w\. ,]+))|(?:from +(\w+) +cimport)|(?:include *[\'"]([^\'"]+)[\'"])|(?:cdef *extern *from *[\'"]([^\'"]+)[\'"]))', re.M)

class DependencyTree:
    """
    This class stores all the information about the dependencies of a set of
    Cython files. It uses a lot of caching so information only needs to be
    looked up once per build.
    """
    def __init__(self):
        self._last_parse = {}
        self._timestamps = {}
        self._deps = {}
        self._deps_all = {}
        self.root = "%s/devel/sage/" % SAGE_ROOT

    def __getstate__(self):
        """
        Used for pickling.

        Timestamps and deep dependencies may change between builds,
        so we don't want to save those.
        """
        state = dict(self.__dict__)
        state['_timestamps'] = {}
        state['_deps_all'] = {}
        return state

    def __setstate__(self, state):
        """
        Used for unpickling.
        """
        self.__dict__.update(state)
        self._timestamps = {}
        self._deps_all = {}
        self.root = "%s/devel/sage/" % SAGE_ROOT

    def timestamp(self, filename):
        """
        Look up the last modified time of a file, with caching.
        """
        if filename not in self._timestamps:
            try:
                self._timestamps[filename] = os.path.getmtime(filename)
            except OSError:
                self._timestamps[filename] = 0
        return self._timestamps[filename]

    def parse_deps(self, filename, verify=True):
        """
        Open a Cython file and extract all of its dependencies.

        INPUT:
            filename -- the file to parse
            verify   -- only return existing files (default True)

        OUTPUT:
            list of dependency files
        """
        # only parse cython files
        if filename[-4:] not in ('.pyx', '.pxd', '.pxi'):
            return []

        dirname = os.path.split(filename)[0]
        deps = set()
        if filename.endswith('.pyx'):
            pxd_file = filename[:-4] + '.pxd'
            if os.path.exists(pxd_file):
                deps.add(pxd_file)

        raw_deps = []
        f = open(filename)
        for m in dep_regex.finditer(open(filename).read()):
            groups = m.groups()
            modules = groups[0] or groups[1] # cimport or from ... cimport
            if modules is not None:
                for module in modules.split(','):
                    module = module.strip().split(' ')[0] # get rid of 'as' clause
                    if '.' in module:
                        path = module.replace('.', '/') + '.pxd'
                        base_dependency_name = path
                    else:
                        path = "%s/%s.pxd" % (dirname, module)
                        base_dependency_name = "%s.pxd"%module
                    raw_deps.append((path, base_dependency_name))
            else: # include or extern from
                extern_file = groups[2] or groups[3]
                path = '%s/%s'%(dirname, extern_file)
                if not os.path.exists(path):
                    path = extern_file
                raw_deps.append((path, extern_file))

        for path, base_dependency_name in raw_deps:
            # if we can find the file, add it to the dependencies.
            path = os.path.normpath(path)
            if os.path.exists(path):
                deps.add(path)
            # we didn't find the file locally, so check the
            # Cython include path.
            else:
                found_include = False
                for idir in CYTHON_INCLUDE_DIRS:
                    new_path = os.path.normpath(idir + base_dependency_name)
                    if os.path.exists(new_path):
                        deps.add(new_path)
                        found_include = True
                        break
                # so we really couldn't find the dependency -- raise
                # an exception.
                if not found_include:
                    if path[-2:] != '.h':  # there are implicit headers from distutils, etc
                        raise IOError, "could not find dependency %s included in %s."%(path, filename)
        f.close()
        return list(deps)

    def immediate_deps(self, filename):
        """
        Returns a list of files directly referenced by this file.
        """
        if (filename not in self._deps
                or self.timestamp(filename) < self._last_parse[filename]):
            self._deps[filename] = self.parse_deps(filename)
            self._last_parse[filename] = self.timestamp(filename)
        return self._deps[filename]

    def all_deps(self, filename, path=None):
        """
        Returns all files directly or indirectly referenced by this file.

        A recursive algorithm is used here to maximize caching, but it is
        still robust for circular cimports (via the path parameter).
        """
        if filename not in self._deps_all:
            circular = False
            deps = set([filename])
            if path is None:
                path = set([filename])
            else:
                path.add(filename)
            for f in self.immediate_deps(filename):
                if f not in path:
                    deps.update(self.all_deps(f, path))
                else:
                    circular = True
            path.remove(filename)
            if circular:
                return deps # Don't cache, as this may be incomplete
            else:
                self._deps_all[filename] = deps
        return self._deps_all[filename]

    def newest_dep(self, filename):
        """
        Returns the most recently modified file that filename depends on,
        along with its timestamp.
        """
        nfile = filename
        ntime = self.timestamp(filename)
        for f in self.all_deps(filename):
            if self.timestamp(f) > ntime:
                nfile = f
                ntime = self.timestamp(f)
        return nfile, ntime

#############################################
###### Build code
#############################################

def process_filename(f, m):
    base, ext = os.path.splitext(f)
    if ext == '.pyx':
        if m.language == 'c++':
            return base + '.cpp'
        else:
            return base + '.c'
    else:
        return f

def compile_command(p):
    """
    Given a pair p = (f, m), with a .pyx file f which is a part the
    module m, call Cython on f

    INPUT:
         p -- a 2-tuple f, m

    copy the file to SITE_PACKAGES, and return a string
    which will call Cython on it.
    """
    f, m = p
    if f.endswith('.pyx'):
        # process cython file

        # find the right filename
        outfile = f[:-4]
        if m.language == 'c++':
            outfile += ".cpp"
        else:
            outfile += ".c"

        # call cython, abort if it failed
        cmd = "python2.5 `which cython` --embed-positions --incref-local-binop -I%s -o %s %s"%(os.getcwd(), outfile, f)
        r = run_command(cmd)
        if r:
            return r

        # if cython worked, copy the file to the build directory
        pyx_inst_file = '%s/%s'%(SITE_PACKAGES, f)
        retval = os.system('cp %s %s 2>/dev/null'%(f, pyx_inst_file))
        # we could do this more elegantly -- load the files, use
        # os.path.exists to check that they exist, etc. ... but the
        # *vast* majority of the time, the copy just works. so this is
        # just specializing for the most common use case.
        if retval:
            dirname, filename = os.path.split(pyx_inst_file)
            if not os.path.exists(dirname):
                os.makedirs(dirname)
            retval = os.system('cp %s %s 2>/dev/null'%(f, pyx_inst_file))
            if retval:
                raise OSError, "cannot copy %s to %s"%(f,pyx_inst_file)
        print "%s --> %s"%(f, pyx_inst_file)

    elif f.endswith(('.c','.cc','.cpp')):
        # process C/C++ file
        cmd = "touch %s"%f
        r = run_command(cmd)

    return r

def compile_command_list(ext_modules, deps):
    """
    Computes a list of commands needed to compile and link the
    extension modules given in 'ext_modules'
    """
    queue_compile_high = []
    queue_compile_med = []
    queue_compile_low = []

    for m in ext_modules:
        new_sources = []
        for f in m.sources:
            if f.endswith('.pyx'):
                dep_file, dep_time = deps.newest_dep(f)
                dest_file = "%s/%s"%(SITE_PACKAGES, f)
                dest_time = deps.timestamp(dest_file)
                if dest_time < dep_time:
                    if dep_file == f:
                        print "Building modified file %s."%f
                        queue_compile_high.append([compile_command, (f,m)])
                    elif dep_file == (f[:-4] + '.pxd'):
                        print "Building %s because it depends on %s."%(f, dep_file)
                        queue_compile_med.append([compile_command, (f,m)])
                    else:
                        print "Building %s because it depends on %s."%(f, dep_file)
                        queue_compile_low.append([compile_command, (f,m)])
            new_sources.append(process_filename(f, m))
        m.sources = new_sources
    return queue_compile_high + queue_compile_med + queue_compile_low

## Note: the DependencyTree object created below was designed with
## the intention of pickling it and saving it between builds. However,
## this wasn't robust enough to handle all of the various cases we
## run into with the Sage build process, so caching of this information
## has been temporarily disabled (see trac #4647 and trac #4651). If
## you want to try this out, uncomment all the lines that begin with
## two hash marks below, and comment out the line that says
## "deps = DependencyTree()".

##import cPickle as pickle
##CYTHON_DEPS_FILE='.cython_deps'

if not sdist:
    print "Updating Cython code...."
    t = time.time()
    ## try:
    ##     f = open(CYTHON_DEPS_FILE)
    ##     deps = pickle.load(open(CYTHON_DEPS_FILE))
    ##     f.close()
    ## except:
    ##     deps = DependencyTree()
    deps = DependencyTree()
    queue = compile_command_list(ext_modules, deps)
    execute_list_of_commands(queue)
    ## f = open(CYTHON_DEPS_FILE, 'w')
    ## pickle.dump(deps, f)
    ## f.close()
    print "Finished compiling Cython code (time = %s seconds)"%(time.time() - t)

#########################################################
### Distutils
#########################################################

code = setup(name = 'sage',

      version     =  SAGE_VERSION,

      description = 'Sage: Open Source Mathematics Software',

      license     = 'GNU Public License (GPL)',

      author      = 'William Stein et al.',

      author_email= 'http://groups.google.com/group/sage-support',

      url         = 'http://www.sagemath.org',

      packages    = ['sage',

                     'sage.algebras',
                     'sage.algebras.quatalg',

                     'sage.calculus',

                     'sage.catalogue',

                     'sage.categories',

                     'sage.coding',

                     'sage.combinat',
                     'sage.combinat.crystals',
                     'sage.combinat.designs',
                     'sage.combinat.sf',
                     'sage.combinat.root_system',
                     'sage.combinat.matrices',
                     'sage.combinat.posets',
                     'sage.combinat.species',

                     'sage.combinat.words',

                     'sage.crypto',
                     'sage.crypto.mq',

                     'sage.databases',

                     'sage.ext',
                     'sage.ext.interpreters',

                     'sage.finance',

                     'sage.functions',

                     'sage.geometry',

                     'sage.games',

                     'sage.gsl',

                     'sage.graphs',
                     'sage.graphs.base',

                     'sage.groups',
                     'sage.groups.abelian_gps',
                     'sage.groups.matrix_gps',
                     'sage.groups.perm_gps',
                     'sage.groups.perm_gps.partn_ref',

                     'sage.homology',

                     'sage.interfaces',

                     'sage.lfunctions',

                     'sage.libs',
                     'sage.libs.fplll',
                     'sage.libs.linbox',
                     'sage.libs.mwrank',
                     'sage.libs.ntl',
                     'sage.libs.flint',
                     'sage.libs.pari',
                     'sage.libs.singular',
                     'sage.libs.symmetrica',
                     'sage.libs.cremona',

                     'sage.logic',

                     'sage.matrix',
                     'sage.media',
                     'sage.misc',

                     'sage.modules',

                     'sage.modular',
                     'sage.modular.arithgroup',
                     'sage.modular.abvar',
                     'sage.modular.hecke',
                     'sage.modular.modform',
                     'sage.modular.modsym',
                     'sage.modular.quatalg',
                     'sage.modular.ssmod',
                     'sage.modular.overconvergent',

                     'sage.monoids',

                     'sage.numerical',

                     'sage.plot',
                     'sage.plot.plot3d',

                     'sage.probability',

                     'sage.quadratic_forms',
                     'sage.quadratic_forms.genera',

                     'sage.rings',
                     'sage.rings.number_field',
                     'sage.rings.padics',
                     'sage.rings.polynomial',
                     'sage.rings.polynomial.padics',

                     'sage.tests',

                     'sage.sets',

                     'sage.stats',

                     'sage.stats.hmm',

                     'sage.symbolic',

                     'sage.parallel',

                     'sage.schemes',
                     'sage.schemes.generic',
                     'sage.schemes.jacobians',
                     'sage.schemes.plane_curves',
                     'sage.schemes.plane_quartics',
                     'sage.schemes.elliptic_curves',
                     'sage.schemes.hyperelliptic_curves',

                     'sage.server',
                     'sage.server.simple',
                     'sage.server.notebook',
                     'sage.server.notebook.compress',
                     'sage.server.wiki',
                     'sage.server.trac',

                     'sage.structure',
                     'sage.structure.proof',

                     'sage.dsage',
                     'sage.dsage.tests',
                     'sage.dsage.database',
                     'sage.dsage.database.tests',
                     'sage.dsage.server',
                     'sage.dsage.server.tests',
                     'sage.dsage.interface',
                     'sage.dsage.interface.tests',
                     'sage.dsage.errors',
                     'sage.dsage.twisted',
                     'sage.dsage.twisted.tests',
                     'sage.dsage.dist_functions',
                     'sage.dsage.dist_functions.tests',
                     'sage.dsage.misc',
                     'sage.dsage.misc.tests',
                     'sage.dsage.web',
                     'sage.dsage.scripts',
                     ],

      scripts = ['sage/dsage/scripts/dsage_worker.py',
                 'sage/dsage/scripts/dsage_setup.py',
                 'spkg-debian-maybe',
                ],

      data_files = [('dsage/web/static',
                    ['sage/dsage/web/static/dsage_web.css',
                     'sage/dsage/web/static/dsage_web.js',
                     'sage/dsage/web/static/jquery.js',
                     'sage/dsage/web/static/jquery.tablesorter.pack.js',
                     'sage/dsage/web/static/jquery.history.js',
                     'sage/dsage/web/static/jquery.form.js',
                     'sage/dsage/web/static/asc.gif',
                     'sage/dsage/web/static/desc.gif',
                     'sage/dsage/web/static/bg.gif',
                     'sage/dsage/README.html']),
                    ('dsage/web/',
                    ['sage/dsage/web/index.html'])],

      ext_modules = ext_modules,
      include_dirs = include_dirs)
