#!/usr/bin/python

# This software is Copyright (c) 2008-2011
# Adam Maxwell. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# - Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 
# - Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in
# the documentation and/or other materials provided with the
# distribution.
# 
# - Neither the name of Adam Maxwell nor the names of any
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import os, sys
import subprocess
import tempfile
import glob
import shutil

import datetime

import smtplib
from email.mime.text import MIMEText

#
# NOTE: various paths are hard coded here at the top of the file.
#
# Do not edit this file unless you're doing nightly builds.  The script can 
# certainly be improved or redesigned, but it's working and has been tested
# as written.  This is mainly in svn to provide a persistent backup.
# 
# See the end of the file for a launchd plist and installation instructions.
#

# svn checkout directory
SOURCE_DIR="/Volumes/Local/Users/amaxwell/build/bibdesk-clean"

# create a private temporary directory
TEMP_DIR=tempfile.mkdtemp("build_bibdesk_py")
OBJROOT = os.path.join(TEMP_DIR, "objroot")
SYMROOT = os.path.join(TEMP_DIR, "symroot")
XCODEBUILD = "/Xcode3/usr/bin/xcodebuild"

# wherever the final app ends up
BUILT_APP = os.path.join(SYMROOT, "Release", "BibDesk.app")

TEMP_DMG = os.path.join(TEMP_DIR, "BibDesk.dmg")

# number of days to keep files on the server
AGE_LIMIT = 14

# nightly build ftp server
HOST_NAME = 'michael-mccracken.net'
SERVER_PATH = "/users/home/michaelmccracken/web/public/bibdesk/nightlies"

# path for error logging (log is e-mailed in case of failure)
LOG_PATH=os.path.join(TEMP_DIR, "build_bibdesk_py.log")

# for error reporting when the script fails
EMAIL_ADDRESS="amaxwell@mac.com"
SMTP_SERVER="smtp.olypen.com"

# create a dictionary of config values
buildConfigPath = os.path.join(SOURCE_DIR, "build_config.txt")
buildConfigFile = open(buildConfigPath)
buildConfig = {}
for configLine in buildConfigFile:
    key, value = configLine.split()
    # always store as string
    buildConfig[key] = value

def removeTemporaryDirectory():
    shutil.rmtree(TEMP_DIR)

def sendEmailAndRemoveTemporaryDirectory():
    print 'sending e-mail notification that build_bibdesk.py failed'
    logFile = open(LOG_PATH, "rb")
    msg = MIMEText(logFile.read())
    logFile.close()

    msg["Subject"] = "build_bibdesk.py failure"
    msg["From"] = EMAIL_ADDRESS
    msg["To"] = EMAIL_ADDRESS
    try:
        s = smtplib.SMTP(SMTP_SERVER)
        s.sendmail(EMAIL_ADDRESS, [EMAIL_ADDRESS], msg.as_string())
        s.quit()
    except Exception, e:
        print 'Failed to send mail:', e
    finally:
        removeTemporaryDirectory()
    
