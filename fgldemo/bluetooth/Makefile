# Property of Four Js*
# (c) Copyright Four Js 2017, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

# if GMI is not present,only the .42m .42f files are made
# GMI only:
# calling make without parameters simply creates a GMI .ipa for the device
# (simulator : no bluetooth available)
# use "make gmi.install" to install on the device

BUNDLE_IDENTIFIER   = com.4js.cdvble
APPNAME             = CDVBlue
TARGET              = phone
MODE                = debug
BUILD_FGL           = no
IDENTITY="(59W7RY75ZU)"
PROVISIONING_PROFILE=/Users/leo/Library/MobileDevice/Provisioning\ Profiles/4js_wildcard

MODULES  = $(patsubst %.4gl, %.42m, $(wildcard *.4gl))
FORMS    = $(patsubst %.per, %.42f, $(wildcard *.per))

%.42m: %.4gl
	fglcomp -M $*

%.42f: %.per
	fglform -M $*

all:: $(MODULES) $(FORMS)

#include the generic Makefile-gmi with a lot of targets
ifndef GMIDIR
GMIDIR=$(FGLDIR)
endif
MAKEFILE_GMI=$(shell GMIDIR="$(GMIDIR)";echo $${GMIDIR// /\\ })/lib/Makefile-gmi
-include $(MAKEFILE_GMI)

# temporary workaround the transition from CDV prefixed plugin lib names to
# github lib names

USER_EXTENSION_LIBS=$(shell GMIDIR="$(GMIDIR)";echo $${GMIDIR// /\\ })/lib/cordova/CDVBLE.a
ifeq ($(wildcard $(USER_EXTENSION_LIBS)),)
# new way
  USER_EXTENSION_LIBS = -lcordova-plugin-bluetoothle
endif

main.42m: bgevents.42f detail.42f
