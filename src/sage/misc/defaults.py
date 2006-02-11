"""
Defaults

AUTHORS: William Stein and David Kohel
"""

#*****************************************************************************
#       Copyright (C) 2004 William Stein <wstein@ucsd.edu>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#
#    This code is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    General Public License for more details.
#
#  The full text of the GPL is available at:
#
#                  http://www.gnu.org/licenses/
#*****************************************************************************

# default variable name
var_name = 'x'

def variable_names(n, name=None):
    if name is None:
        name = var_name
    n = int(n)
    if n == 1:
        return [name]
    return tuple(['%s_%s'%(name,i) for i in range(n)])

def latex_variable_names(n, name=None):
    if name is None:
        name = var_name
    n = int(n)
    if n == 1:
        return [name]
    return tuple(['%s_{%s}'%(name,i) for i in range(n)])

def set_default_variable_name(name, separator='_'):
    r"""
    Change the default variable name and separator.
    """
    global var_name, var_sep
    var_name = str(name)
    var_sep = str(separator)
