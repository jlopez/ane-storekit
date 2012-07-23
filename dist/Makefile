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

SRCDIR = $(ROOT)/src/test
SRC_MAIN = $(SRCDIR)/test.mxml
APP_XML_IN = $(SRCDIR)/app.xml.in
ANES = $(ANE)
OTHER_RESOURCES =

################## ANE Config
EXT_ID = com.jesusla.storekit
ANE_IOS_LIB_SOURCES = $(call findcfiles,../src/ios)
ANE_IOS_LIB_CFLAGS = -I../src/ios/ane/src
ANE_BUNDLED_LIBS = $(NATIVE_LIBRARY_LIB)

NATIVE_LIBRARY_LIB = libNativeLibrary.a
NATIVE_LIBRARY_LIB_SOURCES = $(call findcfiles,../src/ios/ane/src)
NATIVE_LIBRARY_LIB_CFLAGS = -I$(FLEX_SDK)/include

include mk/ane.mk