# return dictionary with keys "username" and "password" from keychain
def getUserAndPass():
    try:
        pwtask = subprocess.Popen(["security", "find-internet-password", "-g", "-s", HOST_NAME], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        [output, error] = pwtask.communicate()
        pwoutput = output + error
        pwlines = pwoutput.splitlines()
        username = ''
        password = ''
        for line in pwlines:
            line = line.lstrip()
            if line.startswith('"acct"<blob>='):
                username = line.replace('"acct"<blob>=', '').strip('"')

            if line.startswith('password: '):
                password = line.replace('password: ', '').strip('"')
    except Exception, e:
        print e
            
    return { "username":username, "password":password }

def runSvnUpdate():
    cmd = ["/usr/bin/svn", "up"]
    try:
        logFile = open(LOG_PATH, "a", -1)
        x = subprocess.Popen(cmd, cwd=SOURCE_DIR, stdout=logFile, stderr=logFile)
        rc = x.wait()
    except Exception, e:
        rc = 1
        logFile.write('svn update failed')
    logFile.close()
    return rc

def runVersionBump():
    cmd = ["/usr/bin/agvtool", "bump"]
    try:
        logFile = open(LOG_PATH, "a", -1)
        x = subprocess.Popen(cmd, cwd=SOURCE_DIR, stdout=logFile, stderr=logFile)
        rc = x.wait()
    except Exception, e:
        rc = 1
        logFile.write('agvtool failed')
    logFile.close()
    return rc
    
def runXcodeBuild():
    cmd = [XCODEBUILD, "-configuration", "Release", "-target", "BibDesk", "clean", "build", "SYMROOT=" + SYMROOT, "OBJROOT=" + OBJROOT]
    try:
        logFile = open(LOG_PATH, "a", -1)
        x = subprocess.Popen(cmd, cwd=SOURCE_DIR, stdout=logFile, stderr=logFile)
        rc = x.wait()
    except Exception, e:
        rc = 1
        logFile.write('xcodebuild failed')
    logFile.close()
    return rc

def runXcodeUnitTest():
	# nb right now UnitTests only valid for Debug config
    cmd = [XCODEBUILD, "-configuration", "Debug", "-target", "UnitTests", "clean", "build", "SYMROOT=" + SYMROOT, "OBJROOT=" + OBJROOT]
    try:
        logFile = open(LOG_PATH, "a", -1)
        x = subprocess.Popen(cmd, cwd=SOURCE_DIR, stdout=logFile, stderr=logFile)
        rc = x.wait()
    except Exception, e:
        rc = 1
        logFile.write('xcodebuild unit tests failed')
    logFile.close()
    return rc

# disable all localizations except English, since they're usually broken before release
def disableLocalizations(pathToApplicationBundle):
    
    disabledResourcesPath = os.path.join(pathToApplicationBundle, "Contents", "Resources Disabled")
    
    if os.path.exists(disabledResourcesPath) is False:
        os.mkdir(disabledResourcesPath)

    resourcesPath = os.path.join(pathToApplicationBundle, "Contents", "Resources")    
    allLocalizations = glob.glob(resourcesPath + "/*.lproj")
    
    logFile = open(LOG_PATH, "a")
    
    for loc in allLocalizations:
        
        if loc.endswith(("en.lproj", "English.lproj")) is False:
            loc = os.path.join(resourcesPath, loc)
            dst = os.path.join(disabledResourcesPath, os.path.basename(loc))
            shutil.move(loc, dst)
            logFile.write("moving %s to %s\n" % (loc, dst))
            #print "moving %s to %s" % (loc, dst)
            
    logFile.close()

def createDiskImage(imageName):
            
    # create an image from the app folder
    cmd = ["/usr/bin/hdiutil", "create", "-srcfolder", BUILT_APP, TEMP_DMG]
    try:
        logFile = open(LOG_PATH, "a", -1)
        x = subprocess.Popen(cmd, cwd=TEMP_DIR, stdout=logFile, stderr=logFile)
        if x.wait() != 0:
            logFile.write("Failure: " + cmd)
            logFile.close()
            sendEmailAndRemoveTemporaryDirectory()
            exit(1)
    
        # convert the image and compress it
        cmd = ["/usr/bin/hdiutil", "convert", TEMP_DMG, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", imageName]
        x = subprocess.Popen(cmd, cwd=TEMP_DIR, stdout=logFile, stderr=logFile)
        if x.wait() != 0:
            logFile.write("Failure: " + cmd)
            logFile.close()
            sendEmailAndRemoveTemporaryDirectory()
            exit(1)
        
        # set the evil internet-enable bit
        cmd = ["/usr/bin/hdiutil", "internet-enable", "-YES", imageName]
        x = subprocess.Popen(cmd, cwd=TEMP_DIR, stdout=logFile, stderr=logFile)
        if x.wait() != 0:
            logFile.write("Failure: " + cmd)
            logFile.close()
            sendEmailAndRemoveTemporaryDirectory()
            exit(1)
        logFile.close()
    except Exception, e:
        logFile.close()
        sendEmailAndRemoveTemporaryDirectory()
        exit(1)
    
# update the source tree
rc = runSvnUpdate()
if rc != 0:
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)

# run the unit test target first, since it builds quicker
rc = runXcodeUnitTest()
if rc != 0:
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)
    
# bump the project version with agvtool
rc = runVersionBump()
if rc != 0:
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)

# clean and build the Xcode project
rc = runXcodeBuild()
if rc != 0:
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)

# the build function should have returned nonzero in this case, but check again
if os.access(BUILT_APP, os.F_OK) == False:
    logFile = open(LOG_PATH, "a")
    logFile.write("No application at " + BUILT_APP)
    logFile.close()
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)
    
