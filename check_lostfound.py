#!/usr/bin/python
#
# usage: check_lostfound.py <pathtolost+found> [make_it_so]
#
# Purpose: to find files in lost+found and trying to restore 
# original files by comparing ls-md5sum-files.txt (generated by
# make-lsLR.sh
# Option make_it_so cause the data actually being written/moved
# whereas the script runs in dry mode per default. 
# 
# Author: Ingo Juergensman - http://blog.windfluechter.net
# License: GPL v2, see http://gnu.org for details. 
#

from string import *
import sys, os
from os.path import *
import string
	
if len(sys.argv)<>4:
	print "usage: "+sys.argv[0]+" <source> <target> <mode>"
	sys.exit(1)
else:
	mnt = sys.argv[1]
	target = sys.argv[2]
	mode   = sys.argv[3]

dirs="/root/ls-md5sum-dirs.txt"
source="/root/ls-md5sum-files.txt"
lost="/root/lostfound-files.txt"
print "Creating list of files in %s/lost+found" % mnt
cmd = 'find %s/lost+found -type f -printf "%%s %%U:%%G %%#m " -exec nice -15 md5sum {} \; > /root/lostfound-files.txt' % mnt
os.system(cmd)

d = open(dirs, 'r+')
f = open(source, 'r+')
l = open(lost, 'r+')

sfiles={}
lfiles=[]


# create the missing directories first
print "Creating missing directories in %s" % target
for entry in d: 
	ugid=string.split(entry, " ", 2)[0]
	perm=string.split(entry, " ", 2)[1]
	pfad="%s%s" % (target,string.split(replace(entry, "\n", ""), " ", 2)[2:][0])
	res = isdir(pfad)
	if (os.path.exists(pfad) and os.path.isdir(pfad)):
		print "%s exists... " % pfad
	else:
		cmd = "%s %s - mkdir %s" % (ugid, perm, pfad)
		print cmd 
		try: 
			if mode == "make_it_so":
				os.makedirs(pfad)
				uid, gid = string.split(ugid, ":")
				os.chown(pfad, int(uid), int(gid))
				os.chmod(pfad, int(perm))
		except OSError:
			print "%s exists... " % pfad 
			
# now parse /root/ls-md5sum-files.txt to get 
# md5sum and /path/to/filename pairs
for line in f: 
	line=replace(line, "\n", "")
	#size1 = split(line)[0]
	#ugid1 = split(line)[1]
	#perm1 = split(line)[2]
	md5s1 = string.split(line)[3]
	#path1 = split(line)[4]
	sfiles[md5s1]  = strip(str(string.split(line," ", 4)[4:][0]))

# next: do the same to the files in lost+found
for line in l: 
	size2 = string.split(line)[0]
	ugid2 = string.split(line)[1]
	perm2 = string.split(line)[2]
	md5s2 = string.split(line)[3]
	path2 = strip(str(string.split(replace(line, "\n", "")," ", 4)[4:][0]))
	s = "%s %s %s %s %s" % (md5s2, ugid2, perm2, size2, path2)
	lfiles.append(s)


# finally look at lost+found and copy the files 
# to the appropriate place. Instead of copying 
# the files can be moved as well, but to copy is 
# safer in case of mistakes or errors
for lf in lfiles:
	md5s  = string.split(lf)[0]
	lfile = string.split(lf, " ", 4)[4:][0]
	if sfiles.has_key(md5s):
		if os.path.exists(target+sfiles[md5s]):
			pass
		else:
			targetfile = sfiles[md5s]
			print "restoring %s%s " % (target, targetfile)  #lfile
			cmd = 'cp -p "%s" "%s%s"' % (lfile, target, targetfile)
			if mode == "make_it_so":
				os.system(cmd)
			del sfiles[md5s]

	
	

