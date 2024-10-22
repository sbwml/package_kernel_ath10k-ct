include $(TOPDIR)/rules.mk

PKG_NAME:=ath10k-ct
PKG_RELEASE:=1

PKG_LICENSE:=GPLv2
PKG_LICENSE_FILES:=

PKG_SOURCE_URL:=https://github.com/greearb/ath10k-ct.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2024-07-30
PKG_SOURCE_VERSION:=ac71b14dc93aef0af6f0f24808b0afb673eaa5f5
PKG_MIRROR_HASH:=325f0bc22bc6f1e047cc77b3c7d7ed5aa7edc9bc8dc7253ec30ce748d69564dc

# Build the 6.10 ath10k-ct driver version.
# Probably this should match as closely as
# possible to whatever mac80211 backports version is being used.
CT_KVER="-6.10"

PKG_MAINTAINER:=Ben Greear <greearb@candelatech.com>
PKG_BUILD_PARALLEL:=1
PKG_EXTMOD_SUBDIRS:=ath10k$(CT_KVER)

STAMP_CONFIGURED_DEPENDS := $(STAGING_DIR)/usr/include/mac80211-backport/backport/autoconf.h

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define KernelPackage/ath10k-ct
  SUBMENU:=Wireless Drivers
  TITLE:=ath10k-ct driver optimized for CT ath10k firmware
  DEPENDS:=+kmod-mac80211 +kmod-ath +@DRIVER_11AC_SUPPORT @PCI_SUPPORT +kmod-hwmon-core +@PACKAGE_MAC80211_DEBUGFS
  FILES:=\
	$(PKG_BUILD_DIR)/ath10k$(CT_KVER)/ath10k_pci.ko \
	$(PKG_BUILD_DIR)/ath10k$(CT_KVER)/ath10k_core.ko
  AUTOLOAD:=$(call AutoProbe,ath10k_pci)
  PROVIDES:=kmod-ath10k
  VARIANT:=regular
endef

define KernelPackage/ath10k-ct/config

       config ATH10K-CT_LEDS
               bool "Enable LED support"
               default y
               depends on PACKAGE_kmod-ath10k-ct || PACKAGE_kmod-ath10k-ct-smallbuffers
endef

define KernelPackage/ath10k-ct-smallbuffers
$(call KernelPackage/ath10k-ct)
  TITLE+= (small buffers for low-RAM devices)
  VARIANT:=smallbuffers
endef

NOSTDINC_FLAGS := \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-include backport/autoconf.h \
	-include backport/backport.h

ifdef CONFIG_PACKAGE_MAC80211_MESH
  NOSTDINC_FLAGS += -DCONFIG_MAC80211_MESH
endif

CT_MAKEDEFS += CONFIG_ATH10K=m CONFIG_ATH10K_PCI=m CONFIG_ATH10K_CE=y

# This AHB logic is needed for IPQ4019 radios
CT_MAKEDEFS += CONFIG_ATH10K_AHB=m
NOSTDINC_FLAGS += -DCONFIG_ATH10K_AHB

NOSTDINC_FLAGS += -DSTANDALONE_CT

ifdef CONFIG_PACKAGE_MAC80211_DEBUGFS
  CT_MAKEDEFS += CONFIG_ATH10K_DEBUGFS=y CONFIG_MAC80211_DEBUGFS=y
  NOSTDINC_FLAGS += -DCONFIG_MAC80211_DEBUGFS
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_DEBUGFS
endif

ifdef CONFIG_PACKAGE_ATH_DEBUG
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_DEBUG
endif

ifdef CONFIG_PACKAGE_ATH_DFS
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_DFS_CERTIFIED
endif

ifdef CONFIG_PACKAGE_ATH_SPECTRAL
  CT_MAKEDEFS += CONFIG_ATH10K_SPECTRAL=y
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_SPECTRAL
endif

ifeq ($(CONFIG_ATH10K-CT_LEDS),y)
  CT_MAKEDEFS += CONFIG_ATH10K_LEDS=y
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_LEDS
endif

ifeq ($(BUILD_VARIANT),smallbuffers)
  NOSTDINC_FLAGS += -DCONFIG_ATH10K_SMALLBUFFERS
endif

define Build/Configure
	cp $(STAGING_DIR)/usr/include/mac80211/ath/*.h $(PKG_BUILD_DIR)
endef

ifneq ($(findstring c,$(OPENWRT_VERBOSE)),)
  CT_MAKEDEFS += V=1
endif

define Build/Compile
	+$(KERNEL_MAKE) $(CT_MAKEDEFS) $(PKG_JOBS) \
		M="$(PKG_BUILD_DIR)/ath10k$(CT_KVER)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		modules
endef

$(eval $(call KernelPackage,ath10k-ct))
$(eval $(call KernelPackage,ath10k-ct-smallbuffers))
