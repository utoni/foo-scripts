#!/usr/bin/env python

import os

start_pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
print 'PIDs', str(start_pids)

while True:
    cur_pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
    for pid in cur_pids:
        if pid in start_pids:
            continue
        try:
            cmdline = open(os.path.join('/proc', pid, 'cmdline'), 'rb').read().replace('\x00', ' ')

            if len(cmdline) == 0 or cmdline.startswith('bash') is True or \
                    cmdline.endswith('sh') is True:
                continue
            start_pids.append(pid)
            outstr = 'NEW[%s]: ' % (pid) + cmdline
            print outstr
        except IOError:
            print 'PID', pid, '!exist'
            continue
