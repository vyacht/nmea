#
# Copyright (C) 2013 Bernd Ocklin <bernd@vyacht.net>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=iomode
PKG_VERSION:=0.1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/iomode
	SECTION:=net
	DEPENDS:=+io
	CATEGORY:=Network
	TITLE:=iomode sets desired io mode for RT305x UART/GPIO
	MAINTAINER:=Bernd Ocklin <bernd@vyacht.net>
endef

define Package/iomode/description
  A tiny package with a config file and init script to set io mode at startup.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/iomode/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/iomode.init $(1)/etc/init.d/iomode
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/iomode.config $(1)/etc/config/iomode
endef

define Package/iomode/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
        echo "Enabling rc.d symlink for iomode"
        /etc/init.d/iomode enable
fi
exit 0
endef

define Package/iomode/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
        echo "Removing rc.d symlink for iomode"
        /etc/init.d/iomode disable
fi
exit 0
endef

$(eval $(call BuildPackage,iomode))
