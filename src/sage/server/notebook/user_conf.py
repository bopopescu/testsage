# This file is part of the OLD Sage notebook and is NOT actively developed,
# maintained, or supported.  As of Sage v4.1.2, all notebook development has
# moved to the separate Sage Notebook project:
#
# http://nb.sagemath.org/
#
# The new notebook is installed in Sage as an spkg (e.g., sagenb-0.3.spkg).
#
# Please visit the project's home page for more information, including directions on
# obtaining the latest source code.  For notebook-related development and support,
# please consult the sage-notebook discussion group:
#
# http://groups.google.com/group/sage-notebook

"""nodoctest
"""

import conf

defaults = {'max_history_length':1000,
            'default_system':'sage',
            'autosave_interval':60*60,   # 1 hour in seconds
            'default_pretty_print': False
            }

class UserConfiguration(conf.Configuration):
    def defaults(self):
        return defaults