# disable localizations if needed
if int(buildConfig["disableLocalizations"]) != 0:
    disableLocalizations(BUILT_APP)      

# create a name for the disk image based on today's date
imageName = datetime.date.today().strftime("%Y%m%d")
imageName = os.path.join(TEMP_DIR, "BibDesk-" + imageName + ".dmg")
createDiskImage(imageName)

# takes a string of the form "20081102" (year month day) and returns a date object
def dateFromString(datePart):
    year = datePart[0:4]
    month = datePart[4:6]
    day = datePart[6:8]
    theDate = datetime.date(int(year), int(month), int(day))
    return theDate

def removeOldFiles(ftp):
    try:
        ftp.chdir(SERVER_PATH)
        dirlist = ftp.listdir()
        for fileName in dirlist:
            if fileName.startswith("BibDesk-") and fileName.endswith(".dmg"):
                datePart = fileName.replace("BibDesk-", "")
                datePart = datePart.replace(".dmg", "")
                if datePart.isdigit() and len(datePart) == 8:
                    # check to see how old the file is, based on its name
                    diff = datetime.date.today() - dateFromString(datePart)
                    if diff.days >= AGE_LIMIT:
                        ftp.unlink(fileName)
                else:
                    # file had BibDesk- as prefix, so assume it's a bad filename
                    ftp.unlink(fileName)
    except Exception, e:
        print "Failed deleting old files", e

# get user/pass from keychain
d = getUserAndPass()
if len(d["username"]) == 0 or len(d["password"]) == 0:
    # truncate the log file
    logFile = open(LOG_PATH, "w")
    logFile.write("Failed getting username and password from keychain")
    logFile.close()
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)

# create the ftp object and log in...
sftp = None
try:
    import paramiko
    t = paramiko.Transport((HOST_NAME, 22))
    t.connect(username=d["username"], password=d["password"])
    sftp = paramiko.SFTPClient.from_transport(t)
except Exception, e:
    # truncate the log file
    logFile = open(LOG_PATH, "w")
    logFile.write("Failed sftp connection with exception " + str(e) + "\n")
    logFile.close()
    sendEmailAndRemoveTemporaryDirectory()
    exit(1)

# remove old files before uploading
removeOldFiles(sftp)

# now try to put the new file in place
try:
    sftp.chdir(SERVER_PATH)
    sftp.put(imageName, os.path.basename(imageName))
except Exception, e:
    # truncate the log file
    logFile = open(LOG_PATH, "w")
    logFile.write("Failed to upload file with exception " + str(e) + "\n")
    logFile.write("File was " + imageName)
    logFile.close()
    sendEmailAndRemoveTemporaryDirectory()
finally:
    sftp.close()
    # close the connection or else we don't exit because of a select() loop hanging around
    t.close()
    removeTemporaryDirectory()
  
#
# Sourceforge has broken ssh support such that this step will no longer work.  Hopefully
# they'll restore cron support at some time so this can be handled properly on the server.
#    
# ssh amaxwell@shell.sf.net '/bin/sh /home/groups/b/bi/bibdesk/updateHelp.sh > /home/groups/b/bi/bibdesk/updateHelp.log'
#

#
# Save this plist as ~/Library/LaunchAgents/com.mac.amaxwell.build_bibdesk.plist
# 
# Load: `launchctl load -w ~/Library/LaunchAgents/com.mac.amaxwell.build_bibdesk.plist`
# Unload: `launchctl unload -w ~/Library/LaunchAgents/com.mac.amaxwell.build_bibdesk.plist`
#

# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#   <key>AbandonProcessGroup</key>
#   <true/>
#   <key>Label</key>
#   <string>com.mac.amaxwell.build_bibdesk</string>
#   <key>LimitLoadToSessionType</key>
#   <array>
#       <string>Aqua</string>
#       <string>LoginWindow</string>
#   </array>
#   <key>LowPriorityIO</key>
#   <true/>
#   <key>Nice</key>
#   <integer>5</integer>
#   <key>ProgramArguments</key>
#   <array>
#       <string>/usr/bin/python</string>
#       <string>/Volumes/Local/Users/amaxwell/build/bibdesk-clean/build_bibdesk.py</string>
#   </array>
#   <key>StartCalendarInterval</key>
#   <dict>
#       <key>Hour</key>
#       <integer>22</integer>
#       <key>Minute</key>
#       <integer>55</integer>
#   </dict>
# </dict>
# </plist>
