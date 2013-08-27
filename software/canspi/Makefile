#
# Copyright (C) 2013 Bernd Ocklin <bernd@vyacht.net>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=canspi
PKG_VERSION:=0.2.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tgz

include $(INCLUDE_DIR)/package.mk

define Package/canspi
	SECTION:=net
	DEPENDS:=+kmod-spi-dev +libstdcpp
	CATEGORY:=Network
	TITLE:=simple spi driver to a can board
	MAINTAINER:=Bernd Ocklin <bernd@vyacht.net>
endef

define Package/canspi/description
  Needs more description.
endef

LIBS:=

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	LIBS="$(LIBS)"

define Build/Compile
$(call Build/Compile/Default)
	echo $(TARGET_LDFLAGS)
endef

define Package/canspi/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/canspi $(1)/usr/sbin/
	$(INSTALL_DATA) ./files/canspi.config $(1)/etc/config/canspi
endef

$(eval $(call BuildPackage,canspi))
