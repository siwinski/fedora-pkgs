#!/usr/bin/env python

import re
import sys
import urllib2


def main():
    prefixes = sys.argv
    prefixes.pop(0)  # Get rid of script name

    pkgs = []

    for prefix in prefixes:
        req = urllib2.Request('https://admin.fedoraproject.org/pkgdb/acls/list/?searchwords=' + prefix + '*&packages_tgp_limit=5000')
        response = urllib2.urlopen(req)
        page = response.read()

        for t in re.findall('/name/' + prefix + '[-_a-z0-9]*', page, re.IGNORECASE):
            t = t.lstrip('/name/')
            if t not in pkgs:
                pkgs.append(t)

    pkgs.sort()
    print ' '.join(pkgs)


if __name__ == '__main__':
    main()
