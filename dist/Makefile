################## SWF Config
APP_ID = $(EXT_ID).test
NAME = StoreKit
COMPANY = company
VERSION = 1.0
TESTFLIGHT_API_TOKEN = API_TOKEN_HERE
TESTFLIGHT_TEAM_TOKEN = TEAM_TOKEN_HERE
TESTFLIGHT_DLS = DIST_LISTS_HERE
TESTFLIGHT_NOTIFY = False
FACEBOOK_APP_ID = FB_APP_ID_HERE
WIKI_GIT_URL = git@github.com:jlopez/ane-storekit.wiki.git

STORE_PROVIDER = GOOGLE_OR_AMAZON
GOOGLE_IDENTITY = GOOGLE_PUBLIC_KEY

SRCDIR = $(ROOT)/src/test
SRC_MAIN = $(SRCDIR)/test.mxml
APP_XML_IN = $(SRCDIR)/app.xml.in
ANES = $(ANE) ../lib/ane/dist/nativelibrary.ane
OTHER_RESOURCES =

################## ANE Config
EXT_ID = com.jesusla.storekit
ANE_IOS_LIB_SOURCES = $(call findcfiles,../src/ios)
ANE_IOS_LIB_CFLAGS = -I../lib/ane/src/ios

NATIVE_LIBRARY_LIB = libNativeLibrary.a
NATIVE_LIBRARY_LIB_SOURCES = $(call findcfiles,../lib/ane/src/ios)
NATIVE_LIBRARY_LIB_CFLAGS = -I$(FLEX_SDK)/include

ANE_ANDROID_JAR_SOURCES = ../src/android
ANE_ANDROID_JAR_CLASSPATH = $(NATIVE_LIBRARY_JAR)

NATIVE_LIBRARY_JAR = nativeLibrary.jar
NATIVE_LIBRARY_JAR_SOURCES = ../lib/ane/src/android

include mk/ane.mk
