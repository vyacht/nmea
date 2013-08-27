#
# Copyright (C) 2013 Bernd Ocklin <bernd@vyacht.net>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gpsd-util
PKG_VERSION:=0.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tgz

PKG_BUILD_DEPENDS:=libgps

include $(INCLUDE_DIR)/package.mk

define Package/gpsd-util
	SECTION:=net
	DEPENDS:=+libgps
	CATEGORY:=Network
	TITLE:=gpsd-util supports to read date/time from gpsd
	MAINTAINER:=Bernd Ocklin <bernd@vyacht.net>
endef

define Package/gpsd-util/description
  A tiny package to allow reading date/time from gpsd (and setting system time).
  The only reason for this package is the lacking support of NTP/GPSD in openwrt.

  The only reason its called gpsd-util is that it might be extended one day.
endef

LIBS:=-lgps

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	LIBS="$(LIBS)"

define Build/Compile
$(call Build/Compile/Default)
	echo $(TARGET_LDFLAGS)
endef

define Package/gpsd-util/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/gpsd-util $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,gpsd-util))
