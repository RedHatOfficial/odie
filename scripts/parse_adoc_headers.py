#!/usr/bin/env python2.7

import glob
import re

global output_file
output_file = ''

SHEBANG = re.compile("^#!")
BLANK_LINE = re.compile("^\s*$")
COMMENT_LINE = re.compile("^#+")
SLASHES = re.compile("/")

def glob_scripts(pattern):
    global output_file
    for f in glob.glob(pattern):
        with open(f, "r") as script_file:
            #print "> " + f

            anchor = SLASHES.sub("-",f)

            output_file += "#### " + f + " [[" +anchor + "]] \n"
            for line in script_file:
                # skip the shebang line
                if SHEBANG.match(line):
                    continue

                # Stop processing on the first blank line
                if BLANK_LINE.match(line):
                    output_file += "\n"
                    break

                if COMMENT_LINE.match(line):
                    output_file += COMMENT_LINE.sub("",line)

# All paths are relevant from the root directory

output_file += "# Shell Scripts\n"
## TODO: support multiple (sorted) globs
glob_scripts("*.sh")
glob_scripts("scripts/*.sh")
glob_scripts("scripts/*.py")
glob_scripts("scripts/*.pl")

output_file += "# Dynamic Inventory Scripts\n"
glob_scripts("inventory/*.py")

output_file += "# Ansible Playbooks\n"
glob_scripts("odie-*.yml")
glob_scripts("playbooks/*/*.yml")

output_file += "# Ansible Roles\n"
glob_scripts("roles/*/tasks/main.yml")

print output_file
