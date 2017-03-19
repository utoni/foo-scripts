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

CONFIG_MAIL_FROM = 'toni.uhlig@stud.htwk-leipzig.de'
CONFIG_MAIL_TO   = 'toni.uhlig@stud.htwk-leipzig.de'
CONFIG_MAIL_CC   = [ 'toni.uhlig@stud.htwk-leipzig.de' ]
CONFIG_MAIL_HOST = 'localhost'

CONFIG_MAIL_SUBJ = 'Portal state changed: %s'
CONFIG_MAIL_OFF  = ''+ \
    'Dies ist eine automatisch generierte E-Mail.\n\n'+ \
    'Die URI %s ist seit dem %s nicht mehr erreichbar.\n'+ \
    'Letzter HTTP response code: %s\n\n'+ \
    'Sie werden benachrichtigt, wenn das Portal wieder erreichbar ist.\n'
CONFIG_MAIL_ON   = ''+ \
    'Dies ist eine automatisch generierte E-Mail.\n\n'+ \
    'Die URI %s ist seit %s wieder erreichbar.\n'+ \
    'Offline Dauer: %s\n'

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
    DATETIME_FMT = '%02d.%02d.%04d - %02d:%02d:%02d'
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

    def doTimeFormat(self, tm):
        lt = time.localtime(tm);
        return '%02d.%02d.%04d - %02d:%02d:%02d' % (lt.tm_mday, lt.tm_mon, lt.tm_year, lt.tm_hour, lt.tm_min, lt.tm_sec)

    def sendMail(self):
        typ = self.loadType()
        typstr = 'UNKNOWN'
        mailcon = 'EMPTY'
        last = self.loadLast()
        tdstr = self.doTimeFormat(last.timestamp)
        if typ == TYPE_ONLINE or typ == TYPE_ONLINE_AGAIN:
            typstr = 'ONLINE'
            ind = self.loadIndex()
            forelast = self.loadObject(ind - 1)
            offdays = divmod(last.timestamp - forelast.timestamp, 86400)
            offhrs = divmod(offdays[1], 3600)
            offmins = divmod(offhrs[1], 60)
            offsecs = offmins[1]
            offstr = '%d Tag%c, %d Stunde%c, %d Minute%c, %d Sekunde%c' % \
                (offdays[0], 'e' if offdays[0] != 1 else ' ', \
                 offhrs[0], 'n' if offhrs[0] != 1 else ' ', \
                 offmins[0], 'n' if offmins[0] != 1 else ' ', \
                 offsecs, 'n' if offsecs != 1 else ' ')
            mailcon = CONFIG_MAIL_ON % (self.uri, tdstr, offstr)
        elif typ == TYPE_OFFLINE or typ == TYPE_OFFLINE_AGAIN:
            typstr = 'OFFLINE'
            httpresp = str(last.httpresp) if last.httpresp != -1 else 'connection error (' + str(last.errstr) + ')'
            mailcon = CONFIG_MAIL_OFF % (self.uri, tdstr, httpresp)
        else:
            return
        subj = CONFIG_MAIL_SUBJ % (typstr)
        dbg(str(subj))
        dbg(str(mailcon))
        import smtplib
        from email.mime.text import MIMEText
        msg = MIMEText(str(mailcon))
        msg['Subject'] = str(subj)
        msg['From'] = CONFIG_MAIL_FROM
        msg['To'] = CONFIG_MAIL_TO
        msg['Cc'] = ', '.join(CONFIG_MAIL_CC)
        s = smtplib.SMTP(CONFIG_MAIL_HOST)
        s.sendmail(CONFIG_MAIL_FROM, [CONFIG_MAIL_TO]+CONFIG_MAIL_CC, msg.as_string())

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
        return self.shelvedb[str( (int(index) % CONFIG_DICTMAX) )]
    def storeObject(self, portalObject):
        ind = self.loadIndex()
        self.shelvedb[str(ind)] = portalObject
        ind = (ind + 1) % CONFIG_DICTMAX
        self.storeIndex(ind)

    def loadType(self):
        return int(self.shelvedb[self.DICT_CURRENT_TYPE])
    def storeType(self, onlineType):
        self.shelvedb[self.DICT_CURRENT_TYPE] = int(onlineType)

    def loadIndex(self):
        return int(self.shelvedb[self.DICT_CURRENT_INDEX] % CONFIG_DICTMAX)
    def storeIndex(self, index):
        self.shelvedb[self.DICT_CURRENT_INDEX] = (index % CONFIG_DICTMAX)

    def listObjects(self):
        for (key, value) in sorted(self.shelvedb.iteritems()):
            if type(value) == PortalObject:
                outdate = self.doTimeFormat(value.timestamp)
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
        po = PortalObject(curtime, httpresp, errstr)
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
                self.sendMail()
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
                self.sendMail()


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
