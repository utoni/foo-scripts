#!/usr/bin/env python

import sys, os.path
import urllib, shelve
import time, datetime

from string import rjust


CONFIG_USER     = 'portalcheck'
CONFIG_NAME     = 'portal'
CONFIG_DBFILE   = '/var/lib/portalcheck/shelvedb'
CONFIG_CHECKURL = 'https://portal.imn.htwk-leipzig.de'
CONFIG_DICTMAX  = 10

TYPE_ONLINE        = 0
TYPE_ONLINE_AGAIN  = 1
TYPE_OFFLINE       = 2
TYPE_OFFLINE_AGAIN = 3


def dbg(dbgstr):
    if sys.flags.debug:
        print('>>> pcheck: ' + str(dbgstr))


class PortalObject(object):
    def __init__(self, timestamp, httpresp, errstr=None):
        self.timestamp = float(timestamp)
        self.httpresp = int(httpresp)
        self.errstr = str(errstr)


class PortalCheck(object):
    DICT_LAST = 'last'
    DICT_CURRENT_TYPE = 'cur_type'
    DICT_CURRENT_INDEX = 'cur_index'

    def __init__(self, uri, dbpath):
        self.uri = uri
        dbpath += '-' + CONFIG_NAME
        try:
            self.dbfilename = dbpath
            self.shelvedb = shelve.open(self.dbfilename)
        except:
            self.dbfilename = './' + os.path.basename(dbpath)
            self.shelvedb = shelve.open(self.dbfilename)
        try:
            po = self.shelvedb[self.DICT_LAST]
        except KeyError:
            dbg('Init shelvedb')
            self.shelvedb[self.DICT_LAST] = PortalObject(time.time(), 200)
            self.shelvedb[self.DICT_CURRENT_TYPE] = TYPE_ONLINE
            self.shelvedb[self.DICT_CURRENT_INDEX] = 0
        dbg('Open ' + self.dbfilename)

    def cleanup(self):
        self.shelvedb.close()

    def doCheck(self):
        sock = urllib.urlopen(str(self.uri))
        resp = sock.getcode()
        sock.close()
        return resp

    def loadLast(self):
        return self.shelvedb[self.DICT_LAST]
    def storeLast(self, portalObject):
        self.shelvedb[self.DICT_LAST] = portalObject

    def loadObject(self, index):
        return self.shelvedb[str(index)]
    def storeObject(self, portalObject):
        ind = self.loadIndex()
        self.shelvedb[str(ind)] = portalObject
        if ind + 1 == CONFIG_DICTMAX:
            ind = 0
        else:
            ind = ind + 1
        self.storeIndex(ind)

    def loadType(self):
        return int(self.shelvedb[self.DICT_CURRENT_TYPE])
    def storeType(self, onlineType):
        self.shelvedb[self.DICT_CURRENT_TYPE] = int(onlineType)

    def loadIndex(self):
        return int(self.shelvedb[self.DICT_CURRENT_INDEX])
    def storeIndex(self, index):
        self.shelvedb[self.DICT_CURRENT_INDEX] = index

    def listObjects(self):
        for (key, value) in sorted(self.shelvedb.iteritems()):
            if type(value) == PortalObject:
                td = time.localtime(value.timestamp)
                outdate = '%02d.%02d.%04d - %02d:%02d:%02d' % (td.tm_mday, td.tm_mon, td.tm_year, td.tm_hour, td.tm_min, td.tm_sec)
                outval = outdate + ' ' + rjust(str(value.httpresp), 3, ' ')
            else:
                outval = str(value)
            print('Key: [%s] | Value: [%s]' % ( rjust(key, 9, ' '), rjust(outval, 25, ' ') ))

    def doPortalCheck(self):
        errstr = None
        try:
            httpresp = self.doCheck()
        except IOError as err:
            httpresp = -1
            errstr = str(err)
        curtime = time.time()
        po = PortalObject(curtime, httpresp)
        ct = self.loadType()
        if httpresp is 200:
            dbg('Ok')
            if ct == TYPE_ONLINE:
                self.storeType(TYPE_ONLINE_AGAIN)
            elif ct != TYPE_ONLINE_AGAIN:
                self.storeType(TYPE_ONLINE)
                last = self.loadLast()
                self.storeObject(last)
                self.storeLast(po)
            self.shelvedb.sync()
        else:
            dbgstr = str()
            dbgstr += ' (' + errstr + ')' if errstr is not None else ''
            dbg('Err ' + str(httpresp) + dbgstr)
            if ct == TYPE_OFFLINE:
                self.storeType(TYPE_OFFLINE_AGAIN)
            elif ct != TYPE_OFFLINE_AGAIN:
                self.storeType(TYPE_OFFLINE)
                last = self.loadLast()
                self.storeObject(last)
                self.storeLast(po)


if __name__ == '__main__':
    os.umask(0117)
    if os.getuid() == 0:
        oldmask = os.umask(0)
        try:
            os.mkdir(os.path.dirname(CONFIG_DBFILE), 0755)
        except:
            pass
        os.umask(oldmask)
        pc = PortalCheck(CONFIG_CHECKURL, CONFIG_DBFILE)
        dbg('dropping root privileges')
        import pwd
        pwd = pwd.getpwnam(CONFIG_USER)
        os.chown(pc.dbfilename, 0, pwd.pw_gid)
    else:
        pc = PortalCheck(CONFIG_CHECKURL, CONFIG_DBFILE)

    pc.doPortalCheck()
    if sys.flags.debug:
        pc.listObjects()
    pc.cleanup()
